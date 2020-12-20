module MH

include("Experiment.jl")

const Execute = Experiment.Execute
const StoppingCriteria = Execute.StoppingCriteria
const PM = Experiment.PM
const PMeta = PM.PMeta
const DescFunc = PM.DescFunc
const Watershed = PM.Watershed
const Problem = Watershed.Problem
const Prob = Problem.Prob
const Solution = Watershed.Solution
const Sol = Watershed.Sol

function repr(p::Prob)
	"d$(p.id.dataset)_i$(p.id.instance)_c$(p.id.case).json"
end

function ba_to_int(arr)
    return sum(arr .* (2 .^ collect(length(arr)-1:-1:0)))
end

function grayencode(n::Integer)
	n ⊻ (n >> 1)
end

function encode_bitarray(ba)
	join([grayencode(ba_to_int(a)) for a in
			collect(Iterators.partition(ba, 10))], "/")
end

function repr(s::Sol)
	encode_bitarray(s.bitarray)
end

"""This is a configured really-good metaheuristic. """
function repeat_opt(; time_limit=.5, n=(5*60)/.5)
    meta = MH.PM.create_PMetaDefs(2)["CAC"]
	#make the optimizer method
    meta_opt = MH.Execute.make_exec(meta, MH.Experiment.get_best_sol_score,
        MH.StoppingCriteria(time_limit=time_limit))
	function rep_opt(prob; popsize=30)
		all_solutions = Set{MH.Sol}()
		for _ in 1:n
			pop = MH.Experiment.create_random_pop(popsize, prob)
			meta_opt(pop)
			union!(all_solutions, Set(pop))
		end
		sort(collect(all_solutions), by=x->x.score, rev=true)
	end
end

end
