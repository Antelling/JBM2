import SSIT_methods as sr
import json

f = open("./results/ds8_tolsteps.json")
data = json.loads(f.read())
f.close()


book = sr.create_book("fast_SSIT_comp_ds8.xlsx")
sheet = book.add_worksheet("Dataset 8 tolerance steps")

row = 0
col = 0

gap_analysis = {label: [] for label in data[0]["methods"]}
time_analysis = {label: [] for label in data[0]["methods"]}

for res in data:
    pid = res["problem_id"]
    problem_id = f"d{pid['dataset']}_i{pid['instance']}_c{pid['case']}"

    for method in res["methods"]:
        tolsteps = res["methods"][method]
        row, _ = sr.add_step_tolerances(book, sheet, tolsteps, row, col,
            labels=[problem_id, method])
        gap_analysis[method].append(tolsteps[-1]["gap"])
        time_analysis[method].append(tolsteps[-1]["elapsed_time"])
        row += 2

result_sheet = book.add_worksheet("Method Analysis")
row, _ = sr.add_method_gap_comparisons(book, result_sheet, gap_analysis, "one tolerance", "gap analysis", 0, 0)
row, _ = sr.add_method_gap_comparisons(book, result_sheet, time_analysis, "one tolerance", "time analysis", row+4, 0)

book.close()
