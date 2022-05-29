using JSON
using PyCall

include("checkMUL_MB.jl")
include("check.jl")
include("compute_oos.jl")
include("compute_met_load.jl")
include("run_dam_rtm.jl")
include("alignment.jl")


f_name="2017-08-01.json"
f_path = "input_files/$(f_name)"
ext_name="sc"
rtm_gen_path = "input_files/rtm_gen.json"
frp_req_file =  "input_files/frp_req.json"
# frp_req_file = "input_files/frp_req_zeros.json"
json_rtm_gen = JSON.parse(open(rtm_gen_path), dicttype = () -> DefaultOrderedDict(nothing))
snumbers=[5, 10]
# mkdir("results")
# for i in 10:10:30
#     push!(snumbers,i)
# end

avals = [4]
# for i in 2:1:4
#     push!(avals,i)
# end

bvals = [2, 4, 8]
# for i in 2:1:4
#     push!(bvals,i)
# end

oos_sn=10
tf = 4
rtm_hor = 4
rtm_num = 24
frp_factor=0.02
oos_factors = [1]
time_model = @elapsed begin
    for a in avals
        for b in bvals
            for f in oos_factors
                intra_d = Normal(0, b*0.005)
                mkdir("results/$(a)_$(b)_$(f)")
                ext_path = extend_time(f_path, f_name, tf, intra_d, a, b, f)
                ext_rtm_path = rtm_gen_add(ext_path, json_rtm_gen, a, b, f)
                write_to_det_file(f_path, f_name, a, b, f)
                obj_vs, time_vs, sys_upfrp_reqs, sys_dwfrp_reqs, T = mul_compute(f_name, ext_path, ext_name, snumbers, tf, a, b, f)
                write_single_frp_req(ext_rtm_path, frp_req_file, frp_factor)
                read_frp_req(f_name, f_path, frp_req_file, tf, a, b, f)
                create_oos_files(ext_rtm_path, snumbers, oos_sn, rtm_hor, sys_upfrp_reqs, sys_dwfrp_reqs, frp_req_file, a, b, f)
                time_vals_fixed_frp, time_vals_frp, time_single, time_wout, obj_fixed_frp_dams, obj_frp_dams, obj_single_dam, obj_wout_dam, obj_fixed_frp_rtms, obj_frp_rtms, obj_single_rtm,  obj_wout_rtm = dam_rtm_computations(snumbers, f_name,  oos_sn, tf, rtm_num, a, b, f)
                py"aligment_function"(a, b, f)
                py"calculating_totals"(a, b, f)
                py"optimum_values_tables"(a, b, f, snumbers)
            end
        end
    end
end

println("computed in $(time_model) seconds")


# py"optimum_values_tables"(3, 1, snumbers)
