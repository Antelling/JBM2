#=
Cplex is found at
/opt/ibm/ILOG/CPLEX_Studio1210/cplex/bin
=#
using JSON
include("SSIT.jl")

include("./diverse_selection_heuristic.jl")

problems = SSIT.MH.Problem.load_folder("./benchmark_problems/")
hard_problems = SSIT.MH.Problem.slice_select(
        problems, datasets=[8, 9], cases=[3, 6])


repop = SSIT.MH.repeat_opt(n=5, time_limit=5)

function run_matheuristic(problems, results_folder;
		optimizer=repop,
		popsize=30,
		cold_start=true,
		n_starts=1,
		tolerances = [.001, .005, .01, .05, .08, .12],
		times = [300, 300, 300, 300, 300, 300],
		cs_times=[600, 300, 300, 300, 300, 300])

	#set up results storage
	results = Vector{Dict{String,Any}}()
	mkpath(results_folder)

	println("----------------Running Trials------------")
	for p in problems
		println("running on problem $(p.id)")
		problem_results = Vector{}()

		# cold start check
		if cold_start
			#the cold start gets twice as much time for the first phase
			push!(problem_results, SSIT.test_problem(p,
					times=cs_times))
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
					initial_sol_time=elapsed_time, times=times,
					tolerances=tolerances))
		end

		# save the problem results
		push!(results, Dict("problem"=>p.id, "solution_steps"=>problem_results))
		f = open(joinpath(results_folder,
			SSIT.MH.repr(p)), "w")
		write(f, JSON.json(results[end]))
		close(f)
	end
	results
end

# solset = run_matheuristic(test_problems, "oct_13_test", tol_time=2,
# 	optimizer=MH.repeat_opt(time_limit=10, n=1), popsize=30, n_starts=2)


solset = run_matheuristic(hard_problems, "ds_8_9_res_fast",
	optimizer=SSIT.MH.repeat_opt(time_limit=30, n=1), popsize=15, n_starts=1,
	times=[5, 5, 5, 5, 5, 5],
	cs_times=[35, 5, 5, 5, 5, 5])

solset = run_matheuristic(hard_problems, "ds_8_9_res",
	optimizer=SSIT.MH.repeat_opt(time_limit=300, n=2), popsize=35, n_starts=1,
	times=[300, 300, 300, 300, 300, 300],
	cs_times=[900, 300, 300, 300, 300, 300])

println("done")
