"""MIPS GA

make a population of solutions.
repeatedly select closest pairs of solutions, mark the columns that have a
difference as ambiguous and let a JuMP optimizer decide the best configuration
between them. """

using JuMP
using Distances
include("../MIPS/MM.jl")
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

function produce_child(parent, otherparent, model, tl)
	MM.set_bitlist!(model, parent)
	constrained_vals = [parent.bitlist[i] == otherparent.bitlist[i] for i in 1:length(parent.bitlist)]
	x = model[:x]
	for (i, constrain) in enumerate(constrained_vals)
		if constrain
			fix(x[i], parent.bitlist[i])
		end
	end
	set_time_limit_sec(model, tl)

	#run opt silently
	silent_optimize!(model)
	println("time limit is $tl, termination status is $(raw_status(model)) $(termination_status(model))")
	println(model)
	println("")

	#unfix fixed variables
	for (i, constrain) in enumerate(constrained_vals)
		if constrain
			unfix(x[i])
		end
	end

	#check if anything was found andor proven
	if termination_status(model) == "OPTIMAL"
		return parent
	elseif has_values(model)
		println("found solution")
		sol = MH.Sol(parent.problem, value.(model[:x]))
		return sol, termination_status(model) == "OPTIMAL"
	else
		println("failed to find solution")
		child_ba = [c ? parent.bitlist[i] : rand([false, true]) for (i, c) in enumerate(constrained_vals)]
		return MH.Sol(convert(BitArray, child_ba), parent.problem), false
	end
end

function ga!(parents, model;
			reproduction_time_limit=.1, experiment_time_limit=10.0, minkoswki=1)
	start_time = time()
	should_cont = true
	while should_cont
		for (i, parent) in enumerate(parents)
			println(parent.score)
			# otherparent = select_closest_parent(parent, parents)
			otherparent = rand(parents)

			child, proven_optimal = produce_child(parent, otherparent, model,
								  reproduction_time_limit)

			#optimal short circuit
			if proven_optimal
				return child
			end

			#check if cplex found an improvement
			if child.score > parent.score
				parents[i] == child
			end

			#check status of time limit
			if time() - start_time > experiment_time_limit
				should_cont = false
				break
			end
		end
	end
end

function get_best_sol(sols)
	best_found_sol = sols[1]
	for sol in sols[2:end]
		if sol.score == best_found_sol.score
			best_found_sol = sol
		end
	end
	best_found_sol
end

problems = MH.Problem.load_folder("./benchmark_problems")
prob = rand(problems)
model = MM.create_always_feasible_model(prob)
repop = MH.repeat_opt(n=1, time_limit=30)
pop = repop(prob)

get_best_sol(pop).score

ga!(pop, model, reproduction_time_limit=.3, experiment_time_limit=5)

get_best_sol(pop).score
