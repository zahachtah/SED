module SEDist

    include("SEDist_selfcontained.jl")
    using Reexport


    export SED, sed, dist!, astext
    export has_dependencies, is_distribution_type, find_sed_by_name
    export sim
    export scenario, base, high_impact, low_impact, high_incentives
    export γ, μ, ϕ, regulate
    export Γ, Φ
    export γ_exclusive_use_rights, regulate_exclusive_use_rights
    export γ_tradable_use_rights, ϕ_tradable_use_rights, regulate_tradable_use_rights
    export γ_economic_incentive, μ_economic_incentive, regulate_economic_incentive
    export Uniform, LogNormal, Normal, Exponential, Dirac, Bernoulli
    export incomes, regulation_scan, gini
    # Plotting functions are provided via a Makie extension when Makie is loaded.
    export phase_plot!, incomes_plot!, dependency_graph, dependency_graph_plot
end
