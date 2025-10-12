module SED


# Core split: Dist (sampling/deps), Sim (dxdt/sim), Metrics (Γ, Φ, incomes)
include("src/SED/Core/Dist.jl")
include("src/SED/Sim/Model.jl")
include("src/SED/Sim/Metrics.jl")

# Policy defaults and scenario builders
include("SED_core.jl")

# Visualizations (optional; depends on Makie)
include("src/SED/Plots/Plots.jl")
include("src/SED/Policies/Policies.jl")

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
export regulate_protected_area, γ_protected_area, μ_protected_area
export γ_protected_area_two_pop, μ_protected_area_two_pop, ϕ_protected_area_two_pop
export regulate_development, μ_development, γ_development
export with_policy
export exclusive_use_rights_kit, tradable_use_rights_kit, protected_area_kit, economic_incentives_kit, development_kit
export Uniform, LogNormal, LogitNormal, Normal, Exponential, Dirac, Bernoulli, Beta
export incomes, regulation_scan, gini
export getmedian, getsigma

# Exports (visualizations)
export phase_plot!, incomes_plot!, dependency_graph, dependency_graph_plot, dependency_graph_plot!, Φ_plot!, Γ_plot!, attractor_plot!, arrow_arc_deg!

# Adapted policy instruments (EURL/TUR/PA/etc.)
include("src/SED/Policies/Policies.jl")

end
