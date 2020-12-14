import xlsxwriter, json, os
import numpy as np
import itertools


"""Accept an array of tolsteps and write them as parallel columns in a table.
Labels is an array of additional information to include. """
def add_step_tolerances(book, sheet, st, row, col, labels):
    bold_format = book.add_format({'bold': True, 'align': 'right'})

    #add labels for this set of tolerance increments
    for (i, label) in enumerate(labels):
        sheet.write(row+i, col, label, bold_format)

    col += 1

    #add labels for data attributes
    for (i, label) in enumerate(["tolerance", "CPLEX Objective", "True Objective", "Infeasibility", "Solution status", "termination reason", "elapsed time", "gap"]):
        sheet.write(row+i, col, label + ":", bold_format)

    #write data
    for (i, trial_step) in enumerate(st):
        for (j, key) in enumerate(["tolerance", "cplex_objective", "objective", "infeasibility", "solution_status", "termination_status", "elapsed_time", "gap"]):
            sheet.write(row+j, col+i+1, trial_step[key])

    #return row and column moved to bottom right of where data was written
    return (row + 9, col + len(st))


"""
Accept a dictionary mapping method names to synced vectors of tolerance gaps.
This method will add a table to compare the gaps both naively, and scaled to
a base case.
"""
def add_method_gap_comparisons(book, sheet, method_results, base_case, title, row, col):
    bold_format = book.add_format({'bold': True, 'align': 'right'})

    scale_method = lambda special, base: (special - base) / base

    #write title
    sheet.write(row, col, title, bold_format)
    row += 1

    #write table headers
    sheet.write(row, col, "method", bold_format)
    sheet.write(row, col+1, "average", bold_format)
    sheet.write(row, col+2, "std dev", bold_format)
    sheet.write(row, col+3, "scaled average", bold_format)
    sheet.write(row, col+4, "scaled std dev", bold_format)

    i = 1
    for (method, results) in method_results.items():
        average = np.mean(results)
        deviation = np.std(results)
        scaled_results = [scale_method(result, method_results[base_case][i])
            for (i, result) in enumerate(results)]
        scaled_average = np.mean(scaled_results)
        scaled_std = np.std(scaled_results)

        sheet.write(row+i, col, method)
        sheet.write(row+i, col+1, str(average))
        sheet.write(row+i, col+2, str(deviation))
        sheet.write(row+i, col+3, str(scaled_average))
        sheet.write(row+i, col+4, str(scaled_std))
        i += 1
    return row + i, col + 4


def create_book(filename):
    return xlsxwriter.Workbook(filename)

def save_book(book):
    book.close()
