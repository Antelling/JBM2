cd("JBM2")

using JSON
include("SSIT.jl")

hard_problems_i = [
    (8, 1, 6),
    (8, 2, 6),
    (8, 3, 3),
    (8, 3, 6),
    (8, 4, 3),
    (8, 4, 6),
    (8, 5, 6),
    (8, 6, 6),
    (8, 7, 6),
    (8, 8, 6),
    (8, 9, 6),
    (8, 10, 6),
    (8, 12, 6),
    (8, 14, 6),
    (8, 15, 6)
]

all_problems = SSIT.MH.Problem.load_folder("./benchmark_problems/")
hard_problems = [SSIT.MH.Problem.slice_select(
    all_problems, datasets=[d], cases=[c], instances=[i])[1]
    for (d, i, c) in hard_problems_i]
fast_problems = SSIT.MH.Problem.slice_select(all_problems, datasets=[6])

struct SSIT_method
    tolerances::Vector{Number}
    times::Vector{Number}
    name::String
end

methods = [
    SSIT_method([.01, .05, .08], [800, 800, 800], "even time")
    SSIT_method([.01, .05, .08], [400, 800, 1200], "increasing time")
    SSIT_method([.01, .05, .08], [1200, 800, 400], "decreasing time")
]

fast_methods = [
    SSIT_method([12*.005, .01, .05, .08], [5, 5, 5, 5], "even time")
    SSIT_method([.005], [20], "one tolerance")
    SSIT_method([.005, .01, .05, .08], [2, 4, 6, 8], "increasing time")
    SSIT_method([.005, .01, .05, .08], [8, 6, 4, 2], "decreasing time")
]


function run_exp(methods, problems)
    results = []
    for p in problems
        p_res = []
        for method in methods
            push!(p_res, SSIT.test_problem(p, tolerances=method.tolerances, times=method.times))
        end
        push!(results, p_res)
    end
    results
end

# results = run_exp(phases[1:30])

fast_results = run_exp(fast_methods, fast_problems)

function extract_stopping_reas(results, phases)
    all_terms = []
    for (i, phase) in enumerate(phases)
        phase_results = [r[i] for r in results]
        last_tolsteps = [r[end] for r in phase_results]
        term_status(x) = x.termination_status == "TIME_LIMIT" ? "time" : x.tolerance
        terms = [term_status(r) for r in last_tolsteps]
        push!(all_terms, terms)
    end
    all_terms
end

function count_occ(arr::Array{})
    record = Dict{Any,Int}()
    for el in arr
        if el in keys(record)
            record[el] += 1
        else
            record[el] = 1
        end
    end
    record
end
fast_results
analysis = extract_stopping_reas(fast_results, fast_methods)
ds1_test = count_occ.(analysis)

f = open("ds6_tolsteps.json", "w")
write(f, JSON.json(fast_results))
close(f)
