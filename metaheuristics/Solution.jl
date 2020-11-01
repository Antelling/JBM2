"""Solution API

The solution module contains all problem methods under the Problem
submodule.

A solution is tightly coupled with a problem, and exposes the following
methods:

Solution(bitarray, problem)::Solution - construct a solution object for the passed
problem, and score it for the passed bitarray

Solution.score::Int - objective function value of the solution

cond_flip_bit!(Solution, index)::Bool - check if flipping the bit in the solution at
index will improve the objective value in an efficient manner. If it will,
mutate the passed solution to the new improved version, and return True. It
it will not, do nothing and return False.

flip_bit!(Solution, index) - mutate the solution in place

"""

module Solution

include("Problem.jl")

"""evaluates score of bitlist

If the solution is feasible, return the objective function score.
If the solution is infeasible, return the negative infeasibility. """
function eval_objective(bl::BitArray, problem::Problem.Prob)::Int
    total_infeas = 0
    for upper_bound in problem.upper_bounds
        diff = sum(upper_bound[1] .* bl) - upper_bound[2]
        if diff > 0
            total_infeas += diff
        end
    end
    for lower_bound in problem.lower_bounds
        diff = lower_bound[2] - sum(lower_bound[1] .* bl)
        if diff > 0
            total_infeas += diff
        end
    end
    if total_infeas > 0
        return -total_infeas
    else
        total = sum(problem.objective .* bl)
        return total
    end
end


"""A solution associates a bitlist with a problem. It stores any intermediate
computational steps that are used on the way to calculate the objective function
value and feasibility, and may provide optimized methods to flip a single bit.
"""
mutable struct Sol
	problem::Problem.Prob
    bitlist::BitArray
    _objective_value::Int64
    _infeasibility::Int64
    score::Int64
    _upper_bounds_totals::Vector{Int}
    _lower_bounds_totals::Vector{Int}
end

"""Solution Constructor """
function Sol(bitlist::BitArray, problem::Problem.Prob)
    upper_bounds_totals = [sum(coeffs .* bitlist) for (coeffs, bound) in
		problem.upper_bounds]
    lower_bounds_totals = [sum(coeffs .* bitlist) for (coeffs, bound) in
		problem.lower_bounds]

	#add dimension constraint infeasibility
    infeasibility = sum([
		upper_bounds_totals[i] > upper_bound ?
			upper_bounds_totals[i] - upper_bound : 0
    	for (i, (constraint_coeffs, upper_bound)) in enumerate(
				problem.upper_bounds)
	])

	#add demand constraint infeasibility
    infeasibility += sum([
		lower_bounds_totals[i] < lower_bound ?
			lower_bound - lower_bounds_totals[i] : 0
        for (i, (contraint_coeffs, lower_bound)) in enumerate(
				problem.lower_bounds)
	])

	#calculate the objective function
    objective_value = sum(problem.objective .* bitlist)

	#the score is the objective function if feasible, else infeasibility
    score = infeasibility > 0 ? -infeasibility : objective_value

    Sol(
		problem,
        bitlist,
        objective_value,
        infeasibility,
        score,
        upper_bounds_totals,
        lower_bounds_totals
    )
end

"""
fast copy method
"""
function copysol(s::Sol)
	Sol(s.problem, copy(s.bitlist), s._objective_value, s._infeasibility,
		s.score, copy(s._upper_bounds_totals), copy(s._lower_bounds_totals))
end


"""Efficiently flip a bit of the passed solution. The conditional flag
will cause the function to only apply itself if the objective function value
will be improved, otherwise, nothing will happen and the function will return
false."""
function cond_flip_bit!(solution::Sol, bit_index::Int;)
	problem = solution.problem

	#are we turning a bit on or off?
    plus_or_minus = solution.bitlist[bit_index] ? -1 : 1

	#calculate new objective value
	new_objective = solution._objective_value +
		(plus_or_minus * problem.objective[bit_index])

	# There is a shortcut we can take if:
	# 	1. The objective function has gotten worse
	# 	2. The sol is currently feasible
	# 	3. We are only supposed to flip a bit if it improves the solution
	# The shortcut saves us from having to update all the constraints
    if new_objective < solution._objective_value &&
		 	solution._infeasibility == 0
        return false
    end

	#we could loop along every constraint, keeping track of the new total and
	#having a short circuit optimization that will exit the loop early if we
	#are meant to be lazy and have become more infeasible than the previous sol.
	#However, branches cannot be optimized into SIMD operations, and we have
	#five or less constraints for each loop, so this is probably faster
    new_UB_totals = solution._upper_bounds_totals .+
		[plus_or_minus * coeffs[bit_index]
			for (coeffs, bound) in problem.upper_bounds]
    new_LB_totals = solution._lower_bounds_totals .+
		[plus_or_minus * coeffs[bit_index]
			for (coeffs, bound) in problem.lower_bounds]

	#sum the violations of the new constraints
    new_infeasibility = sum(
	        [new_UB_totals[i] > UB ? new_UB_totals[i] - UB : 0
	        	for (i, (_, UB)) in enumerate(problem.upper_bounds)]
	    ) + sum(
	    	[new_LB_totals[i] < LB ? LB - new_LB_totals[i] : 0
	    		for (i, (_, LB)) in enumerate(problem.lower_bounds)]
		)

	#get the new score and have the lazy optimization check for infeasibility
	new_score = new_infeasibility > 0 ? new_infeasibility : updated_objective
	if new_score < solution.score
		return false
	end

	#modify the solution to reflect the new values
    solution.bitlist[bit_index] = !solution.bitlist[bit_index]
	solution._objective_value = new_objective
	solution._infeasibility = new_infeasibility
	solution.score = new_score
	solution._upper_bounds_totals = new_UB_totals
	solution_lower_bounds_totals = new_LB_totals
	true
end

"""
efficiently update the passed solution to have a bit flipped at bit_index value
"""
function flip_bit!(solution::Sol, bit_index::Int)
    plus_or_minus = solution.bitlist[bit_index] ? -1 : 1
	problem = solution.problem
    solution.bitlist[bit_index] = !solution.bitlist[bit_index]
	solution._objective_value += (plus_or_minus * problem.objective[bit_index])
    solution._upper_bounds_totals .+=
		[plus_or_minus * coeffs[bit_index]
			for (coeffs, bound) in problem.upper_bounds]
    solution._lower_bounds_totals .+=
		[plus_or_minus * coeffs[bit_index]
			for (coeffs, bound) in problem.lower_bounds]
    solution._infeasibility = sum(
	        [solution._upper_bounds_totals[i] > UB ?
				solution._upper_bounds_totals[i] - UB : 0
	        	for (i, (_, UB)) in enumerate(problem.upper_bounds)]
	    ) + sum(
	    	[solution._lower_bounds_totals[i]  < LB ?
				LB - solution._lower_bounds_totals[i] : 0
	    		for (i, (_, LB)) in enumerate(problem.lower_bounds)]
		)
	solution.score = solution._infeasibility > 0 ?
		-solution._infeasibility : solution._objective_value
end

"""Behaves the same as flip_bit!, but makes a deepcopy of the passed
CompleteSolution, and returns the new CompleteSolution instead of a Boolean."""
function flip_bit(solution::Sol, problem::Problem.Prob, bit_index::Int)
    solution = deepcopy(solution)
    flip_bit!(solution, problem, bit_index)
    return solution
end

end
