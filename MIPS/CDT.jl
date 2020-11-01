#= SSIT is a simple sequential increasing tolerance.

This is a complex decreasing tolerance.

We create a metaheuristic population, select a diverse subset using a simple
heuristic, and then test each of the starting values with an initially very
large tolerance, removing the solutions CPLEX is unable to do anything with and
then decreasing the tolerance. Do this until CPLEX can't prove anything. =#

include("../metaheuristics/MH.jl")
include("diverse_selection_heuristic.jl")
include("./MM.jl")
using JuMP, Distances

const tolerances = [.5, .25, .12, .08, .05, .02, .01, .005, .001, .0005, .0001]

function CDT(problem::MH.Prob;
		tolerances::Vector=tolerances, optimizer=MH.repeat_opt(), popsize=30,
		n_feed_sol=7, cplex_time_limit=10)

	m = MM.create_always_feasible_model(problem, time_limit=cplex_time_limit)

	solset = optimizer(problem, popsize=popsize)
	useful_solutions = DS.diverse_select(solset, n_feed_sol)

	lowest_tolerance_with_proved_result = 1
	for tolerance in tolerances
		MM.set_tolerance(m, tolerance)
		new_useful_solutions = []
		for solution in useful_solutions
			MM.set_bitlist!(m, solution)

			#run optimizer silently
			tempout = stdout # save stream
			try
				redirect_stdout() # redirect to null
				optimize!(m)
				redirect_stdout(tempout)
			catch e
				redirect_stdout(tempout)
				return e
			end

			if termination_status(m) == MOI.OPTIMAL
				push!(new_useful_solutions, solution)
			end
		end
		if length(new_useful_solutions) > 0
			useful_solutions = new_useful_solutions
			lowest_tolerance_with_proved_result = tolerance
		else
			break #we have proven nothing about our current set of solutions
		end
	end
	return useful_solutions, lowest_tolerance_with_proved_result
end

problems = MH.Problem.load_folder("./benchmark_problems/")
easy_problems = problems[1:4]
hard_problems = MH.Problem.slice_select(problems, datasets=[7], cases=[3, 6])

optimizer = MH.repeat_opt(time_limit=60, n=10)
res = [CDT(p, tolerances=tolerances, optimizer=optimizer, popsize=50, cplex_time_limit=120) for p in hard_problems[1:2]]
res
