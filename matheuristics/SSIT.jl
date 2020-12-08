#= Simple Sequential Increasing Tolerance

Increasing the tolerance of deviation from optimal allows CPLEX to progressively
become more and more aggressive when pruning the search space. This makes it
possible to make stronger claims about the upper bounds of a problem then a
simple application of CPLEX would allow.
=#

module SSIT

# library for formulating MDMKP problems for CPLEX
include("../MIPS/MM.jl")

# metaheuristic library is used for bitlist representation function, and double
# checking that solution objectives reported by CPLEX match the metaheuristic
# library reported objectives
include("../metaheuristics/MH.jl")

# include the Math Opt Interface library (MOI) for querying the CPLEX model
using JuMP

"""
Record for resulting status of a tolerance step.
"""
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
   gap::Number
end

"""Run CPLEX optimization without printing to the console"""
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

"""
Accept an MDMKP problem, an optional initial solution and associated generation
time, and an array of tolerances and a matched array of time limits. Run the
SSIT method on the problem, and record the results thereof.
"""
function test_problem(problem;
		initial_sol=nothing, #is there a MH-generated initial solution?
		initial_sol_time=nothing, #we need the time for result recording
		tolerances=[.001, .005, .01, .05, .08, .12], #the tolerance steps
		times=[30, 30, 30, 30, 30, 30], #array of times per tolerance step
		_inf_penalty_weight=10000) #Big M penalty constant for artificial vars

	t = 0 #store the highest reached tolerance
	sol_results = Vector{TolStep}() #store results of each tolerance step

	#create the cplex model
	m = MM.create_always_feasible_model(problem, weight=_inf_penalty_weight)

	# is there a passed initial solution to seed the model?
	if !isnothing(initial_sol)

		#if the initial score is negative, convert it to the CPLEX obj value
		if initial_sol.score < 0
			score = initial_sol._objective_value - inf_penalty_weight *
						initial_sol._infeasibility
		# if its feasible, the two objective values are the same
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
	      "CPLEX not ran",
			-1))

		#seed the cplex model
		MM.set_bitlist!(m, initial_sol)
	end

	#loop over tolerances
	for i in 1:length(tolerances)

		#update the cplex model
		MM.set_tolerance!(m, tolerances[i])
		MM.set_time!(m, times[i])

		#run optimizer silently
		elapsed_time = silent_optimize!(m)

		#guarded information extraction
		ba, repr, cplex_obj, sol_obj, sol_inf = [], "", 0, 0, 0
		try
			# if CPLEX fails to prove anything, it won't want to give us values
			# for x
			ba = convert(BitArray, value.(m[:x]))

			# generate the representation and objective values from the bitarray
			repr = MH.encode_bitarray(ba)
			cplex_obj = objective_value(m)

			temp_sol = MH.Sol(ba, problem)
			sol_obj = temp_sol._objective_value
			sol_inf = temp_sol._infeasibility
		catch e
			ba = [0]
			repr = "$(e)"
		end

		#save this tolerance step result
		push!(sol_results, TolStep(
			ba,
			repr,
			tolerances[i],
			cplex_obj,
			sol_obj,
			sol_inf,
			elapsed_time,
			"$(primal_status(m))",
			"$(termination_status(m))",
			MOI.get(m, MOI.RelativeGap())))

		#check if something was proven with this tolerance, if so terminate early
		if termination_status(m) == MOI.OPTIMAL
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
