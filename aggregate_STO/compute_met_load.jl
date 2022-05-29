using DataStructures: push!
using JSON: print
using Base: Float64
using Printf
using JSON
using DataStructures
using GZip
import Base: getindex, time
using Random, Distributions

function write_frp_reqs(bus_upfrp_req, sys_upfrp_req_red, bus_dwfrp_req, sys_dwfrp_req_red, sn, bus_names, T, f_name, f_path, a, b, f)

    nf = open("results/$(a)_$(b)_$(f)/frp_reqs/frp_upsn$(sn).txt", "w")
    @printf(nf, "Bus:{\n")
    for b in bus_names
        @printf(nf, "\t %s :{\n", b)
        @printf(nf,"\t\t\t[\n")
        for t in 1:T-1
            @printf(nf, "\t\t\t\t%d, \n", bus_upfrp_req[Any[b,t]])
        end
        @printf(nf, "\t\t\t\t%d\n", bus_upfrp_req[Any[b,T]])
        @printf(nf, "\t\t\t]\n")
        if b!=bus_names[length(bus_names)]
            @printf(nf, "\t\t},\n")
        else
            @printf(nf, "\t\t}\n")
        end
    end
    @printf(nf, "}")
    close(nf)
    nf = open("results/$(a)_$(b)_$(f)/frp_reqs/frp_dwsn$(sn).txt", "w")
    @printf(nf, "Bus:{\n")
    for b in bus_names
        @printf(nf, "\t %s :{\n", b)
        @printf(nf,"\t\t\t[\n")
        for t in 1:T-1
            @printf(nf, "\t\t\t\t%d, \n", bus_dwfrp_req[Any[b,t]])
        end
        @printf(nf, "\t\t\t\t%d\n", bus_dwfrp_req[Any[b,T]])
        @printf(nf, "\t\t\t]\n")
        if b!=bus_names[length(bus_names)]
            @printf(nf, "\t\t},\n")
        else
            @printf(nf, "\t\t}\n")
        end
    end
    @printf(nf, "}")
    close(nf)
    
    f_input_frp = "results/$(a)_$(b)_$(f)/frp_scenarios/$(split(f_name,".")[1])_sn$(sn)_frp.json"
    snum=1
    json=JSON.parse(open(f_path), dicttype = () -> DefaultOrderedDict(nothing))
    bn= length(json["Buses"])
    gn = length(json["Generators"])
    tn = json["Parameters"]["Time (h)"]
    if tn === nothing
        tn = json["Parameters"]["Time horizon (h)"]
    end
    ls_s=zeros(bn, tn)
    nf = open(f_input_frp, "w")
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
    println(nf, "\t\"Scenario number\": $(snum),")
    println(nf, "\t\"Time horizon (h)\": ", tn,"},")
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
        for s in 1:snum
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
            if s!=snum
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
    @printf(nf, ",\n\t\"Reserves\": {\n")
    @printf(nf, "\t\t\"Up-FRP (MW)\": [\n")
    for t in 1:tn-1
        @printf(nf, "\t\t\t%f, \n", sys_upfrp_req_red[t])
    end
    @printf(nf, "\t\t\t%f],\n", sys_upfrp_req_red[tn])
    @printf(nf, "\t\t\"Down-FRP (MW)\": [\n")
    for t in 1:tn-1
        @printf(nf, "\t\t\t%f, \n", sys_dwfrp_req_red[t])
    end
    @printf(nf, "\t\t\t%f]\n", sys_dwfrp_req_red[tn])
    @printf(nf, "\t}\n")
    @printf(nf, "}")
    close(nf)
    
