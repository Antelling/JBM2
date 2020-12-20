#= MIPS GA

TODO: finish this

make a population of solutions.
repeatedly select closest pairs of solutions, mark the columns that have a
difference as ambiguous and let a JuMP optimizer decide the best configuration
between them. =#

using JuMP
using Distances
include("../MIPS/MM.jl")
include("../MIPS/diverse_selection_heuristic.jl")
include("../metaheuristics/MH.jl")

function select_closest_parent(parent, parents, mink=1)
	distance_func = Distances.Minkowski(mink)
	cop = [Inf, nothing]
	for otherparent in parents
		if parent == otherparent
			continue
		else
			d = Distances.evaluate(distance_func, parent.bitlist, otherparent.bitlist)
			if d < cop[1]
				cop = [d, otherparent]
			end
		end
	end
	cop[2]
end

function silent_optimize!(model)
	tempout = stdout # save stream
	try
		redirect_stdout() # redirect to null
		optimize!(model)
		redirect_stdout(tempout)
	catch e
		redirect_stdout(tempout)
		error(e)
	end
end

function produce_child(parent, otherparents, model, tl)
	MM.set_bitlist!(model, parent)
	unconstrained_vals = [any(parent.bitlist[i] .!= [op.bitlist[i] for op in otherparents]) for i in 1:length(parent.bitlist)]
	x = model[:x]
	for (i, uc) in enumerate(unconstrained_vals)
		if uc
			fix(x[i], parent.bitlist[i])
		end
	end
	MM.set_time_limit_sec(model, tl)

	#run opt silently
	tempout = stdout # save stream
	try
		redirect_stdout() # redirect to null
		optimize!(model)
		redirect_stdout(tempout)
	catch e
		redirect_stdout(tempout)
		error(e)
	end

	sol = MH.Sol(convert(BitArray, round.(value.(model[:x]))), parent.problem)

	#unfix fixed variables
	for (i, uc) in enumerate(unconstrained_vals)
		if uc
			unfix(x[i])
		end
	end
	# child_ba = [c ? parent.bitlist[i] : rand([false, true]) for (i, c) in enumerate(constrained_vals)]

	sol
end

function ga(parents, model;
			reproduction_time_limit=.1, experiment_time_limit=10.0, minkoswki=1)
	start_time = time()
	should_cont = true
	while should_cont
		new_solutions = []
		println("")
		for (i, parent) in enumerate(parents)
			# otherparent = select_closest_parent(parent, parents)
			otherparents = rand(parents, 3)

			child = produce_child(parent, otherparents, model,
								  reproduction_time_limit)

			#check if cplex found an improvement
			if !(child in new_solutions)
				push!(new_solutions, child)
				println("adding solution with score $(child.score)")
			end

			#check status of time limit
			if time() - start_time > experiment_time_limit
				should_cont = false
				#we are building the new_solutions array as we go so we can't
				#exit here without first saving the remaining solutions
				append!(new_solutions, parents[i:end])
				parents = new_solutions
				break
			end
		end
		parents = new_solutions
	end
	parents
end

function get_best_sol(sols)
	best_found_sol = sols[1]
	for sol in sols[2:end]
		if sol.score > best_found_sol.score
			best_found_sol = sol
		end
	end
	best_found_sol
end


function test_problem(problem,
		initial_pop, initial_pop_time)

	t = 0 #store the highest reached tolerance
	best = [[0], 0] #default falsey values if CPLEX cannot prove anything
	sol_results = Vector{TolStep}() #store results of each tolerance step

	#create the cplex model
	m = MM.create_always_feasible_model(problem, time_limit=times[1],
			weight=_inf_penalty_weight)

	# is there a passed initial solution to seed the model?
	if !isnothing(initial_sol)

		#if the initial score is negative, convert it to the CPLEX obj value
		if initial_sol.score < 0
			score = initial_sol._objective_value - inf_penalty_weight * initial_sol._infeasibility
		else
			score = initial_sol._objective_value
		end

		# save the passed solution in the tolerance steps
		push!(sol_results, TolStep(
	    	initial_sol.bitlist,
	        MH.encode_bitarray(initial_sol.bitlist),
	        -1,
	        score,
			initial_sol._objective_value,
			initial_sol._infeasibility,
			initial_sol_time,
	        "initial solution",
	        "CPLEX not ran"))

		#seed the cplex model
		MM.set_bitlist!(m, initial_sol)
	end

	#loop over tolerances
	for i in 1:length(tolerances)
		#update highest reached tracker
    	t = tolerances[i]

		#update the cplex model
		MM.set_tolerance!(m, t)
		MM.set_time!(m, times[i])

		#run optimizer silently
		elapsed_time = silent_optimize!(m)

		ba, repr, cplex_obj, sol_obj, sol_inf = [], "", 0, 0, 0

		#guarded information extraction
		try
			#if CPLEX fails to prove anything, it won't want to give us values
			#for x
			ba = convert(BitArray, value.(m[:x]))
			repr = MH.encode_bitarray(ba)
			cplex_obj = objective_value(m)

			temp_sol = MH.Sol(ba, problem)
			sol_obj = temp_sol._objective_value
			sol_inf = temp_sol._infeasibility
		catch e
			ba = [0]
			repr = "$(e)"
			obj = 0
		end

		#save this tolerance step result
		push!(sol_results, TolStep(
			ba,
			repr,
			t,
			cplex_obj,
			sol_obj,
			sol_inf,
			elapsed_time,
			"$(primal_status(m))",
			"$(termination_status(m))"))

		#check if something was proven with this tolerance
		if termination_status(m) == MOI.OPTIMAL
			#do not go to the next tolerance step
			best = (value.(all_variables(m)), objective_value(m))
			break
		end
		if termination_status(m) == MOI.INFEASIBLE
			println("CPLEX proved infeasible")
			break
		end
	end
	sol_results
end

problems = MH.Problem.load_folder("./benchmark_problems")
prob = rand(problems)
model = MM.create_always_feasible_model(prob)
repop = MH.repeat_opt(n=1, time_limit=30)
pop = repop(prob, popsize=40)

subpop = DS.diverse_select(pop, 10)

get_best_sol(subpop).score
get_best_sol(pop).score
"$(prob.id)"

optimized = ga(subpop, model, reproduction_time_limit=15, experiment_time_limit=60*10)

get_best_sol(optimized).score
