import xlsxwriter, json, os
import numpy as np
import itertools

book = xlsxwriter.Workbook("ds8_9_res.xlsx")

bold_format = book.add_format({'bold': True, 'align': 'right'})
impgen_format = book.add_format({'align': 'center', 'bg_color': '#CCFFFF', 'border_color': 'black', 'border': 1})
solution_format = book.add_format({'bg_color': '#85ffa', 'border_color': 'black', 'border': 1})

def add_step_tolerances(sheet, st, row, col):
    sheet.write(row, col, "Tolerance Increments: ", bold_format)
    col += 2

    for trial_result in st:
        for (i, trial_step) in enumerate(trial_result):

            sheet.write(row, col, "Tolerance:", bold_format)
            sheet.write(row+1, col, "CPLEX Objective:", bold_format)
            sheet.write(row+2, col, "True Objective:", bold_format)
            sheet.write(row+3, col, "Infeasibility: ", bold_format)
            sheet.write(row+4, col, "Solution status:", bold_format)
            sheet.write(row+5, col, "Termination reason:", bold_format)
            sheet.write(row+5, col, "Bounded:", bold_format)
            sheet.write(row+7, col, "Elapsed time:", bold_format)

            sheet.write(row, col+1+i, trial_step["tolerance"], bold_format)
            sheet.write(row+1, col+1+i, trial_step["cplex_objective"], impgen_format)
            sheet.write(row+2, col+1+i, trial_step["objective"], impgen_format)
            sheet.write(row+3, col+1+i, trial_step["infeasibility"], impgen_format)
            sheet.write(row+4, col+1+i, trial_step["solution_status"], impgen_format)
            sheet.write(row+5, col+1+i, trial_step["termination_status"], impgen_format)
            bounded = trial_step["termination_status"] == "OPTIMAL"
            sheet.write(row+6, col+1+i, str(bounded), impgen_format)
            sheet.write(row+7, col+1+i, trial_step["elapsed_time"], impgen_format)
        row += 9

    return (row + 4, col + len(st))

def add_summary_table(sheet, all_problems, row, col):
    print("creating summary table. ")
    sheet.write(row, col, "Summary Table", bold_format)
    col += 2

    #make table headings
    sheet.write(row, col + 0, "dataset", bold_format)
    sheet.write(row, col + 1, "instance", bold_format)
    sheet.write(row, col + 2, "case", bold_format)
    sheet.write(row, col + 3, "cold start", bold_format)
    sheet.write(row, col + 4, "start objective value", bold_format)
    sheet.write(row, col + 5, "start infeasibility total ", bold_format)
    sheet.write(row, col + 6, "end objective value ", bold_format)
    sheet.write(row, col + 7, "end infeasibility total", bold_format)
    sheet.write(row, col + 8, "elapsed time", bold_format)
    sheet.write(row, col + 9, "end CPLEX tolerance", bold_format)
    sheet.write(row, col + 10, "proven", bold_format)

    for problem in all_problems:
        dataset = problem["problem"]["dataset"]
        instance = problem["problem"]["instance"]
        case = problem["problem"]["case"]
        for trial_result in problem["solution_steps"]:
            row += 1
            cold_start = trial_result[0]["tolerance"] > 0
            if not cold_start:
                start_obj_val = trial_result[0]["objective"]
                start_infeas_tot = trial_result[0]["infeasibility"]
            else:
                start_obj_val, start_infeas_tot = -1, -1
            end_obj_val = trial_result[-1]["objective"]
            end_infeas_tot = trial_result[-1]["infeasibility"]
            elapsed_time = sum([s["elapsed_time"] for s in trial_result])
            end_CPLEX_tol = trial_result[-1]["tolerance"]
            proven = trial_result[-1]["termination_status"] == "OPTIMAL"

            sheet.write(row, col + 0, dataset)
            sheet.write(row, col + 1, instance)
            sheet.write(row, col + 2, case)
            sheet.write(row, col + 3, cold_start)
            sheet.write(row, col + 4, start_obj_val)
            sheet.write(row, col + 5, start_infeas_tot)
            sheet.write(row, col + 6, end_obj_val)
            sheet.write(row, col + 7, end_infeas_tot)
            sheet.write(row, col + 8, elapsed_time)
            sheet.write(row, col + 9, end_CPLEX_tol)
            sheet.write(row, col + 10, proven)

