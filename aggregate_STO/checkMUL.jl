using Base: Float64, @var
using Gurobi
using Cbc
using Clp
using JuMP
using Printf
import Base
include("sc_create.jl")
basedir = homedir()
push!(LOAD_PATH,"content/flexiramp_imp/UnitCommitmentSTO/6AWag/src/")
using UnitCommitmentMUL
import MathOptInterface
using LinearAlgebra
import UnitCommitmentMUL:
    Formulation,
    KnuOstWat2018,
    MorLatRam2013,
    ShiftFactorsFormulation
function checkfunc()

    instance = UnitCommitmentMUL.read("2017-08-01_sb_sc.json",)
    model = UnitCommitmentMUL.build_model(
        instance = instance,
        optimizer = Gurobi.Optimizer,
        formulation = Formulation(
            )
    )
    UnitCommitmentMUL.optimize!(model)
    nf = open("commitment_values.txt", "w")
    @printf(nf,"\t")
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
d=Normal(0,0)
f_name="2017-08-01_sb.json"
ext_name="sc"
new_scen(f_name, ext_name, 1, d)
@time checkfunc()