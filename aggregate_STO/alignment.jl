py"""

import json

def aligment_function(a, b, f):

    output_file = open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/rtm_compare/rtm_oos_modified_" + str(a) + "_" + str(b) + "_" + str(f) + ".txt", "a")
    with open(r"results/" + str(a) + "_" + str(b) + "_" + str(f) + "/rtm_compare/rtm_oos.txt", 'r') as lines:
        for line in lines:
            data = line.split()    # Splits on whitespace

            if len(data) == 14:
                output_file.write( "{:21}{:8} {:19}{:6} {:23}{:6} {:23}{:6} {:2} {:20}{:6} {:23}{:6} {:2} {:20}\n".format( " ", data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7], data[8], data[9], data[10], data[11], data[12], data[13]) )
            elif len(data) == 9:
                output_file.write( "{:10} {:10}{:30}{:30}{:30}{:30}{:30}{:30}{:30}\n".format( data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7], data[8]) )
            elif len(data) == 8:
                output_file.write( "{:21}{:30}{:30}{:30}{:30}{:30}{:30}{:30}\n".format( data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7]) )
            elif len(data) == 1:
                output_file.write( "-----------------------------------------------------------------------------------------------------------------------------------------\n")
            elif len(data) == 5:
                output_file.write( "{:10}{:10}{:10}{:10}{:20}\n".format( data[0], data[1], data[2], data[3], data[4]) )
            elif len(data) == 4:
                output_file.write( "{:20}{:10}{:10}{:20}\n".format( data[0], data[1], data[2], data[3]) )
            else:
                continue


def calculating_totals(a, b, f):



    # FIRST PART START*************************************************************************

    file1 = open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/rtm_compare/rtm_oos.txt", 'r')
    Lines_finder_sample_number = file1.readlines()
    sample_number = 0
    for line in Lines_finder_sample_number:
        splitted_line = line.split()
        if len(splitted_line) == 1:
            break
        else:
            sample_number = sample_number + 1

    sample_number = sample_number - 3
    sample_number = sample_number / 2
    sample_number = int(sample_number)

    # FIRST PART FINISH*************************************************************************

    # SECOND PART START*************************************************************************

    file2 = open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/rtm_compare/rtm_oos.txt", 'r')
    Line_counter = file2.readlines()
    total_line_count = 0

    for line in Line_counter:
        splitted_line = line.split()
        if(len(splitted_line) != 1 and len(splitted_line) <= 5):
            break

        total_line_count = total_line_count + 1

    # SECOND PART FINISH*************************************************************************

    # THIRD PART START*************************************************************************

    fixed_names = []
    file3 = open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/rtm_compare/rtm_oos.txt", 'r')
    line_finding_fixed_names = file3.readline()
    for i in range(sample_number):
        line_finding_fixed_names = file3.readline()
        splitted_line_finding_name = line_finding_fixed_names.split()
        fixed_names.append(splitted_line_finding_name[1][:len(splitted_line_finding_name[1]) - 1])

        line_finding_fixed_names = file3.readline()


    # ****************************************************************************************************************
    # FINDING TOTALS OF PAYMENTS
    # ****************************************************************************************************************


    post_up_total_fixed     = [0.0] * sample_number
    post_up_total_non_fixed = [0.0] * sample_number

    total_single            = 0.0
    total_wout              = 0.0


    file4 = open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/rtm_compare/rtm_oos.txt", 'r')
    file_counter = 1

    total_line_count = int(total_line_count)
    sample_number = int(sample_number)

    for i in range( int( int(total_line_count) / ( int(sample_number) * 2 + 4) ) ) :

        fixed_array       = []
        non_fixed_array   = []

        line_before_split = file4.readline()
        for pairs in range(sample_number):

            line_before_split = file4.readline()
            line_after_split = line_before_split.split()
            post_up_total_fixed[pairs] = float(line_after_split[-2][:25]) + post_up_total_fixed[pairs]

            line_before_split = file4.readline()
            line_after_split = line_before_split.split()
            post_up_total_non_fixed[pairs] = float(line_after_split[-2][:25]) + post_up_total_non_fixed[pairs]

        line_before_split = file4.readline()
        line_after_split = line_before_split.split()
        total_single = total_single + float(line_after_split[-2][:25])

        line_before_split = file4.readline()
        line_after_split = line_before_split.split()
        total_wout = total_wout + float(line_after_split[-2][:25])

        line_before_split = file4.readline()


    # ****************************************************************************************************************
    # COMPUTING TOTAL COSTS & PAYMENTS
    # ****************************************************************************************************************


    file5 = open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/rtm_compare/rtm_oos.txt", 'r')
    line = "cenk"
    for i in range(total_line_count):
        line = file5.readline()


    post_up_total_fixed_cost     = [0.0] * sample_number
    post_up_total_non_fixed_cost = [0.0] * sample_number

    total_single_cost            = 0.0
    total_wout_cost              = 0.0

    for i in range( int( int(total_line_count) / ( int(sample_number) * 2 + 4) ) ) :

            fixed_array     = []
            non_fixed_array = []

            for pairs in range(sample_number):

                line_before_split = file5.readline()
                line_after_split = line_before_split.split()
                post_up_total_fixed_cost[pairs] = float(line_after_split[-1][:25]) + post_up_total_fixed_cost[pairs]

                line_before_split = file5.readline()
                line_after_split = line_before_split.split()
                post_up_total_non_fixed_cost[pairs] = float(line_after_split[-1][:25]) + post_up_total_non_fixed_cost[pairs]


            line_before_split = file5.readline()
            line_after_split = line_before_split.split()
            total_single_cost = total_single_cost + float(line_after_split[-1][:25])

            line_before_split = file5.readline()
            line_after_split = line_before_split.split()
            total_wout_cost = total_wout_cost + float(line_after_split[-1][:25])

            line_before_split = file5.readline()     # last read, it is required due to "------" line


                # -----------------------------------------------------------------------------------------------------------------------------------
                # creating .txt file and writing sum values
                # -----------------------------------------------------------------------------------------------------------------------------------


    sum_post_up = open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/rtm_compare/rtm_oos_modified_" + str(a) + "_" + str(b) + "_" + str(f) + ".txt", "a")
    sum_cost    = open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/rtm_compare/rtm_oos_modified_" + str(a) + "_" + str(b) + "_" + str(f) + ".txt", "a")

    sum_post_up.write("-----------------------------------------------------------------------------------------------------------------------------------------\n")
    sum_post_up.write("TOTAL PAYMENTS\n")
    for sample5 in range( sample_number ):
        sum_post_up.write( "Total post-up t. payment of fixed sample      {:7} {:3} {:9}\n".format( fixed_names[sample5], ":", post_up_total_fixed[sample5]) )
        sum_post_up.write( "Total post-up t. payment of non-fixed sample  {:7} {:3} {:10}\n".format( fixed_names[sample5], ":", str(post_up_total_non_fixed[sample5]) ) )
        # sum_post_up.write("Total post-up t. payment of fixed sample " + str(fixed_names[sample5]) + " : " +  str( post_up_total_fixed[sample5] ) + "\n" )
        # sum_post_up.write("Total post-up t. payment of non-fixed sample " + str(fixed_names[sample5]) + " : " +  str( post_up_total_non_fixed[sample5] ) + "\n" )
    sum_post_up.write("Total post-up t. payment of single sample             :   " +  str( total_single ) + "\n" )
    sum_post_up.write("Total post-up t. payment of wout sample               :   " +  str( total_wout ) + "\n" )
    sum_post_up.write("-----------------------------------------------------------------------------------------------------------------------------------------\n")


    sum_post_up.write("TOTAL COSTS\n")
    for sample6 in range( sample_number ):
        # sum_cost.write("Total cost of fixed sample " + str(fixed_names[sample6]) + " : " +  str( post_up_total_fixed_cost[sample6] ) + "\n" )
        # sum_cost.write("Total cost of non-fixed sample " + str(fixed_names[sample6]) + " : " +  str( post_up_total_non_fixed_cost[sample6] ) + "\n" )

        sum_post_up.write( "Total cost of fixed sample                   {:8} {:3} {:9}\n".format( fixed_names[sample6], ":", post_up_total_fixed_cost[sample6]) )
        sum_post_up.write( "Total cost of non-fixed sample               {:8} {:3} {:10}\n".format( fixed_names[sample6], ":", str(post_up_total_non_fixed_cost[sample6]) ) )


    sum_cost.write("Total cost of single sample                           :   " +  str( total_single_cost ) + "\n" )
    sum_cost.write("Total cost of  wout sample                            :   " +  str( total_wout_cost ) + "\n" )
    sum_cost.write("-----------------------------------------------------------------------------------------------------------------------------------------\n")
    return


def optimum_values_tables(a, b, f, arr_file_names):


    how_many_generators  = 0
    how_many_time_period = 0

    with open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/DAM_RTM/output_DAM.json") as json_file:
        data = json.load(json_file)
        how_many_generators = len(data["Is on"])
        how_many_time_period = len(data["Is on"]["g1"])


    output_file = open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/is_on_table.txt", "w+")

    for generator_number in range(how_many_generators):

        output_file.write("g" + str(generator_number + 1) + "\n \n")

        output_of_times = "                     "
        for time in range(how_many_time_period):
            output_of_times = output_of_times +  ( 5 - len(str(time)) ) * " " + str(time + 1)

        output_file.write(output_of_times + "\n")

        with open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/DAM_RTM/output_DAM.json") as json_file:
            data = json.load(json_file)
            data = data["Is on"][ "g" + str(generator_number + 1) ]

            output_txt = "DAM_RTM              "

            for time_number in range(how_many_time_period):
                output_txt = output_txt + "    " + str( int(data[time_number]) )

            output_file.write(output_txt + "\n")


        with open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/DAM_FRP/output_DAM.json") as json_file:
            data = json.load(json_file)
            data = data["Is on"][ "g" + str(generator_number + 1) ]

            output_txt = "DAM_FRP              "

            for time_number in range(how_many_time_period):
                output_txt = output_txt + "    " + str( int(data[time_number]) )

            output_file.write(output_txt + "\n")

        for fixed_non_fixed_number in arr_file_names:

            with open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/DAM_FRP_fixed_s" + str(fixed_non_fixed_number) + "/output_DAM_" + str(fixed_non_fixed_number) + ".json") as json_file:
                data = json.load(json_file)
                data = data["Is on"][ "g" + str(generator_number + 1) ]

                output_txt = "DAM_FRP_fixed_s" + str(fixed_non_fixed_number) + ( 6 - len( str(fixed_non_fixed_number) ) ) * " "

                for time_number in range(how_many_time_period):
                    output_txt = output_txt + "    " + str( int(data[time_number]) )

                output_file.write(output_txt + "\n")

            with open("results/" + str(a) + "_" + str(b) + "_" + str(f) + "/DAM_FRP_s" + str(fixed_non_fixed_number) + "/output_DAM_" + str(fixed_non_fixed_number) + ".json") as json_file:
                data = json.load(json_file)
                data = data["Is on"][ "g" + str(generator_number + 1) ]

                output_txt = "DAM_FRP_s" + str(fixed_non_fixed_number) + ( 12 - len( str(fixed_non_fixed_number) ) ) * " "

                for time_number in range(how_many_time_period):
                    output_txt = output_txt + "    " + str( int(data[time_number]) )

                output_file.write(output_txt + "\n")

        output_file.write("************************************************************************************************* \n \n")


"""
