#=
Population based metaheuristics will ideally produce a diverse population, with
solutions ranging over a wide variety of the solution space. Sorting the
population by objective values and taking the top n may result in the loss of
some of this diversity, as one particularly good region with a few
representative solutions may prevent another interesting region from being
represented. This file contains a heuristic that attempts to ensure selected
solutions represent a diverse sample of the larger metaheuristic population.
=#

module DS

using Distances

"""accept a collection of objects exposing a score value and bitlist value.
This heuristic will sequentially select the solution that has the highest
(score of solution)(distance to closest already selected solution) value"""
function diverse_select(solutions, n::Int; minkowski=1)
	# minkowski distance is a generalized distance metric. m=1 is manhattan dist
	distance_func = Distances.Minkowski(minkowski)

	current_selected_solutions = []
	for _ in 1:n
		best_s, best_v = solutions[1], -Inf
		for s in solutions

			# check if solution has already been selected
			if s in current_selected_solutions
				continue
			end

			# find the already selected solution closest to this one
			shortest_distance = Inf
			for already_selected in current_selected_solutions
				d = Distances.evaluate(distance_func, s.bitlist, 
					already_selected.bitlist)
				if d < shortest_distance
					shortest_distance = d
				end
			end

			# evaluate the selection score of this solution
			v = s.score * shortest_distance
			if v > best_v
				best_s = s
				best_v = v
			end
		end

		#save the highest selection scoring solution
		push!(current_selected_solutions, best_s)
	end
	current_selected_solutions
end

end
