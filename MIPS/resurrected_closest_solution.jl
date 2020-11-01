include("./SSIT.jl")
include("../metaheuristics/MH.jl")
include("./MM.jl")
using JuMP

best_initial = convert(BitArray, [s == '1' for s in
	"1110100111111101111111100111111111111011011111100111100110101101111011011111111001110110001111101011"])

problems = MH.Problem.load_folder("./benchmark_problems/")
easy_problems = problems[1:4]
hard_problems = MH.Problem.slice_select(
        problems, datasets=[7], cases=[3, 6])

sol = MH.Sol(best_initial, hard_problems[1])

# results = SSIT.test_problem(hard_problems[1], initial_sol=sol, initial_sol_time=0, time_per_tol_step=60*5)


model = MM.create_always_feasible_model(hard_problems[1], weight=10000)
MM.set_bitlist!(model, sol)
for x in 1:50 optimize!(model) end
termination_status(model)
value.(model[:s])
