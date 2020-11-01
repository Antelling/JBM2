#=
Cplex is found at
/opt/ibm/ILOG/CPLEX_Studio1210/cplex/bin
=#
using JSON
include("SSIT.jl")
const MH = SSIT.MH

include("./diverse_selection_heuristic.jl")

problems = MH.Problem.load_folder("../benchmark_problems/")
test_problems = problems[600:604]
hard_problems = MH.Problem.slice_select(
        problems, datasets=[7], cases=[3, 6])


repop = MH.repeat_opt(n=5, time_limit=5)

function run_matheuristic(problems, results_folder; optimizer=repop,
		tol_time=10, popsize=30, cold_start=true, n_starts=1)
	#set up results storage
	results = Vector{Dict{String,Any}}()
	mkpath(results_folder)

	println("----------------Running Trials------------")
	for p in problems
		println("running on problem $(p.id)")
		problem_results = Vector{}()

		# cold start check
		if cold_start
			push!(problem_results, SSIT.test_problem(p,
					time_per_tol_step=tol_time))
		end

		#now, use the metaheuristic to generate a population
    	start_time = time()
		pop = optimizer(p, popsize=popsize)
    	end_time = time()
		elapsed_time = end_time - start_time

		#select a diverse subset of the population
		subset = DS.diverse_select(pop, n_starts)

		#start with several different solutions
		for sol in subset
			push!(problem_results, SSIT.test_problem(p, initial_sol=sol,
					initial_sol_time=elapsed_time, time_per_tol_step=tol_time))
		end

		# save the problem results
		push!(results, Dict("problem"=>p.id, "solution_steps"=>problem_results))
		f = open(joinpath(results_folder,
			MH.repr(p)), "w")
		write(f, JSON.json(results[end]))
		close(f)
	end
	results
end

# solset = run_matheuristic(test_problems, "oct_13_test", tol_time=2,
# 	optimizer=MH.repeat_opt(time_limit=10, n=1), popsize=30, n_starts=2)


solset = run_matheuristic(hard_problems[26:30], "../long_cold_start", tol_time=60*(5 + 5*6*3)/6,
	optimizer=MH.repeat_opt(time_limit=10, n=6*5), popsize=50, n_starts=0)

println("done")
