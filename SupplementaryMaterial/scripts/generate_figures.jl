using SED
using CairoMakie
using LaTeXStrings
using Statistics

CairoMakie.activate!()

const FIGURE_DIR = normpath(joinpath(@__DIR__, "..", "figures"))
mkpath(FIGURE_DIR)

const ORANGE = Makie.RGBf(0.93, 0.49, 0.10)
const BLUE = Makie.RGBf(0.20, 0.43, 0.72)
const GREEN = Makie.RGBf(0.16, 0.55, 0.36)
const RED = Makie.RGBf(0.78, 0.25, 0.23)
const PURPLE = Makie.RGBf(0.49, 0.34, 0.70)
const GRAY = Makie.RGBf(0.68, 0.70, 0.73)
const DARK = Makie.RGBf(0.12, 0.14, 0.17)
const GRID = Makie.RGBAf(0.12, 0.14, 0.17, 0.10)

function paper_theme()
    Theme(
        fontsize=30,
        font="Arial",
        Axis=(
            backgroundcolor=:white,
            xgridcolor=GRID,
            ygridcolor=GRID,
            xgridwidth=1,
            ygridwidth=1,
            spinewidth=1.2,
            xticklabelsize=25,
            yticklabelsize=25,
            xlabelsize=29,
            ylabelsize=29,
            titlesize=32,
            titlefont=:bold,
        ),
    )
end

function teaching_population(; α=0.12)
    thresholds = [0.08, 0.14, 0.20, 0.27, 0.34, 0.42, 0.51, 0.62, 0.76, 0.90]
    potentials = [0.08, 0.11, 0.07, 0.14, 0.10, 0.16, 0.09, 0.13, 0.12, 0.10]
    N = length(thresholds)
    s = scenario((;
        N,
        α,
        w̃=dist(data=thresholds),
        ū=dist(data=potentials),
        R=ones(N),
    ))
    sample!(s)
    return s, thresholds, potentials
end

function attractor_data(s, potentials; t_end=2500.0)
    sol = sim(s; t_end)
    N = s.N
    ystar = sol[N + 1, end - 2]
    pstar = sum(sol[1:N, end - 2] ./ potentials) / N
    return sol, ystar, pstar
end

function panel_label!(layout, text)
    Label(layout, text, halign=:left, valign=:top, fontsize=32, font=:bold,
        tellwidth=false, tellheight=false, padding=(4, 0, 0, 0))
end

function save_figure(fig, stem)
    save(joinpath(FIGURE_DIR, stem * ".pdf"), fig)
    save(joinpath(FIGURE_DIR, stem * ".png"), fig; px_per_unit=2)
end

