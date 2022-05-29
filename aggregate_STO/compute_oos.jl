using Base: Float64, @var
using Gurobi
using Cbc
using Clp
using JuMP
using Printf
import Base
using Random, Distributions
using JSON
using DataStructures
using JSON: print
using GZip
import Base: getindex, time
using DataStructures: push!
basedir = homedir()
push!(LOAD_PATH,"$basedir/.julia/packages/UnitCommitmentSTO/6AWag/src/")
import UnitCommitmentSTO
import MathOptInterface
using LinearAlgebra
function timeseries(x, T; default = nothing)
    x !== nothing || return default
    x isa Array || return [x for t in 1:T]
    return x
end

function create_sub_hor(f_name, i, tn, snumbers, a, b, f)
    for sval in snumbers
        sn=1
        oos_file = open("results/$(a)_$(b)_$(f)/oos/oos_$(i)/s$(sval)/$(split(f_name,".")[1])_$(i).json")
        json=JSON.parse(oos_file, dicttype = () -> DefaultOrderedDict(nothing))
        bn= length(json["Buses"])
        gn = length(json["Generators"])
        ts = scalar(json["Parameters"]["Time step (min)"], default = 60) #15 min
        tf = convert(Int64, (60/ts)) #4 How many intra-hourly time periods do we represent in each hour? 
        orig_T = json["Parameters"]["Time (h)"]  #24
        if orig_T === nothing
            orig_T = json["Parameters"]["Time horizon (h)"]
        end
        tnum = convert(Int64, orig_T * tf) #96 total number of original intra-hourly time periods
        fnum = convert(Int64, tnum / tn) #24 number of RTM files
        T = convert(Int64, tn / tf) # tn = 4, tf = 4 Horizon of RTM in hours
        ls_s = zeros(bn, tnum) 
        loads=[]
        for (bus_name, dict) in json["Buses"]
            load=dict["s1"]["Load (MW)"]
            push!(loads, load)
        end
        for b in 1:bn
            ls_s[b,:]=abs.(timeseries(loads[b], tnum))
        end
        
        for j in 1:fnum
            nf = open("results/$(a)_$(b)_$(f)/oos/oos_$(i)/s$(sval)/$(split(f_name,".")[1])_$(i)_sub$(j).json", "w")
            # T = json["Parameters"]["Time (h)"]
            # if T === nothing
            #     T = json["Parameters"]["Time horizon (h)"]
            # end
            println(nf,"{")
            println(nf, "\"Parameters\": {")
            if j!=fnum
                power_balance_penalty = timeseries(
                    convert(Vector{Float64}, json["Parameters"]["Power balance penalty (\$/MW)"]),
                    default = [5000.0 for t in 1:tf*(j + 1)], tf*(j + 1)
                )
            else
                power_balance_penalty = timeseries(
                    convert(Vector{Float64}, json["Parameters"]["Power balance penalty (\$/MW)"]),
                    default = [5000.0 for t in 1:tf*(j)], tf*(j)
                )
            end
            println(nf, "\t\"Power balance penalty (\$/MW)\": ",power_balance_penalty,",")
            println(nf, "\t\"Scenario number\": 1,")
            if j!=fnum
                println(nf, "\t\"Time horizon (h)\": ", j + 1,",")
            else
                println(nf, "\t\"Time horizon (h)\": ", j ,",")
            end
            println(nf, "\t\"Time step (min)\": ", ts,"},")
            println(nf, "\t\"Generators\": {")
            for g in 1:gn
                println(nf,"\t\t\"g$g\": {")
                println(nf, "\t\t\t\"Bus\": \"", json["Generators"]["g$g"]["Bus"],"\",") 
                println(nf, "\t\t\t\"Production cost curve (MW)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Production cost curve (MW)"]),",")
                println(nf, "\t\t\t\"Production cost curve (\$)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Production cost curve (\$)"]),",")
                st_cost = scalar(convert(Array{Float64},json["Generators"]["g$g"]["Startup costs (\$)"]), default = [0.0])
                st_delay = scalar(convert(Array{Float64},json["Generators"]["g$g"]["Startup delays (h)"]), default = [0.0])
                println(nf, "\t\t\t\"Startup costs (\$)\": ", st_cost,",")
                println(nf, "\t\t\t\"Startup delays (h)\": ", st_delay,",") 
                ramp_up = scalar(json["Generators"]["g$g"]["Ramp up limit (MW)"], default = 1e6)
                ramp_dw = scalar(json["Generators"]["g$g"]["Ramp down limit (MW)"], default = 1e6)
                println(nf, "\t\t\t\"Ramp up limit (MW)\": ",ramp_up,",") 
                println(nf, "\t\t\t\"Ramp down limit (MW)\": ", ramp_dw,",") 
                st_up = scalar(json["Generators"]["g$g"]["Startup limit (MW)"], default = 1e6)
                sh_dw = scalar(json["Generators"]["g$g"]["Shutdown limit (MW)"], default = 1e6)
                println(nf, "\t\t\t\"Startup limit (MW)\": ", st_up,",") 
                println(nf, "\t\t\t\"Shutdown limit (MW)\": ", sh_dw,",") 
                min_up = scalar(json["Generators"]["g$g"]["Minimum uptime (h)"], default = 1)
                min_dw = scalar(json["Generators"]["g$g"]["Minimum downtime (h)"], default = 1)
                println(nf, "\t\t\t\"Minimum uptime (h)\": ", min_up,",") 
                println(nf, "\t\t\t\"Minimum downtime (h)\": ", min_dw,",") 
                # m_run =  timeseries(json["Generators"]["g$g"]["Must run?"], T, default = ["false" for t in 1:T])
                # println(nf, "\t\t\t\"Must run?\": ", m_run,",") 
                # pr_sp_re = timeseries(json["Generators"]["g$g"]["Provides spinning reserve?"],T, default = ["true" for t in 1:T])
                # println(nf, "\t\t\t\"Provides spinning reserve?\": ",pr_sp_re ,",") 
                # pr_fl_ca = timeseries(json["Generators"]["g$g"]["Provides flexible capacity?"]~, default = ["true" for t in 1:T])
                # println(nf, "\t\t\t\"Provides flexible capacity?\": ",pr_fl_ca ,",") 
                initial_power = scalar(json["Generators"]["g$g"]["Initial power (MW)"], default = nothing)
                initial_status = scalar(json["Generators"]["g$g"]["Initial status (h)"], default = nothing)
                println(nf, "\t\t\t\"Initial status (h)\": ", initial_status,",") 
                if g!=gn
                    println(nf, "\t\t\t\"Initial power (MW)\": ", initial_power,"\n\t\t},") 
                else
                    println(nf, "\t\t\t\"Initial power (MW)\": ", initial_power,"\n\t\t}\n\t},") 
                end
            end
            if json["Transmission lines"] !== nothing
                ln = length(json["Transmission lines"])
                println(nf, "\t\"Transmission lines\": {")
                for l in 1:ln
                    println(nf,"\t\t\"l$l\": {")
                    println(nf,"\t\t\t\"Source bus\": \"", json["Transmission lines"]["l$l"]["Source bus"],"\",")
                    println(nf,"\t\t\t\"Target bus\": \"", json["Transmission lines"]["l$l"]["Target bus"],"\",")
                    println(nf,"\t\t\t\"Reactance (ohms)\": ", json["Transmission lines"]["l$l"]["Reactance (ohms)"],",")
                    println(nf,"\t\t\t\"Susceptance (S)\": ", json["Transmission lines"]["l$l"]["Susceptance (S)"])
                    if l!=ln
                        println(nf,"\t\t},")
                    else
                        println(nf,"\t\t}\n\t},")
                    end
                end
            end
            if j<fnum
                thor = convert(Int8, tf * (j + 1))
            else
                thor = convert(Int8, tf * (j))
            end
            println(nf,"\t\"Buses\": {")
            for b in 1:bn
                println(nf,"\t\t\"b$b\": {")
                for s in 1:sn
                    println(nf,"\t\t\t\"s$s\": {")
                    println(nf,"\t\t\t\t\"Load (MW)\":[")
                    for t in 1:thor
                        if t<=tnum
                            if t!=thor
                                println(nf,"\t\t\t\t\t$(ls_s[b, t]),")
                            else
                                println(nf,"\t\t\t\t\t$(ls_s[b, t])")
                            end
                        else
                            if t!=thor
                                println(nf,"\t\t\t\t\t$(ls_s[b, tnum]),")
                            else
                                println(nf,"\t\t\t\t\t$(ls_s[b, tnum])")
                            end
                        end
                    end
                    println(nf,"\t\t\t\t],")
                    println(nf, "\"Probability\":", 1)
                    if s!=sn
                        println(nf,"\t\t\t},")
                    else
                        println(nf,"\t\t\t}")
                    end
                end
                if b!=bn
                    println(nf,"\t\t},")
                else
                    println(nf,"\t\t}")
                end
            end
            println(nf,"\t},")
            @printf(nf, "\n\t\"Reserves\": {\n")
            @printf(nf, "\t\t\"Up-FRP (MW)\": [\n")
            for t in 1:thor-1
                @printf(nf, "\t\t\t%f, \n", json["Reserves"]["Up-FRP (MW)"][t])
            end
            @printf(nf, "\t\t\t%f],\n", json["Reserves"]["Up-FRP (MW)"][thor])
            @printf(nf, "\t\t\"Down-FRP (MW)\": [\n")
            for t in 1:thor-1
                @printf(nf, "\t\t\t%f, \n", json["Reserves"]["Down-FRP (MW)"][t])
            end
            @printf(nf, "\t\t\t%f]\n", json["Reserves"]["Down-FRP (MW)"][thor])
            @printf(nf, "\t}\n")
            @printf(nf, "}")
            close(nf)
        end
    end
    sn=1
    oos_file = open("results/$(a)_$(b)_$(f)/oos/oos_$(i)/single/$(split(f_name,".")[1])_$(i).json")
    json=JSON.parse(oos_file, dicttype = () -> DefaultOrderedDict(nothing))
    bn= length(json["Buses"])
    gn = length(json["Generators"])
    ts = scalar(json["Parameters"]["Time step (min)"], default = 60) #15 min
    tf = convert(Int64, (60/ts)) #4 How many intra-hourly time periods do we represent in each hour? 
    orig_T = json["Parameters"]["Time (h)"]  #24
    if orig_T === nothing
        orig_T = json["Parameters"]["Time horizon (h)"]
    end
    tnum = convert(Int64, orig_T * tf) #96 total number of original intra-hourly time periods
    fnum = convert(Int64, tnum / tn) #24 number of RTM files
    T = convert(Int64, tn / tf) # tn = 4, tf = 4 Horizon of RTM in hours
    ls_s = zeros(bn, tnum) 
    loads=[]
    for (bus_name, dict) in json["Buses"]
        load=dict["s1"]["Load (MW)"]
        push!(loads, load)
    end
    for b in 1:bn
        ls_s[b,:]=abs.(timeseries(loads[b], tnum))
    end
    
    for j in 1:fnum
        nf = open("results/$(a)_$(b)_$(f)/oos/oos_$(i)/single/$(split(f_name,".")[1])_$(i)_sub$(j).json", "w")
        # T = json["Parameters"]["Time (h)"]
        # if T === nothing
        #     T = json["Parameters"]["Time horizon (h)"]
        # end
        println(nf,"{")
        println(nf, "\"Parameters\": {")
        if j!=fnum
            power_balance_penalty = timeseries(
                convert(Vector{Float64}, json["Parameters"]["Power balance penalty (\$/MW)"]),
                default = [1000.0 for t in 1:tf*(j + 1)], tf*(j + 1)
            )
        else
            power_balance_penalty = timeseries(
                convert(Vector{Float64}, json["Parameters"]["Power balance penalty (\$/MW)"]),
                default = [1000.0 for t in 1:tf*(j)], tf*(j)
            )
        end
        println(nf, "\t\"Power balance penalty (\$/MW)\": ",power_balance_penalty,",")
        println(nf, "\t\"Scenario number\": 1,")
        if j!=fnum
            println(nf, "\t\"Time horizon (h)\": ", j + 1,",")
        else
            println(nf, "\t\"Time horizon (h)\": ", j ,",")
        end
        println(nf, "\t\"Time step (min)\": ", ts,"},")
        println(nf, "\t\"Generators\": {")
        for g in 1:gn
            println(nf,"\t\t\"g$g\": {")
            println(nf, "\t\t\t\"Bus\": \"", json["Generators"]["g$g"]["Bus"],"\",") 
            println(nf, "\t\t\t\"Production cost curve (MW)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Production cost curve (MW)"]),",")
            println(nf, "\t\t\t\"Production cost curve (\$)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Production cost curve (\$)"]),",")
            st_cost = scalar(convert(Array{Float64},json["Generators"]["g$g"]["Startup costs (\$)"]), default = [0.0])
            st_delay = scalar(convert(Array{Float64},json["Generators"]["g$g"]["Startup delays (h)"]), default = [0.0])
            println(nf, "\t\t\t\"Startup costs (\$)\": ", st_cost,",")
            println(nf, "\t\t\t\"Startup delays (h)\": ", st_delay,",") 
            ramp_up = scalar(json["Generators"]["g$g"]["Ramp up limit (MW)"], default = 1e6)
            ramp_dw = scalar(json["Generators"]["g$g"]["Ramp down limit (MW)"], default = 1e6)
            println(nf, "\t\t\t\"Ramp up limit (MW)\": ",ramp_up,",") 
            println(nf, "\t\t\t\"Ramp down limit (MW)\": ", ramp_dw,",") 
            st_up = scalar(json["Generators"]["g$g"]["Startup limit (MW)"], default = 1e6)
            sh_dw = scalar(json["Generators"]["g$g"]["Shutdown limit (MW)"], default = 1e6)
            println(nf, "\t\t\t\"Startup limit (MW)\": ", st_up,",") 
            println(nf, "\t\t\t\"Shutdown limit (MW)\": ", sh_dw,",") 
            min_up = scalar(json["Generators"]["g$g"]["Minimum uptime (h)"], default = 1)
            min_dw = scalar(json["Generators"]["g$g"]["Minimum downtime (h)"], default = 1)
            println(nf, "\t\t\t\"Minimum uptime (h)\": ", min_up,",") 
            println(nf, "\t\t\t\"Minimum downtime (h)\": ", min_dw,",") 
            # m_run =  timeseries(json["Generators"]["g$g"]["Must run?"], T, default = ["false" for t in 1:T])
            # println(nf, "\t\t\t\"Must run?\": ", m_run,",") 
            # pr_sp_re = timeseries(json["Generators"]["g$g"]["Provides spinning reserve?"],T, default = ["true" for t in 1:T])
            # println(nf, "\t\t\t\"Provides spinning reserve?\": ",pr_sp_re ,",") 
            # pr_fl_ca = timeseries(json["Generators"]["g$g"]["Provides flexible capacity?"]~, default = ["true" for t in 1:T])
            # println(nf, "\t\t\t\"Provides flexible capacity?\": ",pr_fl_ca ,",") 
            initial_power = scalar(json["Generators"]["g$g"]["Initial power (MW)"], default = nothing)
            initial_status = scalar(json["Generators"]["g$g"]["Initial status (h)"], default = nothing)
            println(nf, "\t\t\t\"Initial status (h)\": ", initial_status,",") 
            if g!=gn
                println(nf, "\t\t\t\"Initial power (MW)\": ", initial_power,"\n\t\t},") 
            else
                println(nf, "\t\t\t\"Initial power (MW)\": ", initial_power,"\n\t\t}\n\t},") 
            end
        end
        if json["Transmission lines"] !== nothing
            ln = length(json["Transmission lines"])
            println(nf, "\t\"Transmission lines\": {")
            for l in 1:ln
                println(nf,"\t\t\"l$l\": {")
                println(nf,"\t\t\t\"Source bus\": \"", json["Transmission lines"]["l$l"]["Source bus"],"\",")
                println(nf,"\t\t\t\"Target bus\": \"", json["Transmission lines"]["l$l"]["Target bus"],"\",")
                println(nf,"\t\t\t\"Reactance (ohms)\": ", json["Transmission lines"]["l$l"]["Reactance (ohms)"],",")
                println(nf,"\t\t\t\"Susceptance (S)\": ", json["Transmission lines"]["l$l"]["Susceptance (S)"])
                if l!=ln
                    println(nf,"\t\t},")
                else
                    println(nf,"\t\t}\n\t},")
                end
            end
        end
        if j<fnum
            thor = convert(Int8, tf * (j + 1))
        else
            thor = convert(Int8, tf * (j))
        end
        println(nf,"\t\"Buses\": {")
        for b in 1:bn
            println(nf,"\t\t\"b$b\": {")
            for s in 1:sn
                println(nf,"\t\t\t\"s$s\": {")
                println(nf,"\t\t\t\t\"Load (MW)\":[")
                for t in 1:thor
                    if t<=tnum
                        if t!=thor
                            println(nf,"\t\t\t\t\t$(ls_s[b, t]),")
                        else
                            println(nf,"\t\t\t\t\t$(ls_s[b, t])")
                        end
                    else
                        if t!=thor
                            println(nf,"\t\t\t\t\t$(ls_s[b, tnum]),")
                        else
                            println(nf,"\t\t\t\t\t$(ls_s[b, tnum])")
                        end
                    end
                end
                println(nf,"\t\t\t\t],")
                println(nf, "\"Probability\":", 1)
                if s!=sn
                    println(nf,"\t\t\t},")
                else
                    println(nf,"\t\t\t}")
                end
            end
            if b!=bn
                println(nf,"\t\t},")
            else
                println(nf,"\t\t}")
            end
        end
        println(nf,"\t},")
        @printf(nf, "\n\t\"Reserves\": {\n")
        @printf(nf, "\t\t\"Up-FRP (MW)\": [\n")
        for t in 1:thor-1
            @printf(nf, "\t\t\t%f, \n", json["Reserves"]["Up-FRP (MW)"][t])
        end
        @printf(nf, "\t\t\t%f],\n", json["Reserves"]["Up-FRP (MW)"][thor])
        @printf(nf, "\t\t\"Down-FRP (MW)\": [\n")
        for t in 1:thor-1
            @printf(nf, "\t\t\t%f, \n", json["Reserves"]["Down-FRP (MW)"][t])
        end
        @printf(nf, "\t\t\t%f]\n", json["Reserves"]["Down-FRP (MW)"][thor])
        @printf(nf, "\t}\n")
        @printf(nf, "}")
        close(nf)
    end
    oos_file = open("results/$(a)_$(b)_$(f)/oos/oos_$(i)/wout/$(split(f_name,".")[1])_$(i).json")
    json=JSON.parse(oos_file, dicttype = () -> DefaultOrderedDict(nothing))
    bn= length(json["Buses"])
    gn = length(json["Generators"])
    ts = scalar(json["Parameters"]["Time step (min)"], default = 60) #15 min
    tf = convert(Int64, (60/ts)) #4 How many intra-hourly time periods do we represent in each hour? 
    orig_T = json["Parameters"]["Time (h)"]  #24
    if orig_T === nothing
        orig_T = json["Parameters"]["Time horizon (h)"]
    end
    tnum = convert(Int64, orig_T * tf) #96 total number of original intra-hourly time periods
    fnum = convert(Int64, tnum / tn) #24 number of RTM files
    T = convert(Int64, tn / tf) # tn = 4, tf = 4 Horizon of RTM in hours
    ls_s = zeros(bn, tnum) 
    loads=[]
    for (bus_name, dict) in json["Buses"]
        load=dict["s1"]["Load (MW)"]
        push!(loads, load)
    end
    for b in 1:bn
        ls_s[b,:]=abs.(timeseries(loads[b], tnum))
    end
    
    for j in 1:fnum
        nf = open("results/$(a)_$(b)_$(f)/oos/oos_$(i)/wout/$(split(f_name,".")[1])_$(i)_sub$(j).json", "w")
        # T = json["Parameters"]["Time (h)"]
        # if T === nothing
        #     T = json["Parameters"]["Time horizon (h)"]
        # end
        println(nf,"{")
        println(nf, "\"Parameters\": {")
        if j!=fnum
            power_balance_penalty = timeseries(
                convert(Vector{Float64}, json["Parameters"]["Power balance penalty (\$/MW)"]),
                default = [1000.0 for t in 1:tf*(j + 1)], tf*(j + 1)
            )
        else
            power_balance_penalty = timeseries(
                convert(Vector{Float64}, json["Parameters"]["Power balance penalty (\$/MW)"]),
                default = [1000.0 for t in 1:tf*(j)], tf*(j)
            )
        end
        println(nf, "\t\"Power balance penalty (\$/MW)\": ",power_balance_penalty,",")
        println(nf, "\t\"Scenario number\": 1,")
        if j!=fnum
            println(nf, "\t\"Time horizon (h)\": ", j + 1,",")
        else
            println(nf, "\t\"Time horizon (h)\": ", j ,",")
        end
        println(nf, "\t\"Time step (min)\": ", ts,"},")
        println(nf, "\t\"Generators\": {")
        for g in 1:gn
            println(nf,"\t\t\"g$g\": {")
            println(nf, "\t\t\t\"Bus\": \"", json["Generators"]["g$g"]["Bus"],"\",") 
            println(nf, "\t\t\t\"Production cost curve (MW)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Production cost curve (MW)"]),",")
            println(nf, "\t\t\t\"Production cost curve (\$)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Production cost curve (\$)"]),",")
            st_cost = scalar(convert(Array{Float64},json["Generators"]["g$g"]["Startup costs (\$)"]), default = [0.0])
            st_delay = scalar(convert(Array{Float64},json["Generators"]["g$g"]["Startup delays (h)"]), default = [0.0])
            println(nf, "\t\t\t\"Startup costs (\$)\": ", st_cost,",")
            println(nf, "\t\t\t\"Startup delays (h)\": ", st_delay,",") 
            ramp_up = scalar(json["Generators"]["g$g"]["Ramp up limit (MW)"], default = 1e6)
            ramp_dw = scalar(json["Generators"]["g$g"]["Ramp down limit (MW)"], default = 1e6)
            println(nf, "\t\t\t\"Ramp up limit (MW)\": ",ramp_up,",") 
            println(nf, "\t\t\t\"Ramp down limit (MW)\": ", ramp_dw,",") 
            st_up = scalar(json["Generators"]["g$g"]["Startup limit (MW)"], default = 1e6)
            sh_dw = scalar(json["Generators"]["g$g"]["Shutdown limit (MW)"], default = 1e6)
            println(nf, "\t\t\t\"Startup limit (MW)\": ", st_up,",") 
            println(nf, "\t\t\t\"Shutdown limit (MW)\": ", sh_dw,",") 
            min_up = scalar(json["Generators"]["g$g"]["Minimum uptime (h)"], default = 1)
            min_dw = scalar(json["Generators"]["g$g"]["Minimum downtime (h)"], default = 1)
            println(nf, "\t\t\t\"Minimum uptime (h)\": ", min_up,",") 
            println(nf, "\t\t\t\"Minimum downtime (h)\": ", min_dw,",") 
            # m_run =  timeseries(json["Generators"]["g$g"]["Must run?"], T, default = ["false" for t in 1:T])
            # println(nf, "\t\t\t\"Must run?\": ", m_run,",") 
            # pr_sp_re = timeseries(json["Generators"]["g$g"]["Provides spinning reserve?"],T, default = ["true" for t in 1:T])
            # println(nf, "\t\t\t\"Provides spinning reserve?\": ",pr_sp_re ,",") 
            # pr_fl_ca = timeseries(json["Generators"]["g$g"]["Provides flexible capacity?"]~, default = ["true" for t in 1:T])
            # println(nf, "\t\t\t\"Provides flexible capacity?\": ",pr_fl_ca ,",") 
            initial_power = scalar(json["Generators"]["g$g"]["Initial power (MW)"], default = nothing)
            initial_status = scalar(json["Generators"]["g$g"]["Initial status (h)"], default = nothing)
            println(nf, "\t\t\t\"Initial status (h)\": ", initial_status,",") 
            if g!=gn
                println(nf, "\t\t\t\"Initial power (MW)\": ", initial_power,"\n\t\t},") 
            else
                println(nf, "\t\t\t\"Initial power (MW)\": ", initial_power,"\n\t\t}\n\t},") 
            end
        end
        if json["Transmission lines"] !== nothing
            ln = length(json["Transmission lines"])
            println(nf, "\t\"Transmission lines\": {")
            for l in 1:ln
                println(nf,"\t\t\"l$l\": {")
                println(nf,"\t\t\t\"Source bus\": \"", json["Transmission lines"]["l$l"]["Source bus"],"\",")
                println(nf,"\t\t\t\"Target bus\": \"", json["Transmission lines"]["l$l"]["Target bus"],"\",")
                println(nf,"\t\t\t\"Reactance (ohms)\": ", json["Transmission lines"]["l$l"]["Reactance (ohms)"],",")
                println(nf,"\t\t\t\"Susceptance (S)\": ", json["Transmission lines"]["l$l"]["Susceptance (S)"])
                if l!=ln
                    println(nf,"\t\t},")
                else
                    println(nf,"\t\t}\n\t},")
                end
            end
        end
        if j<fnum
            thor = convert(Int8, tf * (j + 1))
        else
            thor = convert(Int8, tf * (j))
        end
        println(nf,"\t\"Buses\": {")
        for b in 1:bn
            println(nf,"\t\t\"b$b\": {")
            for s in 1:sn
                println(nf,"\t\t\t\"s$s\": {")
                println(nf,"\t\t\t\t\"Load (MW)\":[")
                for t in 1:thor
                    if t<=tnum
                        if t!=thor
                            println(nf,"\t\t\t\t\t$(ls_s[b, t]),")
                        else
                            println(nf,"\t\t\t\t\t$(ls_s[b, t])")
                        end
                    else
                        if t!=thor
                            println(nf,"\t\t\t\t\t$(ls_s[b, tnum]),")
                        else
                            println(nf,"\t\t\t\t\t$(ls_s[b, tnum])")
                        end
                    end
                end
                println(nf,"\t\t\t\t],")
                println(nf, "\"Probability\":", 1)
                if s!=sn
                    println(nf,"\t\t\t},")
                else
                    println(nf,"\t\t\t}")
                end
            end
            if b!=bn
                println(nf,"\t\t},")
            else
                println(nf,"\t\t}")
            end
        end
        println(nf,"\t}")
        @printf(nf, "}")
        close(nf)
    end
    
