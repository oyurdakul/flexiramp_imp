# UnitCommitmentSTO.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function solution(model::JuMP.Model)::OrderedDict
    instance, T = model[:instance], model[:instance].time
    function timeseries(vars, collection)
        return OrderedDict(
            b.name => [round(value(vars[b.name, t]), digits = 5) for t in 1:T]
            for b in collection
        )
    end
    function production_cost(sc, g)
        return [
            value(model[:is_on][g.name, t]) * g.min_power_cost[t] + sum(
                Float64[
                    value(model[:segprod][sc.name, g.name, t, k]) *
                    g.cost_segments[k].cost[t] for
                    k in 1:length(g.cost_segments)
                ],
            ) for t in 1:T
        ]
    end
    function production(sc, g)
        return [
            value(model[:is_on][g.name, t]) * g.min_power[t] + sum(
                Float64[
                    value(model[:segprod][sc.name, g.name, t, k]) for
                    k in 1:length(g.cost_segments)
                ],
            ) for t in 1:T
        ]
    end
    function net_inj(sc, b)
        return [
            value(model[:net_injection][sc.name, b.name, t]) for t in 1:T
        ]
    end
    function load_cur_scen(sc, b)
        return OrderedDict("Load curtailment (MW)"=>[
            value(model[:curtail][sc.name, b.name, t]) for t in 1:T
        ])
    end
    function load_cur(b)
        return OrderedDict(sc.name => load_cur_scen(sc, b) for sc in b.scenarios)
    end

    function res(sc, g)
        return [
            value(model[:reserve][sc.name, g.name,t]) for t in 1:T
        ]
    end

    function upfr(sc, g)
        return [
            value(model[:upfrp][sc.name, g.name,t]) for t in 1:T
        ]
    end

    function dwfr(sc, g)
        return [
            value(model[:dwfrp][sc.name, g.name,t]) for t in 1:T
        ]
    end

    function over_flo(sc, l)
        return [
            value(model[:overflow][sc.name, l.name,t]) for t in 1:T
        ]
    end
    function startup_cost(g)
        S = length(g.startup_categories)
        return [
            sum(
                g.startup_categories[s].cost *
                value(model[:startup][g.name, t, s]) for s in 1:S
            ) for t in 1:T
        ]
    end
    sol = OrderedDict()
    for sc in instance.buses[1].scenarios
        sol["Production (MW), Scenario: $(sc.name)"] =
            OrderedDict(g.name => production(sc, g) for g in instance.units)
        sol["Production cost (\$), Scenario: $(sc.name)"] =
            OrderedDict(g.name => production_cost(sc, g) for g in instance.units)
        if instance.reserves.upfrp != zeros(T) || instance.reserves.dwfrp != zeros(T)
            # Report flexiramp solutions only if either of the up-flexiramp and  
            # down-flexiramp requirements is not a default array of zeros
            sol["up-flexiramp (MW), Scenario: $(sc.name)"] = 
                OrderedDict(g.name => upfr(sc, g) for g in instance.units)
            sol["up-flexiramp shortfall (MW), Scenario: $(sc.name)"] = OrderedDict(
                t =>
                    (instance.frp_shortfall_penalty[t] >= 0) ?
                    round(value(model[:upfrp_shortfall][sc.name, t]), digits = 5) : 0.0 for
                t in 1:instance.time
            )
            sol["down-flexiramp (MW), Scenario: $(sc.name)"] = 
                OrderedDict(g.name => dwfr(sc, g) for g in instance.units)
            sol["down-flexiramp shortfall (MW), Scenario: $(sc.name)"] = OrderedDict(
                t =>
                    (instance.frp_shortfall_penalty[t] >= 0) ?
                    round(value(model[:dwfrp_shortfall][sc.name, t]), digits = 5) : 0.0 for
                t in 1:instance.time
            )
        else
            # Report spinning reserve solutions only if both up-flexiramp and  
            # down-flexiramp requirements are arrays of zeros.
            sol["Reserve (MW), Scenario: $(sc.name)"] = OrderedDict(g.name => res(sc, g) for g in instance.units)
            sol["Reserve shortfall (MW)"] = OrderedDict(
                t =>
                    (instance.shortfall_penalty[t] >= 0) ?
                    round(value(model[:reserve_shortfall][sc.name, t]), digits = 5) : 0.0 for
                t in 1:instance.time
            )    
            
        end

        if !isempty(instance.lines)
            sol["Line overflow (MW), Scenario: $(sc.name)"] = 
                OrderedDict(l.name => over_flo(sc, l) for l in instance.lines)
        end
        
    end

    sol["Curtailment"] = OrderedDict(b.name => load_cur(b) for b in instance.buses)
    if !isempty(instance.price_sensitive_loads)
        sol["Price-sensitive loads (MW)"] =
            timeseries(model[:loads], instance.price_sensitive_loads)
    end
    sol["Startup cost (\$)"] =
        OrderedDict(g.name => startup_cost(g) for g in instance.units)
    sol["Is on"] = timeseries(model[:is_on], instance.units)
    sol["Switch on"] = timeseries(model[:switch_on], instance.units)
    sol["Switch off"] = timeseries(model[:switch_off], instance.units)
    
    
    return sol
end
