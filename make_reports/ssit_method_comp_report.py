import SSIT_methods as sr
import json 

f = open("./ds6_tolsteps.json")
data = json.loads(f.read())
f.close()

def make_problem_labels(datasets=range(1, 10), instances=range(1, 15), cases=range(1, 7)):
    output = []
    for ds in datasets:
        for i in instances:
            for c in cases:
                output.append(f"({ds}, {i}, {c})")
    return output
problem_labels = make_problem_labels(datasets=[6])
method_labels = ["even time", "one tolerance", "increasing time", "decreasing time"]

book = sr.create_book("fast_SSIT_comp.xlsx")
sheet = book.add_worksheet("Dataset 6 tolerance steps")

row = 0 
col = 0 

gap_analysis = {label: [] for label in method_labels}
time_analysis = {label: [] for label in method_labels}

for (problem_results, problem_id) in zip(data, problem_labels):
    for (tolsteps, method_label) in zip(problem_results, method_labels):
        row, _ = sr.add_step_tolerances(book, sheet, tolsteps, row, col, 
            labels=[problem_id, method_label])
        gap_analysis[method_label].append(tolsteps[-1]["gap"])
        time_analysis[method_label].append(tolsteps[-1]["elapsed_time"])
        row += 2

result_sheet = book.add_worksheet("Method Analysis")
row, _ = sr.add_method_gap_comparisons(book, result_sheet, gap_analysis, "one tolerance", 0, 0)
row, _ = sr.add_method_gap_comparisons(book, result_sheet, time_analysis, "one tolerance", row+4, 0)

book.close()