end
function compute_frp_req(inf, outf, T, sn, f_name, f_path, tf, a, b, f)
    jsonin = JSON.parse(open(inf), dicttype = () -> DefaultOrderedDict(nothing))
    jsonou = JSON.parse(open(outf), dicttype = () -> DefaultOrderedDict(nothing))
    th = convert(Int64, T/tf)
    load_values = OrderedDict()
    curtailment_values = OrderedDict()
    met_load_values = OrderedDict()

    bus_upfrp_req = OrderedDict()
    bus_dwfrp_req = OrderedDict()

    sys_upfrp_req = OrderedDict()
    sys_dwfrp_req = OrderedDict()

    sys_upfrp_req_red = OrderedDict()
    sys_dwfrp_req_red = OrderedDict()

    for (bus_name, dict) in jsonin["Buses"]
        for (scen_name, dict2) in dict
            bus_load = dict2["Load (MW)"]
            push!(load_values, [bus_name, scen_name]=>bus_load)
        end
    end

    for (bus_name, dict) in jsonou["Curtailment"]
        for (scen_name, dict2) in dict
            bus_curtailment = dict2["Load curtailment (MW)"]
            push!(curtailment_values, [bus_name, scen_name]=>bus_curtailment)
        end
    end

    bus_names = []
    for (bus_name, dict) in jsonou["Curtailment"]
        push!(bus_names,bus_name)
    end

    scen_names = []
    for (bus_name, dict) in jsonou["Curtailment"]
        for (scen_name, dict2) in dict
            push!(scen_names, scen_name)
        end
    end

    for b in bus_names
        for s in scen_names
            for t in 1:T
                push!(met_load_values, [b, s, t]=> 
                    ((load_values[Any[b, s]][t])-(curtailment_values[Any[b, s]][t])))
            end
        end
    end
    

    for b in bus_names
        for t in 1:(T-1)
            push!(bus_upfrp_req, [b, t] => 
                maximum(met_load_values[Any[b, s, t+1]]-met_load_values[Any[b, s, t]] for s in scen_names ))
            push!(bus_dwfrp_req, [b, t] => 
                maximum(met_load_values[Any[b, s, t]]-met_load_values[Any[b, s, t+1]] for s in scen_names ))
        end
        push!(bus_upfrp_req, [b, T] => 0)
        push!(bus_dwfrp_req, [b, T] => 0)
    end

    for t in 1:T
        push!(sys_upfrp_req, t => sum(bus_upfrp_req[Any[b, t]] for b in bus_names))
        push!(sys_dwfrp_req, t => sum(bus_dwfrp_req[Any[b, t]] for b in bus_names))
    end
    # Uncomment the for loop below for frp requirement calculations  
    for t in 0:th-1
        push!(sys_upfrp_req_red, t+1 => tf*maximum(sys_upfrp_req[4*t+k] for k in 1:tf))
        push!(sys_dwfrp_req_red, t+1 => tf*maximum(sys_dwfrp_req[4*t+k] for k in 1:tf))
    end
    # Uncomment the for loop above for frp req calculations 
    # for t in 0:th-1
    #     push!(sys_upfrp_req_red, t+1 => sum(sys_upfrp_req[4*t+k] for k in 1:tf))
    #     push!(sys_dwfrp_req_red, t+1 => sum(sys_dwfrp_req[4*t+k] for k in 1:tf))
    # end
   
    write_frp_reqs(bus_upfrp_req, sys_upfrp_req_red, bus_dwfrp_req, sys_dwfrp_req_red, sn, bus_names, T, f_name, f_path, a, b, f)
   
    return sys_upfrp_req, sys_dwfrp_req
end

function read_frp_req(f_name, f_path, req_file, tf, a, b, f)
    jsonfrp=JSON.parse(open(req_file), dicttype = () -> DefaultOrderedDict(nothing))
    json=JSON.parse(open(f_path), dicttype = () -> DefaultOrderedDict(nothing))
    sn=1
    bn= length(json["Buses"])
    gn = length(json["Generators"])
    tn = json["Parameters"]["Time (h)"]
    if tn === nothing
        tn = json["Parameters"]["Time horizon (h)"]
    end
    ls_s=zeros(bn, tn)
    nf = open("results/$(a)_$(b)_$(f)/frp_scenarios/$(split(f_name,".")[1])_sn0_frp.json", "w")
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
    println(nf, "\t\"Time horizon (h)\": ", tn,"},")
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
    @printf(nf, ",\n\t\"Reserves\": {\n")
    @printf(nf, "\t\t\"Up-FRP (MW)\": [\n")
    for t in 0:tn-2
        @printf(nf, "\t\t\t%f, \n", 1/4*sum(jsonfrp["Reserves"]["Up-FRP (MW)"][tf*t+k] for k in 1:tf))
    end
    @printf(nf, "\t\t\t%f], \n", 1/4*sum(jsonfrp["Reserves"]["Up-FRP (MW)"][tf*(tn-1)+k] for k in 1:tf))
    @printf(nf, "\t\t\"Down-FRP (MW)\": [\n")
    for t in 0:tn-1
        @printf(nf, "\t\t\t%f, \n", 1/4*sum(jsonfrp["Reserves"]["Down-FRP (MW)"][tf*t+k] for k in 1:tf))
    end
    @printf(nf, "\t\t\t%f] \n", 1/4*sum(jsonfrp["Reserves"]["Down-FRP (MW)"][tf*(tn-1)+k] for k in 1:tf))
    @printf(nf, "\t}\n")
    @printf(nf, "}")
    close(nf)
end

function write_single_frp_req(f_path, req_file, frp_factor)
    nf = open(req_file, "w")
    json=JSON.parse(open(f_path), dicttype = () -> DefaultOrderedDict(nothing))
    tn = length(json["Buses"]["b1"]["Load (MW)"])
    # @show "TN IS $(tn)"
    load_sum = zeros(tn)
    for (bus_name, dict) in json["Buses"]
        # @show "bus name: $(bus_name)"
        load=dict["Load (MW)"]
        # @show load
        load_sum += load 
        # @show load_sum
    end
    @printf(nf, "{\n\t\"Reserves\": {\n")
    @printf(nf, "\t\t\"Up-FRP (MW)\": [\n")
    for t in 1:tn-1
        @printf(nf, "\t\t\t%f, \n", load_sum[t]*(frp_factor))
    end
    @printf(nf, "\t\t\t%f],\n", load_sum[tn]*(frp_factor))
    @printf(nf, "\t\t\"Down-FRP (MW)\": [\n")
    for t in 1:tn-1
        @printf(nf, "\t\t\t%f, \n", load_sum[t]*(frp_factor))
    end
    @printf(nf, "\t\t\t%f]\n", load_sum[tn]*(frp_factor))
    @printf(nf, "\t}\n")
    @printf(nf, "}")
    close(nf)
    close(open(f_path))
end