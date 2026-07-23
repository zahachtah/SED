#!/usr/bin/env julia

include(joinpath(@__DIR__, "figure4_right_columns_compact.jl"))

using CairoMakie

distdata(x) = hasproperty(x, :data) ? x.data : x

function original_policy_rows()
    base_s, _, _ = figure_population(; N=140)
    base_thresholds = distdata(base_s.w̃)
    tourism_s = scenario(base_s;
        w̃=dist(data=base_thresholds .* 1.2),
        opportunities=dist(data=base_thresholds .* 1.2))
    oa_sol = sim(base_s; regulation=0.0, t_end=1000.0)
    rows = [
        (;
            title="Exclusive use rights",
            note="A fixed share of users is excluded; selection determines which part of the distribution remains active. Rᵢ is the assigned use right and S is the fine.",
            variants=[
                (label="High θᵢ exclusion", color=BLUE,
                    sol=run_variant(scenario(base_s; policy="Exclusive Use Rights", selector=:top);
                        regulation=109 / 140)),
                (label="Low θᵢ exclusion", color=LIGHTBLUE,
                    sol=run_variant(scenario(base_s; policy="Exclusive Use Rights", selector=:bottom);
                        regulation=50 / 140)),
            ],
        ),
        (;
            title="Tradable use rights",
            note="An aggregate effort quota creates a use-right price ϕ; allocation Rᵢ changes rent distribution to all actors or historical users.",
            variants=[
                (label="Equal effort rights", color=ORANGE,
                    sol=run_variant(scenario(base_s; policy="Tradable Use Rights",
                        policy_target=:effort, market_rate=0.05, historical_use_rights=false);
                        regulation=0.50)),
                (label="Historical effort rights", color=LIGHTORANGE,
                    sol=run_variant(scenario(base_s; policy="Tradable Use Rights",
                        policy_target=:effort, market_rate=0.05, historical_use_rights=true);
                        regulation=0.50)),
            ],
        ),
        (;
            title="Protected areas",
            note="Protected area reduces access but creates a spillover effect. Better ecological status can generate a tourism effect, θᵢ*.",
            variants=[
                (label="Protected area only", color=GREEN,
                    sol=run_variant(scenario(base_s; policy="Protected Area", m=0.30);
                        regulation=0.50)),
                (label="Protected area + tourism", color=LIGHTGREEN,
                    sol=run_variant(scenario(tourism_s; policy="Protected Area", m=0.30);
                        regulation=0.50)),
            ],
        ),
        (;
            title="Economic policy outcomes",
            note="Royalty shifts exit thresholds; gear subsidies change impact potentials.",
            variants=[
                (label="Tax / royalty", color=BLUE,
                    sol=run_variant(scenario(base_s; policy="Economic Incentives",
                        policy_target=:cost, policy_method=:taxation);
                        regulation=2.47216785)),
                (label="Gear subsidy", color=ORANGE,
                    sol=run_variant(scenario(base_s; policy="Economic Incentives",
                        policy_target=:limit, policy_method=:taxation);
                        regulation=0.50)),
            ],
        ),
    ]
    return rows, oa_sol
end

function figure4_original_right_columns(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)
    rows, oa_sol = original_policy_rows()
    fig = Figure(size=(980, 1340), backgroundcolor=:white, fontsize=13)

    Label(fig[0, 1:2], "Policy instruments: geometry and distributions";
        fontsize=24, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 1], "Phase diagram", fontsize=15.5, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 2], "Income distributions", fontsize=15.5, font=:bold, color=DARK, tellwidth=false)

    for (r, row) in enumerate(rows)
        phase_ax = Axis(fig[r + 1, 1])
        draw_compact_phase!(phase_ax, row, oa_sol)

        income_grid = GridLayout(fig[r + 1, 2])
        draw_income_pair!(income_grid, row; annotate=r == 1)
    end

    rowsize!(fig.layout, 0, Auto(0.30))
    rowsize!(fig.layout, 1, Auto(0.18))
    colsize!(fig.layout, 1, Relative(0.55))
    colsize!(fig.layout, 2, Relative(0.45))
    colgap!(fig.layout, 20)
    rowgap!(fig.layout, 12)

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "figure4_original_right_columns.png")
        pdf = joinpath(outdir, "figure4_original_right_columns.pdf")
        save(png, fig, px_per_unit=2)
        save(pdf, fig)
        append!(paths, [png, pdf])
    end
    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure4_original_right_columns()
    println("Wrote:")
    foreach(path -> println("  ", path), paths)
end
