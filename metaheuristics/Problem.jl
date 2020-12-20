module Problem
"""Definition of a problem object, and a function to parse the MDMKP problem
format from the Beasley OR library of Benchmark problems."""

"""The Beasley library sorts problems by amount of items into datasets, each of
which has 15 problems with 5 demand constraints and 5 dimension constraints,
and then five more cases of problem that use the same instance but have
progressively smaller amounts of demand and dimension constraints, or different
objective functions. The three numbers together serve as a name for a specific
problem. """
struct Problem_ID
	dataset::Int
	instance::Int
	case::Int
end

"""A problem has an:
	objective: the array of values that will be multiplied with a solution mask
		to get the objective value of the solution
	upper_bounds: a vector of tuples pairing:
		a vector of values to be multiplied by the solution mask
		a value the sum of said products MUST NOT exceed
	lower_bounds: same as upper_bounds, but the sum MUST equal or exceed the
		second value
	id: the dataset, instance, case values
"""
struct Prob
    objective::Vector{Int}
    upper_bounds::Vector{Tuple{Vector{Int},Int}}
    lower_bounds::Vector{Tuple{Vector{Int},Int}}
	id::Problem_ID
end

function parse_file(filename::String, dataset_num::Int)::Vector{Prob}
	"""Will load a collection of 90 problems from a passed filename.
	Files must be in the
	http://people.brunel.ac.uk/~mastjjb/jeb/orlib/mdmkpinfo.html format.s"""
    f = open(filename)

    problems::Vector{Prob} = []

    #the very first item in the array is the amount of problems found in the
    #file.
    amount_of_problems = next_line(f)[1]

	instance_num = 0
    #so now for every problem:
    for problem in 1:amount_of_problems
		instance_num += 1
        n, m = next_line(f)
        lower_than_values::Vector{Vector{Int}} = []
        for i in 1:m
            push!(lower_than_values, next_line(f))
        end
        lower_than_constraints::Vector{Int} =  next_line(f)
        greater_than_values::Vector{Vector{Int}} = []
        for i in 1:m
            push!(greater_than_values, next_line(f))
        end
        greater_than_constraints = next_line(f)
        cost_coefficient_values::Vector{Vector{Int}} = []
        for i in 1:6
            push!(cost_coefficient_values, next_line(f))
        end

        upper_bounds::Vector{Tuple{Vector{Int},Int}} = []
        lower_bounds::Vector{Tuple{Vector{Int},Int}} = []

        for i in 1:m
            push!(lower_bounds, (greater_than_values[i], greater_than_constraints[i]))
            push!(upper_bounds, (lower_than_values[i], lower_than_constraints[i]))
        end

        q = [1, div(m, 2), m, 1, div(m, 2), m]
        for i in 1:6
            push!(problems, Prob(
                cost_coefficient_values[i],
                upper_bounds,
                lower_bounds[1:q[i]],
				Problem_ID(dataset_num, instance_num, i)
            ))
        end
    end

    #problems are currently in an instance first order: for every problem instance,
    #generate the six cases and append them
    #however, vasko and lu do all their cplex computations in a case first order:
    #for every case, fill in the problem instance
	#let's make our load function the same as their load function
    new_problems = Vector{Prob}()
    for offset in 1:6
        append!(new_problems, [problems[i] for i in offset:6:90])
    end

    problems
end

function next_line(file::IOStream)
    return parse_line(readline(file))
end

function parse_line(line)
    return map(parse_int, split(line))
end

function parse_int(x)
    return parse(Int, x)
end

function load_folder(
		folder_path="benchmark_problems",
		filename="mdmkp_ct{ds}.txt", datasets=1:9)
	collection = []
	for ds in datasets
		fn = replace(filename, "{ds}"=>"$ds")
		problems = parse_file(joinpath(folder_path, fn), ds)
		push!(collection, problems)
	end
	vcat(collection...)
end

function specific_select(
		problems::Vector{Prob},
		ids::Vector{Problem_ID})
	extracted = []
	for prob in problems
		if prob.id in ids
			push!(extracted, prob)
		end
	end
	extracted
end

function slice_select(problems::Vector{Prob};
		datasets=1:9, cases=1:6, instances=1:15)::Vector{Prob}
	extracted = []
	for prob in problems
		if prob.id.dataset in datasets &&
				prob.id.case in cases &&
				prob.id.instance in instances
			push!(extracted, prob)
		end
	end
	extracted
end

export Problem_ID, Prob, parse_file, load_folder, specific_select, slice_select
end
