using JSON
include("../matheuristics/SSIT.jl")

# get dataset 6 problems
all_problems = SSIT.MH.Problem.load_folder("./benchmark_problems/")
problems = SSIT.MH.Problem.slice_select(all_problems, datasets=[6])

""" container for SSIT formulations """
struct SSIT_method
    tolerances::Vector{Number}
    times::Vector{Number}
    name::String
end

""" create a variety of SSIT methods. Accept a parameter to multiply each time
limit by. """
function make_SSIT_methods(m=1)
    fast_methods = [
        SSIT_method([.005, .01, .05, .08], [m*5, m*5, m*5, m*5], "even time")
        SSIT_method([.005], [m*20], "one tolerance")
        SSIT_method([.005, .01, .05, .08], [m*2, m*4, m*6, m*8], "increasing time")
        SSIT_method([.005, .01, .05, .08], [m*8, m*6, m*4, m*2], "decreasing time")
    ]
end

# Dr. Vasko said to give everything 12 times as much time
ssit_methods = make_SSIT_methods(12)

"""Struct to store results of experimental trials"""
struct Problem_Result
    problem_id
    methods::Dict{String,Vector}
end

function string_id(pid)
    "d$(pid.dataset)_i$(pid.instance)_c$(pid.case)"
end

""" Accept a vector of SSIT methods and problems, and then record the results
of each method ran on each problem."""
function run_exp(methods::Vector{SSIT_method}, problems::Vector{SSIT.MH.Prob})
    results = Vector{Problem_Result}()
    for p in problems
        method_results = Dict()
        for method in methods
            tolsteps = SSIT.test_problem(p, tolerances=method.tolerances,
                times=method.times)
            method_results[method.name] = tolsteps
        end

        pr = Problem_Result(p.id, method_results)
        f = open("./results/ds6_tolsteps/" * string_id(p.id) * ".json", "w")
        write(f, JSON.json(pr))
        close(f)

        push!(results, pr)
    end
    results
end

results = run_exp(ssit_methods, problems)

f = open("./results/ds6_tolsteps.json", "w")
write(f, JSON.json(results))
close(f)
