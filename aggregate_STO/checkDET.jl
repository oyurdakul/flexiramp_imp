using LinearAlgebra: length
using Base: Float64, @var
using Gurobi
using Cbc
using Clp
using JuMP
using DataStructures
using Printf
import Base
include("comp_cost_pay.jl")
basedir = homedir()

# import UnitCommitment
import MathOptInterface
using LinearAlgebra
# import UnitCommitment:
#     Formulation,
#     KnuOstWat2018,
#     MorLatRam2013,
#     ShiftFactorsFormulation


# function compute(f_name, dam_model=1)

#     instance = UnitCommitment.read(f_name,)

#     model = UnitCommitment.build_model(
#         instance = instance,
#         optimizer = Gurobi.Optimizer,
#         formulation = UnitCommitment.Formulation(
#             )
#     )

#     T=instance.time
#     if dam_model!==1
#         for g in dam_model[:instance].units
#             for t in 1:T
#                 @constraint(model, model[:is_on][g.name,t]==value(dam_model[:is_on][g.name,t]))
#             end
#         end
   
#     else
#         for t in 1:T
#             @constraint(model, model[:is_on]["g3",t]==0)
#         end
#         for t in 2:T
#             @constraint(model, model[:is_on]["g2",t]==1)
#         end
#         @constraint(model, model[:is_on]["g2",1]==0)
#     end
#     UnitCommitment.optimize!(model)
   
#     solution = UnitCommitment.solution(model)
#     if dam_model==1
#         UnitCommitmentFL.write("output_DAM.json", solution)
#     else
#         UnitCommitmentFL.write("output_RTM.json", solution)
#     end
#     vals = Dict(v=>value(v) for v in all_variables(model) if is_binary(v))
#     for (v, val) in vals
#         fix(v, val)
#     end
#     relax_integrality(model)
#     JuMP.optimize!(model)
#     compute_cost_payment(f_name, model, "wout_frp", dam_model)
#     return objective_value(model), model
# end

