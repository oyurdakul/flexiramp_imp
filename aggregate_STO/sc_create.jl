using DataStructures: push!
using JSON: print
using Base: Float64
using Printf
using JSON
using DataStructures
using GZip
import Base: getindex, time
using Random, Distributions

function read(path::AbstractString)
    if endswith(path, ".gz")
        return _read(gzopen(path))
    else
        return _read(open(path))
    end
end

function _read(file::IO)
    return _from_json(
        JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing)),
    )
end

function _from_json(json; repair = true)
    loads=[]
    for (bus_name, dict) in json["Buses"]
        load=dict["Load (MW)"]
        push!(loads, load)
    end
    bn= length(json["Buses"])
    tn = json["Parameters"]["Time horizon (h)"]
    gn = length(json["Generators"])
    return json, loads, gn, bn, tn
end

function create_scenarios(d, f_name, sn)
    json, ls, gn, bn, tn = read(f_name)
    ls_s=zeros(bn, sn, tn)
    for b in 1:bn
        for s in 1:sn
            ls_s[b,s,:]=ls[b]+rand(d,tn)
        end
    end
    return ls_s, gn, bn, tn, json
end


function write_to_json(json, f_name,ls_s, sn, gn, bn, tn, en)
    nf = open("$(split(f_name,".")[1])_$(en).json", "w")
    println(nf,"{")
    println(nf, "\"Parameters\": {")
    println(nf, "\t\"Power balance penalty (\$/MW)\": ", json["Parameters"]["Power balance penalty (\$/MW)"],",")
    println(nf, "\t\"FRP penalty (\$/MW)\": ", json["Parameters"]["FRP penalty (\$/MW)"],",")
    println(nf, "\t\"Time horizon (h)\": ", json["Parameters"]["Time horizon (h)"],",")
    println(nf, "\t\"Scenario number\": ", sn,"},")
    println(nf, "\t\"Generators\": {")
    for g in 1:gn
        println(nf,"\t\t\"g$g\": {")
        println(nf, "\t\t\t\"Bus\": \"", json["Generators"]["g$g"]["Bus"],"\",") 
        println(nf, "\t\t\t\"Production cost curve (MW)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Production cost curve (MW)"]),",")
        println(nf, "\t\t\t\"Production cost curve (\$)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Production cost curve (\$)"]),",")
        println(nf, "\t\t\t\"Startup costs (\$)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Startup costs (\$)"]),",")
        println(nf, "\t\t\t\"Startup delays (h)\": ", convert(Array{Float64},json["Generators"]["g$g"]["Startup delays (h)"]),",") 
        println(nf, "\t\t\t\"Ramp up limit (MW)\": ", json["Generators"]["g$g"]["Ramp up limit (MW)"],",") 
        println(nf, "\t\t\t\"Ramp down limit (MW)\": ", json["Generators"]["g$g"]["Ramp down limit (MW)"],",") 
        println(nf, "\t\t\t\"Startup limit (MW)\": ", json["Generators"]["g$g"]["Startup limit (MW)"],",") 
        println(nf, "\t\t\t\"Shutdown limit (MW)\": ", json["Generators"]["g$g"]["Shutdown limit (MW)"],",") 
        println(nf, "\t\t\t\"Minimum uptime (h)\": ", json["Generators"]["g$g"]["Minimum uptime (h)"],",") 
        println(nf, "\t\t\t\"Minimum downtime (h)\": ", json["Generators"]["g$g"]["Minimum downtime (h)"],",") 
        # println(nf, "\t\t\t\"Must run?\": ", json["Generators"]["g$g"]["Must run?"],",") 
        # println(nf, "\t\t\t\"Provides spinning reserve?\": ", json["Generators"]["g$g"]["Must run?"],",") 
        # println(nf, "\t\t\t\"Provides flexible capacity?\": ", json["Generators"]["g$g"]["Provides flexible capacity?"],",") 
        println(nf, "\t\t\t\"Initial status (h)\": ", json["Generators"]["g$g"]["Initial status (h)"],",") 
        if g!=gn
            println(nf, "\t\t\t\"Initial power (MW)\": ", json["Generators"]["g$g"]["Initial power (MW)"],"\n\t\t},") 
        else
            println(nf, "\t\t\t\"Initial power (MW)\": ", json["Generators"]["g$g"]["Initial power (MW)"],"\n\t\t}\n\t},") 
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
            println(nf,"\t\t\t\t]")
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
    println(nf, "\t\t\"Spinning\": [")
    for t in 1:tn
        if t!=tn
            println(nf,"\t\t\t",json["Reserves"]["Spinning (MW)"][t],",")
        else
            println(nf,"\t\t\t",json["Reserves"]["Spinning (MW)"][t],"\n\t\t]")
        end
    end
    println(nf, "\t}\n}")
    close(nf)
end
function new_scen(f_name, en, sn, d)
    ls_s, gn, bn, tn, json=create_scenarios(d, f_name, sn)
    write_to_json(json,f_name,ls_s, sn, gn, bn, tn, en)
end

                