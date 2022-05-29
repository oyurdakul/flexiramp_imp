using Base: Float64, @var
using Gurobi
using Cbc
using Clp
using JuMP
using Printf
import Base
include("sc_create_mul_bus.jl")
include("compute_met_load.jl")
basedir = homedir()
push!(LOAD_PATH,"$basedir/.julia/packages/UnitCommitmentSTO/6AWag/src/")
import UnitCommitmentSTO
import MathOptInterface
using LinearAlgebra

function extend_time(f_path, f_name, tm, d, a, b, f)
    file = open(f_path)
    mkdir("results/$(a)_$(b)_$(f)/scenarios")
    json=JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
    bn = length(json["Buses"])
    gn = length(json["Generators"])
    th = json["Parameters"]["Time (h)"]
    if th === nothing
        th = json["Parameters"]["Time horizon (h)"]
    end
    # ts = scalar(json["Parameters"]["Time step (min)"], default = 60)
    # (60 % ts == 0) ||
    #     error("Time step $ts is not a divisor of 60")
    # tm = 60 ÷ ts
    # tm = 4
    tn = th * tm
    ls_s=zeros(bn, th)
    ext_path = "results/$(a)_$(b)_$(f)/scenarios/$(split(f_name,".")[1])_ext.json"
    nf = open(ext_path, "w")
    println(nf,"{")
    println(nf, "\"Parameters\": {")
    power_balance_penalty = timeseries(
        json["Parameters"]["Power balance penalty (\$/MW)"],
        default = [5000.0 for t in 1:tn], tn
    )
    println(nf, "\t\"Power balance penalty (\$/MW)\": ", power_balance_penalty,",")
    frp_penalty = timeseries(
        json["Parameters"]["FRP penalty (\$/MW)"],
        default = [2000.0 for t in 1:tn], tn
    )
    println(nf, "\t\"FRP penalty (\$/MW)\": ", convert(Vector{Float64}, frp_penalty),",")
    println(nf, "\t\"Time horizon (h)\": ", th,",")
    println(nf, "\t\"Time step (min)\": ", convert(Int64, 60/tm),"},")
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
        ramp_up = scalar(json["Generators"]["g$g"]["Ramp up limit (MW)"]/tf, default = 1e6)
        ramp_dw = scalar(json["Generators"]["g$g"]["Ramp down limit (MW)"]/tf, default = 1e6)
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
        ls_s[b,:]=abs.(timeseries(loads[b], th))
    end
    println(nf,"\t\"Buses\": {")
    for b in 1:bn
        println(nf,"\t\t\"b$b\": {")
        println(nf,"\t\t\t\t\"Load (MW)\":[")
        for t in 1:th
            a=rand(d)
            if t!=th
                println(nf,"\t\t\t\t\t$(ls_s[b,t]*(1+a)),")
                println(nf,"\t\t\t\t\t$(ls_s[b,t]*(1-a)),")
                println(nf,"\t\t\t\t\t$(ls_s[b,t]*(1+a)),")
                println(nf,"\t\t\t\t\t$(ls_s[b,t]*(1-a)),")
            else
                println(nf,"\t\t\t\t\t$(ls_s[b,t]*(1+a)),")
                println(nf,"\t\t\t\t\t$(ls_s[b,t]*(1-a)),")
                println(nf,"\t\t\t\t\t$(ls_s[b,t]*(1+a)),")
                println(nf,"\t\t\t\t\t$(ls_s[b,t]*(1-a))")
            end
        end
        println(nf,"\t\t\t\t]")
       
        
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
        for t in 1:th
            if t!=th
                for r in 1:tm
                    println(nf,"\t\t\t",json["Reserves"]["Spinning (MW)"][t],",")
                end
            else
                for r in 1:tm-1
                    println(nf,"\t\t\t",json["Reserves"]["Spinning (MW)"][t],",")
                end
                println(nf,"\t\t\t",json["Reserves"]["Spinning (MW)"][t],"\n\t\t],")
            end
        end
    else
        println(nf,timeseries(0, tn),",")
    end
    println(nf, "\t\t\"Up-FRP (MW)\": ")
    if json["Reserves"]["Up-FRP (MW)"] !== nothing
        println(nf, "\t\t\t[")
        for t in 1:th
            if t!=th
                for r in 1:tm
                    println(nf,"\t\t\t",json["Reserves"]["Up-FRP (MW)"][t],",")
                end
            else
                for r in 1:tm-1
                    println(nf,"\t\t\t",json["Reserves"]["Up-FRP (MW)"][t],",")
                end
                println(nf,"\t\t\t",json["Reserves"]["Up-FRP (MW)"][t],"\n\t\t],")
            end
        end
    else
        println(nf,timeseries(0, tn),",")
    end
    println(nf, "\t\t\"Down-FRP (MW)\": ")
    if json["Reserves"]["Down-FRP (MW)"] !== nothing
        println(nf, "\t\t\t[")
        for t in 1:th
            if t!=th
                for r in 1:tm
                    println(nf,"\t\t\t",json["Reserves"]["Down-FRP (MW)"][t],",")
                end
            else
                for r in 1:tm-1
                    println(nf,"\t\t\t",json["Reserves"]["Down-FRP (MW)"][t],",")
                end
                println(nf,"\t\t\t",json["Reserves"]["Down-FRP (MW)"][t],"\n\t\t]")
            end
        end
    else
        println(nf,timeseries(0, tn),)
    end

    println(nf, "}\n}")
    close(nf)
    return ext_path
