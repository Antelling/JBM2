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

function silent_optimize!(m)
	tempout = stdout # save stream
	start_time, end_time = 0, 0
	try
		redirect_stdout() # redirect to null
		start_time = time()
		optimize!(m)
		end_time = time()
		redirect_stdout(tempout)
	catch e
		#restore stream if user interrupts process, or other error
		redirect_stdout(tempout)
		return e
	end
	end_time - start_time
end

function test_problem(problem;
		initial_sol=nothing, #is there a MH-generated initial solution?
		initial_sol_time=nothing, #we need the time for result recording
		tolerances=[.001, .005, .01, .05, .08, .12], #the tolerance steps
		times=[30, 30, 30, 30, 30, 30], #array of times per tolerance step
		_inf_penalty_weight=10000) #Big M penalty constant

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

end
