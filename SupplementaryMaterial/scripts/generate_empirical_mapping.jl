module EmpiricalMappingFigure

using CairoMakie
using Random
using Statistics
using SED

CairoMakie.activate!()

const BLUE = RGBf(0.22, 0.44, 0.78)
const ORANGE = RGBf(0.95, 0.48, 0.08)
const GREEN = RGBf(0.18, 0.56, 0.25)
const DARK = RGBf(0.13, 0.14, 0.16)

function illustrative_population(; N=240, seed=37)
    Random.seed!(seed)
    data = (
        N=N,
        gender=dist(mean=0.5, distribution=Bernoulli, random=true),
        health=dist(mean=0, sigma=1.6, distribution=Normal,
            dependency_fun="1 / (1 + exp(-1.5 - independent))"),
        parental=dist(min=0.08, max=3.2, distribution=LogNormal),
        time=dist(min=0.05, max=1.0,
            dependency_fun="clamp(health * (1 - 0.30*gender) / (1 + 0.18*parental) * independent, 0.03, 1.0)"),
        efficiency=dist(min=0.015, max=0.16, normalize=false,
            dependency_fun="0.16 * health * ((1-gender) + 0.62*gender) * (1 + 0.16*parental) * independent"),
        opportunities=dist(min=0.03, max=0.55, distribution=LogNormal,
            dependency_fun="0.22 * health * (1 - 0.28*gender) * (1 + 0.14*parental) * independent"),
        ū=dist(min=-0.1, max=0.1,
            dependency_fun="time * efficiency / 0.12"),
        w̃=dist(min=-0.1, max=0.1,
            dependency_fun="opportunities / (30.0 * efficiency + 1e-8)"),
    )
    sample!(data, random=true)
    return data
end

function generate_empirical_mapping(; outdir=normpath(joinpath(@__DIR__, "..", "figures")))
    data = illustrative_population()
    vars = [:gender, :health, :parental, :time, :efficiency, :opportunities, :ū, :w̃]
    labels = [
        "Gender", "Health", "Parental status", "Available effort",
        "Efficiency", "Outside opportunity", "Impact potential", "Exit threshold",
    ]

    fig = distribution_plot(data, vars;
        labels,
        corr=:spearman,
        cellsize=(185, 185),
        markersize=3,
        fontsize=13,
        labelsize=16,
        cmap=:coolwarm,
        reverse_cmap=true,
        dep_range=(1:4, 5:8),
        dep_title="Illustrative dependency map",
        dep_titlesize=21,
        dependency_fontsize=16)

    ax = Axis(fig[5:6, 7:8];
        title="Joint relational positions",
        xlabel="exit threshold, θᵢ",
        ylabel="impact potential, ūᵢ",
        titlesize=20,
        xlabelsize=17,
        ylabelsize=17,
        xticklabelsize=14,
        yticklabelsize=14)
    scatter!(ax, data.w̃, data.ū; color=(DARK, 0.54), markersize=5)
    r = cor(data.w̃, data.ū)
    text!(ax, 0.04, 0.94;
        text="corr(θᵢ, ūᵢ) = $(round(r, digits=2))",
        space=:relative, align=(:left, :top), fontsize=17, font=:bold, color=DARK)

    text!(fig[1:4, 5:8], 0.02, 0.02;
        text="observed attributes  →  dimensional pathways  →  model quantities",
        space=:relative, align=(:left, :bottom), fontsize=16, color=:gray35)

    mkpath(outdir)
    save(joinpath(outdir, "figure_empirical_mapping.pdf"), fig)
    save(joinpath(outdir, "figure_empirical_mapping.png"), fig; px_per_unit=2)
    return fig
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    EmpiricalMappingFigure.generate_empirical_mapping()
end
