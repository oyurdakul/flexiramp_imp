include("checkFRP.jl")
include("compute_oos.jl")
include("comp_cost_pay.jl")



# obj_dam, model_dam=compute(input_dam_file)
# obj_frp_dam, model_frp_dam=frp_compute(input_dam_file)
# # println("objective function value w/out FRP: $(obj_dam)")
# # println("objective function value w/ FRP: $(obj_frp_dam)") 
# obj_rtm, model_rtm = compute(input_rtm_file, model_dam)
# obj_frp_rtm, model_frp_rtm = frp_compute(input_rtm_file, model_frp_dam)
# # println("objective function value w/out FRP: $(obj_rtm)")
# # println("objective function value w/ FRP: $(obj_frp_rtm)") 
function red_dam_vals(fixed_ext_dam_values, tf)
    gn = length(fixed_ext_dam_values[:, 1])
    
    tn = length(fixed_ext_dam_values[1, :])
    # println("gn is: $(gn)")
    # println("tn is: $(tn)")
    T = convert(Int64, tn/tf)
    fixed_dam_values = zeros(gn, T)
    for i in 1:gn
        for j in 1:T
            fixed_dam_values[i, j] = fixed_ext_dam_values[i, tf*(j-1)+1]
        end
    end
    return fixed_dam_values

end
function fixed_dam_fl_rtm(sval, fixed_dam_values, f_name, oos_sn, rtm_num, a, b, f)
    # println("fixed scen for sval: $(sval): $(fixed_dam_values)")
    obj_fixed_frp_dam, dam_model, time_fixed_frp = frp_compute("results/$(a)_$(b)_$(f)/frp_scenarios/$(split(f_name,".")[1])_sn$(sval)_frp.json", 
        "dam",
        fixed_dam_values,
        sval,
        0,
        0, 
        "fixed_scen",
        "0", a, b, f)
        obj_fixed_frp_rtms = []
        time_fixed_frp = []
        for i in 1:oos_sn
            # println("current i:$(i) sval:$(sval) aggregate fixed scen")
            obj_fixed_frp_rtm, rtm_model, time_rtm = frp_compute("results/$(a)_$(b)_$(f)/oos/oos_$(i)/s$(sval)/$(split(f_name,".")[1])_$(i).json", 
                "rtm",
                0,
                sval,
                dam_model,
                i,
                "fixed_scen",
                100, a, b, f)
            for j in 1:rtm_num
                # println("current i:$(i) j:$(j) sval:$(sval) fixed scen")
                obj_fixed_frp_rtm, rtm_model, time_rtm = frp_compute("results/$(a)_$(b)_$(f)/oos/oos_$(i)/s$(sval)/$(split(f_name,".")[1])_$(i)_sub$(j).json", 
                    "rtm",
                    0,
                    sval,
                    dam_model,
                    i,
                    "fixed_scen",
                    j, a, b, f)
                if j==rtm_num
                    push!(obj_fixed_frp_rtms, obj_fixed_frp_rtm)
                end
                push!(time_fixed_frp, time_rtm)
            end
            
        end
    return obj_fixed_frp_dam, obj_fixed_frp_rtms, time_fixed_frp
end

function dam_fl_rtm(sval, f_name, oos_sn, rtm_num, a, b, f)
    obj_frp_dam, dam_model, time_frp = frp_compute("results/$(a)_$(b)_$(f)/frp_scenarios/$(split(f_name,".")[1])_sn$(sval)_frp.json", 
        "dam",
        0,
        sval,
        0,
        0,
        "scen",
        "0", a, b, f)
    obj_frp_rtms = []
    time_frp = []
    for i in 1:oos_sn
        # println("current i:$(i) sval:$(sval) aggregate scen")
        # obj_frp_rtm, rtm_model, time_rtm = frp_compute("results/$(a)_$(b)_$(f)/oos/oos_$(i)/s$(sval)/$(split(f_name,".")[1])_$(i).json", 
        #     "rtm",
        #     0,
        #     sval,
        #     dam_model,
        #     i,
        #     "scen",
        #     100, a, b, f)
        for j in 1:rtm_num
            println("current i:$(i) j:$(j) sval:$(sval) scen")
            obj_frp_rtm, rtm_model, time_rtm = frp_compute("results/$(a)_$(b)_$(f)/oos/oos_$(i)/s$(sval)/$(split(f_name,".")[1])_$(i)_sub$(j).json", 
                "rtm",
                0,
                sval,
                dam_model,
                i,
                "scen",
                j, a, b, f)
            if j==rtm_num
                push!(obj_frp_rtms, obj_frp_rtm)
            end
            push!(time_frp, time_rtm)
        end
        
    end
    return obj_frp_dam, obj_frp_rtms, time_frp
end


function dam_frp(f_name, oos_sn, a, b, f)
    obj_single_dam, dam_model, time_single = frp_compute("results/$(a)_$(b)_$(f)/frp_scenarios/$(split(f_name,".")[1])_sn0_frp.json", 
        "dam",
        0,
        0,
        0,
        0,
        "single",
        "0", a, b, f)
    obj_single_rtms = []
    time_single = []
    for i in 1:oos_sn
        # println("current i:$(i)  aggregate single")
        # obj_single_rtm, rtm_model, time_rtm = frp_compute("results/$(a)_$(b)_$(f)/oos/oos_$(i)/single/$(split(f_name,".")[1])_$(i).json", 
        #     "rtm",
        #     0,
        #     0,
        #     dam_model,
        #     i,
        #     "single",
        #     100, a, b, f)
        for j in 1:rtm_num
            println("current i:$(i) j:$(j) single")
            obj_single_rtm, rtm_model, time_rtm = frp_compute("results/$(a)_$(b)_$(f)/oos/oos_$(i)/single/$(split(f_name,".")[1])_$(i)_sub$(j).json", 
                "rtm",
                0,
                0,
                dam_model,
                i,
                "single",
                j, a, b, f)
            if j==rtm_num
                push!(obj_single_rtms, obj_single_rtm)
            end
            push!(time_single, time_rtm)
        end
        
    end
    return obj_single_dam, obj_single_rtms, time_single