def add_equal_time_comp_table(sheet, warm_starts):
    row, col = 0, 0
    sheet.write(row, col + 0, "dataset", bold_format)
    sheet.write(row, col + 1, "instance", bold_format)
    sheet.write(row, col + 2, "case", bold_format)
    sheet.write(row, col + 4, "c obj", bold_format)
    sheet.write(row, col + 5, "c inf", bold_format)
    sheet.write(row, col + 6, "c time", bold_format)
    sheet.write(row, col + 7, "c tol", bold_format)
    sheet.write(row, col + 8, "c termination", bold_format)
    sheet.write(row, col + 9, "c bounded", bold_format)
    sheet.write(row, col + 11, "w start obj", bold_format)
    sheet.write(row, col + 12, "w start infeas", bold_format)
    sheet.write(row, col + 13, "w final obj", bold_format)
    sheet.write(row, col + 14, "w final infeas", bold_format)
    sheet.write(row, col + 15, "w time", bold_format)
    sheet.write(row, col + 16, "w tolerance", bold_format)
    sheet.write(row, col + 17, "w termination", bold_format)
    sheet.write(row, col + 18, "w bounded", bold_format)

    sheet.write(row, col + 19, "warm cold difference", bold_format)

    warm_starts.sort(key=lambda x: x["problem"]["dataset"]*100000 +
        x["problem"]["instance"]*100 + x["problem"]["case"])

    for problem in warm_starts:
        cold_result = problem["solution_steps"][0]
        warm_result = problem["solution_steps"][1]
        row += 1
        sheet.write(row, col + 0, problem["problem"]["dataset"])
        sheet.write(row, col + 1, problem["problem"]["instance"])
        sheet.write(row, col + 2, problem["problem"]["case"])

        sheet.write(row, col + 4, cold_result[-1]["objective"])
        sheet.write(row, col + 5, cold_result[-1]["infeasibility"])
        sheet.write(row, col + 6, sum([step["elapsed_time"] for step in cold_result]))
        sheet.write(row, col + 7, cold_result[-1]["tolerance"])
        sheet.write(row, col + 8, cold_result[-1]["termination_status"])
        bounded = cold_result[-1]["termination_status"] == "OPTIMAL"
        sheet.write(row, col + 9, str(bounded))

        sheet.write(row, col + 11, warm_result[0]["objective"])
        sheet.write(row, col + 12, warm_result[0]["infeasibility"])
        sheet.write(row, col + 13, warm_result[-1]["objective"])
        sheet.write(row, col + 14, warm_result[-1]["infeasibility"])
        sheet.write(row, col + 15, sum([step["elapsed_time"] for step in warm_result]))
        sheet.write(row, col + 16, warm_result[-1]["tolerance"])
        sheet.write(row, col + 17, warm_result[-1]["termination_status"])
        bounded = warm_result[-1]["termination_status"] == "OPTIMAL"
        sheet.write(row, col + 18, str(bounded))

        sheet.write(row, col + 19, warm_result[-1]["objective"] - cold_result[-1]["objective"])

    return row, col+18

def add_comparison_table(sheet, warm_starts, cold_starts):
    row, col = 0, 0
    sheet.write(row, col + 0, "dataset", bold_format)
    sheet.write(row, col + 1, "instance", bold_format)
    sheet.write(row, col + 2, "case", bold_format)
    sheet.write(row, col + 4, "c obj", bold_format)
    sheet.write(row, col + 5, "c infeas", bold_format)
    sheet.write(row, col + 6, "c time", bold_format)
    sheet.write(row, col + 7, "c tol", bold_format)
    sheet.write(row, col + 8, "c termination", bold_format)
    sheet.write(row, col + 10, "w start obj", bold_format)
    sheet.write(row, col + 11, "w start infeas", bold_format)
    sheet.write(row, col + 12, "w final obj", bold_format)
    sheet.write(row, col + 13, "w infeas", bold_format)
    sheet.write(row, col + 14, "w time", bold_format)
    sheet.write(row, col + 15, "w tol", bold_format)
    sheet.write(row, col + 16, "w termination", bold_format)

    sheet.write(row, col + 18, "warm cold difference", bold_format)

    cold_starts.sort(key=lambda x: x["problem"]["instance"]*100 + x["problem"]["case"])



    for cold_result in cold_starts:
        warm_result = None
        for problem in warm_starts:
            if problem["problem"] == cold_result["problem"]:
                warm_result = problem
                break
        if warm_result is None:
            print("no matching warm start results for ", cold_result["problem"])
            continue
        else:
            row += 1
            sheet.write(row, col + 0, cold_result["problem"]["dataset"])
            sheet.write(row, col + 1, cold_result["problem"]["instance"])
            sheet.write(row, col + 2, cold_result["problem"]["case"])

            sheet.write(row, col + 4, cold_result["solution_steps"][0][-1]["objective"])
            sheet.write(row, col + 5, cold_result["solution_steps"][0][-1]["infeasibility"])
            sheet.write(row, col + 6, sum([step["elapsed_time"] for step in cold_result["solution_steps"][0]]))
            sheet.write(row, col + 7, cold_result["solution_steps"][0][-1]["tolerance"])
            sheet.write(row, col + 8, cold_result["solution_steps"][0][-1]["termination_status"])

            #now we need to select the best of the warm starts
            best_warm_start_ss = min(warm_result["solution_steps"], key=lambda ss: ss[0]["tolerance"] * ss[-1]["objective"])

            sheet.write(row, col + 10, best_warm_start_ss[0]["objective"])
            sheet.write(row, col + 11, best_warm_start_ss[0]["infeasibility"])
            sheet.write(row, col + 12, best_warm_start_ss[-1]["objective"])
            sheet.write(row, col + 13, best_warm_start_ss[-1]["infeasibility"])
            sheet.write(row, col + 14, sum([step["elapsed_time"] for step in best_warm_start_ss]))
            sheet.write(row, col + 15, best_warm_start_ss[-1]["tolerance"])
            sheet.write(row, col + 16, best_warm_start_ss[-1]["termination_status"])

            sheet.write(row, col + 18, best_warm_start_ss[-1]["objective"] - cold_result["solution_steps"][0][-1]["objective"])


