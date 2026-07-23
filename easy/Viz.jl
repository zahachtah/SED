module EasySEDViz

include("Sim.jl")
using .EasySED
const SED = EasySED.SED

using CairoMakie, ColorSchemes
CairoMakie.activate!()

export EasySED, SED, theme!, phase_income, scanplot, policy_gallery, savefig

const PALETTE = Makie.wong_colors()

function theme!()
    set_theme!(Theme(
        fontsize=13,
        Figure=(; backgroundcolor=:white),
        Axis=(; xgridcolor=(:gray80, 0.35), ygridcolor=(:gray80, 0.35),
            topspinevisible=false, rightspinevisible=false,
            titlefont=:bold, xlabelsize=13, ylabelsize=13),
        Lines=(; linewidth=3),
        Scatter=(; markersize=11),
        BarPlot=(; strokewidth=0)
    ))
end
theme!()

_best(rs, metric) = getproperty(rs, Symbol("o", String(metric)))
_metric(rs, metric) = getproperty(rs, metric)
_label(x) = x isa Pair ? first(x) : hasproperty(x, :label) ? x.label : string(x)

function phase_income(sol; title="", order=true, size=(980, 420), color=PALETTE[2])
    fig = Figure(size=size)
    ax1 = Axis(fig[1, 1], title=title, xlabel="Resource stock", ylabel="Participation (fraction)")
    ax2 = Axis(fig[1, 2], xlabel="Actors", ylabel="Income")
    SED.phase_plot!(ax1, sol; incentive_line_color=color, impact_line_color=color)
    SED.incomes_plot!(ax2, sol; order, color)
    fig
end

function scanplot(results; metric=:ToR, title="", size=(900, 430), optimum=true)
    rows = results isa AbstractVector ? results : [results]
    fig = Figure(size=size)
    ax = Axis(fig[1, 1], title=title, xlabel="Regulation", ylabel=String(metric))
    for (i, row) in enumerate(rows)
        rs = hasproperty(row, :scan) ? row.scan : row
        col = PALETTE[mod1(i, length(PALETTE))]
        lines!(ax, rs.r, _metric(rs, metric); color=col, label=_label(row))
        if optimum
            j = _best(rs, metric)
            scatter!(ax, [rs.r[j]], [_metric(rs, metric)[j]]; color=col)
        end
    end
    axislegend(ax; framevisible=false, position=:rb)
    fig
end

function policy_gallery(s; policies=EasySED.suite(s), goal=:Gov, size=(1200, 720), t_end=1000.0)
    rows = policies isa AbstractVector && all(x -> hasproperty(x, :scan), policies) ? policies : EasySED.suite(s; policies)
    fig = Figure(size=size)
    for (i, row) in enumerate(rows)
        rs = row.scan
        r = rs.r[_best(rs, goal)]
        sol = SED.sim(row.scenario; regulation=r, t_end)
        col = PALETTE[mod1(i, length(PALETTE))]
        ax1 = Axis(fig[1, i], title="$(row.label)\nr=$(round(r, digits=2))")
        ax2 = Axis(fig[2, i])
        SED.phase_plot!(ax1, sol; incentive_line_color=col, impact_line_color=col)
        SED.incomes_plot!(ax2, sol; order=true, color=col)
        hidedecorations!(ax2; grid=false)
    end
    fig
end

savefig(path, fig) = (save(path, fig); path)

end
