using Base: Float64, @var
using Gurobi
using Cbc
using Clp
using JuMP
using Printf
import Base
using Random, Distributions
using JSON
using DataStructures
using JSON: print
using GZip
import Base: getindex, time
using DataStructures: push!
basedir = homedir()
push!(LOAD_PATH,"content/flexiramp_imp/UnitCommitmentSTO/6AWag/src/")
import UnitCommitmentSTO
import MathOptInterface
using LinearAlgebra

function read_comm_values(comm_path)
    comm_values=readlines(comm_path)
    gn=trunc(Int,((length(comm_values)-1)))
    tn=trunc(Int,((length(split(comm_values[2],"\t"))-3)/2))
    sto_comm_values=zeros(gn, tn)
    @show gn
    @show tn
    # det_comm_values=zeros(gn, tn)
    for i in 1:gn
        for j in 1:tn
            sto_comm_values[i,j]=parse(Int64, split(comm_values[i+1],"\t")[2j+1])
            # det_comm_values[i,j]=parse(Int64, split(comm_values[3i],"\t")[1+2j])
        end
    end
    return sto_comm_values
end

