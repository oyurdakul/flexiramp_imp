# UnitCommitmentSTO.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.
mutable struct Scenario
    name::String
    load::Vector{Float64}
    probability::Float64
end

mutable struct Bus
    name::String
    offset::Int
    scenarios::Vector
    units::Vector
    price_sensitive_loads::Vector
end

mutable struct CostSegment
    mw::Vector{Float64}
    cost::Vector{Float64}
end

mutable struct StartupCategory
    delay::Int
    cost::Float64
end

mutable struct Unit
    name::String
    bus::Bus
    max_power::Vector{Float64}
    min_power::Vector{Float64}
    must_run::Vector{Bool}
    min_power_cost::Vector{Float64}
    cost_segments::Vector{CostSegment}
    min_uptime::Int
    min_downtime::Int
    ramp_up_limit::Float64
    ramp_down_limit::Float64
    startup_limit::Float64
    shutdown_limit::Float64
    initial_status::Union{Int,Nothing}
    initial_power::Union{Float64,Nothing}
    provides_spinning_reserves::Vector{Bool}
    provides_frp_reserves::Vector{Bool} # binary variable indicating whether the unit provides flexiramp
    startup_categories::Vector{StartupCategory}
end

mutable struct TransmissionLine
    name::String
    offset::Int
    source::Bus
    target::Bus
    reactance::Float64
    susceptance::Float64
    normal_flow_limit::Vector{Float64}
    emergency_flow_limit::Vector{Float64}
    flow_limit_penalty::Vector{Float64}
end

mutable struct Reserves
    spinning::Vector{Float64}
    upfrp::Vector{Float64} # up-flexiramp reserve requirements
    dwfrp::Vector{Float64} # down-flexiramp reserve requirements
end

mutable struct Contingency
    name::String
    lines::Vector{TransmissionLine}
    units::Vector{Unit}
end

mutable struct PriceSensitiveLoad
    name::String
    bus::Bus
    demand::Vector{Float64}
    revenue::Vector{Float64}
end

Base.@kwdef mutable struct UnitCommitmentSTOInstance
    nscenarios::Int
    buses_by_name::Dict{AbstractString,Bus}
    buses::Vector{Bus}
    contingencies_by_name::Dict{AbstractString,Contingency}
    contingencies::Vector{Contingency}
    lines_by_name::Dict{AbstractString,TransmissionLine}
    lines::Vector{TransmissionLine}
    power_balance_penalty::Vector{Float64}
    price_sensitive_loads_by_name::Dict{AbstractString,PriceSensitiveLoad}
    price_sensitive_loads::Vector{PriceSensitiveLoad}
    reserves::Reserves
    shortfall_penalty::Vector{Float64}
    frp_shortfall_penalty::Vector{Float64} # penalty price for FRP shortfall
    time::Int
    time_multiplier::Int
    units_by_name::Dict{AbstractString,Unit}
    units::Vector{Unit}
end

function Base.show(io::IO, instance::UnitCommitmentSTOInstance)
    print(io, "UnitCommitmentSTOInstance(")
    print(io, "$(length(instance.units)) units, ")
    print(io, "$(length(instance.buses)) buses, ")
    print(io, "$(length(instance.lines)) lines, ")
    print(io, "$(length(instance.nscenarios)) scenarios, ")
    print(io, "$(length(instance.contingencies)) contingencies, ")
    print(
        io,
        "$(length(instance.price_sensitive_loads)) price sensitive loads, ",
    )
    print(io, "$(instance.time) time steps")
    print(io, ")")
    return
end

export UnitCommitmentSTOInstance
