using DataStructures: push!
using JSON: print
using Base: Float64
using Printf
using JSON
using DataStructures
using GZip
import Base: getindex, time
using Random, Distributions

function timeseries(x, T; default = nothing)
    x !== nothing || return default
    x isa Array || return [x for t in 1:T]
    return x
end

function scalar(x; default = nothing)
    x !== nothing || return default
    return x
end



function _from_json(ext_name; repair = true)
    json = JSON.parse(open(ext_name), dicttype = () -> DefaultOrderedDict(nothing))
    loads=[]
    for (bus_name, dict) in json["Buses"]
        load=dict["Load (MW)"]
        push!(loads, load)
    end
    bn= length(json["Buses"])
    th = json["Parameters"]["Time (h)"]
    if th === nothing
        th = json["Parameters"]["Time horizon (h)"]
    end
    ts = convert(UInt8, scalar(json["Parameters"]["Time step (min)"], default = 60))
    (60 % ts == 0) ||
        error("Time step $ts is not a divisor of 60")
    tm = 60 ÷ ts
    tn = convert(Int64, th * tm)
    gn = length(json["Generators"])
    return json, loads, gn, bn, tn
end

function create_scenarios(ext_path, sn, a, b, f)
    json, ls, gn, bn, tn = _from_json(ext_path)
    ls_s=zeros(bn, sn, tn)
    for b in 1:bn
        temp = abs.(timeseries(ls[b], tn))
        for t in 1:tn
            d = Normal(0, a / 100 * temp[t])
            for s in 1:sn
                ls_s[b,s,t]=abs.(temp[t]+rand(d))
            end
        end
    end
    return ls_s, gn, bn, tn, json
end


function write_to_json(json, f_name,ls_s, sn, gn, bn, tn, en, a, b, f)
    nf = open("results/$(a)_$(b)_$(f)/scenarios/$(split(f_name,".")[1])_$(en)$(sn).json", "w")
    println(nf,"{")
    println(nf, "\"Parameters\": {")
    th = json["Parameters"]["Time (h)"]
    if th === nothing
        th = json["Parameters"]["Time horizon (h)"]
    end
    ts = scalar(json["Parameters"]["Time step (min)"], default = 60)
    (60 % ts == 0) ||
        error("Time step $ts is not a divisor of 60")
    tm = 60 ÷ ts
    T = th * tm
    power_balance_penalty = timeseries(
        json["Parameters"]["Power balance penalty (\$/MW)"],
        default = [5000.0 for t in 1:tn], tn
    )
    println(nf, "\t\"Power balance penalty (\$/MW)\": ", convert(Vector{Float64}, power_balance_penalty),",")
    frp_penalty = timeseries(
        json["Parameters"]["FRP penalty (\$/MW)"],
        default = [1000.0 for t in 1:tn], tn
    )
    println(nf, "\t\"FRP penalty (\$/MW)\": ", convert(Vector{Float64}, frp_penalty),",")
    println(nf, "\t\"Time horizon (h)\": ", th,",")
    println(nf, "\t\"Time step (min)\": ", ts,",")
    println(nf, "\t\"Scenario number\": ", sn,"},")
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
        # pr_fl_ca = timeseries(json["Generators"]["g$g"]["Provides flexible capacity?"],T, default = ["true" for t in 1:T])
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
                    println(nf,"\t\t\t\t\t$(ls_s[b,s,t]),")
                else
                    println(nf,"\t\t\t\t\t$(ls_s[b,s,t])")
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
        println(nf,timeseries(0,T),",")
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
        println(nf,timeseries(0,T),",")
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
        println(nf,timeseries(0,T),",")
    end

    println(nf, "}\n}")
    close(nf)
end
function new_scen_mul_bus(f_name, ext_path, en, sn, a, b, f)
    ls_s, gn, bn, tn, json=create_scenarios(ext_path, sn, a, b, f)
    write_to_json(json,f_name,ls_s, sn, gn, bn, tn, en, a, b, f)
end