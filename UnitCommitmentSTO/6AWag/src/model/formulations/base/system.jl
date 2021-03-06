# UnitCommitmentSTO.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_system_wide_eqs!(model::JuMP.Model, sc::Scenario)::Nothing
    _add_net_injection_eqs!(model, sc)
    _add_reserve_eqs!(model, sc)
    _add_frp_eqs!(model, sc) # Add system-wide flexiramp requirements
    return
end

function _add_net_injection_eqs!(model::JuMP.Model, sc::Scenario)::Nothing
    T = model[:instance].time
    net_injection = _init(model, :net_injection)
    eq_net_injection_def = _init(model, :eq_net_injection_def)
    eq_power_balance = _init(model, :eq_power_balance)
    for t in 1:T, b in model[:instance].buses
        n = net_injection[sc.name, b.name, t] = @variable(model)
        eq_net_injection_def[sc.name, b.name, t] =
            @constraint(model, n == model[:expr_net_injection][sc.name, b.name, t])
    end
    for t in 1:T
        eq_power_balance[sc.name, t] = @constraint(
            model,
            sum(net_injection[sc.name, b.name, t] for b in model[:instance].buses) == 0
        )
    end
    return
end

function _add_reserve_eqs!(model::JuMP.Model, sc::Scenario)::Nothing
    eq_min_reserve = _init(model, :eq_min_reserve)
    instance = model[:instance]
    tf = 1/(model[:instance].time_multiplier)
    for t in 1:instance.time
        # Equation (68) in Kneuven et al. (2020)
        # As in Morales-España et al. (2013a)
        # Akin to the alternative formulation with max_power_avail
        # from Carrión and Arroyo (2006) and Ostrowski et al. (2012)
        shortfall_penalty = instance.shortfall_penalty[t]
        eq_min_reserve[sc.name, t] = @constraint(
            model,
            sum(model[:reserve][sc.name, g.name, t] for g in instance.units) +
            (shortfall_penalty >= 0 ? model[:reserve_shortfall][sc.name, t] : 0.0) >=
            instance.reserves.spinning[t]
        )

        # Account for shortfall contribution to objective
        if shortfall_penalty >= 0
            add_to_expression!(
                model[:obj],
                tf*sc.probability*shortfall_penalty,
                model[:reserve_shortfall][t],
            )
        end
    end
    return
end

function _add_frp_eqs!(model::JuMP.Model, sc::Scenario)::Nothing
    # Note: The flexpramp requirements in Wang & Hobbs (2016) are imposed as hard constraints 
   #       through Eq. (17) and Eq. (18). The constraints eq_min_upfrp[t] and eq_min_dwfrp[t] 
   #       provided below are modified versions of Eq. (17) and Eq. (18), respectively, in that   
   #       they include slack variables for flexiramp shortfall, which are penalized in the
   #       objective function.
   eq_min_upfrp = _init(model, :eq_min_upfrp)
   eq_min_dwfrp = _init(model, :eq_min_dwfrp)
   instance = model[:instance]
   tf = 1/(model[:instance].time_multiplier)
   for t in 1:instance.time
       frp_shortfall_penalty = instance.frp_shortfall_penalty[t]
       # Eq. (17) in Wang & Hobbs (2016)
       eq_min_upfrp[sc.name, t] = @constraint(
           model,
           sum(model[:upfrp][sc.name, g.name, t] for g in instance.units) +
           (frp_shortfall_penalty >= 0 ? model[:upfrp_shortfall][sc.name, t] : 0.0) >=
           instance.reserves.upfrp[t]
       )
       # Eq. (18) in Wang & Hobbs (2016)
       eq_min_dwfrp[sc.name, t] = @constraint(
           model,
           sum(model[:dwfrp][sc.name, g.name, t] for g in instance.units) +
           (frp_shortfall_penalty >= 0 ? model[:dwfrp_shortfall][sc.name, t] : 0.0) >=
           instance.reserves.dwfrp[t]
       )

       # Account for flexiramp shortfall contribution to objective
       if frp_shortfall_penalty >= 0
           add_to_expression!(
               model[:obj],
               tf*sc.probability*frp_shortfall_penalty,
               (model[:upfrp_shortfall][sc.name, t]+model[:dwfrp_shortfall][sc.name, t]),
           )
       end
   end
   return
end