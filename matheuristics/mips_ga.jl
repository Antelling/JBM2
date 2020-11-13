"""MIPS GA

make a population of solutions.
repeatedly select closest pairs of solutions, mark the columns that have a
difference as ambiguous and let a JuMP optimizer decide the best configuration
between them. """

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