function attractor_construction_figure(; save_output=true)
    s, thresholds, potentials = teaching_population()
    sol, ystar, pstar = attractor_data(s, potentials)
    N = length(thresholds)
    ygrid = range(0.0, 1.0; length=801)
    participation = [Γ(y, s) for y in ygrid]
    required = [Φ(y, s) for y in ygrid]
    active = thresholds .< ystar
    ordered_cumulative = cumsum(potentials)
    pressure = 1 - ystar
    full = count(<(pressure), ordered_cumulative)
    marginal_fraction = full == 0 ? pressure / potentials[1] :
        (pressure - ordered_cumulative[full]) / potentials[full + 1]
    marginal_position = Φ(ystar, s)
    @assert isapprox(marginal_position, (full + marginal_fraction) / N; atol=1e-10)
    participation_note = "$(full) full + $(round(marginal_fraction; digits=2)) of one actor\n= $(round(Int, 100pstar))% participation"

    fig = with_theme(paper_theme()) do
        Figure(size=(1650, 1300), backgroundcolor=:white)
    end

    ax1 = Axis(fig[1, 1], title="1. Order the actors",
        xlabel=L"\mathrm{exit\ threshold},\ \theta_i",
        ylabel=L"\mathrm{impact\ potential},\ \bar{u}_i",
        limits=(0, 1, 0, 0.19))
    for i in eachindex(thresholds)
        marginal = i == full + 1 && 0 < marginal_fraction < 1
        color = marginal ? GRAY : (active[i] ? ORANGE : GRAY)
        lines!(ax1, [thresholds[i], thresholds[i]], [0, potentials[i]],
            color=color, linewidth=4)
        scatter!(ax1, [thresholds[i]], [potentials[i]], color=color, markersize=14)
        if marginal
            lines!(ax1, [thresholds[i], thresholds[i]], [0, marginal_fraction * potentials[i]],
                color=ORANGE, linewidth=7)
            scatter!(ax1, [thresholds[i]], [marginal_fraction * potentials[i]],
                color=DARK, markersize=15)
        end
    end
    vlines!(ax1, [ystar], color=DARK, linestyle=:dash, linewidth=2)
    text!(ax1, 0.18, 0.184, text="full use", color=ORANGE, fontsize=26, align=(:center, :top))
    text!(ax1, 0.79, 0.184, text="exited", color=:gray40, fontsize=26, align=(:center, :top))
    text!(ax1, 0.47, 0.169, text="marginal actor\npartial use", color=DARK, fontsize=24,
        align=(:left, :top))
    arrows2d!(ax1, [Point2f(0.49, 0.130)], [Vec2f(ystar - 0.49, 0.085 - 0.130)];
        color=DARK, shaftwidth=2.5, tipwidth=13, tiplength=15)
    text!(ax1, ystar + 0.015, 0.010, text=L"y^*", color=DARK, fontsize=26)
    panel_label!(fig[1, 1], "A")

    ax2 = Axis(fig[1, 2], title="2. Count willing actors",
        xlabel="resource density, y",
        ylabel="Participation (share of all actors)",
        limits=(0, 1, 0, 1.02))
    stairs!(ax2, ygrid, participation, color=ORANGE, linewidth=5, step=:post)
    lines!(ax2, [ystar, ystar], [0, pstar]; color=DARK, linestyle=:dash, linewidth=2)
    hlines!(ax2, [pstar], color=DARK, linestyle=:dot, linewidth=2)
    scatter!(ax2, [ystar], [pstar], color=DARK, markersize=17)
    lines!(ax2, [ystar, ystar], [full / N, (full + 1) / N];
        color=DARK, linewidth=6)
    text!(ax2, 0.06, 0.91, text=L"P_-(y)=N^{-1}\sum_i\mathbf{1}(\theta_i<y)",
        color=ORANGE, fontsize=26, align=(:left, :top))
    text!(ax2, 0.54, 0.22; text=participation_note,
        color=DARK, fontsize=25, align=(:left, :center))
    panel_label!(fig[1, 2], "B")

    ax3 = Axis(fig[2, 1], title="3. Sum their impact potentials",
        xlabel="share of actors, in threshold order",
        ylabel="cumulative impact", limits=(0, 1, 0, 1.15))
    fractions = collect(0:N) ./ N
    vspan!(ax3, [full / N], [(full + 1) / N]; color=(GRAY, 0.18))
    lines!(ax3, fractions, [0.0; ordered_cumulative], color=BLUE, linewidth=5)
    scatter!(ax3, fractions, [0.0; ordered_cumulative]; color=BLUE, markersize=10)
    hlines!(ax3, [pressure], color=RED, linewidth=3, linestyle=:dash)
    vlines!(ax3, [marginal_position], color=DARK, linewidth=2, linestyle=:dot)
    scatter!(ax3, [marginal_position], [pressure], color=DARK, markersize=17)
    text!(ax3, 0.04, pressure + 0.10,
        text="renewal pressure\n1 − y* = $(round(pressure; digits=2))",
        color=RED, fontsize=25, align=(:left, :bottom))
    text!(ax3, marginal_position + 0.04, 0.15,
        text="$(round(Int, 100marginal_position))% of actors\nincluding partial use", color=DARK,
        fontsize=25, align=(:left, :center))
    panel_label!(fig[2, 1], "C")

    ax4 = Axis(fig[2, 2], title="4. Locate the resource balance",
        xlabel="resource density, y",
        ylabel="Participation (share of all actors)",
        limits=(0, 1, 0, 1.02))
    lines!(ax4, ygrid, participation, color=ORANGE, linewidth=5)
    lines!(ax4, ygrid, required, color=BLUE, linewidth=5, linestyle=:dash)
    lines!(ax4, [ystar, ystar], [0, pstar]; color=DARK, linestyle=:dot, linewidth=2)
    scatter!(ax4, [ystar], [pstar], color=DARK, markersize=21)
    text!(ax4, 0.28, 0.92, text="participation  P(y)", color=ORANGE,
        fontsize=26, align=(:center, :center))
    text!(ax4, 0.70, 0.07, text="required participation  I(y)", color=BLUE,
        fontsize=26, align=(:center, :center))
    text!(ax4, 0.58, pstar + 0.10,
        text="attractor  y* = $(round(ystar, digits=2))", color=DARK, fontsize=26)
    panel_label!(fig[2, 2], "D")

    colgap!(fig.layout, 55)
    rowgap!(fig.layout, 55)
    save_output && save_figure(fig, "figureS1_attractor_construction")
    return fig
