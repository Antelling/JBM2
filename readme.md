# Julia Binary Metaheuristics

A collection of meta and math heuristics for the multi demand multi dimensional
knapsack problem.

## Folder structure:

- benchmark_problems
	- contains the 9 Beasley library MDMKP datasets
- experiments
	- warm vs cold start comparison experiment
	- different SSIT methods experiment
- make_reports
	- contains python files to generate excel sheets from JSON files
- matheuristics
	- contains a variety of supervisory strategies for the application of CPLEX
- metaheuristics
	- contains a collection of population based metaheuristics
	- I've rewritten this part three times and still don't like it
- MIPS
	- formulate MDMKP problems for CPLEX
- reports
	- excel files copied from make_reports with additional manual formatting and
	analysis
- results
	- folder to store JSON result files from experiments


## To run

All files have relative imports based off the julia cwd being in the JBM2
folder root. So, to run the various ssit methods experiment:
`julia experiments/various_cold_ssit_phases.jl`
