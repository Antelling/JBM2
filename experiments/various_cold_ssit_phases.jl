using JSON
include("../matheuristics/SSIT.jl")


""" container for SSIT formulations """
struct SSIT_method
    tolerances::Vector{Number}
    times::Vector{Number}
    name::String
    num_threads::Int
end

""" create a variety of SSIT methods. Accept a parameter to multiply each time
limit by. """
function make_SSIT_methods(m=1; n_threads=6)
    [
        SSIT_method([.005, .01, .05, .08], [m*5, m*5, m*5, m*5], "even time",
            n_threads)
        SSIT_method([.005], [m*20], "one tolerance", n_threads)
        SSIT_method([.005, .01, .05, .08], [m*2, m*4, m*6, m*8],
            "increasing time", n_threads)
        SSIT_method([.005, .01, .05, .08], [m*8, m*6, m*4, m*2],
            "decreasing time", n_threads)
    ]
end


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
        println("testing on problem $(string_id(p.id))")
        method_results = Dict()
        for method in methods
            tolsteps = SSIT.test_problem(p, tolerances=method.tolerances,
                times=method.times, num_threads=method.num_threads)
            method_results[method.name] = tolsteps
        end

        pr = Problem_Result(p.id, method_results)
        push!(results, pr)
    end
    results
end

# take constant ARGS and put in normal variable args (for debugging purposes)
args = ARGS

# accept the first CLA as the multiplier for SSIT methods
ssit_methods = make_SSIT_methods(parse(Float64, args[1]), n_threads=parse(Int, args[2]))

# next two CLA specify the datasets to test
start_ds = parse(Int, args[3])
end_ds = parse(Int, args[4])

println("Generating results for datasets $start_ds through $end_ds...")

all_problems = SSIT.MH.Problem.load_folder("./benchmark_problems/")
for dataset in start_ds:end_ds
    # get dataset problems
    problems = SSIT.MH.Problem.slice_select(all_problems, datasets=[dataset])

    results = run_exp(ssit_methods, problems)

    f = open("./results/ds$(dataset)_tolsteps.json", "w")
    write(f, JSON.json(results))
    close(f)
end

println("done.")
