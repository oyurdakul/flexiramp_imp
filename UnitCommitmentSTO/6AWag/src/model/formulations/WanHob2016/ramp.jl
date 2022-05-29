# UnitCommitmentSTOFL.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_frp_vars!(model::JuMP.Model, sc::Scenario, g::Unit)::Nothing
    upfrp = _init(model, :upfrp)
    upfrp_shortfall = _init(model, :upfrp_shortfall)
    mfg=_init(model,:mfg)
    dwfrp = _init(model, :dwfrp)
    dwfrp_shortfall = _init(model, :dwfrp_shortfall)
    for t in 1:model[:instance].time
        # maximum feasible generation, \bar{g_{its}} in Wang & Hobbs (2016)
        mfg[sc.name, g.name, t]=@variable(model, lower_bound = 0)
        if g.provides_frp_reserves[t]
            upfrp[sc.name, g.name, t] = @variable(model) # up-flexiramp, ur_{it} in Wang & Hobbs (2016)
            dwfrp[sc.name, g.name, t] = @variable(model) # down-flexiramp, dr_{it} in Wang & Hobbs (2016)
        else
            upfrp[sc.name, g.name, t] = 0.0
            dwfrp[sc.name, g.name, t] = 0.0
        end
        upfrp_shortfall[sc.name, t] =
            (model[:instance].frp_shortfall_penalty[t] >= 0) ?
            @variable(model, lower_bound = 0) : 0.0
        dwfrp_shortfall[sc.name, t] =
            (model[:instance].frp_shortfall_penalty[t] >= 0) ?
            @variable(model, lower_bound = 0) : 0.0
    end
    return
end



