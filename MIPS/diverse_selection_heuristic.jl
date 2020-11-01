module DS

using Distances

"""accept a collection of objects exposing a score value and bitlist value.
This heuristic will sequentially select the solution that has the highest
(score of solution)(distance to closest already selected solution) value"""
function diverse_select(solutions, n::Int; minkowski=1)
	distance_func = Distances.Minkowski(minkowski)
	current_selected_solutions = []
	for _ in 1:n
		best_s, best_v = solutions[1], -Inf
		for s in solutions
			if s in current_selected_solutions
				continue
			else
				closest_distance = 1 # the greatest the distance can be
				for already_selected in current_selected_solutions
					d = Distances.evaluate(distance_func, s.bitlist, already_selected.bitlist)
					v = s.score*d
					if v > best_v
						best_s = s
						best_v = v
					end
				end
			end
		end
		push!(current_selected_solutions, best_s)
	end
	current_selected_solutions
end

end
