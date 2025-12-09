
include("../SED.jl")
using .SED
using Random
using Distributions
using CairoMakie

# Define the user's scenario T
function get_T()
    (
        N=200,
        health=dist(mean=0, sigma=2.0, distribution=Normal, dependency_fun="1/(1+exp(-2-independent))"),
        gender=dist(mean=0.5, distribution=Bernoulli, random=true),
        parental=dist(min=0.1, max=4.0, distribution=LogNormal),
        time=dist(min=0.0, max=1.0, dependency_fun="clamp( health * (1 - 0.60*gender) * independent , 0, 1)"),
        efficiency=dist(min=0.015, max=0.20, normalize=false, dependency_fun="( (1-gender) + 0.35*gender ) * parental * independent"),
        AIO=dist(min=0.1, max=1.6, distribution=LogNormal, dependency_fun="0.02 * parental * (1 + 0.30*gender) * independent"),
        r=0.08,
        K=0.8,
        fK=0.50,
        ū=dist(min=-0.1, max=0.1, dependency_fun="time * efficiency"),
        w̃=dist(min=-0.1, max=0.1, dependency_fun="(AIO ./ (efficiency + 1e-6)) .+ independent"),
        α=dist(min=0.1, max=0.1, distribution=Uniform)
    )
end

function verify()
    f = Figure()
    ax1 = Axis(f[1, 1])
    ax2 = Axis(f[2, 1])
    ax3 = Axis(f[3, 1])
    T = get_T()

    println("--- Testing with opportunities = nothing (Default) ---")
    s_default = scenario(T, policy="Tradable Use Rights", market_rate=0.05, buyer_bias=0.9)
    # Without opportunities, bias should be ignored.
    # We can check if `sim` runs.
    # But to check if bias is ignored, we need to compare with bias=0.0.
    s_neutral = scenario(T, policy="Tradable Use Rights", market_rate=0.05, buyer_bias=0.0)

    # Run short sim
    sol_def = sim(s_default, regulation=0.5)
    sol_neu = sim(s_neutral, regulation=0.5)

    lines!(ax1, sol_neu.u[end][1:end-2])
    lines!(ax1, sol_def.u[end][1:end-2])

    diff_def = sum(abs.(sol_def.u[end][1:end-2] .- sol_neu.u[end][1:end-2]))
    println("Diff (Bias=0.9 vs Bias=0.0) without opportunities: $diff_def")
    println("Diff if resource price: $(sol_def.u[end][end-1] .- sol_neu.u[end][end-1])")
    println("Diff if market price: $(sol_def.u[end][end] .- sol_neu.u[end][end])")
    println("\n--- Testing with opportunities = T.parental ---")
    s_parental_bias = scenario(T, opportunities=T.parental, policy="Tradable Use Rights", market_rate=0.05, buyer_bias=0.9)
    s_parental_neu = scenario(T, opportunities=T.parental, policy="Tradable Use Rights", market_rate=0.05, buyer_bias=0.0)

    sol_par_bias = sim(s_parental_bias, regulation=0.5)
    sol_par_neu = sim(s_parental_neu, regulation=0.5)

    lines!(ax2, sol_par_neu.u[end][1:end-2])
    lines!(ax2, sol_par_bias.u[end][1:end-2])

    diff_par = sum(abs.(sol_par_bias.u[end][1:end-2] .- sol_par_neu.u[end][1:end-2]))
    println("Diff (Bias=0.9 vs Bias=0.0) with opportunities=parental: $diff_par")
    println("Diff if resource price: $(sol_par_bias.u[end][end-1] .- sol_par_neu.u[end][end-1])")
    println("Diff if market price: $(sol_par_bias.u[end][end] .- sol_par_neu.u[end][end])")

    println("\n--- Testing with opportunities = T.AIO ---")
    s_aio_bias = scenario(T, opportunities=T.AIO, policy="Tradable Use Rights", market_rate=0.05, buyer_bias=0.9)
    s_aio_neu = scenario(T, opportunities=T.AIO, policy="Tradable Use Rights", market_rate=0.05, buyer_bias=0.0)

    sol_aio_bias = sim(s_aio_bias, regulation=0.5)
    sol_aio_neu = sim(s_aio_neu, regulation=0.5)

    lines!(ax3, sol_aio_neu.u[end][1:end-2])
    lines!(ax3, sol_aio_bias.u[end][1:end-2])

    diff_aio = sum(abs.(sol_aio_bias.u[end][1:end-2] .- sol_aio_neu.u[end][1:end-2]))
    println("Diff (Bias=0.9 vs Bias=0.0) with opportunities=AIO: $diff_aio")
    println("Diff if resource price: $(sol_aio_bias.u[end][end-1] .- sol_aio_neu.u[end][end-1])")
    println("Diff if market price: $(sol_aio_bias.u[end][end] .- sol_aio_neu.u[end][end])")

    println("\n--- Testing Base vs parental")
    println("Diff (Base vs parental) with opportunities=AIO: $(sum(abs.(sol_aio_bias.u[end][1:end-2] .- sol_par_neu.u[end][1:end-2])))")
    println("Diff if resource price: $(sol_aio_bias.u[end][end-1] .- sol_par_neu.u[end][end-1])")
    println("Diff if market price: $(sol_aio_bias.u[end][end] .- sol_par_neu.u[end][end])")


    println("\n--- Testing Base vs AIO")
    println("Diff (Base vs AIO) with opportunities=AIO: $(sum(abs.(sol_aio_bias.u[end][1:end-2] .- sol_par_neu.u[end][1:end-2])))")
    println("Diff if resource price: $(sol_aio_bias.u[end][end-1] .- sol_par_neu.u[end][end-1])")
    println("Diff if market price: $(sol_aio_bias.u[end][end] .- sol_par_neu.u[end][end])")

    if diff_def < 1e-10 && diff_par > 1e-4 && diff_aio > 1e-4
        println("\nVERIFICATION SUCCESSFUL: Bias works only when opportunities are defined.")
    else
        println("\nVERIFICATION FAILED.")
    end
    return f

end

verify()
