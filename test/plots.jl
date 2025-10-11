using Test

include(joinpath(@__DIR__, "..", "SED.jl"))
using .SED

let makie_loaded = false
    try
        @eval begin
            using CairoMakie
            CairoMakie.activate!()
            makie_loaded = true
        end
    catch
        @info "Makie not available; skipping plot tests"
    end

    if makie_loaded
        @testset "plot smoke tests" begin
            s = scenario(base(N=50))
            sol = sim(s)
            fig = (begin
                f = Figure(size=(600, 300))
                a = Axis(f[1, 1])
                phase_plot!(a, sol)
                f
            end)
            @test !isnothing(fig)

            ctx = (
                N = 50,
                q = dist(min=1/50, max=1/50, normalize=true),
                w = dist(min=0.2, max=0.4),
                K = 2.0,
                w̃ = dist(min=0.1, max=1.0, dependency_fun="q .* w ./ K .+ independent"),
                ū  = dist(dependency_fun="q ./ w̃"),
            )
            dist!(ctx)
            gfig = dependency_graph_plot(ctx)
            @test !isnothing(gfig)
        end
    end
end