end

function dynamics_figure()
    base_s, _, potentials = teaching_population()
    _, ystar, pstar = attractor_data(base_s, potentials)
    ygrid = range(0.0, 1.0; length=801)
    participation = [Γ(y, base_s) for y in ygrid]
    required = [Φ(y, base_s) for y in ygrid]
    rates = [0.01, 0.10, 0.70]
    colors = [GREEN, PURPLE, RED]
    labels = ["slow", "intermediate", "fast"]
    sols = [sim(change(base_s, α=rate); t_end=3000.0) for rate in rates]

    fig = with_theme(paper_theme()) do
        Figure(size=(1650, 1360), backgroundcolor=:white)
    end

    ax1 = Axis(fig[1, 1:2], title="Same attractor, different approaches",
        xlabel="resource density, y",
        ylabel="Participation (share of all actors)",
        limits=(0, 1, 0, 1.02))
    lines!(ax1, ygrid, participation, color=ORANGE, linewidth=3, alpha=0.45)
    lines!(ax1, ygrid, required, color=BLUE, linewidth=3, linestyle=:dash, alpha=0.45)
    for (sol, rate, color, label) in zip(sols, rates, colors, labels)
        N = base_s.N
        path_y = sol[N + 1, :]
        path_p = [sum(u[1:N] ./ potentials) / N for u in sol.u]
        lines!(ax1, path_y, path_p, color=color, linewidth=4)
        scatter!(ax1, [path_y[1]], [path_p[1]], color=color, markersize=12, marker=:rect)
        idx = argmin(abs.(path_y .- 0.78))
        nextidx = findnext(j -> hypot(path_y[j] - path_y[idx], path_p[j] - path_p[idx]) >= 0.035,
            eachindex(path_y), idx + 1)
        if nextidx !== nothing
            arrows2d!(ax1, [Point2f(path_y[idx], path_p[idx])],
                [Vec2f(path_y[nextidx] - path_y[idx], path_p[nextidx] - path_p[idx])];
                color, shaftwidth=3, tipwidth=16, tiplength=18)
        end
    end
    scatter!(ax1, [ystar], [pstar], color=DARK, markersize=22)
    text!(ax1, ystar - 0.03, pstar - 0.08, text="shared attractor", color=DARK,
        fontsize=26, align=(:right, :top))
    text!(ax1, 0.85, 0.06; text="start: full stock, no use", color=DARK,
        fontsize=24, align=(:right, :bottom))
    Legend(fig[0, 1:2], [LineElement(color=c, linewidth=4) for c in colors],
        ["$(uppercasefirst(label)): α = $(rate)" for (label, rate) in zip(labels, rates)];
        orientation=:horizontal, framevisible=false, labelsize=26)
    panel_label!(fig[1, 1:2], "A")

    ax2 = Axis(fig[2, 1], title="Resource trajectories",
        xlabel=L"\mathrm{dimensionless\ time},\ \tau+1\ \mathrm{(log\ scale)}",
        ylabel="resource density, y", xscale=log10, limits=(1, 3001, 0.30, 1.02))
    for (sol, color, label) in zip(sols, colors, labels)
        lines!(ax2, sol.t .+ 1, sol[base_s.N + 1, :], color=color, linewidth=4, label=label)
    end
    hlines!(ax2, [ystar], color=DARK, linestyle=:dot, linewidth=2)
    panel_label!(fig[2, 1], "B")

    ax3 = Axis(fig[2, 2], title="Participation trajectories",
        xlabel=L"\mathrm{dimensionless\ time},\ \tau+1\ \mathrm{(log\ scale)}",
        ylabel="Participation (share of all actors)",
        xscale=log10, limits=(1, 3001, 0, 0.95))
    for (sol, color) in zip(sols, colors)
        path_p = [sum(u[1:base_s.N] ./ potentials) / base_s.N for u in sol.u]
        lines!(ax3, sol.t .+ 1, path_p, color=color, linewidth=4)
    end
    hlines!(ax3, [pstar], color=DARK, linestyle=:dot, linewidth=2)
    panel_label!(fig[2, 2], "C")

    colgap!(fig.layout, 55)
    rowgap!(fig.layout, 65)
    save_figure(fig, "figureS2_adjustment_dynamics")
    return fig
