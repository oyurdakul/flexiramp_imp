# UnitCommitmentSTO.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_price_sensitive_load!(
    model::JuMP.Model,
    sc::Scenario,
    ps::PriceSensitiveLoad,
)::Nothing
    loads = _init(model, :loads)
    net_injection = _init(model, :expr_net_injection)
    tf=1/(model[:instance].time_multiplier)
    for t in 1:model[:instance].time
        # Decision variable
        loads[sc.name, ps.name, t] =
            @variable(model, lower_bound = 0, upper_bound = ps.demand[t])

        # Objective function terms
        add_to_expression!(model[:obj], tf*sc.probability*loads[sc.name, ps.name, t], -ps.revenue[t])

        # Net injection
        add_to_expression!(
            net_injection[sc.name, ps.bus.name,  t],
            loads[sc.name, ps.name,  t],
            -1.0,
        )
    end
    return
end
