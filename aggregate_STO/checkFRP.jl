using DataStructures: push!
include("comp_cost_pay.jl")
using Base: Float64, @var, Ordered
using Gurobi
using Cbc
using Clp
using JuMP
using Printf
import Base
using DataStructures
basedir = homedir()
push!(LOAD_PATH,"$basedir/.julia/packages/UnitCommitmentSTO/6AWag/src/")
import UnitCommitmentSTO
import MathOptInterface
using LinearAlgebra

function val_mod(x)
    if abs(value(x))<1e-4
        return  0.0
    end
    return round(abs(value(x)), digits=6)
end

function val_bin(x)
    if abs(value(x))<1e-4
        return  0
    else
        return 1
    end
end

function frp_compute(input_file, market, fixed_vals = 0, sval=0, dam_model = 0, oos_n = 0, type = "type", j="0", a=0, b=0, f=0)
    if market=="dam"
        time_f = 1
    else
        time_f = 4
    end
    time_model = @elapsed begin
        instance = UnitCommitmentSTO.read(input_file,)
        # instance = UnitCommitment.read_benchmark(
        # "matpower/case14/2017-08-01",)
        
        model = UnitCommitmentSTO.build_model(
            instance = instance,
            optimizer = Gurobi.Optimizer,
            formulation = UnitCommitmentSTO.Formulation(
                ramping = UnitCommitmentSTO.WanHob2016.Ramping()
                )
        )
        T=instance.time
        tf = instance.time_multiplier
        
        if type=="fixed_scen" && market == "dam"
            @show "type is $(type) and inside the condition where there are fixed dam values"
            g=0
            for gen in instance.units
                g+=1
                for t in 1:T
                    if fixed_vals[g,t]>=.9
                        @constraint(model, model[:is_on][gen.name,t] - fixed_vals[g,t]  <= 1e-3)
                        @constraint(model, model[:is_on][gen.name,t] - fixed_vals[g,t]  >= -1e-3)
                    end
                end
            end
        end
        if dam_model!==0
            for gen in dam_model[:instance].units
                for t in 1:T
                    
                    # if type !="fixed_scen"
                    @constraint(model, model[:is_on][gen.name, t] - value(dam_model[:is_on][gen.name, div((t+tf-1), tf)])<=1e-3)
                    @constraint(model, model[:is_on][gen.name, t] - value(dam_model[:is_on][gen.name, div((t+tf-1), tf)])>=-1e-3)
                    # @constraint(model, model[:prod_above]["s1", gen.name, t]
                    #     -value(dam_model[:prod_above]["s1", gen.name, div((t+tf-1), tf)])<=gen.ramp_up_limit)
                    # @constraint(model, -model[:prod_above]["s1",gen.name, t]
                    #     +value(dam_model[:prod_above]["s1", gen.name, div((t+tf-1), tf)])<=gen.ramp_down_limit)
                    # end
                end
            end
            if type == "fixed_scen"
                comm_results = "results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)/OOS_results/com_results_$(oos_n).txt"
                prod_results = "results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)/OOS_results/prod_results_$(oos_n).txt"
            elseif type == "scen"
                comm_results = "results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)/OOS_results/com_results_$(oos_n).txt"
                prod_results = "results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)/OOS_results/prod_results_$(oos_n).txt"
            elseif type == "single"
                comm_results = "results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/com_results_$(oos_n).txt"
                prod_results = "results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/prod_results_$(oos_n).txt"
            elseif type == "wout"
                comm_results = "results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/com_results_$(oos_n).txt"
                prod_results = "results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/prod_results_$(oos_n).txt"
            end
            
            if isfile(comm_results)
                com_l = readlines(comm_results)
                prod_l = readlines(prod_results)
                gn = length(com_l)-1
                # @show gn
                pr_rtm_hor = length(split(com_l[1], "\t"))-5
                println("for j=$(j) we have previous time horizon $(pr_rtm_hor) and scheduling horizon of $(T)")
                rtm_is_on = zeros(gn, pr_rtm_hor)
                rtm_prod = zeros(gn, pr_rtm_hor)
                for i in 2:gn+1
                    temp = split(com_l[i], "\t")
                    temp1 = split(prod_l[i], "\t")
                    for t in 1:pr_rtm_hor
                        rtm_is_on[i-1, t] = val_bin(parse.(Int64, temp[t]))
                        rtm_prod[i-1, t] = val_mod(parse.(Float64, temp1[t]))
                    end
                end
                if type=="wout"
                    nf = open("results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/rtm_prod_results_sval$(sval)_oos$(oos_n)_j$(j).txt", "w")
                    for i in 1:gn
                        for t in 1:pr_rtm_hor
                            @printf(nf,"%f\t", rtm_prod[i,t])
                        end
                        @printf(nf,"\n" )
                    end
                end

                # @show rtm_is_on
                g = 0
                for gen in instance.units
                    g += 1
          
                    for t in 1:pr_rtm_hor
                        # @constraint(model, model[:is_on][gen.name, t] - rtm_is_on[g, t] <= 1e-3)
                        # @constraint(model, model[:is_on][gen.name, t] - rtm_is_on[g, t] >= -1e-3)
                        # if type !="fixed_scen"
                        diff_slack_up = UnitCommitmentSTO._init(model, :diff_slack_up)
                        diff_slack_dw = UnitCommitmentSTO._init(model, :diff_slack_dw)
                        diff_slack_up[gen.name, t] = @variable(model, lower_bound=0)
                        diff_slack_dw[gen.name, t] = @variable(model, lower_bound=0)
                        @constraint(model, model[:prod_above]["s1", gen.name, t] - rtm_prod[g, t] - diff_slack_up[gen.name, t] <= 0)
                        @constraint(model, model[:prod_above]["s1", gen.name, t] - rtm_prod[g, t] + diff_slack_dw[gen.name, t] >= 0)
                        # @constraint(model, model[:prod_above]["s1", gen.name, t] - rtm_prod[g, t] + slack_down >= -1)
                        # end
                        add_to_expression!(model[:obj], 10000*(diff_slack_up[gen.name, t] + diff_slack_dw[gen.name, t]))
                        # @constraint(model, model[:prod_above]["s1", gen.name, t] - rtm_prod[g, t] == 0)
                    end
                end
         
            end
        end
        UnitCommitmentSTO.optimize!(model)
        vals = Dict(v=> val_mod(v) for v in all_variables(model) if is_binary(v))
        for (v, val) in vals
            fix(v, val)
        end
        relax_integrality(model)
        JuMP.optimize!(model)

        solution = UnitCommitmentSTO.solution(model)

        if market=="dam" && type == "fixed_scen"
            UnitCommitmentSTO.write("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)/output_DAM_$(sval).json", solution)
            compute_cost_payment("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)/generation_payment_DAM.txt", model, "frp", "dam", dam_model, time_f)
        elseif market=="dam" && type == "scen"
            UnitCommitmentSTO.write("results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)/output_DAM_$(sval).json", solution)
            compute_cost_payment("results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)/generation_payment_DAM.txt", model, "frp", "dam", dam_model, time_f)
        elseif market=="dam" && type == "single"
            UnitCommitmentSTO.write("results/$(a)_$(b)_$(f)/DAM_FRP/output_DAM.json", solution)
            compute_cost_payment("results/$(a)_$(b)_$(f)/DAM_FRP/generation_payment_DAM.txt", model, "frp", "dam", dam_model, time_f)
        elseif market=="dam" && type == "wout"
            UnitCommitmentSTO.write("results/$(a)_$(b)_$(f)/DAM_RTM/output_DAM.json", solution)
            compute_cost_payment("results/$(a)_$(b)_$(f)/DAM_RTM/generation_payment_DAM.txt", model, "frp", "dam", dam_model, time_f)
        elseif market=="rtm"  && type == "fixed_scen"
            UnitCommitmentSTO.write("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)/OOS_results/output_RTM_$(oos_n).json", solution)
            if j!=100
                nf = open("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)/OOS_results/com_results_$(oos_n).txt", "w")
                for t in 1:T
                    @printf(nf, "%d\t", t)
                end
                @printf(nf, "\n")
                for gen in instance.units
                    for t in 1:T
                        @printf(nf, "%d\t", abs(value(model[:is_on][gen.name, t])))
                    end
                    if gen!=instance.units[length(instance.units)]
                        @printf(nf, "\n")
                    end
                end
                close(nf)
                nf = open("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)/OOS_results/prod_results_$(oos_n).txt", "w")
                for t in 1:T
                    @printf(nf, "%d\t", t)
                end
                @printf(nf, "\n")
                for gen in instance.units
                    for t in 1:T
                        @printf(nf, "%f\t", abs(value(model[:prod_above]["s1", gen.name, t])))
                    end
                    if gen!=instance.units[length(instance.units)]
                        @printf(nf, "\n")
                    end
                end
                close(nf)
            end
            nf = open("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)/OOS_results/com_results_$(oos_n)_$(j).txt", "w")
            for t in 1:T
                @printf(nf, "%d\t", t)
            end
            @printf(nf, "\n")
            for gen in instance.units
                for t in 1:T
                    @printf(nf, "%d\t", abs(value(model[:is_on][gen.name, t])))
                end
                if gen!=instance.units[length(instance.units)]
                    @printf(nf, "\n")
                end
            end
            close(nf)
            nf = open("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)/OOS_results/prod_results_$(oos_n)_$(j).txt", "w")
            for t in 1:T
                @printf(nf, "%d\t", t)
            end
            @printf(nf, "\n")
            for gen in instance.units
                for t in 1:T
                    @printf(nf, "%f\t", abs(value(model[:prod_above]["s1", gen.name, t])))
                end
                if gen!=instance.units[length(instance.units)]
                    @printf(nf, "\n")
                end
            end
            close(nf)
            compute_cost_payment("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)/OOS_results/generation_payment_RTM_$(oos_n).txt", model, "frp", "rtm", dam_model, time_f, "$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)", oos_n)
        elseif market=="rtm"  && type == "scen"
            UnitCommitmentSTO.write("results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)/OOS_results/output_RTM_$(oos_n).json", solution)
            if j!=100
                nf = open("results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)/OOS_results/com_results_$(oos_n).txt", "w")
                for t in 1:T
                    @printf(nf, "%d\t", t)
                end
                @printf(nf, "\n")
                for gen in instance.units
                    for t in 1:T
                        @printf(nf, "%d\t", abs(value(model[:is_on][gen.name, t])))
                    end
                    if gen!=instance.units[length(instance.units)]
                        @printf(nf, "\n")
                    end
                end
                close(nf)
                nf = open("results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)/OOS_results/prod_results_$(oos_n).txt", "w")
                for t in 1:T
                    @printf(nf, "%d\t", t)
                end
                @printf(nf, "\n")
                for gen in instance.units
                    for t in 1:T
                        @printf(nf, "%f\t", abs(value(model[:prod_above]["s1", gen.name, t])))
                    end
                    if gen!=instance.units[length(instance.units)]
                        @printf(nf, "\n")
                    end
                end
                close(nf)
            end
            nf = open("results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)/OOS_results/com_results_$(oos_n)_$(j).txt", "w")
            for t in 1:T
                @printf(nf, "%d\t", t)
            end
            @printf(nf, "\n")
            for gen in instance.units
                for t in 1:T
                    @printf(nf, "%d\t", abs(value(model[:is_on][gen.name, t])))
                end
                if gen!=instance.units[length(instance.units)]
                    @printf(nf, "\n")
                end
            end
            close(nf)
            nf = open("results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)/OOS_results/prod_results_$(oos_n)_$(j).txt", "w")
            for t in 1:T
                @printf(nf, "%d\t", t)
            end
            @printf(nf, "\n")
            for gen in instance.units
                for t in 1:T
                    @printf(nf, "%f\t", abs(value(model[:prod_above]["s1", gen.name, t])))
                end
                if gen!=instance.units[length(instance.units)]
                    @printf(nf, "\n")
                end
            end
            close(nf)
            compute_cost_payment("results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)/OOS_results/generation_payment_RTM_$(oos_n).txt", model, "frp", "rtm", dam_model, time_f, "$(a)_$(b)_$(f)/DAM_FRP_s$(sval)", oos_n)
        elseif market=="rtm"  && type == "single"
            UnitCommitmentSTO.write("results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/output_RTM_$(oos_n).json", solution)

            if j!=100
                nf = open("results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/com_results_$(oos_n).txt", "w")
                for t in 1:T
                    @printf(nf, "%d\t", t)
                end
                @printf(nf, "\n")
                for gen in instance.units
                    for t in 1:T
                        @printf(nf, "%d\t", abs(value(model[:is_on][gen.name, t])))
                    end
                    if gen!=instance.units[length(instance.units)]
                        @printf(nf, "\n")
                    end
                end
                close(nf)
                nf = open("results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/prod_results_$(oos_n).txt", "w")
                for t in 1:T
                    @printf(nf, "%d\t", t)
                end
                @printf(nf, "\n")
                for gen in instance.units
                    for t in 1:T
                        @printf(nf, "%f\t", abs(value(model[:prod_above]["s1", gen.name, t])))
                    end
                    if gen!=instance.units[length(instance.units)]
                        @printf(nf, "\n")
                    end
                end
                close(nf)
            end
            nf = open("results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/com_results_$(oos_n)_$(j).txt", "w")
            for t in 1:T
                @printf(nf, "%d\t", t)
            end
            @printf(nf, "\n")
            for gen in instance.units
                for t in 1:T
                    @printf(nf, "%d\t", abs(value(model[:is_on][gen.name, t])))
                end
                if gen!=instance.units[length(instance.units)]
                    @printf(nf, "\n")
                end
            end
            close(nf)
            nf = open("results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/prod_results_$(oos_n)_$(j).txt", "w")
            for t in 1:T
                @printf(nf, "%d\t", t)
            end
            @printf(nf, "\n")
            for gen in instance.units
                for t in 1:T
                    @printf(nf, "%f\t", abs(value(model[:prod_above]["s1", gen.name, t])))
                end
                if gen!=instance.units[length(instance.units)]
                    @printf(nf, "\n")
                end
            end
            close(nf)
            compute_cost_payment("results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/generation_payment_RTM_$(oos_n).txt", model, "frp", "rtm", dam_model, time_f, "$(a)_$(b)_$(f)/DAM_FRP", oos_n)
        elseif market=="rtm" && type == "wout"
            UnitCommitmentSTO.write("results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/output_RTM_$(oos_n).json", solution)
            if j!=100
                nf = open("results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/com_results_$(oos_n).txt", "w")
                for t in 1:T
                    @printf(nf, "%d\t", t)
                end
                @printf(nf, "\n")
                for gen in instance.units
                    for t in 1:T
                        @printf(nf, "%d\t", abs(value(model[:is_on][gen.name, t])))
                    end
                    if gen!=instance.units[length(instance.units)]
                        @printf(nf, "\n")
                    end
                end
                close(nf)
                nf = open("results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/prod_results_$(oos_n).txt", "w")
                for t in 1:T
                    @printf(nf, "%d\t", t)
                end
                @printf(nf, "\n")
                for gen in instance.units
                    for t in 1:T
                        @printf(nf, "%f\t", abs(value(model[:prod_above]["s1", gen.name, t])))
                    end
                    if gen!=instance.units[length(instance.units)]
                        @printf(nf, "\n")
                    end
                end
                close(nf)
            end
            nf = open("results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/com_results_$(oos_n)_$(j).txt", "w")
            for t in 1:T
                @printf(nf, "%d\t", t)
            end
            @printf(nf, "\n")
            for gen in instance.units
                for t in 1:T
                    @printf(nf, "%d\t", abs(value(model[:is_on][gen.name, t])))
                end
                if gen!=instance.units[length(instance.units)]
                    @printf(nf, "\n")
                end
            end
            close(nf)
            nf = open("results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/prod_results_$(oos_n)_$(j).txt", "w")
            for t in 1:T
                @printf(nf, "%d\t", t)
            end
            @printf(nf, "\n")
            for gen in instance.units
                for t in 1:T
                    @printf(nf, "%f\t", abs(value(model[:prod_above]["s1", gen.name, t])))
                end
                if gen!=instance.units[length(instance.units)]
                    @printf(nf, "\n")
                end
            end
            close(nf)
            compute_cost_payment("results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/generation_payment_RTM_$(oos_n).txt", model, "frp", "rtm", dam_model, time_f, "$(a)_$(b)_$(f)/DAM_RTM", oos_n)
        end
    end
    println("objective function for market: $(market) and type: $(type): $(objective_value(model))")
    return objective_value(model),  model, time_model
end