end

function rtm_gen_add(ext_path, json_rtm_gen, a, b, f)
    file = open(ext_path)
    json=JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
    bn = length(json["Buses"])
    gn = length(json["Generators"])
    th = json["Parameters"]["Time (h)"]
    if th === nothing
        th = json["Parameters"]["Time horizon (h)"]
    end
    ts = scalar(json["Parameters"]["Time step (min)"], default = 60)
    (60 % ts == 0) ||
        error("Time step $ts is not a divisor of 60")
    tm = 60 ÷ ts
    tn = th * tm
    ls_s=zeros(bn, tn)
    ext_rtm_path = "$(split(ext_path,".")[1])_rtm.json"
    nf = open(ext_rtm_path, "w")
    println(nf,"{")
    println(nf, "\"Parameters\": {")
    power_balance_penalty = timeseries(
        convert(Vector{Float64},json["Parameters"]["Power balance penalty (\$/MW)"]),
        default = [5000.0 for t in 1:tn], tn
    )
    println(nf, "\t\"Power balance penalty (\$/MW)\": ", power_balance_penalty,",")
    frp_penalty = timeseries(
        json["Parameters"]["FRP penalty (\$/MW)"],
        default = [2000.0 for t in 1:tn], tn
    )
    println(nf, "\t\"FRP penalty (\$/MW)\": ", convert(Vector{Float64}, frp_penalty),",")
    println(nf, "\t\"Time horizon (h)\": ", th,",")
    println(nf, "\t\"Time step (min)\": ", convert(Int64, 60/tm),"},")
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
            println(nf, "\t\t\t\"Initial power (MW)\": ", initial_power,"\n\t\t}") 
        end
    end
    gn_rtm = length(json_rtm_gen["Generators"])
    if gn_rtm >= 1
        println(nf, ",")
        for g in 1:gn_rtm
            println(nf,"\t\t\"g$(g+gn)\": {")
            println(nf, "\t\t\t\"Bus\": \"", json_rtm_gen["Generators"]["g$g"]["Bus"],"\",") 
            println(nf, "\t\t\t\"Production cost curve (MW)\": ", convert(Array{Float64},json_rtm_gen["Generators"]["g$g"]["Production cost curve (MW)"]),",")
            println(nf, "\t\t\t\"Production cost curve (\$)\": ", convert(Array{Float64},json_rtm_gen["Generators"]["g$g"]["Production cost curve (\$)"]),",")
            st_cost = scalar(convert(Array{Float64},json_rtm_gen["Generators"]["g$g"]["Startup costs (\$)"]), default = [0.0])
            st_delay = scalar(convert(Array{Float64},json_rtm_gen["Generators"]["g$g"]["Startup delays (h)"]), default = [0.0])
            println(nf, "\t\t\t\"Startup costs (\$)\": ", st_cost,",")
            println(nf, "\t\t\t\"Startup delays (h)\": ", st_delay,",") 
            ramp_up = scalar(json_rtm_gen["Generators"]["g$g"]["Ramp up limit (MW)"]/tf, default = 1e6)
            ramp_dw = scalar(json_rtm_gen["Generators"]["g$g"]["Ramp down limit (MW)"]/tf, default = 1e6)
            println(nf, "\t\t\t\"Ramp up limit (MW)\": ",ramp_up,",") 
            println(nf, "\t\t\t\"Ramp down limit (MW)\": ", ramp_dw,",") 
            st_up = scalar(json_rtm_gen["Generators"]["g$g"]["Startup limit (MW)"], default = 1e6)
            sh_dw = scalar(json_rtm_gen["Generators"]["g$g"]["Shutdown limit (MW)"], default = 1e6)
            println(nf, "\t\t\t\"Startup limit (MW)\": ", st_up,",") 
            println(nf, "\t\t\t\"Shutdown limit (MW)\": ", sh_dw,",") 
            min_up = scalar(json_rtm_gen["Generators"]["g$g"]["Minimum uptime (h)"], default = 1)
            min_dw = scalar(json_rtm_gen["Generators"]["g$g"]["Minimum downtime (h)"], default = 1)
            println(nf, "\t\t\t\"Minimum uptime (h)\": ", min_up,",") 
            println(nf, "\t\t\t\"Minimum downtime (h)\": ", min_dw,",") 
            # m_run =  timeseries(json_rtm_gen["Generators"]["g$g"]["Must run?"], T, default = ["false" for t in 1:T])
            # println(nf, "\t\t\t\"Must run?\": ", m_run,",") 
            # pr_sp_re = timeseries(json_rtm_gen["Generators"]["g$g"]["Provides spinning reserve?"],T, default = ["true" for t in 1:T])
            # println(nf, "\t\t\t\"Provides spinning reserve?\": ",pr_sp_re ,",") 
            # pr_fl_ca = timeseries(json_rtm_gen["Generators"]["g$g"]["Provides flexible capacity?"]~, default = ["true" for t in 1:T])
            # println(nf, "\t\t\t\"Provides flexible capacity?\": ",pr_fl_ca ,",") 
            initial_power = scalar(json_rtm_gen["Generators"]["g$g"]["Initial power (MW)"], default = nothing)
            initial_status = scalar(json_rtm_gen["Generators"]["g$g"]["Initial status (h)"], default = nothing)
            println(nf, "\t\t\t\"Initial status (h)\": ", initial_status,",") 
            if g!=gn
                println(nf, "\t\t\t\"Initial power (MW)\": ", initial_power,"\n\t\t},") 
            else
                println(nf, "\t\t\t\"Initial power (MW)\": ", initial_power,"\n\t\t}") 
            end
        end
        
    end
    println(nf, "\n\t},")
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
        println(nf,"\t\t\t\t\"Load (MW)\":[")
        for t in 1:tn-1
            println(nf,"\t\t\t\t\t$(ls_s[b,t]),")
        end
        println(nf,"\t\t\t\t\t$(ls_s[b,tn])")
        println(nf,"\t\t\t\t]")
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
        for t in 1:tn-1
            println(nf,"\t\t\t",json["Reserves"]["Spinning (MW)"][t],",")
        end
        println(nf,"\t\t\t",json["Reserves"]["Spinning (MW)"][tn],"\n\t\t],")
    else
        println(nf,timeseries(0, tn),",")
    end
    println(nf, "\t\t\"Up-FRP (MW)\": ")
    if json["Reserves"]["Up-FRP (MW)"] !== nothing
        println(nf, "\t\t\t[")
        for t in 1:tn-1
            println(nf,"\t\t\t",json["Reserves"]["Up-FRP (MW)"][t],",")
        end
        println(nf,"\t\t\t",json["Reserves"]["Up-FRP (MW)"][tn],"\n\t\t],")
    else
        println(nf,timeseries(0, tn),",")
    end
    println(nf, "\t\t\"Down-FRP (MW)\": ")
    if json["Reserves"]["Down-FRP (MW)"] !== nothing
        println(nf, "\t\t\t[")
        for t in 1:tn-1
            println(nf,"\t\t\t",json["Reserves"]["Down-FRP (MW)"][t],",")
        end
        println(nf,"\t\t\t",json["Reserves"]["Down-FRP (MW)"][tn],"\n\t\t]")
    else
        println(nf, timeseries(0, tn))
    end
    println(nf, "}\n}")
    close(nf)
    return ext_rtm_path
