module SSIT
include("MM.jl")
include("../metaheuristics/MH.jl")
using JuMP


struct TolStep
   solution::BitArray
   repr::String
   tolerance::Number
   cplex_objective::Number
   objective::Number
   infeasibility::Number
   elapsed_time::Number
   solution_status::String
   termination_status::String
end

function test_problem(problem; initial_sol=nothing,
		initial_sol_time=nothing, tolerances=[.001, .005, .01, .05, .08, .12],
		time_per_tol_step=10, inf_penalty_weight=10000)

	t = 0 #store the highest reached tolerance in this scope
	best = [[0], 0] #default if CPLEX cannot prove anything
	sol_results = Vector{TolStep}() #place to store results of inc. tol.

	#create the cplex model
	m = MM.create_always_feasible_model(problem, time_limit=time_per_tol_step,
			weight=inf_penalty_weight)

	#save metaheuristic produced solution as first tolstep
	if !isnothing(initial_sol)
		if initial_sol.score < 0
			score = initial_sol._objective_value - inf_penalty_weight * initial_sol._infeasibility
		else
			score = initial_sol._objective_value
		end
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
		MM.set_bitlist!(m, initial_sol)
	end

	#loop over tolerances
	for tolerance in tolerances
    	t = tolerance
		MM.set_tolerance(m, tolerance)

		#run optimizer silently
		tempout = stdout # save stream
		start_time, end_time = 0, 0
		try
			redirect_stdout() # redirect to null
			start_time = time()
			optimize!(m)
			end_time = time()
			redirect_stdout(tempout)
		catch e
			redirect_stdout(tempout)
			return e
		end

		ba, repr, cplex_obj, sol_obj, sol_inf = [], "", 0, 0, 0
		elapsed_time = end_time - start_time

		#guarded information extraction
		try
			#if CPLEX fails to prove anything, it won't want to give us:
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
			tolerance,
			cplex_obj,
			sol_obj,
			sol_inf,
			elapsed_time,
			"$(primal_status(m))",
			"$(termination_status(m))"))

		#check if something was proven with this tolerance
		if termination_status(m) == MOI.ALMOST_OPTIMAL ||
				termination_status(m) == MOI.OPTIMAL
			#do not go to the next tolerance step
			best = (value.(all_variables(m)), objective_value(m))
			break
		end
		if termination_status(m) == MOI.INFEASIBLE ||
				termination_status(m) == MOI.ALMOST_INFEASIBLE
			println("CPLEX proved infeasible")
			break
		end
	end
	sol_results
end

end