end


function dam_rtm(f_name, oos_sn, a, b, f)
    obj_wout_dam, dam_model,  time_wout = frp_compute("results/$(a)_$(b)_$(f)/det/$(split(f_name,".")[1])_det.json", 
        "dam",
        0,
        0,
        0,
        0,
        "wout",
        "0", a, b, f)
    obj_wout_rtms = []
    time_wout = []
    for i in 1:oos_sn
        # println("current i:$(i) aggregate wout")
        # obj_wout_rtm, rtm_model, time_rtm = frp_compute("results/$(a)_$(b)_$(f)/oos/oos_$(i)/wout/$(split(f_name,".")[1])_$(i).json", 
        #     "rtm",
        #     0,
        #     0,
        #     dam_model,
        #     i,
        #     "wout",
        #     100, a, b, f)
        for j in 1:rtm_num
            println("current i:$(i) j:$(j) wout")
            obj_wout_rtm, rtm_model, time_rtm = frp_compute("results/$(a)_$(b)_$(f)/oos/oos_$(i)/wout/$(split(f_name,".")[1])_$(i)_sub$(j).json", 
            "rtm",
            0,
            0,
            dam_model,
            i,
            "wout",
            j, a, b, f)
            if j==rtm_num
                push!(obj_wout_rtms, obj_wout_rtm)
            end
            push!(time_wout, time_rtm)
        end
    end
    return obj_wout_dam, obj_wout_rtms, time_wout
end

function dam_rtm_computations(snumbers, f_name, oos_sn, tf, rtm_num, a, b, f)
 
    
    obj_fixed_frp_dams=[]
    obj_fixed_frp_rtms=[]
    time_vals_fixed_frp=[]
    obj_frp_dams=[]
    obj_frp_rtms = []
    time_vals_frp=[]
    fixed_ext_dam_values_svals = []
    fixed_dam_values_svals = []
    
    
    mkdir("results/$(a)_$(b)_$(f)/DAM_FRP")
    mkdir("results/$(a)_$(b)_$(f)/DAM_FRP/OOS_results")
    mkdir("results/$(a)_$(b)_$(f)/DAM_RTM")
    mkdir("results/$(a)_$(b)_$(f)/DAM_RTM/OOS_results") 
    
   
    obj_wout_dam, obj_wout_rtm, time_wout=dam_rtm(f_name, oos_sn, a, b, f)
    obj_single_dam, obj_single_rtm, time_single=dam_frp(f_name, oos_sn, a, b, f)

    for sval in snumbers
        mkdir("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)")
        mkdir("results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)")
        mkdir("results/$(a)_$(b)_$(f)/DAM_FRP_fixed_s$(sval)/OOS_results")
        mkdir("results/$(a)_$(b)_$(f)/DAM_FRP_s$(sval)/OOS_results")
        comm_path = "results/$(a)_$(b)_$(f)/comm_results/commitment_values_$(sval).txt"
        fixed_ext_dam_values = read_comm_values(comm_path)
        fixed_dam_values = red_dam_vals(fixed_ext_dam_values, tf)
        push!(fixed_ext_dam_values_svals, fixed_ext_dam_values)
        push!(fixed_dam_values_svals, fixed_dam_values)
        obj_frp_dam, obj_frp_rtm, time_frp = dam_fl_rtm(sval, f_name, oos_sn, rtm_num, a, b, f)
        push!(obj_frp_dams, obj_frp_dam)
        push!(obj_frp_rtms, obj_frp_rtm)
        push!(time_vals_frp, time_frp)
        obj_fixed_frp_dam, obj_fixed_frp_rtm, time_fixed_frp = fixed_dam_fl_rtm(sval, fixed_dam_values, f_name, oos_sn, rtm_num, a, b, f)
        push!(obj_fixed_frp_dams, obj_fixed_frp_dam)
        push!(obj_fixed_frp_rtms, obj_fixed_frp_rtm)
        push!(time_vals_fixed_frp, time_fixed_frp)
    end
    
    mkdir("results/$(a)_$(b)_$(f)/rtm_compare")
    nf = open("results/$(a)_$(b)_$(f)/rtm_compare/rtm_oos.txt", "w")
    rtm_compare(snumbers, oos_sn, nf, obj_fixed_frp_rtms, obj_frp_rtms, obj_single_rtm, obj_wout_rtm, a, b, f)
    close(nf)
    return time_vals_fixed_frp, time_vals_frp, time_single, time_wout, obj_fixed_frp_dams, obj_frp_dams, obj_single_dam, obj_wout_dam, obj_fixed_frp_rtms, obj_frp_rtms, obj_single_rtm,  obj_wout_rtm
    # return time_vals_frp, time_single, time_wout, obj_frp_dams, obj_single_dam, obj_wout_dam, obj_frp_rtms, obj_single_rtm,  obj_wout_rtm

end