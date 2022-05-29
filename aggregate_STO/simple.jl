using Gurobi: Optimizer
using Base: Float64, @var
using Gurobi
using Cbc
using Clp
using JuMP
using Printf
import Base
basedir = homedir()
push!(LOAD_PATH,"$basedir/flexibility repo/UnitCommitmentFRP/src")
import UnitCommitmentFRP
import MathOptInterface
using LinearAlgebra

function simple_comp(f_name)
    
    instance = UnitCommitmentFRP.read(f_name,)

    model = UnitCommitmentFRP.build_model(
        instance = instance,
        optimizer = Gurobi.Optimizer,
        formulation = UnitCommitmentFRP.Formulation(
            ramping = UnitCommitmentFRP.WanHob2016.Ramping()
            )
    )

    UnitCommitmentFRP.optimize!(model)
   
    solution = UnitCommitmentFRP.solution(model)
end
function comp_json(path)
    json_inp = JSON.parse(open(path), dicttype = () -> DefaultOrderedDict(nothing))
    load_sum = zeros(36)
    for (bus_name, dict) in json_inp["Buses"]
        load=dict["Load (MW)"]
        load_sum += load 
    end
    @show load_sum
    
    nf = open("new_files.txt", "w")
    for t in 1:length(load_sum)
        println(nf, "$(load_sum[t]),")
    end
    close(nf)
end
simple_comp("g5_new.json")
