#!/usr/bin/env julia
# Policy outcomes scan plot using new function-based policies + warm-start scans

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end
const S = Main.SED

using CairoMakie
using ColorSchemes

function regscan(; u=false, inc=false, s=S.high_impact(), warmstart::Symbol=:chain)
    # — Build policies using function-based kits —
    # Helpers for EUR selection: top vs bottom by w̃
    getdata(v) = hasproperty(v, :data) ? v.data : v
    sel_top = (w̃, n) -> sortperm(getdata(w̃), rev=true)[1:n]
    sel_bot = (w̃, n) -> sortperm(getdata(w̃))[1:n]

    policies = [
        S.with_policy(s; S.exclusive_use_rights_kit(; selector=sel_top)...),                  # HIGH w̃ excluded
        S.with_policy(s; S.exclusive_use_rights_kit(; selector=sel_bot)...),                  # LOW w̃ excluded
        S.with_policy(s; S.tradable_use_rights_kit(; target=:effort, market_rate=0.05)...),  # TUR — effort
        S.with_policy(s; S.tradable_use_rights_kit(; target=:yield,  market_rate=0.05)...),  # TUR — yield
        S.with_policy(s; S.protected_area_kit(; m=0.3)...),                                   # PA m=0.3
        S.with_policy(s; S.protected_area_kit(; m=0.5)...),                                   # PA m=0.5
    ]

    Labels = Dict(
        :RR => rich("Resource\nRevenues\nR"),
        :ToR => rich("Total\nRevenues\nT"),
        :GI => rich("Gini\nG"),
        :EH => rich("Ecological\nStatus\nE"),
        :RI => rich("Impact\non\nbehaviour\n∑|uᵒᵃᵢ − uᵢ|"),
        :Gov => rich("Combined\nGovernance\ngoal\nR⁰⋅⁵·T¹⋅⁰·G⁻⁰⋅²"),
        :WR => rich("Alternative\nIncomes"),
    )
    policylabels = [
        "Use Rights\nHIGH w̃\nexcluded",
        "Use Rights\nLOW w̃\nexcluded",
        "Tradable \nUse Rights\nEFFORT",
        "Tradable \nUse Rights\nYIELD",
        "Protected Area\n\nmobility=0.3",
        "Protected Area\n\nmobility=0.5",
        "Economic incentive\n\nRoyalties",
    ]
    policyxlabels = [
        "fraction excluded",
        "fraction excluded",
        "1 - effort quota",
        "1 - yield quota",
        "fraction protected",
        "fraction protected",
        "econ policy",
    ]

    # — Warm-started scans for performance/resilience —
    RS = [S.regulation_scan(p; kR=0.5, kT=1.0, kG=-0.2, kE=0.0, warmstart=warmstart) for p in policies]

    f = Figure(size=(1000, 1000))
    outcomes = [:RR, :ToR, :GI, :EH, :RI, :Gov]
    A = Dict{Tuple{Int,Int}, Axis}(); B = Dict{Tuple{Int,Int}, Axis}()
    LL = 0
    for (i, rs) in enumerate(RS)
        for (jj, o) in enumerate(outcomes)
            j = jj + 1
            if i == 1
                Label(f[j, 0], text=Labels[o], tellheight=false)
            end

            osym = Symbol("o" * string(o))
            xv = round(rs.r[rs[osym]], digits=2)
            yv = round(rs[o][rs[osym]], digits=2)
            xtv = [xv]; xts = [string(xv)]
            ytv = [yv]; yts = [string(yv)]

            if 3 < jj < 6
                A[i, j] = Axis(f[j, i], backgroundcolor="#f1f1f1")
                hidespines!(A[i, j]); hidedecorations!(A[i, j])
            else
                A[i, j] = Axis(f[j, i],
                    xticks=(xtv, xts), xticklabelsize=12, xticklabelcolor=ColorSchemes.tab20[i],
                    yticks=(ytv, yts), yticklabelsize=12, yticklabelrotation=pi/2, yticklabelcolor=ColorSchemes.tab20[i],
                    xgridcolor=ColorSchemes.tab20[i], ygridcolor=ColorSchemes.tab20[i],
                    backgroundcolor="#f1f1f1", yaxisposition=:right, xaxisposition=:top)
                hidespines!(A[i, j])
            end

            if i == 1 || jj == length(outcomes)
                B[i, j] = Axis(f[j, i],
                    xlabel=policyxlabels[i], yaxisposition=:left, xaxisposition=:bottom,
                    backgroundcolor="#f1f1f1", yticklabelsize=12, xticklabelsize=12,
                    xgridvisible=false, ygridvisible=false,
                    xticklabelsvisible=jj == length(outcomes), xlabelvisible=jj == length(outcomes),
                    yticklabelsvisible=i == 1)
                lines!(B[i, j], rs.r, rs[o], color=:transparent, linewidth=0)
                hidespines!(B[i, j])
                if o == :RR
                    B[i, j].yticks = [0.0, 0.1, 0.2, 0.25]
                end
            end

            lines!(A[i, j], rs.r, rs[o], color=ColorSchemes.tab20[i], linewidth=3)
        end

        if u
            A[i, LL+1] = Axis(f[LL+1, i], ylabel=i == 1 ? "Actors \nlow to high w̃ →" : "")
            heatmap!(A[i, LL+1], rs.sols, colormap=cgrad(["#f1f1f1", ColorSchemes.tab20[i]]))
            hidexdecorations!(A[i, LL+1]); hidespines!(A[i, LL+1])
            if i == 1
                hideydecorations!(A[i, LL+1], label=false, ticklabels=true, minorgrid=false)
            else
                hideydecorations!(A[i, LL+1], minorgrid=false, ticklabels=true)
            end
            Label(f[1, 0], text="Actors articipation\nin resource use from\nlow to high w̃ (yaxis)\nagainst regulation level (xaxis)  ", tellheight=false)
        end

        if inc
            A[i, length(outcomes)+LL+2] = Axis(f[length(outcomes)+LL+2, i])
            S.incomes_plot!(A[i, length(outcomes)+LL+2], S.sim(policies[i], regulation=RS[i].r[RS[i].oGov]))
            hidedecorations!(A[i, length(outcomes)+LL+2])
        end

        Label(f[0, i], text=policylabels[i], color=ColorSchemes.tab20[i], tellwidth=false)
    end

    sa = Axis(f[0, 0], aspect=1); hidedecorations!(sa); hidespines!(sa)
    S.phase_plot!(sa, S.sim(s), incentive_line_color=:gray, impact_line_color=:gray)

    [linkyaxes!([A[i, j+LL+1] for i in 1:length(RS)]..., B[1, j+1]) for j in 1:length(outcomes)]
    f
end
