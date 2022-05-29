using DataStructures: push!
basedir = homedir()
push!(LOAD_PATH,"$basedir/.julia/packages/UnitCommitmentSTO/6AWag/src/")
import UnitCommitmentSTO
using Base: Float64, @var, Ordered
using Gurobi
using Cbc
using Clp
using JuMP
using Printf
import Base
using DataStructures
import MathOptInterface
using LinearAlgebra

function val_mod(x)
    if x === nothing || abs(value(x))<1e-2
        return  0.0
    end
    return round(value(x), digits=6)
end

function rtm_compare(snumbers, oos_sn, nf, obj_vals_fixed_frp, obj_vals_frp, obj_val_single, obj_val_wout, a, b, f)
    pr_cur = open("results/$(a)_$(b)_$(f)/rtm_compare/comp.json", "w")
    println(pr_cur,"{")
    println(pr_cur,"\"Average LMPs\":{")
    for i in snumbers
        damc_almps=OrderedDict()
        println(pr_cur,"\t\"DAMC_s$(i)\":[")
        for j in 1:oos_sn
            damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(i)/OOS_results/LMP_$(j).json"
            damc_j = open(damc_sj, "r")
            damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
            push!(damc_almps, j=>damc_js["Average LMPs"])
        end
        T = length(damc_almps[1])
        # temp=OrderedDict()
        for t in 1:T-1
            # temp[t] = sum(damc_almps[j][t] for j in 1:oos_sn)
            println(pr_cur,"\t\t$(sum(damc_almps[j][t] for j in 1:oos_sn)/oos_sn),")
        end
        println(pr_cur,"\t\t$(sum(damc_almps[j][T] for j in 1:oos_sn)/oos_sn)")
        println(pr_cur,"\t],")
        damc_nf_almps=OrderedDict()
        println(pr_cur,"\t\"DAMC_nf_s$(i)\":[")
        for j in 1:oos_sn
            damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP_s$(i)/OOS_results/LMP_$(j).json"
            damc_j = open(damc_sj, "r")
            damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
            push!(damc_nf_almps, j=>damc_js["Average LMPs"])
        end
        for t in 1:T-1
            println(pr_cur,"\t\t$(sum(damc_nf_almps[j][t] for j in 1:oos_sn)/oos_sn),")
        end
        println(pr_cur,"\t\t$(sum(damc_nf_almps[j][T] for j in 1:oos_sn)/oos_sn)")
        println(pr_cur,"\t],")
    end
    damc_95_almps=OrderedDict()
    println(pr_cur,"\t\"DAMC_95\":[")
    for j in 1:oos_sn
        damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/LMP_$(j).json"
        damc_j = open(damc_sj, "r")
        damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
        push!(damc_95_almps, j=>damc_js["Average LMPs"])
    end
    T = length(damc_95_almps[1])
    for t in 1:T-1
        println(pr_cur,"\t\t$(sum(damc_95_almps[j][t] for j in 1:oos_sn)/oos_sn),")
    end
    println(pr_cur,"\t\t$(sum(damc_95_almps[j][T] for j in 1:oos_sn)/oos_sn)")
    println(pr_cur,"\t],")
    println(pr_cur,"\t\"DAMC_w/o\":[")
    damc_wo_almps=OrderedDict()
    for j in 1:oos_sn
        damc_sj = "results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/LMP_$(j).json"
        damc_j = open(damc_sj, "r")
        damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
        push!(damc_wo_almps, j=>damc_js["Average LMPs"])
    end
    for t in 1:T-1
        println(pr_cur,"\t\t$(sum(damc_wo_almps[j][t] for j in 1:oos_sn)/oos_sn),")
    end
    println(pr_cur,"\t\t$(sum(damc_wo_almps[j][T] for j in 1:oos_sn)/oos_sn)")
    println(pr_cur,"\t]")
    println(pr_cur,"\n\t},")
    println(pr_cur,"\"Total LMPs\":{")
    for i in snumbers
        damc_almps=OrderedDict()
        println(pr_cur,"\t\"DAMC_s$(i)\":")
        for j in 1:oos_sn
            damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(i)/OOS_results/LMP_$(j).json"
            damc_j = open(damc_sj, "r")
            damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
            push!(damc_almps, j=>damc_js["Average LMPs"])
        end
        T = length(damc_almps[1])
        println(pr_cur,"\t\t$(sum(damc_almps[j][t] for j in 1:oos_sn for t in 1:T)/oos_sn),")
        damc_nf_almps=OrderedDict()
        println(pr_cur,"\t\"DAMC_nf_s$(i)\":")
        for j in 1:oos_sn
            damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP_s$(i)/OOS_results/LMP_$(j).json"
            damc_j = open(damc_sj, "r")
            damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
            push!(damc_nf_almps, j=>damc_js["Average LMPs"])
        end
        println(pr_cur,"\t\t$(sum(damc_nf_almps[j][t] for j in 1:oos_sn for t in 1:T)/oos_sn),")
    end
    damc_95_almps=OrderedDict()
    println(pr_cur,"\t\"DAMC_95\":")
    for j in 1:oos_sn
        damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/LMP_$(j).json"
        damc_j = open(damc_sj, "r")
        damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
        push!(damc_95_almps, j=>damc_js["Average LMPs"])
    end
    T = length(damc_95_almps[1])
    println(pr_cur,"\t\t$(sum(damc_95_almps[j][t] for j in 1:oos_sn for t in 1:T)/oos_sn),")
    println(pr_cur,"\t\"DAMC_w/o\":")
    damc_wo_almps=OrderedDict()
    for j in 1:oos_sn
        damc_sj = "results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/LMP_$(j).json"
        damc_j = open(damc_sj, "r")
        damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
        push!(damc_wo_almps, j=>damc_js["Average LMPs"])
    end
    println(pr_cur,"\t\t$(sum(damc_wo_almps[j][t] for j in 1:oos_sn for t in 1:T)/oos_sn)")
    println(pr_cur,"\t},")
    println(pr_cur,"\"Total intrahourly curtailment\":{")
    for i in snumbers
        damc_curts=OrderedDict()
        println(pr_cur,"\t\"DAMC_s$(i)\":[")
        for j in 1:oos_sn
            damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(i)/OOS_results/curt_$(j).json"
            damc_j = open(damc_sj, "r")
            damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
            push!(damc_curts, j=>damc_js["Total curtailments"])
        end
        T = length(damc_curts[1])
        for t in 1:T-1
            println(pr_cur,"\t\t$(sum(damc_curts[j][t] for j in 1:oos_sn)),")
        end
        println(pr_cur,"\t\t$(sum(damc_curts[j][T] for j in 1:oos_sn))")
        println(pr_cur,"\t],")
        damc_nf_curts=OrderedDict()
        println(pr_cur,"\t\"DAMC_nf_s$(i)\":[")
        for j in 1:oos_sn
            damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP_s$(i)/OOS_results/curt_$(j).json"
            damc_j = open(damc_sj, "r")
            damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
            push!(damc_nf_curts, j=>damc_js["Total curtailments"])
        end
        for t in 1:T-1
            println(pr_cur,"\t\t$(sum(damc_nf_curts[j][t] for j in 1:oos_sn)),")
        end
        println(pr_cur,"\t\t$(sum(damc_nf_curts[j][T] for j in 1:oos_sn))")
        println(pr_cur,"\t],")
    end
    damc_95_curts=OrderedDict()
    println(pr_cur,"\t\"DAMC_95\":[")
    for j in 1:oos_sn
        damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/curt_$(j).json"
        damc_j = open(damc_sj, "r")
        damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
        push!(damc_95_curts, j=>damc_js["Total curtailments"])
    end
    T = length(damc_95_curts[1])
    for t in 1:T-1
        println(pr_cur,"\t\t$(sum(damc_95_curts[j][t] for j in 1:oos_sn)),")
    end
    println(pr_cur,"\t\t$(sum(damc_95_curts[j][T] for j in 1:oos_sn))")
    println(pr_cur,"\t],")
    println(pr_cur,"\t\"DAMC_w/o\":[")
    damc_wo_curts=OrderedDict()
    for j in 1:oos_sn
        damc_sj = "results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/curt_$(j).json"
        damc_j = open(damc_sj, "r")
        damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
        push!(damc_wo_curts, j=>damc_js["Total curtailments"])
    end
    for t in 1:T-1
        println(pr_cur,"\t\t$(sum(damc_wo_curts[j][t] for j in 1:oos_sn)),")
    end
    println(pr_cur,"\t\t$(sum(damc_wo_curts[j][T] for j in 1:oos_sn))")
    println(pr_cur,"\t]")
    println(pr_cur,"\n\t},")
    println(pr_cur,"\"Total curtailment\":{")
    for i in snumbers
        damc_curts=OrderedDict()
        println(pr_cur,"\t\"DAMC_s$(i)\":")
        for j in 1:oos_sn
            damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(i)/OOS_results/curt_$(j).json"
            damc_j = open(damc_sj, "r")
            damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
            push!(damc_curts, j=>damc_js["Total curtailments"])
        end
        T = length(damc_curts[1])
        println(pr_cur,"\t\t$(sum(damc_curts[j][t] for j in 1:oos_sn for t in 1:T)),")
        
        damc_nf_curts=OrderedDict()
        println(pr_cur,"\t\"DAMC_nf_s$(i)\":")
        for j in 1:oos_sn
            damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP_s$(i)/OOS_results/curt_$(j).json"
            damc_j = open(damc_sj, "r")
            damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
            push!(damc_nf_curts, j=>damc_js["Total curtailments"])
        end
        println(pr_cur,"\t\t$(sum(damc_nf_curts[j][t] for j in 1:oos_sn for t in 1:T)),")
    end
    damc_95_curts=OrderedDict()
    println(pr_cur,"\t\"DAMC_95\":")
    for j in 1:oos_sn
        damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/curt_$(j).json"
        damc_j = open(damc_sj, "r")
        damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
        push!(damc_95_curts, j=>damc_js["Total curtailments"])
    end
    T = length(damc_95_curts[1])
    println(pr_cur,"\t\t$(sum(damc_95_curts[j][t] for j in 1:oos_sn for t in 1:T)),")
    println(pr_cur,"\t\"DAMC_w/o\":")
    damc_wo_curts=OrderedDict()
    for j in 1:oos_sn
        damc_sj = "results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/curt_$(j).json"
        damc_j = open(damc_sj, "r")
        damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
        push!(damc_wo_curts, j=>damc_js["Total curtailments"])
    end
    println(pr_cur,"\t\t$(sum(damc_wo_curts[j][t] for j in 1:oos_sn for t in 1:T))")
    println(pr_cur,"\t},")
    println(pr_cur,"\"Total operating cost\":{")
    for i in snumbers
        damc_costs=OrderedDict()
        println(pr_cur,"\t\"DAMC_s$(i)\":")
        for j in 1:oos_sn
            damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(i)/OOS_results/cost_$(j).json"
            damc_j = open(damc_sj, "r")
            damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
            push!(damc_costs, j=>damc_js["Total operating cost"])
        end
        T = length(damc_costs[1])
        println(pr_cur,"\t\t$(sum(damc_costs[j][t] for j in 1:oos_sn for t in 1:T)),")
        
        damc_nf_costs=OrderedDict()
        println(pr_cur,"\t\"DAMC_nf_s$(i)\":")
        for j in 1:oos_sn
            damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP_s$(i)/OOS_results/cost_$(j).json"
            damc_j = open(damc_sj, "r")
            damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
            push!(damc_nf_costs, j=>damc_js["Total operating cost"])
        end
        println(pr_cur,"\t\t$(sum(damc_nf_costs[j][t] for j in 1:oos_sn for t in 1:T)),")
    end
    damc_95_costs=OrderedDict()
    println(pr_cur,"\t\"DAMC_95\":")
    for j in 1:oos_sn
        damc_sj = "results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/cost_$(j).json"
        damc_j = open(damc_sj, "r")
        damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
        push!(damc_95_costs, j=>damc_js["Total operating cost"])
    end
    T = length(damc_95_costs[1])
    println(pr_cur,"\t\t$(sum(damc_95_costs[j][t] for j in 1:oos_sn for t in 1:T)),")
    println(pr_cur,"\t\"DAMC_w/o\":")
    damc_wo_costs=OrderedDict()
    for j in 1:oos_sn
        damc_sj = "results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/cost_$(j).json"
        damc_j = open(damc_sj, "r")
        damc_js=JSON.parse(damc_j, dicttype = () -> DefaultOrderedDict(nothing))
        push!(damc_wo_costs, j=>damc_js["Total operating cost"])
    end
    println(pr_cur,"\t\t$(sum(damc_wo_costs[j][t] for j in 1:oos_sn for t in 1:T))")
    println(pr_cur,"\t}\n}")
    close(pr_cur)
    for i in 1:oos_sn
        println(nf, "generation payment \t up-FRP payment \t dw-FRP payment \t pre-up t. payment \t uplift payment \t post-up t. payment")
        k=0
        for j in snumbers
            k+=1 
            nf_2 = open("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(j)/OOS_results/generation_payment_RTM_$(i).txt", "r")
            lines = readlines(nf_2)
            ln = length(lines)
            println(nf, "fixed $(j):\t $(lines[ln])")
            close(nf_2)
            nf_2 = open("results/$(a)_$(b)_$(f)/DAM_FRP_s$(j)/OOS_results/generation_payment_RTM_$(i).txt", "r")
            lines = readlines(nf_2)
            ln = length(lines)
            println(nf, "not-fixed $(j):\t $(lines[ln])")
            close(nf_2)
        end
        nf_2 = open("results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/generation_payment_RTM_$(i).txt", "r")
        lines = readlines(nf_2)
        ln = length(lines)
        println(nf, "single:\t $(lines[ln])")
        close(nf_2)
        nf_2 = open("results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/generation_payment_RTM_$(i).txt", "r")
        lines = readlines(nf_2)
        ln = length(lines)
        println(nf, "wout:\t $(lines[ln])")
        close(nf_2)
        println(nf, "-"^120)
    end
    for i in 1:oos_sn
        k=0
        for j in snumbers
            k+=1
            nf_2 = open("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(j)/OOS_results/generation_payment_RTM_$(i).txt", "r")
            println(nf, "fixed $(j) total cost: $(obj_vals_fixed_frp[k][i])" )
            close(nf_2)
            nf_2 = open("results/$(a)_$(b)_$(f)/DAM_FRP_s$(j)/OOS_results/generation_payment_RTM_$(i).txt", "r")
            println(nf, "not-fixed $(j) total cost: $(obj_vals_frp[k][i])" )
            close(nf_2)
        end
        nf_2 = open("results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results/generation_payment_RTM_$(i).txt", "r")
        println(nf, "single total cost: $(obj_val_single[i])" )
        close(nf_2)
        nf_2 = open("results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results/generation_payment_RTM_$(i).txt", "r")
        println(nf, "wout total cost: $(obj_val_wout[i])" )
        close(nf_2)
        println(nf, "-"^120)
    end
