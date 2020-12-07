module MM
#= MDMKP MIPS module
This module provides methods to manage a JuMP model describing an MDMKP problem.
=#

using CPLEX, JuMP

"""Accept an MDMKP problem instance and return a CPLEX model"""
function create_model(problem; time_limit=20)
	model = Model(CPLEX.Optimizer)

	#make cplex params
	set_optimizer_attribute(model, "CPXPARAM_Threads", 6)
	set_optimizer_attribute(model, "CPXPARAM_TimeLimit", time_limit)

    #make the problem variables with a Binary constraint
    @variable(model, x[1:length(problem.objective)], Bin)

    @objective(model, Max, sum(problem.objective .* x))

    for ub in problem.upper_bounds
        @constraint(model, sum(ub[1] .* x) <= ub[2])
    end

    for lb in problem.lower_bounds
        @constraint(model, sum(lb[1] .* x) >= lb[2])
    end

    model
end

function create_always_feasible_model(problem; time_limit=20, weight=20)
	model = Model(CPLEX.Optimizer)

	#set cplex params
	set_optimizer_attribute(model, "CPXPARAM_Threads", 6)
	set_optimizer_attribute(model, "CPXPARAM_TimeLimit", time_limit)

    #make the problem variables with a Binary constraint
    @variable(model, x[1:length(problem.objective)], Bin)

	#make the artificial variables to fix infeasibility
	@variable(model, s[1:length(problem.upper_bounds)] <= 0)
	@variable(model, ss[1:length(problem.lower_bounds)] >= 0)

	# objective is the normal objective value minus the slack needed to make feasible
    @objective(model, Max, sum(problem.objective .* x) - weight * (-sum(s)+sum(ss)))

    for (i, ub) in enumerate(problem.upper_bounds)
        @constraint(model, sum(ub[1] .* x) + s[i] <= ub[2])
    end

    for (i, lb) in enumerate(problem.lower_bounds)
        @constraint(model, sum(lb[1] .* x) + ss[i] >= lb[2])
    end

    model
end

function set_tolerance!(model, tolerance)
	set_optimizer_attribute(model, "CPXPARAM_MIP_Tolerances_MIPGap", tolerance)
end


function set_time!(model, time)
	set_optimizer_attribute(model, "CPXPARAM_TimeLimit", time)
end

"""accept an MDMKP Sol and set the model to have the same bitlist"""
function set_bitlist!(model, sol)
	set_start_value.(model[:x], convert.(Float64, sol.bitlist))
end

end