end


function write_to_oos_file(path, i, rtm_hor, snumbers, sys_upfrp_reqs, sys_dwfrp_reqs, frp_req_file, a, b, f)
    file=open(path)
    json=JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
    jsonfrp=JSON.parse(open(frp_req_file), dicttype = () -> DefaultOrderedDict(nothing))
    sn=1
    mkdir("results/$(a)_$(b)_$(f)/oos/oos_$(i)")
    nf = open("results/$(a)_$(b)_$(f)/oos/oos_$(i)/$(split(f_name,".")[1])_$(i).json", "w")
    bn= length(json["Buses"])
    gn = length(json["Generators"])
    T = json["Parameters"]["Time (h)"]
    if T === nothing
        T = json["Parameters"]["Time horizon (h)"]
    end
    ts = scalar(json["Parameters"]["Time step (min)"], default = 60)
    tf = convert(Int64, (60/ts))
    tn = convert(Int64, T*tf)
    ls_s = zeros(bn, tn)
    loads=[]
    for (bus_name, dict) in json["Buses"]
        load=dict["Load (MW)"]
        push!(loads, load)
    end
    for b in 1:bn
       temp = abs.(timeseries(loads[b], tn))
        for t in 1:tn
            d = Normal(0, temp[t]* a * f / 100)
            ls_s[b,t]=abs.(temp[t]+rand(d))
        end
    end
    println(nf,"{")
    println(nf, "\"Parameters\": {")
    power_balance_penalty = timeseries(
        json["Parameters"]["Power balance penalty (\$/MW)"],
        default = [100000.0 for t in 1:tn], tn
    )
    println(nf, "\t\"Power balance penalty (\$/MW)\": ", convert(Vector{Float64}, power_balance_penalty),",")
    println(nf, "\t\"Scenario number\": 1,")
    println(nf, "\t\"Time horizon (h)\": ", T,",")
    println(nf, "\t\"Time step (min)\": ", ts,"},")
    println(nf, "\t\"Generators\": {")
    for g in 1:gn
        println(nf,"\t\t\"g$g\": {")
        println(nf, "\t\t\t\"Bus\": \"", json["Generators"]["g$g"]["Bus"],"\",") 
        println(nf, "\t\t\t\"Production cost curve (MW)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Production cost curve (MW)"]),",")
        println(nf, "\t\t\t\"Production cost curve (\$)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Production cost curve (\$)"]),",")
        st_cost = scalar(convert(Array{Float64},json["Generators"]["g$g"]["Startup costs (\$)"]), default = [0.0])
        st_delay = scalar(convert(Array{Float64},json["Generators"]["g$g"]["Startup delays (h)"]), default = [0.0])
        println(nf, "\t\t\t\"Startup costs (\$)\": ", st_cost,",")
        println(nf, "\t\t\t\"Startup delays (h)\": ", st_delay,",") 
        ramp_up = scalar(json["Generators"]["g$g"]["Ramp up limit (MW)"], default = 1e6)
        ramp_dw = scalar(json["Generators"]["g$g"]["Ramp down limit (MW)"], default = 1e6)
        println(nf, "\t\t\t\"Ramp up limit (MW)\": ",ramp_up,",") 
        println(nf, "\t\t\t\"Ramp down limit (MW)\": ", ramp_dw,",") 
        st_up = scalar(json["Generators"]["g$g"]["Startup limit (MW)"], default = 1e6)
        sh_dw = scalar(json["Generators"]["g$g"]["Shutdown limit (MW)"], default = 1e6)
        println(nf, "\t\t\t\"Startup limit (MW)\": ", st_up,",") 
        println(nf, "\t\t\t\"Shutdown limit (MW)\": ", sh_dw,",") 
        min_up = scalar(json["Generators"]["g$g"]["Minimum uptime (h)"], default = 1)
        min_dw = scalar(json["Generators"]["g$g"]["Minimum downtime (h)"], default = 1)
        println(nf, "\t\t\t\"Minimum uptime (h)\": ", min_up,",") 
        println(nf, "\t\t\t\"Minimum downtime (h)\": ", min_dw,",") 
        # m_run =  timeseries(json["Generators"]["g$g"]["Must run?"], T, default = ["false" for t in 1:T])
        # println(nf, "\t\t\t\"Must run?\": ", m_run,",") 
        # pr_sp_re = timeseries(json["Generators"]["g$g"]["Provides spinning reserve?"],T, default = ["true" for t in 1:T])
        # println(nf, "\t\t\t\"Provides spinning reserve?\": ",pr_sp_re ,",") 
        # pr_fl_ca = timeseries(json["Generators"]["g$g"]["Provides flexible capacity?"]~, default = ["true" for t in 1:T])
        # println(nf, "\t\t\t\"Provides flexible capacity?\": ",pr_fl_ca ,",") 
        initial_power = scalar(json["Generators"]["g$g"]["Initial power (MW)"], default = nothing)
        initial_status = scalar(json["Generators"]["g$g"]["Initial status (h)"], default = nothing)
        println(nf, "\t\t\t\"Initial status (h)\": ", initial_status,",") 
        if g!=gn
            println(nf, "\t\t\t\"Initial power (MW)\": ", initial_power,"\n\t\t},") 
        else
            println(nf, "\t\t\t\"Initial power (MW)\": ", initial_power,"\n\t\t}\n\t},") 
        end
    end
    if json["Transmission lines"] !== nothing
        ln = length(json["Transmission lines"])
        println(nf, "\t\"Transmission lines\": {")
        for l in 1:ln
            println(nf,"\t\t\"l$l\": {")
            println(nf,"\t\t\t\"Source bus\": \"", json["Transmission lines"]["l$l"]["Source bus"],"\",")
            println(nf,"\t\t\t\"Target bus\": \"", json["Transmission lines"]["l$l"]["Target bus"],"\",")
            println(nf,"\t\t\t\"Reactance (ohms)\": ", json["Transmission lines"]["l$l"]["Reactance (ohms)"],",")
            println(nf,"\t\t\t\"Susceptance (S)\": ", json["Transmission lines"]["l$l"]["Susceptance (S)"])
            if l!=ln
                println(nf,"\t\t},")
            else
                println(nf,"\t\t}\n\t},")
            end
        end
    end

    println(nf,"\t\"Buses\": {")
    for b in 1:bn
        println(nf,"\t\t\"b$b\": {")
        for s in 1:sn
            println(nf,"\t\t\t\"s$s\": {")
            println(nf,"\t\t\t\t\"Load (MW)\":[")
            for t in 1:tn
                if t!=tn
                    println(nf,"\t\t\t\t\t$(ls_s[b,t]),")
                else
                    println(nf,"\t\t\t\t\t$(ls_s[b,t])")
                end
            end
            println(nf,"\t\t\t\t],")
            println(nf, "\"Probability\":", 1)
            if s!=sn
                println(nf,"\t\t\t},")
            else
                println(nf,"\t\t\t}")
            end
        end
        if b!=bn
            println(nf,"\t\t},")
        else
            println(nf,"\t\t}")
        end
    end
    println(nf,"\t}")
    println(nf, "}")
    close(nf)
    old_f = "results/$(a)_$(b)_$(f)/oos/oos_$(i)/$(split(f_name,".")[1])_$(i).json"
    lines = readlines(old_f)
    for sn in snumbers
        mkdir("results/$(a)_$(b)_$(f)/oos/oos_$(i)/s$(sn)")
        nf = open("results/$(a)_$(b)_$(f)/oos/oos_$(i)/s$(sn)/$(split(f_name,".")[1])_$(i).json", "w")
        for i in 1:length(lines)-1
            println(nf, lines[i])
        end
        @printf(nf, ",\n\t\"Reserves\": {\n")
        @printf(nf, "\t\t\"Up-FRP (MW)\": [\n")
        for t in 1:tn-1
            # @printf(nf, "\t\t\t%f, \n", sys_upfrp_reqs[sn][t])
            @printf(nf, "\t\t\t%f, \n", 0)
        end
        # @printf(nf, "\t\t\t%f],\n", sys_upfrp_reqs[sn][tn])
        @printf(nf, "\t\t\t%f],\n", 0)
        @printf(nf, "\t\t\"Down-FRP (MW)\": [\n")
        for t in 1:tn-1
            # @printf(nf, "\t\t\t%f, \n", sys_dwfrp_reqs[sn][t])
            @printf(nf, "\t\t\t%f, \n", 0)
        end
        # @printf(nf, "\t\t\t%f]\n", sys_dwfrp_reqs[sn][tn])
        @printf(nf, "\t\t\t%f]\n", 0)
        @printf(nf, "\t}\n")
        @printf(nf, "}")
        close(nf)
    end
    mkdir("results/$(a)_$(b)_$(f)/oos/oos_$(i)/single")
    nf = open("results/$(a)_$(b)_$(f)/oos/oos_$(i)/single/$(split(f_name,".")[1])_$(i).json", "w")
    for i in 1:length(lines)-1
        println(nf, lines[i])
    end
    @printf(nf, ",\n\t\"Reserves\": {\n")
    @printf(nf, "\t\t\"Up-FRP (MW)\": [\n")
    for t in 1:tn-1
        # @printf(nf, "\t\t\t%f, \n", jsonfrp["Reserves"]["Up-FRP (MW)"][t])
        @printf(nf, "\t\t\t%f, \n", 0)
    end
    # @printf(nf, "\t\t\t%f],\n", jsonfrp["Reserves"]["Up-FRP (MW)"][tn])
    @printf(nf, "\t\t\t%f], \n", 0)
    @printf(nf, "\t\t\"Down-FRP (MW)\": [\n")
    for t in 1:tn-1
        # @printf(nf, "\t\t\t%f, \n", jsonfrp["Reserves"]["Down-FRP (MW)"][t])
        @printf(nf, "\t\t\t%f, \n", 0)
    end
    # @printf(nf, "\t\t\t%f]\n", jsonfrp["Reserves"]["Down-FRP (MW)"][tn])
    @printf(nf, "\t\t\t%f] \n",0)
    @printf(nf, "\t}\n")
    @printf(nf, "}")
    close(nf)
    mkdir("results/$(a)_$(b)_$(f)/oos/oos_$(i)/wout")
    nf = open("results/$(a)_$(b)_$(f)/oos/oos_$(i)/wout/$(split(f_name,".")[1])_$(i).json", "w")
    for i in 1:length(lines)
        println(nf, lines[i])
    end
    close(nf)
    create_sub_hor(f_name, i, rtm_hor, snumbers, a, b, f)