end

function compute_cost_payment(file, model, type, market, dam_model=0, tf=4, conf_name=0, oos_n=0)
    nf = open(file, "w")
    gen_pay=OrderedDict()
    gen_tot_pay=OrderedDict()
    dam_gen_pay=OrderedDict()
    dam_gen_tot_pay=OrderedDict()
    gen_cost = OrderedDict()
    gen_tot_cost = OrderedDict()
    uplift_payment = OrderedDict()
    systemwide_prices = OrderedDict()
    locational_prices = OrderedDict()
    curtailment = OrderedDict()
    instance = model[:instance]
  
    for g in instance.units
        for t in 1:instance.time
            if dam_model==0 
                push!(gen_pay, ["$(g.name)", t, 1]=> (val_mod(model[:prod_above]["s1", g.name, t]) +
                    (val_mod(model[:is_on][g.name, t]) * val_mod(g.min_power[t]))) * 
                    val_mod(-shadow_price(model[:eq_net_injection_def]["s1", g.bus.name, t])))
            elseif !(any(g.name === dam_model[:instance].units[i].name for i in 1:length(dam_model[:instance].units)))
                push!(gen_pay, ["$(g.name)", t, 1]=> (val_mod(model[:prod_above]["s1", g.name, t]) +
                    (val_mod(model[:is_on][g.name, t]) * val_mod(g.min_power[t]))) * 
                    val_mod(-shadow_price(model[:eq_net_injection_def]["s1", g.bus.name, t])))

            else
                push!(gen_pay, ["$(g.name)", t, 1]=> (val_mod(model[:prod_above]["s1", g.name, t]) -
                    val_mod(dam_model[:prod_above]["s1", g.name, div((t+tf-1), tf)]) +
                    (val_mod(model[:is_on][g.name, t]) * val_mod(g.min_power[t]))) * 
                    val_mod(-shadow_price(model[:eq_net_injection_def]["s1", g.bus.name, t])))
                push!(dam_gen_pay, ["$(g.name)", div((t+tf-1), tf), 1]=> (val_mod(dam_model[:prod_above]["s1", g.name, div((t+tf-1), tf)]) +
                    (val_mod(dam_model[:is_on][g.name, div((t+tf-1), tf)]) * val_mod(g.min_power[div((t+tf-1), tf)]))) * 
                    val_mod(-shadow_price(dam_model[:eq_net_injection_def]["s1", g.bus.name, div((t+tf-1), tf)])))
            end
            if type == "frp"
                if dam_model==0 
                    push!(gen_pay, ["$(g.name)", t, 2]=> val_mod(model[:upfrp]["s1", g.name, t]) * 
                        val_mod(-shadow_price(model[:eq_min_upfrp]["s1", t])))
                    push!(gen_pay, ["$(g.name)", t, 3]=> 
                    val_mod(model[:dwfrp]["s1", g.name, t]) * 
                        val_mod(-shadow_price(model[:eq_min_dwfrp]["s1", t])))
                    push!(gen_pay, ["$(g.name)", t, 4]=> (val_mod(gen_pay[Any["$(g.name)", t, 1]]) +
                        val_mod(gen_pay[Any["$(g.name)", t, 2]]) + val_mod(gen_pay[Any["$(g.name)", t, 3]])))
                elseif !(any(g.name === dam_model[:instance].units[i].name for i in 1:length(dam_model[:instance].units)))
                    push!(gen_pay, ["$(g.name)", t, 2]=> val_mod(model[:upfrp]["s1", g.name, t]) * 
                        val_mod(-shadow_price(model[:eq_min_upfrp]["s1", t])))
                    push!(gen_pay, ["$(g.name)", t, 3]=> 
                    val_mod(model[:dwfrp]["s1", g.name, t]) * 
                        val_mod(-shadow_price(model[:eq_min_dwfrp]["s1", t])))
                    push!(gen_pay, ["$(g.name)", t, 4]=> (val_mod(gen_pay[Any["$(g.name)", t, 1]]) +
                        val_mod(gen_pay[Any["$(g.name)", t, 2]]) + val_mod(gen_pay[Any["$(g.name)", t, 3]])))
                else
                    push!(gen_pay, ["$(g.name)", t, 2]=> (val_mod(model[:upfrp]["s1", g.name, t])-val_mod(dam_model[:upfrp]["s1", g.name, div((t+tf-1), tf) ])) * 
                        val_mod(-shadow_price(model[:eq_min_upfrp]["s1", t])))
                    push!(gen_pay, ["$(g.name)", t, 3]=> (val_mod(model[:dwfrp]["s1", g.name, t])-val_mod(dam_model[:dwfrp]["s1", g.name,  div((t+tf-1), tf)])) * 
                        val_mod(-shadow_price(model[:eq_min_dwfrp]["s1", t])))
                    push!(gen_pay, ["$(g.name)", t, 4]=> (val_mod(gen_pay[Any["$(g.name)", t, 1]]) +
                        val_mod(gen_pay[Any["$(g.name)", t, 2]]) + val_mod(gen_pay[Any["$(g.name)", t, 3]])))
                    push!(dam_gen_pay, ["$(g.name)",  div((t+tf-1), tf), 2]=> val_mod(dam_model[:upfrp]["s1", g.name,  div((t+tf-1), tf)]) * 
                        val_mod(-shadow_price(dam_model[:eq_min_upfrp]["s1",  div((t+tf-1), tf)])))
                    push!(dam_gen_pay, ["$(g.name)",  div((t+tf-1), tf), 3]=> val_mod(dam_model[:dwfrp]["s1", g.name,  div((t+tf-1), tf)]) * 
                        val_mod(-shadow_price(dam_model[:eq_min_dwfrp]["s1",  div((t+tf-1), tf)])))
                    push!(dam_gen_pay, ["$(g.name)",  div((t+tf-1), tf), 4]=> (val_mod(dam_gen_pay[Any["$(g.name)",  div((t+tf-1), tf), 1]]) +
                        val_mod(dam_gen_pay[Any["$(g.name)",  div((t+tf-1), tf), 2]]) + val_mod(dam_gen_pay[Any["$(g.name)",  div((t+tf-1), tf), 3]])))
                end
                
            else
                push!(gen_pay, ["$(g.name)", t, 4]=> (val_mod(gen_pay[Any["$(g.name)", t, 1]]) ))
                if dam_model!=0 && (any(g.name === dam_model[:instance].units[i].name for i in 1:length(dam_model[:instance].units)))
                    push!(dam_gen_pay, ["$(g.name)",  div((t+tf-1), tf), 4]=> (val_mod(dam_gen_pay[Any["$(g.name)",  div((t+tf-1), tf), 1]]) ))
                end
            end
            if dam_model==0 
                push!(gen_cost, ["$(g.name)", t, 1]=> value(model[:is_on][g.name, t]) * g.min_power_cost[t] + sum(
                    Float64[
                        value(model[:segprod]["s1", g.name, t, k]) *
                        g.cost_segments[k].cost[t] for
                        k in 1:length(g.cost_segments)
                    ],
                ))
            else

                push!(gen_cost, ["$(g.name)", t, 1]=> (value(model[:is_on][g.name, t]) * g.min_power_cost[t] + sum(
                    Float64[
                        value(model[:segprod]["s1", g.name, t, k]) *
                        g.cost_segments[k].cost[t] for
                        k in 1:length(g.cost_segments)
                    ],
                ))/tf)
            end

            S = length(g.startup_categories)
            push!(gen_cost, ["$(g.name)", t, 2]=> sum(
                g.startup_categories[s].cost *
                value(model[:startup][g.name, t, s]) for s in 1:S
            ))
            push!(gen_cost, ["$(g.name)", t, 3]=> (val_mod(gen_cost[Any["$(g.name)", t, 1]]) +
                val_mod(gen_cost[Any["$(g.name)", t, 2]]) ))
        end
        push!(gen_tot_pay, ["$(g.name)", 1]=> sum(val_mod(gen_pay[Any["$(g.name)", t, 1]]) for t in 1:instance.time))
        if type == "frp"
            push!(gen_tot_pay, ["$(g.name)", 2]=> sum(val_mod(gen_pay[Any["$(g.name)", t, 2]]) for t in 1:instance.time))
            push!(gen_tot_pay, ["$(g.name)", 3]=> sum(val_mod(gen_pay[Any["$(g.name)", t, 3]]) for t in 1:instance.time))
        end
        push!(gen_tot_pay, ["$(g.name)", 4]=> sum(val_mod(gen_pay[Any["$(g.name)", t, 4]]) for t in 1:instance.time))
        
        if ((dam_model!=0) && (any(g.name === dam_model[:instance].units[i].name for i in 1:length(dam_model[:instance].units))))
            
            push!(dam_gen_tot_pay, ["$(g.name)", 1]=> sum(val_mod(dam_gen_pay[Any["$(g.name)",  div((t+tf-1), tf), 1]]) for t in 1:instance.time)/tf)
            if type == "frp"
                push!(dam_gen_tot_pay, ["$(g.name)", 2]=> sum(val_mod(dam_gen_pay[Any["$(g.name)",  div((t+tf-1), tf), 2]]) for t in 1:instance.time)/tf)
                push!(dam_gen_tot_pay, ["$(g.name)", 3]=> sum(val_mod(dam_gen_pay[Any["$(g.name)", div((t+tf-1), tf), 3]]) for t in 1:instance.time)/tf)
            end
            push!(dam_gen_tot_pay, ["$(g.name)", 4]=> sum(val_mod(dam_gen_pay[Any["$(g.name)", div((t+tf-1), tf), 4]]) for t in 1:instance.time)/tf)
        end
        push!(gen_tot_cost, ["$(g.name)", 1]=> sum(val_mod(gen_cost[Any["$(g.name)", t, 1]]) for t in 1:instance.time))
        push!(gen_tot_cost, ["$(g.name)", 2]=> sum(val_mod(gen_cost[Any["$(g.name)", t, 2]]) for t in 1:instance.time))
        push!(gen_tot_cost, ["$(g.name)", 3]=> sum(val_mod(gen_cost[Any["$(g.name)", t, 3]]) for t in 1:instance.time))
        
        
        if dam_model==0 || !(any(g.name === dam_model[:instance].units[i].name for i in 1:length(dam_model[:instance].units)))
            push!(uplift_payment, ["$(g.name)"]=> -val_mod(min(val_mod(gen_tot_pay[Any["$(g.name)", 4]]-gen_tot_cost[Any["$(g.name)", 3]]) , -0))) 
        else
            push!(uplift_payment, ["$(g.name)"]=> -val_mod(min(val_mod(gen_tot_pay[Any["$(g.name)", 4]]+dam_gen_tot_pay[Any["$(g.name)", 4]]-gen_tot_cost[Any["$(g.name)", 3]]) , -0)))      
        end
        push!(gen_tot_pay, ["$(g.name)", 5]=> val_mod(gen_tot_pay[Any["$(g.name)", 4]]) + val_mod(uplift_payment[Any["$(g.name)"]]))
    end
    for t in 1:instance.time
        push!(systemwide_prices, ["$(t)", 1]=>val_mod(-shadow_price(model[:eq_power_balance]["s1", t])))
        if type == "frp"
            push!(systemwide_prices, ["$(t)", 2]=>val_mod(-shadow_price(model[:eq_min_upfrp]["s1", t])))
            push!(systemwide_prices, ["$(t)", 3]=>val_mod(-shadow_price(model[:eq_min_dwfrp]["s1", t])))
        end
    end
    for b in instance.buses
        for t in 1:instance.time
            push!(locational_prices, ["$(b.name)", "$(t)"]=>val_mod(-shadow_price(model[:eq_net_injection_def]["s1", b.name, t])))
        end
    end
    for b in instance.buses
        for t in 1:instance.time
            push!(curtailment, ["$(b.name)", "$(t)"]=>val_mod(model[:curtail]["s1", b.name, t]))
        end
    end
    # Printing
    println(nf, "*"^100)
    println(nf, " ")
    println(nf, "Generation payment")
    println(nf, "-"^112)
    if type == "frp"
        println(nf, "unit\t time \t generation payment \t up-FRP payment \t dw-FRP payment \tpre-up total payment")
    else
        println(nf, "unit\t time \t generation payment \tpre-up total payment")
    end 
    println(nf, "-"^112)
    for g in instance.units
        for t in 1:instance.time
            if type == "frp"
                println(nf, "$(g.name)\t $t \t $(val_mod(gen_pay[Any["$(g.name)", t, 1]])) \t\t\t $(val_mod(gen_pay[Any["$(g.name)", t, 2]])) \t\t\t $(val_mod(gen_pay[Any["$(g.name)", t, 3]]))\t\t\t $(val_mod(gen_pay[Any["$(g.name)", t, 4]])) ")
            else
                println(nf, "$(g.name)\t $t \t $(val_mod(gen_pay[Any["$(g.name)", t, 1]]))\t\t\t $(val_mod(gen_pay[Any["$(g.name)", t, 4]])) ")
            end
        end
        if g!=instance.units[length(instance.units)]
            println(nf, "-"^100)
        else
            println(nf, "-"^112)
        end
    end
    if type == "frp"
        println(nf, "unit \t generation payment \t up-FRP payment \t dw-FRP payment \tpre-up total payment")
    else
        println(nf, "unit \t generation payment \tpre-up total payment")
    end
    println(nf, "-"^112)
    for g in instance.units
        @printf(nf, " %s \t %f\t\t\t", g.name, val_mod(gen_tot_pay[Any["$(g.name)", 1]]))
        if type == "frp"
            @printf(nf, " %f\t\t\t", val_mod(gen_tot_pay[Any["$(g.name)", 2]]))
            @printf(nf, " %f\t\t\t", val_mod(gen_tot_pay[Any["$(g.name)", 3]]))
        end
        @printf(nf, " %f\n", val_mod(gen_tot_pay[Any["$(g.name)", 4]]))
    end
    println(nf, "-"^100)
    if type == "frp"
        println(nf, "generation payment \t up-FRP payment \t dw-FRP payment \t pre-up total payment")
    else
        println(nf, "generation payment \t pre-up total payment")
    end
    println(nf, "-"^100)
    if type == "frp"
        println(nf, "$(sum(val_mod(gen_tot_pay[Any["$(g.name)", 1]]) for g in instance.units)) \t\t\t $(sum(val_mod(gen_tot_pay[Any["$(g.name)", 2]]) for g in instance.units)) \t\t\t $(sum(val_mod(gen_tot_pay[Any["$(g.name)", 3]]) for g in instance.units)) \t\t\t $(sum(val_mod(gen_tot_pay[Any["$(g.name)", 4]]) for g in instance.units))")
    else
        println(nf, "$(sum(val_mod(gen_tot_pay[Any["$(g.name)", 1]]) for g in instance.units)) \t\t\t $(sum(val_mod(gen_tot_pay[Any["$(g.name)", 4]]) for g in instance.units))")
    end
    println(nf, " ")
    println(nf, "*"^100)
    println(nf, " ")
    println(nf, "Generation costs")
    println(nf, "-"^100)
    println(nf, "unit\t time \t generation cost \t start-up cost  \ttotal cost")
    println(nf, "-"^100)
    for g in instance.units
        for t in 1:instance.time
            println(nf, "$(g.name)\t $t \t $(val_mod(gen_cost[Any["$(g.name)", t, 1]])) \t\t\t $(val_mod(gen_cost[Any["$(g.name)", t, 2]])) \t\t\t$(val_mod(gen_cost[Any["$(g.name)", t, 3]]))")
        end
        println(nf, "-"^100)
    end
    println(nf, " ")
    println(nf, "unit \t generation \t generation cost \t start-up cost \t total cost")
    println(nf, "-"^100)
    for g in instance.units
        # println(nf, "$(g.name)\t $(sum(val_mod(gen_cost[Any["$(g.name)", t, 1]]) for t in 1:instance.time)) \t\t  $(sum(val_mod(gen_cost[Any["$(g.name)", t, 2]]) for t in 1:instance.time))  \t\t $(sum(val_mod(gen_cost[Any["$(g.name)", t, 3]]) for t in 1:instance.time))")
        sumv = (sum(val_mod(model[:prod_above]["s1", g.name, t]) + (val_mod(model[:is_on][g.name, t]) * g.min_power[1]) for t in 1:instance.time)/tf)
        @printf(nf, "%s \t %f\t\t\t", g.name, sumv)
        @printf(nf, "%f\t\t\t", val_mod(gen_tot_cost[Any[g.name, 1]]))
        @printf(nf, " %f\t\t", (val_mod(gen_tot_cost[Any[g.name, 2]])))
        @printf(nf, " %f\n", val_mod(gen_tot_cost[Any[g.name, 3]]))
        
    end
    println(nf, "-"^100)
    println(nf, " ")
    println(nf, "generation cost \t start-up cost \t\t total cost")
    println(nf, "-"^100)
    println(nf, "$(sum(val_mod(gen_cost[Any["$(g.name)", t, 1]]) for t in 1:instance.time for g in instance.units)) \t\t\t $(sum(val_mod(gen_cost[Any["$(g.name)", t, 2]]) for t in 1:instance.time for g in instance.units)) \t\t\t $(sum(val_mod(gen_cost[Any["$(g.name)", t, 3]]) for t in 1:instance.time for g in instance.units))")

    println(nf, "-"^100)
    for g in instance.units
        println(nf, "uplift payment for generator $(g.name): $(val_mod(uplift_payment[Any["$(g.name)"]]))")
    end  
    println(nf, " ")
    println(nf, "*"^100)
    println(nf, " ")
    println(nf, "$(market) Systemwide prices")
    println(nf, "-"^100)  
    if type == "frp"
        println(nf, "time\t energy \t up-FRP \t dw-FRP")
    else
        println(nf, "time\t energy")
    end

    println(nf, "-"^100)  
    for t in 1:instance.time
        if type == "frp"
            println(nf, "$t \t $(systemwide_prices[Any["$(t)", 1]]) \t\t $(systemwide_prices[Any["$(t)", 2]]) \t\t $(systemwide_prices[Any["$(t)", 3]])")
        else
            println(nf, "$t \t $(systemwide_prices[Any["$(t)", 1]])")
        end
    end  
    # if length(instance.buses) > 1
    
    # end
    println(nf, " ")
    println(nf, "*"^100)  
    println(nf, " ")
    println(nf, "$(market) Post-uplift payments")
    println(nf, "-"^148)
    if type == "frp"
        println(nf, "unit \t generation payment \t up-FRP payment \t dw-FRP payment \tpre-up t. payment \t uplift payments \t post-up t. payment \t profit")
    else
        println(nf, "unit \t generation payment \t pre-up t. payment \t uplift payments \t post-up t. payment \t profit")
    end
    println(nf, "-"^148)
    for g in instance.units
        @printf(nf, " %s \t %f\t\t\t", g.name, val_mod(gen_tot_pay[Any["$(g.name)", 1]]))
        if type == "frp"
            @printf(nf, " %f\t\t\t", val_mod(gen_tot_pay[Any[g.name, 2]]))
            @printf(nf, " %f\t\t\t", val_mod(gen_tot_pay[Any[g.name, 3]]))
        end
        @printf(nf, " %f\t\t\t", val_mod(gen_tot_pay[Any[g.name, 4]]))
        @printf(nf, " %f\t\t\t", val_mod(uplift_payment[Any[g.name]]))
        @printf(nf, " %f\t\t", val_mod(gen_tot_pay[Any[g.name, 5]]))
        if dam_model==0 || !(any(g.name === dam_model[:instance].units[i].name for i in 1:length(dam_model[:instance].units)))
            sum1 = val_mod(gen_tot_pay[Any[g.name, 5]])-val_mod(gen_tot_cost[Any[g.name, 3]])
            @printf(nf, " %f\n", sum1)
        else
            sum2 = val_mod(gen_tot_pay[Any[g.name, 5]])+val_mod(dam_gen_tot_pay[Any[g.name, 4]])-val_mod(gen_tot_cost[Any[g.name, 3]])
            @printf(nf, " %f\n", sum2)
        end
    end
    if market=="rtm"
        println(nf, "*"^100)  
        println(nf, " ")
        println(nf, "Total generator payments")
        println(nf, "-"^148)
        if type == "frp"
            println(nf, "unit \t generation payment \t up-FRP payment \t dw-FRP payment \tpre-up t. payment \t uplift payments \t post-up t. payment \t profit")
        else
            println(nf, "unit \t generation payment \t pre-up t. payment \t uplift payments \t post-up t. payment \t profit")
        end
        println(nf, "-"^148)
        term1 = term2 = term3 = term4 = term5 = term6 = 0
        for g in instance.units
            term1 = val_mod(gen_tot_pay[Any["$(g.name)", 1]])
            if type == "frp"
                term2 = val_mod(gen_tot_pay[Any["$(g.name)", 2]])
                term3 = val_mod(gen_tot_pay[Any["$(g.name)", 3]])
            end
            term4 = val_mod(gen_tot_pay[Any["$(g.name)", 4]])
            term5 = val_mod(gen_tot_pay[Any["$(g.name)", 5]])
            term6 = val_mod(gen_tot_pay[Any["$(g.name)", 5]]) - val_mod(gen_tot_cost[Any[g.name, 3]])
            if any(g.name === dam_model[:instance].units[i].name for i in 1:length(dam_model[:instance].units))
                term1 += val_mod(dam_gen_tot_pay[Any[g.name, 1]])
                if type == "frp"
                    term2 += val_mod(dam_gen_tot_pay[Any[g.name, 2]])
                    term3 += val_mod(dam_gen_tot_pay[Any[g.name, 3]])
                end
                term4 += val_mod(dam_gen_tot_pay[Any[g.name, 4]])
                term5 += val_mod(dam_gen_tot_pay[Any[g.name, 4]])
                term6 += val_mod(dam_gen_tot_pay[Any[g.name, 4]])
            end
            @printf(nf, " %s \t %f\t\t\t", g.name, term1)
            if type == "frp"
                @printf(nf, " %f\t\t\t", term2)
                @printf(nf, " %f\t\t\t", term3)
            end
            @printf(nf, " %f\t\t\t", term4)
            @printf(nf, " %f\t\t\t", val_mod(uplift_payment[Any[g.name]]))
            @printf(nf, " %f\t\t", term5)
            @printf(nf, " %f\n", term6)
        end
        
        println(nf, " ")
        println(nf, "*"^100)  
        println(nf, " ")
        println(nf, "$(market) LMP")
        println(nf, "-"^100)  
        println(nf, "bus name \t time \t\t LMP")
        println(nf, "-"^100)  
        for b in instance.buses
            for t in 1:instance.time
                println(nf, "$(b.name) \t\t $t \t\t $(locational_prices[Any["$(b.name)", "$(t)"]])")
            end
            println(nf, "-"^100)  
        end
        println(nf, "Total overall payments")
        println(nf, "-"^148)
        if type == "frp"
            println(nf, "total generation payment \t total up-FRP payment \t total dw-FRP payment \t total pre-up t. payment \t uplift payment \t total post-up t. payment \t profit")
        else
            println(nf, "generation payment \t pre-up t. payment \t uplift payment \t post-up t. payment \t profit")
        end
        println(nf, "-"^148)
        term1 = term2 = term3 = term4 = term5 = term6 = 0
        for g in instance.units
            term1 += val_mod(gen_tot_pay[Any["$(g.name)", 1]])
            term4 += val_mod(gen_tot_pay[Any["$(g.name)", 4]])
            term5 += val_mod(gen_tot_pay[Any["$(g.name)", 5]])
            term6 += (val_mod(gen_tot_pay[Any["$(g.name)", 5]]) - val_mod(gen_tot_cost[Any[g.name, 3]]))
            if any(g.name === dam_model[:instance].units[i].name for i in 1:length(dam_model[:instance].units))
                term1 += val_mod(dam_gen_tot_pay[Any[g.name, 1]])
                term4 += val_mod(dam_gen_tot_pay[Any[g.name, 4]])
                term5 += val_mod(dam_gen_tot_pay[Any[g.name, 4]])
                term6 += val_mod(dam_gen_tot_pay[Any[g.name, 4]])
            end
        end

        if type == "frp"
            for g in instance.units
                term2 += val_mod(gen_tot_pay[Any["$(g.name)", 2]])
                term3 += val_mod(gen_tot_pay[Any["$(g.name)", 3]])
                if any(g.name === dam_model[:instance].units[i].name for i in 1:length(dam_model[:instance].units))
                    term2 += val_mod(dam_gen_tot_pay[Any[g.name, 2]])
                    term3 += val_mod(dam_gen_tot_pay[Any[g.name, 3]])
                end
            end
        end
           
        if type == "frp"
            println(nf, "$(term1) \t\t\t $(term2) \t\t\t $(term3) \t\t\t $(term4)\t\t\t $(sum(val_mod(uplift_payment[Any["$(g.name)"]]) for g in instance.units)) \t\t\t $(term5) \t\t\t $(term6)")
        else
            println(nf, "$(term1) \t\t\t $(term4)\t\t\t $(sum(val_mod(uplift_payment[Any["$(g.name)"]]) for g in instance.units)) \t\t\t $(term5) \t\t\t $(term6)")
        end
        js_prices = "results/$(conf_name)/OOS_results/LMP_$(oos_n).json"
        jf_prices = open(js_prices, "w")
        println(jf_prices,"{")
        println(jf_prices, "\"LMPs\": {")
        for b in instance.buses
            println(jf_prices, "\t\"$(b.name)\":[")
            for t in 1:instance.time-1
                println(jf_prices, "\t\t$(locational_prices[Any["$(b.name)", "$(t)"]]),")
            end
            println(jf_prices, "\t\t$(locational_prices[Any["$(b.name)", "$(instance.time)"]])]")
            if b != instance.buses[length(instance.buses)]
                println(jf_prices, ",\n")
            else
                println(jf_prices, "\t},")
            end
        end
        println(jf_prices, "\"Average LMPs\": [")
        for t in 1:instance.time-1
            println(jf_prices, "\t\t$(sum(locational_prices[Any["$(b.name)", "$(t)"]] for b in instance.buses)/length(instance.buses)),")
        end
        println(jf_prices, "\t\t$(sum(locational_prices[Any["$(b.name)", "$(instance.time)"]] for b in instance.buses)/length(instance.buses))]")
        println(jf_prices,"}")
        close(jf_prices)
        js_curts = "results/$(conf_name)/OOS_results/curt_$(oos_n).json"
        jf_curts = open(js_curts, "w")
        println(jf_curts,"{")
        println(jf_curts, "\"Curtailments\": {")
        for b in instance.buses
            println(jf_curts, "\t\"$(b.name)\":[")
            for t in 1:instance.time-1
                println(jf_curts, "\t\t$(curtailment[Any["$(b.name)", "$(t)"]]),")
            end
            println(jf_curts, "\t\t$(curtailment[Any["$(b.name)", "$(instance.time)"]])]")
            if b != instance.buses[length(instance.buses)]
                println(jf_curts, ",\n")
            else
                println(jf_curts, "\t},")
            end
        end
        println(jf_curts, "\"Total curtailments\": [")
        for t in 1:instance.time-1
            println(jf_curts, "\t\t$(sum(curtailment[Any["$(b.name)", "$(t)"]] for b in instance.buses)),")
        end
        println(jf_curts, "\t\t$(sum(curtailment[Any["$(b.name)", "$(instance.time)"]] for b in instance.buses))]")
        println(jf_curts, "}")
        close(jf_curts)
        js_costs = "results/$(conf_name)/OOS_results/cost_$(oos_n).json"
        jf_costs = open(js_costs, "w")
        println(jf_costs,"{")
        println(jf_costs, "\"Total operating cost\": [")
        for t in 1:instance.time-1
            println(jf_costs, "\t\t$(sum(val_mod(gen_cost[Any["$(g.name)", t, 3]]) for g in instance.units)),")
        end
        println(jf_costs, "\t\t$(sum(val_mod(gen_cost[Any["$(g.name)", instance.time, 3]]) for g in instance.units))]")
        println(jf_costs, "}")
        close(jf_costs)
    end
    close(nf)

end