def add_tolerance_comparisons(sheet, problems_results, row, col, solution_step_lables=[(0, "cold"), (1, "warm")]):
    tightness = lambda pid: [.25, .5, .75][int((pid["instance"]-1)/5)]
    case = lambda pid: pid["case"]
    ds = lambda pid: pid["dataset"]
    split_funcs = [tightness, case, ds]
    split_names = ["tightness", "case", "ds"]

    finish_status = lambda tol, term: str(tol) if term == "OPTIMAL" else "time"

    for (index, label) in solution_step_lables:
        sheet.write(row, col, label)
        row += 1
        # data = [(p["problem"], p["solution_steps"][index]) for p in problems_results]
        data = [("problem", p[index]) for p in problems_results]
        collected_splits = []
        for split in split_funcs:
            split_values = {}
            for (problem_id, tolsteps) in data:
                split_val = split(problem_id)
                tol = finish_status(tolsteps[-1]["tolerance"],
                    tolsteps[-1]["termination_status"])
                if not split_val in split_values:
                    split_values[split_val] = {}
                if not tol in split_values[split_val]:
                    split_values[split_val][tol] = 0
                split_values[split_val][tol] += 1
            collected_splits.append(split_values)

        for (sf_index, split_func) in enumerate(split_funcs):
            sf_name = split_names[sf_index]
            results = collected_splits[sf_index]

            #table column names
            split_keys = sorted(results.keys())

            #table row names
            res_sets = [set(results[sk].keys()) for sk in split_keys]
            all_keys = set()
            for res_set in res_sets:
                all_keys = all_keys.union(res_set)
            result_keys = sorted(all_keys)

            row_0 = [sf_name] + split_keys
            other_rows = []
            for rk in result_keys:
                curr_row = [rk]
                for sk in split_keys:
                    curr_row.append(results[sk].get(rk, 0))
                other_rows.append(curr_row)

            table = [row_0] + other_rows
            for (i, tab_row) in enumerate(table):
                for (j, val) in enumerate(tab_row):
                    sheet.write(row + i, col + j, val)
            row += 3 + len(table)


def load_data(dir):
    all_problems = []
    for file in sorted(os.listdir(dir)):
        try:
            data = json.loads(open(os.path.join(dir, file), "r").read())
            all_problems.append(data)
        except json.decoder.JSONDecodeError:
            pass
    return all_problems

# warm_start_problems = load_data("./oct_13_hard")
# cold_start_problems = load_data("./long_cold_start")
#
#
# comp_sheet = book.add_worksheet("Multi Start Comparison")
# add_comparison_table(comp_sheet, warm_start_problems, cold_start_problems)
#
# comp_sheet = book.add_worksheet("Single Start Comparison")
# add_equal_time_comp_table(comp_sheet, warm_start_problems)

import json

import os
print(os.listdir("../../"))

comp_sheet = book.add_worksheet("warm cold comp")
print(os.getcwd())
f = open("./results.json").read()
results = json.loads(f)
add_tolerance_comparisons(comp_sheet, results, 0, 0, solution_step_lables=[(0, "increasing"), (1, "equal"), (2, "decreasing")])

book.close()
quit()



comp_sheet = book.add_worksheet("warm cold comp")
row, col = add_equal_time_comp_table(comp_sheet, results)
add_tolerance_comparisons(comp_sheet, results, row+10, 0)

detail_sheet = book.add_worksheet("detail")
row, col = 0, 0
for result in results:
    detail_sheet.write(row, 1, json.dumps(result["problem"]))
    row, col = add_step_tolerances(detail_sheet, result["solution_steps"], row, 0)
    row += 1

book.close()
