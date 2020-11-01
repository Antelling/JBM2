import xlsxwriter, json, os
import numpy as np

book = xlsxwriter.Workbook("oct13hard.xlsx")

bold_format = book.add_format({'bold': True, 'align': 'right'})
impgen_format = book.add_format({'align': 'center', 'bg_color': '#CCFFFF', 'border_color': 'black', 'border': 1})
solution_format = book.add_format({'bg_color': '#85ffa', 'border_color': 'black', 'border': 1})

def add_step_tolerances(sheet, st, row, col):
    sheet.write(row, col, "Tolerance Increments: ", bold_format)
    col += 2
    print("adding tolerance increments. ")

    for trial_result in st:
        print("    adding one...")
        for (i, trial_step) in enumerate(trial_result):

            sheet.write(row, col, "Tolerance:", bold_format)
            sheet.write(row+1, col, "CPLEX Objective:", bold_format)
            sheet.write(row+2, col, "True Objective:", bold_format)
            sheet.write(row+3, col, "Infeasibility: ", bold_format)
            sheet.write(row+4, col, "Solution status:", bold_format)
            sheet.write(row+5, col, "Termination reason:", bold_format)
            sheet.write(row+6, col, "Elapsed time:", bold_format)

            sheet.write(row, col+1+i, trial_step["tolerance"], bold_format)
            sheet.write(row+1, col+1+i, trial_step["cplex_objective"], impgen_format)
            sheet.write(row+2, col+1+i, trial_step["objective"], impgen_format)
            sheet.write(row+3, col+1+i, trial_step["infeasibility"], impgen_format)
            sheet.write(row+4, col+1+i, trial_step["solution_status"], impgen_format)
            sheet.write(row+5, col+1+i, trial_step["termination_status"], impgen_format)
            sheet.write(row+6, col+1+i, trial_step["elapsed_time"], impgen_format)
        row += 8

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

def add_comparison_table(sheet, warm_starts, cold_starts):
    for problem in cold_starts:
        print(problem)


#collect data
all_problems = []
dir = "../oct_13_hard"
for file in sorted(os.listdir(dir)):
    try:
        print(file)
        data = json.loads(open(os.path.join(dir, file), "r").read())

        all_problems.append(data)
    except json.decoder.JSONDecodeError:
        pass

print(all_problems)

sheet = book.add_worksheet("problem summaries")

row, col = 0, 0
for result in all_problems:
    sheet.write(row, 1, json.dumps(result["problem"]))
    row, col = add_step_tolerances(sheet, result["solution_steps"], row, 0)
    row += 1

summary_sheet = book.add_worksheet("Summary Table")
add_summary_table(summary_sheet, all_problems, 0, 0)


book.close()
