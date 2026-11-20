module IdentityExtensionFigure

using SED
using CairoMakie
using LaTeXStrings

include("identity_extension.jl")
using .IdentityIllustration

function generate_identity_figure()
    CairoMakie.activate!()
    a = IdentityIllustration.PARAMETERS
    baseline = IdentityIllustration.identity_scenario(; strength=0.0)
    extended = IdentityIllustration.identity_scenario()
    oa = sim(baseline; t_end=4000.0)
    managed = sim(extended; u0=oa.u[end][1:2], y0=oa.u[end][3], t_end=4000.0)
    @assert isapprox(oa.u[end][3], 0.60; atol=0.002)
    @assert isapprox(managed.u[end][3], 0.45; atol=0.002)

    gray, blue, dark = :gray55, :steelblue, :gray15
    theme = Theme(font="Arial", fontsize=28,
        Axis=(xlabelsize=30, ylabelsize=30, titlesize=32, titlefont=:bold,
            xgridvisible=false, ygridvisible=false,
            topspinevisible=false, rightspinevisible=false))
    fig = with_theme(theme) do
        fig = Figure(size=(1400, 1100), figure_padding=(25, 30, 25, 30))
        ax1 = Axis(fig[1, 1], title="A  Identity loss",
            xlabel="harvesting fraction, f", ylabel="identity loss",
            limits=(0, 1, -0.002, 0.07))
        f = range(0, 1; length=501)
        loss = IdentityIllustration.identity_loss.(f, 0.70, 0.125)
        lines!(ax1, f, loss; color=blue, linewidth=5)
        scatter!(ax1, [0.70], [0.0]; color=blue, markersize=12)
        text!(ax1, 0.70, 0.008; text=L"f_i^0=0.70", fontsize=30,
            align=(:center, :bottom), color=dark)
        text!(ax1, 0.95, 0.045; text="Loss only below a\nmeaningful activity level",
            align=(:right, :top), fontsize=28, color=blue)

        ax2 = Axis(fig[1, 2], title="B  Harvesting below the threshold",
            xlabel="resource density, y", ylabel="optimal harvesting fraction",
            limits=(0, 1, 0, 1.05))
        onset = a.thresholds[2] - 2 * a.identity_weight[2] / a.potentials[2] * a.meaningful_fraction[2]
        vspan!(ax2, [onset], [a.thresholds[2]]; color=(:steelblue, 0.08))
        ys = sort(unique([collect(range(0, 1; length=501)); a.thresholds]))
        for (s, color) in ((baseline, gray), (extended, blue))
            beta = 2 * s.identity_weight[2] / a.potentials[2]
            x, response = Float64[], Float64[]
            for y in ys, upper in (false, true)
                push!(x, y)
                push!(response, IdentityIllustration.fraction_response(
                    y, a.thresholds[2], beta, a.meaningful_fraction[2]; upper))
            end
            lines!(ax2, x, response; color, linewidth=5)
        end
        text!(ax2, 0.04, 0.88; text="monetary incentives only", fontsize=28, color=gray)
        text!(ax2, 0.05, 0.65; text="with identity loss", fontsize=28, color=blue)
        text!(ax2, 0.67, 0.35; text=L"\theta_i=0.65", fontsize=30, color=dark)

        ax3 = Axis(fig[2, 1:2], title="C  Identity can lower the resource equilibrium",
            xlabel="resource density, y", ylabel="aggregate pressure",
            limits=(0, 1, 0, 1.05))
        for (s, color) in ((baseline, gray), (extended, blue))
            x, response = Float64[], Float64[]
            for y in ys, upper in (false, true)
                push!(x, y)
                push!(response, IdentityIllustration.pressure_response(y, s; upper))
            end
            lines!(ax3, x, response; color, linewidth=5)
        end
        lines!(ax3, [0, 1], [1, 0]; color=dark, linewidth=3, linestyle=:dash)
        arrows2d!(ax3, [Point2f(0.58, 0.44)], [Vec2f(-0.11, 0.09)];
            color=blue, shaftwidth=3, tipwidth=17, tiplength=19)
        scatter!(ax3, [0.60, 0.45], [0.40, 0.55]; color=[gray, blue], markersize=20)
        text!(ax3, 0.69, 0.38; text="y* = 0.60", color=gray, fontsize=28)
        text!(ax3, 0.45, 0.70; text="y* = 0.45", color=blue, fontsize=28,
            align=(:left, :bottom))
        text!(ax3, 0.73, 0.12; text="renewal  1 - y", color=dark, fontsize=28,
            align=(:center, :bottom))
        Label(fig[3, 1:2],
            "The shaded interval shows partial harvesting below the monetary exit threshold.",
            fontsize=28, padding=(0, 0, 15, 0))
        colgap!(fig.layout, 65)
        rowgap!(fig.layout, 25)
        fig
    end
    destination = normpath(joinpath(@__DIR__, "..", "figures"))
    save(joinpath(destination, "figure_identity_extension.pdf"), fig)
    save(joinpath(destination, "figure_identity_extension.png"), fig; px_per_unit=2)
    println("Identity example: baseline y*=$(oa.u[end][3]), extended y*=$(managed.u[end][3])")
    return fig
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    IdentityExtensionFigure.generate_identity_figure()
end
