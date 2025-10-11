module SED


# Core then visualizations
include("SED_core.jl")
include("SED_visualizations.jl")

# Exports (core)
export Dist, dist, sample!, astext
export has_dependencies, is_distribution_type, find_dist_by_name
export sim
export scenario, base, high_impact, low_impact, high_incentives
export γ, μ, ϕ, regulate
export Γ, Φ
export γ_exclusive_use_rights, regulate_exclusive_use_rights
export γ_tradable_use_rights, ϕ_tradable_use_rights, regulate_tradable_use_rights
export γ_economic_incentive, μ_economic_incentive, regulate_economic_incentive
export Uniform, LogNormal, LogitNormal, Normal, Exponential, Dirac, Bernoulli, Beta
export incomes, regulation_scan, gini
export getmedian, getsigma

# Exports (visualizations)
export phase_plot!, incomes_plot!, dependency_graph, dependency_graph_plot, dependency_graph_plot!, Φ_plot!, Γ_plot!, attractor_plot!, arrow_arc_deg!

end