end


function incentive_switch_figure()
    w = exp.(range(log(0.45), log(2.6); length=240))
    N = length(w)
    η_no = 0.65
    η_switch = 1.35
    q_no = w .^ η_no
    q_switch = w .^ η_switch
    q_no ./= median(q_no)
    q_switch ./= median(q_switch)
    pK = 3.0
    ebar_over_r = 1.15 / N
    theta_no = w ./ (pK .* q_no)
    theta_switch = w ./ (pK .* q_switch)
    potential_no = ebar_over_r .* q_no
    potential_switch = ebar_over_r .* q_switch

    function switch_solution(theta, potential, title)
        s = scenario(base(N=N);
            α=0.08,
            w̃=dist(data=theta),
            ū=dist(data=potential),
            opportunities=dist(data=w),
            title)
        sample!(s; force=true)
        return sim(s; t_end=1800.0)
    end

    sol_no = switch_solution(theta_no, potential_no, "outside opportunity dominates")
    sol_switch = switch_solution(theta_switch, potential_switch, "efficiency dominates")

    function income_components(sol)
        x = sol.u[end - 2]
        inc = incomes(x, sol.prob.p)
        idx = sortperm(w)
        return (;
            alternative=inc.wages[idx],
            rent=inc.resource_rent[idx],
            opportunity=inc.opportunity_cost[idx],
            total=inc.total[idx],
        )
    end

    income_no = income_components(sol_no)
    income_switch = income_components(sol_switch)
    income_ylim = 1.28 * max(maximum(income_no.total), maximum(income_switch.total))

    function income_axis!(ax, income, color, annotation; xlabel="")
        actors = 1:N
        barplot!(ax, actors, income.alternative;
            color=Makie.RGBAf(0.72, 0.74, 0.77, 0.78), width=0.92)
        barplot!(ax, actors, income.opportunity;
            offset=income.alternative, color=Makie.RGBAf(color.r, color.g, color.b, 0.35), width=0.92)
        barplot!(ax, actors, income.rent;
            offset=income.alternative .+ income.opportunity, color=color, width=0.92)
        xlims!(ax, 0, N + 1)
        ylims!(ax, 0, income_ylim)
        ax.xticks = ([1, N], ["low", "high"])
        ax.xlabel = xlabel
        text!(ax, 0.02, 0.94; text=annotation, space=:relative,
            color=color, fontsize=26, font=:bold, align=(:left, :top))
        return ax
    end

    half = N ÷ 2
    low_share = sum(income_no.rent[1:half]) / sum(income_no.rent)
    high_share = sum(income_switch.rent[(half + 1):end]) /
        sum(income_switch.rent)

    fig = with_theme(paper_theme()) do
        Figure(size=(1650, 1480), backgroundcolor=:white)
    end

    ax1 = Axis(fig[1, 1], title="Efficiency and outside returns",
        xlabel=L"\mathrm{outside\ opportunity},\ w", ylabel=L"\mathrm{harvesting\ efficiency},\ q(w)")
    lines!(ax1, w, q_no, color=BLUE, linewidth=5)
    lines!(ax1, w, q_switch, color=ORANGE, linewidth=5)
    text!(ax1, 2.42, q_no[end], text=L"\eta=0.65<1", color=BLUE, fontsize=26,
        align=(:right, :bottom))
    text!(ax1, 2.15, q_switch[end] - 0.20, text=L"\eta=1.35>1", color=ORANGE, fontsize=26,
        align=(:right, :bottom))
    panel_label!(fig[1, 1], "A")

    ax2 = Axis(fig[1, 2], title="Exit ordering reverses",
        xlabel=L"\mathrm{outside\ opportunity},\ w",
        ylabel=L"\mathrm{exit\ threshold},\ \theta(w)")
    lines!(ax2, w, theta_no, color=BLUE, linewidth=5)
    lines!(ax2, w, theta_switch, color=ORANGE, linewidth=5)
    text!(ax2, 1.18, 0.47, text="θ rises with w",
        color=BLUE, fontsize=27, align=(:left, :center))
    text!(ax2, 1.65, 0.34, text="θ falls with w",
        color=ORANGE, fontsize=27, align=(:left, :bottom))
    panel_label!(fig[1, 2], "B")

    ax3 = Axis(fig[2, 1], title="Who has the impact?",
        xlabel=L"\mathrm{exit\ threshold},\ \theta",
        ylabel=L"\mathrm{impact\ potential},\ \bar{u}")
    lines!(ax3, theta_no, potential_no, color=BLUE, linewidth=5)
    lines!(ax3, theta_switch, potential_switch, color=ORANGE, linewidth=5)
    scatter!(ax3, theta_no[1:20:end], potential_no[1:20:end], color=BLUE, markersize=10)
    scatter!(ax3, theta_switch[1:20:end], potential_switch[1:20:end],
        color=ORANGE, markersize=10)
    text!(ax3, quantile(theta_no, 0.72), quantile(potential_no, 0.30),
        text="positive ordering", color=BLUE, fontsize=26)
    text!(ax3, quantile(theta_switch, 0.18), quantile(potential_switch, 0.78),
        text="reversed ordering", color=ORANGE, fontsize=26)
    panel_label!(fig[2, 1], "C")

    income_grid = GridLayout(fig[2, 2])
    Label(income_grid[1, 1], "D  Who receives resource rent?";
        fontsize=32, font=:bold, color=DARK, tellwidth=false, halign=:left)
    ax4 = Axis(income_grid[2, 1], ylabel="income")
    income_axis!(ax4, income_no, BLUE,
        "$(round(Int, 100 * low_share))% of resource rent\ngoes to the lower half of w")
    ax5 = Axis(income_grid[3, 1],
        xlabel="actors ordered by outside opportunity, w",
        ylabel="income")
    income_axis!(ax5, income_switch, ORANGE,
        "$(round(Int, 100 * high_share))% of resource rent\ngoes to the upper half of w";
        xlabel="actors ordered by outside opportunity, w")
    linkyaxes!(ax4, ax5)
    text!(ax4, 0.98, 0.94; text="η = 0.65", space=:relative,
        color=BLUE, fontsize=25, align=(:right, :top))
    text!(ax5, 0.98, 0.94; text="η = 1.35", space=:relative,
        color=ORANGE, fontsize=25, align=(:right, :top))
    rowgap!(income_grid, 10)
    Legend(fig[3, 1:2],
        [PolyElement(color=GRAY), PolyElement(color=(BLUE, 0.35)), PolyElement(color=BLUE)],
        ["Outside income", "Opportunity cost", "Resource rent"];
        orientation=:horizontal, framevisible=false, labelsize=26)

    Label(fig[4, 1:2],
        L"\frac{d\log q}{d\log w}>1\quad\Rightarrow\quad\mathrm{higher}\ w\ \mathrm{can\ imply\ lower}\ \theta",
        fontsize=29, tellheight=true, padding=(0, 0, 8, 0))
    colgap!(fig.layout, 55)
    rowgap!(fig.layout, 45)
    save_figure(fig, "figureS7_incentive_switch")
    return fig
end

if abspath(PROGRAM_FILE) == @__FILE__
    with_theme(paper_theme()) do
        attractor_construction_figure()
        dynamics_figure()
        incentive_switch_figure()
    end

    include(joinpath(@__DIR__, "generate_empirical_mapping.jl"))
    EmpiricalMappingFigure.generate_empirical_mapping()

    include(joinpath(@__DIR__, "generate_policy_explainers.jl"))
    PolicyExplainers.generate_policy_explainers()

    include(joinpath(@__DIR__, "generate_identity_figure.jl"))
    IdentityExtensionFigure.generate_identity_figure()
end
