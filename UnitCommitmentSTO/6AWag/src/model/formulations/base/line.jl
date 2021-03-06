# UnitCommitmentSTO.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_transmission_line!(
    model::JuMP.Model,
    sc::Scenario,
    lm::TransmissionLine,
    f::ShiftFactorsFormulation,
)::Nothing
    overflow = _init(model, :overflow)
    for t in 1:model[:instance].time
        overflow[sc.name, lm.name, t] = @variable(model, lower_bound = 0)
        add_to_expression!(
            model[:obj],
            sc.probability*overflow[sc.name, lm.name, t],
            lm.flow_limit_penalty[t],
        )
    end
    return
end

function _setup_transmission(
    model::JuMP.Model,
    formulation::ShiftFactorsFormulation,
)::Nothing
    instance = model[:instance]
    isf = formulation.precomputed_isf
    lodf = formulation.precomputed_lodf
    if length(instance.buses) == 1
        isf = zeros(0, 0)
        lodf = zeros(0, 0)
    elseif isf === nothing
        @info "Computing injection shift factors..."
        time_isf = @elapsed begin
            isf = UnitCommitmentSTO._injection_shift_factors(
                lines = instance.lines,
                buses = instance.buses,
            )
        end
        @info @sprintf("Computed ISF in %.2f seconds", time_isf)
        @info "Computing line outage factors..."
        time_lodf = @elapsed begin
            lodf = UnitCommitmentSTO._line_outage_factors(
                lines = instance.lines,
                buses = instance.buses,
                isf = isf,
            )
        end
        @info @sprintf("Computed LODF in %.2f seconds", time_lodf)
        @info @sprintf(
            "Applying PTDF and LODF cutoffs (%.5f, %.5f)",
            formulation.isf_cutoff,
            formulation.lodf_cutoff
        )
        isf[abs.(isf).<formulation.isf_cutoff] .= 0
        lodf[abs.(lodf).<formulation.lodf_cutoff] .= 0
    end
    model[:isf] = isf
    model[:lodf] = lodf
    return
end
