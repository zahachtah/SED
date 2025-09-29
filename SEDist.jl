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

    # Optional helper to load plotting methods in non-package contexts
    function load_plots!()
        include("ext/SEDMakieExt.jl")
        return nothing
    end

    # Auto-load plots if Makie is already loaded in the session
    try
        if isdefined(Main, :Makie)
            load_plots!()
        end
    catch
        # no-op
    end
end