end

function create_oos_files(path, snumbers, sn, rtm_hor, sys_upfrp_reqs, sys_dwfrp_reqs, frp_req_file, a, b, f)
    mkdir("results/$(a)_$(b)_$(f)/oos")
    for i in 1:sn
        write_to_oos_file(
        path, i, rtm_hor, snumbers, sys_upfrp_reqs, sys_dwfrp_reqs, frp_req_file, a, b, f
    )
    end
end

# function compute_oos_cost(comm_values, path, i)
#     instance = UnitCommitment.read("results/$(a)_$(b)_$(f)/oos/$(split(path,".")[1])_$i.json",)
#     model = UnitCommitment.build_model(
#         instance = instance,
#         optimizer = Gurobi.Optimizer,
#         formulation = UnitCommitment.Formulation(
#             )
#     )
#     g=0
#     for gen in instance.units
#         g+=1
#         for t in 1:instance.time
#             @constraint(model, model[:is_on][gen.name, t]==comm_values[g,t])
#         end
#     end
#     UnitCommitment.optimize!(model)
#     println(objective_value(model))
#     return objective_value(model)
# end


# function compute_oos_costs(comm_values, oos_sn, path)
#     oos_values=[]
#     for i in 1:oos_sn
#         oos_value=compute_oos_cost(comm_values, path, i)
#         push!(oos_values, oos_value)
#     end
#     return oos_values
# end
function read_comm_values(comm_path)
    comm_values=readlines(comm_path)
    gn=trunc(Int,((length(comm_values)-1)))
    tn=trunc(Int,((length(split(comm_values[2],"\t"))-3)/2))
    sto_comm_values=zeros(gn, tn)
    # det_comm_values=zeros(gn, tn)
    for i in 1:gn
        for j in 1:tn
            sto_comm_values[i,j]=parse(Int64, split(comm_values[i+1],"\t")[2j+1])
            # det_comm_values[i,j]=parse(Int64, split(comm_values[3i],"\t")[1+2j])
        end
    end
    return sto_comm_values
end
function read_commitment_values(comm_path)
    comm_values=readlines(comm_path)
    gn=trunc(Int,((length(comm_values)-1)/3))
    tn=trunc(Int,((length(split(comm_values[2],"\t"))-3)/2))
    sto_comm_values=zeros(gn, tn)
    det_comm_values=zeros(gn, tn)
    for i in 1:gn
        for j in 1:tn
            sto_comm_values[i,j]=parse(Int64, split(comm_values[-1+3i],"\t")[1+2j])
            det_comm_values[i,j]=parse(Int64, split(comm_values[3i],"\t")[1+2j])
        end
    end
    return sto_comm_values, det_comm_values
end