function _add_ramp_eqs!(
    model::JuMP.Model,
    sc::Scenario,
    g::Unit,
    formulation_prod_vars::Gar1962.ProdVars,
    formulation_ramping::WanHob2016.Ramping,
    formulation_status_vars::Gar1962.StatusVars,
)::Nothing
    is_initially_on = (g.initial_status > 0)
    SU = g.startup_limit
    SD = g.shutdown_limit
    RU = g.ramp_up_limit
    RD = g.ramp_down_limit
    gn = g.name
    minp=g.min_power
    maxp=g.max_power
    initial_power=g.initial_power
    sn = sc.name
    is_on = model[:is_on]
    prod_above = model[:prod_above]
    upfrp=model[:upfrp]
    dwfrp=model[:dwfrp]
    mfg=model[:mfg]
    
    for t in 1:model[:instance].time
        
        @constraint(model, prod_above[sn, gn, t] + (is_on[gn, t]*minp[t]) 
            <=mfg[sn, gn, t]) # Eq. (19) in Wang & Hobbs (2016)
        @constraint(model, mfg[sn, gn, t]<= is_on[gn, t]* maxp[t]) # Eq. (22) in Wang & Hobbs (2016)
        if t!=model[:instance].time 
            @constraint(model, minp[t] * (is_on[gn, t+1]+is_on[gn, t]-1) <= 
                prod_above[sn, gn, t] - dwfrp[sn, gn, t] +(is_on[gn, t]*minp[t]) 
                ) # first inequality of Eq. (20) in Wang & Hobbs (2016)
            @constraint(model, prod_above[sn, gn, t] - dwfrp[sn, gn, t] + (is_on[gn, t]*minp[t]) <=
                mfg[sn, gn, t+1]
                + (maxp[t] * (1-is_on[gn, t+1]))
                ) # second inequality of Eq. (20) in Wang & Hobbs (2016)
            @constraint(model, minp[t] * (is_on[gn, t+1]+is_on[gn, t]-1) <=
                prod_above[sn, gn, t] + upfrp[sn, gn, t] + (is_on[gn, t]*minp[t])
                ) # first inequality of Eq. (21) in Wang & Hobbs (2016)
            @constraint(model, prod_above[sn, gn, t] + upfrp[sn, gn, t] +(is_on[gn, t]*minp[t]) <=
                mfg[sn, gn, t+1] + (maxp[t] * (1-is_on[gn, t+1]))
                ) # second inequality of Eq. (21) in Wang & Hobbs (2016)
            if t!=1
                @constraint(model, mfg[sn, gn, t]<=prod_above[sn, gn, t-1] + (is_on[gn, t-1]*minp[t])
                    + (RU * is_on[gn, t-1])
                    + (SU*(is_on[gn, t] - is_on[gn, t-1]))
                    + maxp[t] * (1-is_on[gn, t])
                    ) # Eq. (23) in Wang & Hobbs (2016)
                @constraint(model, (prod_above[sn, gn, t-1] + (is_on[gn, t-1]*minp[t])) 
                    - (prod_above[sn, gn, t] + (is_on[gn, t]*minp[t]))
                    <= RD * is_on[gn, t] 
                    + SD * (is_on[gn, t-1] - is_on[gn, t])
                    + maxp[t] * (1-is_on[gn, t-1])
                    ) # Eq. (25) in Wang & Hobbs (2016)
            else
                @constraint(model, mfg[sn, gn, t]<=initial_power 
                    + (RU * is_initially_on)
                    + (SU*(is_on[gn, t] - is_initially_on))
                    + maxp[t] * (1-is_on[gn, t])
                    ) # Eq. (23) in Wang & Hobbs (2016) for the first time period
                @constraint(model, initial_power  
                    - (prod_above[sn, gn, t] + (is_on[gn, t]*minp[t]))
                    <= RD * is_on[gn, t] 
                    + SD * (is_initially_on - is_on[gn, t])
                    + maxp[t] * (1-is_initially_on)
                    ) # Eq. (25) in Wang & Hobbs (2016) for the first time period
            end
            @constraint(model, mfg[sn, gn, t]<=
                (SD*(is_on[gn, t] - is_on[gn, t+1]))
                + (maxp[t] * is_on[gn, t+1])
                ) # Eq. (24) in Wang & Hobbs (2016)
            @constraint(model, -RD * is_on[gn, t+1]
                -SD * (is_on[gn, t]-is_on[gn, t+1])
                -maxp[t] * (1-is_on[gn, t]) 
                <= upfrp[sn, gn, t]
                ) # first inequality of Eq. (26) in Wang & Hobbs (2016)
            @constraint(model, upfrp[sn, gn, t] <=
                RU * is_on[gn, t]
                + SU * (is_on[gn, t+1]-is_on[gn, t])
                + maxp[t] * (1-is_on[gn, t+1])
                ) # second inequality of Eq. (26) in Wang & Hobbs (2016)
            @constraint(model, -RU * is_on[gn, t]
                -SU * (is_on[gn, t+1]-is_on[gn, t])
                -maxp[t] * (1-is_on[gn, t+1])
                <= dwfrp[sn, gn, t] 
                ) # first inequality of Eq. (27) in Wang & Hobbs (2016)
            @constraint(model, dwfrp[sn, gn, t] <=
                RD * is_on[gn, t+1]
                + SD * (is_on[gn, t]-is_on[gn, t+1])
                + maxp[t] * (1-is_on[gn, t])
                ) # second inequality of Eq. (27) in Wang & Hobbs (2016)
            @constraint(model, -maxp[t] * is_on[gn, t]
                +minp[t] * is_on[gn, t+1]
                <= upfrp[sn, gn, t]
                ) # first inequality of Eq. (28) in Wang & Hobbs (2016)
            @constraint(model, upfrp[sn, gn, t] <=
                maxp[t] * is_on[gn, t+1]
                ) # second inequality of Eq. (28) in Wang & Hobbs (2016)
            @constraint(model, -maxp[t] * is_on[gn, t+1]
                <= dwfrp[sn, gn, t]
                ) # first inequality of Eq. (29) in Wang & Hobbs (2016)
            @constraint(model, dwfrp[sn, gn, t] <=
                (maxp[t] * is_on[gn, t])
                -(minp[t] * is_on[gn, t+1])
                ) # second inequality of Eq. (29) in Wang & Hobbs (2016)
        else
            @constraint(model, mfg[sn, gn, t]<=prod_above[sn, gn, t-1] + (is_on[gn, t-1]*minp[t])
                + (RU * is_on[gn, t-1])
                + (SU*(is_on[gn, t] - is_on[gn, t-1]))
                + maxp[t] * (1-is_on[gn, t])
                ) # Eq. (23) in Wang & Hobbs (2016) for the last time period
            @constraint(model, (prod_above[sn, gn, t-1] + (is_on[gn, t-1]*minp[t])) 
                - (prod_above[sn, gn, t] + (is_on[gn, t]*minp[t]))
                <= RD * is_on[gn, t] 
                + SD * (is_on[gn, t-1] - is_on[gn, t])
                + maxp[t] * (1-is_on[gn, t-1])
                ) # Eq. (25) in Wang & Hobbs (2016) for the last time period
        end
    end
end