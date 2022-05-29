using Base: Float64, @var
using Gurobi
using Cbc
using Clp
using JuMP
using Printf
import Base
basedir = homedir()
push!(LOAD_PATH,"content/flexiramp_imp/UnitCommitmentSTO/6AWag/src/")
import UnitCommitmentSTO
import MathOptInterface
using LinearAlgebra

function timeseries(x, T; default = nothing)
    x !== nothing || return default
    x isa Array || return [x for t in 1:T]
    return x
end

function write_to_det_file(f_path, f_name, a, b, f)
    mkdir("results/$(a)_$(b)_$(f)/det")
    file  = open(f_path)
    sn=1
    json=JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
    bn= length(json["Buses"])
    gn = length(json["Generators"])
    tn = json["Parameters"]["Time (h)"]
    if tn === nothing
        tn = json["Parameters"]["Time horizon (h)"]
    end
    ls_s=zeros(bn, tn)
    nf = open("results/$(a)_$(b)_$(f)/det/$(split(f_name,".")[1])_det.json", "w")
    println(nf,"{")
    println(nf, "\"Parameters\": {")
    power_balance_penalty = timeseries(
        nothing,
        default = [100000.0 for t in 1:tn], tn
    )
    println(nf, "\t\"Power balance penalty (\$/MW)\": ", power_balance_penalty,",")
    frp_penalty = timeseries(
        nothing,
        default = [20000.0 for t in 1:tn], tn
    )
    println(nf, "\t\"FRP penalty (\$/MW)\": ", convert(Vector{Float64}, frp_penalty),",")
    println(nf, "\t\"Scenario number\": 1,")
    println(nf, "\t\"Time (h)\": ", tn,"},")
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
    loads=[]
    for (bus_name, dict) in json["Buses"]
        load=dict["Load (MW)"]
        push!(loads, load)
    end
    for b in 1:bn
        ls_s[b,:]=abs.(timeseries(loads[b], tn))
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
            println(nf, "\"Probability\":", 1/sn)
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
    println(nf, "\t\"Reserves\": {")
    println(nf, "\t\t\"Spinning\": ")
    if json["Reserves"]["Spinning (MW)"] !== nothing
        println(nf, "\t\t\t[")
        for t in 1:tn
            if t!=tn
                println(nf,"\t\t\t",json["Reserves"]["Spinning (MW)"][t],",")
            else
                println(nf,"\t\t\t",json["Reserves"]["Spinning (MW)"][t],"\n\t\t]")
            end
        end
    else
        println(nf,timeseries(0, tn),",")
    end
    println(nf, "\t\t\"Up-FRP (MW)\": ")
    if json["Reserves"]["Up-FRP (MW)"] !== nothing
        println(nf, "\t\t\t[")
        for t in 1:tn
            if t!=tn
                println(nf,"\t\t\t",json["Reserves"]["Up-FRP (MW)"][t],",")
            else
                println(nf,"\t\t\t",json["Reserves"]["Up-FRP (MW)"][t],"\n\t\t],")
            end
        end
    else
        println(nf,timeseries(0, tn),",")
    end
    println(nf, "\t\t\"Down-FRP (MW)\": ")
    if json["Reserves"]["Down-FRP (MW)"] !== nothing
        println(nf, "\t\t\t[")
        for t in 1:tn
            if t!=tn
                println(nf,"\t\t\t",json["Reserves"]["Down-FRP (MW)"][t],",")
            else
                println(nf,"\t\t\t",json["Reserves"]["Down-FRP (MW)"][t],"\n\t\t]")
            end
        end
    else
        println(nf,timeseries(0, tn),",")
    end

    println(nf, "}\n}")
    close(nf)
end


function det_compute(f_name, snumbers)
    
    write_to_det_file(f_path, f_name, a, b, f)
    instance = UnitCommitmentSTO.read("results/$(a)_$(b)_$(f)/det/$(split(f_name,".")[1])_det.json")
    # instance = UnitCommitmentSTO.read_benchmark(
    # "matpower/case14/2017-08-01",)

    model = UnitCommitmentSTO.build_model(
        instance = instance,
        optimizer = Gurobi.Optimizer,
        formulation = UnitCommitmentSTO.Formulation(
            ramping = UnitCommitmentSTO.WanHob2016.Ramping()
            )
    )
    UnitCommitmentSTO.optimize!(model)
   
    for sn in snumbers
        nf = open("results/$(a)_$(b)_$(f)/comm_results/commitment_values_$(sn)_j.txt", "w")
        old_lines=readlines("results/$(a)_$(b)_$(f)/comm_results/commitment_values_$(sn).txt", keep=true)
        @printf(nf,"\t\t\t%s", old_lines[1])
        gn=0
        for g in instance.units
            gn+=1
            @printf(nf,"%s",old_lines[gn+1])
            if gn<10
                @printf(nf,"Determinis %s \t", g.name)
            else
                @printf(nf,"Determinis %s \t", g.name)
            end
            for t in 1:instance.time
                @printf(nf,"\t%d \t ", abs(value(model[:is_on][g.name, t])))
            end
            @printf(nf,"\n") 
            println(nf,'—'^310)
        end
        close(nf)
        
    end
    return objective_value(model)
end