end

function checkfunc(sn, en, f_name, tf, a, b, f)
    time_model = @elapsed begin
        
        instance = UnitCommitmentSTO.read("results/$(a)_$(b)_$(f)/scenarios/$(split(f_name,".")[1])_$(en)$(sn).json",)
        model = UnitCommitmentSTO.build_model(
            instance = instance,
            optimizer = Gurobi.Optimizer,
            formulation = UnitCommitmentSTO.Formulation(
                ramping = UnitCommitmentSTO.WanHob2016.Ramping()
                )
        )
        T = instance.time
        th = convert(Int64, T/tf)
        for g in instance.units
            for t in 1:th
                l = model[:is_on][g.name, tf*(t-1)+1]
                for k in 2:tf
                    @constraint(model, model[:is_on][g.name, tf*(t-1)+k] == l) 
                end
            end
        end
        UnitCommitmentSTO.optimize!(model)
        T=instance.time
        
        nf = open("results/$(a)_$(b)_$(f)/comm_results/commitment_values_$sn.txt", "w")
        @printf(nf,"\t\t\t\t")
        for t in 1:instance.time
            @printf(nf,"\tt%d\t",t)
        end
        @printf(nf,"\n")  
        gn=0
        for g in instance.units
            gn+=1
            if gn<10
                @printf(nf,"Stochastic %s \t \t", g.name)
            else
                @printf(nf,"Stochastic %s \t \t", g.name)
            end
            for t in 1:instance.time
                @printf(nf,"%d \t \t", abs(value(model[:is_on][g.name, t])))
            end
            @printf(nf,"\n")       
        end
        close(nf)
    end
    solution = UnitCommitmentSTO.solution(model)
    UnitCommitmentSTO.write("results/$(a)_$(b)_$(f)/comm_results/output_$(sn).json", solution)
    return T, objective_value(model), time_model
