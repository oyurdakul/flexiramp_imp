using Base: Float64, @var
using Gurobi
using Cbc
using Clp
using JuMP
using Printf
import Base
using JSON
basedir = homedir()
push!(LOAD_PATH,"$basedir/.julia/packages/UnitCommitmentSTO/6AWag/src/")
using UnitCommitmentSTO


function testfunc()
    time_model = @elapsed begin
        instance = UnitCommitmentSTO.read("results/dummy2.json",)
        model = UnitCommitmentSTO.build_model(
            instance = instance,
            optimizer = Gurobi.Optimizer,
            formulation = UnitCommitmentSTO.Formulation(
                ramping = UnitCommitmentSTO.WanHob2016.Ramping()
                )
        )
        T = instance.time
        tf = instance.time_multiplier
        # th = convert(Int64, T/tf)
        # for g in instance.units
        #     for t in 1:th
        #         a = model[:is_on][g.name, tf*(t-1)+1]
        #         for k in 2:tf
        #             @constraint(model, model[:is_on][g.name, tf*(t-1)+k] == a) 
        #         end
        #     end
        # end
        UnitCommitmentSTO.optimize!(model)
        # T=instance.time
    #     nf = open("results/$(a)_$(b)_$(f)/comm_results/commitment_values_$sn.txt", "w")
    #     @printf(nf,"\t")
    #     for t in 1:instance.time
    #         @printf(nf,"\tt%d\t",t)
    #     end
    #     @printf(nf,"\n")  
    #     gn=0
    #     for g in instance.units
    #         gn+=1
    #         if gn<10
    #             @printf(nf,"Stochastic %s \t \t", g.name)
    #         else
    #             @printf(nf,"Stochastic %s \t \t", g.name)
    #         end
    #         for t in 1:instance.time
    #             @printf(nf,"%d \t \t", abs(value(model[:is_on][g.name, t])))
    #         end
    #         @printf(nf,"\n")       
    #     end
    #     close(nf)
    end
    solution = UnitCommitmentSTO.solution(model)
    UnitCommitmentSTO.write("newsol.json", solution)
    @show T
    @show tf
    return T, tf, objective_value(model)
end

testfunc()
