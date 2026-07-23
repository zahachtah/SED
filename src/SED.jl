module SED

# Distribution construction, simulation, metrics, scenarios, plots, and policies.
include("core.jl")
include("model.jl")
include("metrics.jl")
include("scenarios.jl")
include("plots.jl")
include("policies.jl")

# Distribution and model API
export SEDist, Dist, dist, sample!, change, @dependent
export sim, sim_init
export scenario, base, high_impact, low_impact, high_incentives
export Uniform, LogNormal, LogitNormal, Normal, Exponential, Dirac, Bernoulli, Beta

# Policy API
export AbstractPolicy
export OpenAccess, TradableUseRights, ExclusiveUseRights, ProtectedArea
export ProtectedAreaTwoPop, EconomicIncentives, Development
export cost, limit, dynamics, regulate

# Outcomes
export Γ, Φ, incomes, regulation_scan, gini

# Plotting API
export phase_plot!, phase_plot, incomes_plot!, incomes_plot
export dependency_graph, dependency_graph_plot, dependency_graph_plot!
export Φ_plot!, Γ_plot!, attractor_plot!, trajectory_plot!, bg_plot!, target_plot!
export dist_plot!, dist_plot_compare, distribution_plot, arrow_arc_deg!

end