end
function mul_compute(f_name, ext_path, ext_name, snumbers, tf, a, b, f)
    sn=1
    mkdir("results/$(a)_$(b)_$(f)/comm_results")
    mkdir("results/$(a)_$(b)_$(f)/frp_reqs")
    mkdir("results/$(a)_$(b)_$(f)/frp_scenarios")
    obj_vs=OrderedDict{Any,Any}()
    time_vs=OrderedDict{Any,Any}()
    sys_upfrp_reqs=OrderedDict{Any,Any}()
    sys_dwfrp_reqs=OrderedDict{Any,Any}()
    thor = 0
    for sn in snumbers
        new_scen_mul_bus(f_name, ext_path, ext_name, sn, a, b, f)
        T, obj_v, time_v=checkfunc(sn, ext_name, f_name, tf, a, b, f)
        merge!(obj_vs, OrderedDict(sn=>obj_v))
        merge!(time_vs, OrderedDict(sn=>time_v))
        sys_upfrp_req, sys_dwfrp_req = compute_frp_req("results/$(a)_$(b)_$(f)/scenarios/$(split(f_name,".")[1])_$(ext_name)$(sn).json", "results/$(a)_$(b)_$(f)/comm_results/output_$(sn).json", T, sn, f_name, f_path, tf, a, b, f)
        merge!(sys_upfrp_reqs, OrderedDict(sn=>sys_upfrp_req))
        merge!(sys_dwfrp_reqs, OrderedDict(sn=>sys_dwfrp_req))
        thor =  T
    end
    return obj_vs, time_vs, sys_upfrp_reqs, sys_dwfrp_reqs, thor
end
  