#!/usr/bin/env julia

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end

using .SED
using Printf

steady_index(sol) = max(1, length(sol.t) - 2)
state_at(sol) = copy(sol.u[steady_index(sol)])

function participation_at(sol)
    p = sol.prob.p
    i = steady_index(sol)
    x = sol.u[i]
    lim = p.limit(x, p, sol.t[i])
    return x[p.N+1], sum(clamp.(x[1:p.N] ./ lim, 0.0, 1.0)) / p.N
end

function gamma_at_state(y, p, x_template; t=0.0)
    x = copy(x_template)
    x[p.N+1] = y
    return sum(p.cost(x, p, t) .< y) / p.N
end

function phi_at_state(y, p, x_template; t=0.0)
    x = copy(x_template)
    x[p.N+1] = y
    c = p.cost(x, p, t)
    id = sortperm(c)
    lim = p.limit(x, p, t)
    cumulative_impact = cumsum(lim[id])
    pressure = 1.0 - y
    f = sum(cumulative_impact .< pressure)

    if f == 0
        frac = pressure / lim[id[1]]
    elseif f < p.N
        frac = f + (pressure - cumulative_impact[f]) / lim[id[f+1]]
    else
        frac = p.N
    end
    return clamp(frac / p.N, 0.0, 1.0)
end

function ordered_population(; N=140)
    r = collect(range(1 / (N + 1), 1 - 1 / (N + 1), length=N))
    w = 0.07 .+ 0.86 .* r .^ 1.35
    raw_impact = 0.20 .+ 1.25 .* exp.(-2.0 .* r)
    u = raw_impact ./ sum(raw_impact) .* 1.35
    return (; w̃=dist(data=w), ū=dist(data=u), opportunities=dist(data=u))
end

function tikz_scenarios(; N=140)
    pop = ordered_population(; N)
    base_s = scenario(base(N=N); pop..., α=0.05, title="Open access")
    sample!(base_s; force=true)

    mechanisms = [
        (;
            tag="A",
            title="Changing incentive thresholds",
            subtitle="taxes/subsidies shift incentives",
            scenario=scenario(base_s; policy="Economic Incentives", policy_target=:cost, policy_method=:taxation),
            regulation=0.38,
            focus=:gamma,
        ),
        (;
            tag="B",
            title="Changing impact curves",
            subtitle="spillover lowers impact capacity",
            scenario=scenario(base_s; policy="Protected Area", m=0.55),
            regulation=0.34,
            focus=:spillover,
        ),
        (;
            tag="C",
            title="Selecting users",
            subtitle="access rules choose who can harvest",
            scenario=scenario(base_s; policy="Exclusive Use Rights", selector=:top),
            regulation=0.28,
            focus=:selection,
        ),
        (;
            tag="D",
            title="Rent reallocation",
            subtitle="prices shift thresholds and rents",
            scenario=scenario(base_s; policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0),
            regulation=0.45,
            focus=:rent,
        ),
    ]

    open_sol = sim(base_s, regulation=0.0, t_end=1000)
    policy_sols = [sim(m.scenario, regulation=m.regulation, t_end=1000) for m in mechanisms]
    return open_sol, mechanisms, policy_sols
end

function curve_data(open_sol, sol; points=121)
    open_p = open_sol.prob.p
    policy_p = sol.prob.p
    ys = collect(range(0.0, 1.0, length=points))
    open_state = state_at(open_sol)
    policy_state = state_at(sol)
    return (;
        y=ys,
        open_gamma=[gamma_at_state(y, open_p, open_state) for y in ys],
        open_phi=[phi_at_state(y, open_p, open_state) for y in ys],
        policy_gamma=[gamma_at_state(y, policy_p, policy_state) for y in ys],
        policy_phi=[phi_at_state(y, policy_p, policy_state) for y in ys],
        open_point=participation_at(open_sol),
        policy_point=participation_at(sol),
    )
end

interp(xs, ys, x) = ys[clamp(searchsortedfirst(xs, x), 1, length(xs))]

function write_table(io, style, xs, ys; name_path=nothing)
    path = isnothing(name_path) ? "" : ", name path=$(name_path)"
    println(io, "\\addplot[$style$path] table[row sep=crcr]{")
    println(io, "x y\\\\")
    for (x, y) in zip(xs, ys)
        @printf(io, "%.5f %.5f\\\\\n", x, y)
    end
    println(io, "};")
end

function write_axis_header(io)
    print(io, raw"""
\documentclass[tikz,border=5pt]{standalone}
\usepackage{pgfplots}
\pgfplotsset{compat=1.18}
\usepgfplotslibrary{groupplots,fillbetween}
\usetikzlibrary{arrows.meta,calc,positioning}

\definecolor{sedorange}{RGB}{224,110,31}
\definecolor{sedblue}{RGB}{46,102,178}
\definecolor{sedpurple}{RGB}{116,86,199}
\definecolor{sedgray}{RGB}{124,134,148}
\definecolor{sedblack}{RGB}{31,36,43}
\definecolor{sedgrid}{RGB}{229,233,238}
\definecolor{sedaxis}{RGB}{196,203,211}

\pgfplotsset{
  phaseaxis/.style={
    width=7.45cm,
    height=5.25cm,
    xmin=0, xmax=1, ymin=0, ymax=1,
    xlabel={resource level, $y$},
    ylabel={Participation (fraction)},
    xtick={0,0.25,0.5,0.75,1},
    ytick={0,0.25,0.5,0.75,1},
    ticklabel style={font=\scriptsize, text=sedgray},
    label style={font=\small, text=sedblack},
    axis line style={draw=sedaxis, line width=0.35pt},
    tick style={draw=sedaxis, line width=0.35pt},
    major grid style={draw=sedgrid, line width=0.25pt},
    grid=major,
    clip=true,
  },
  openGamma/.style={draw=sedgray!58, line width=0.75pt},
  openPhi/.style={draw=sedgray!45, line width=0.75pt, dashed},
  policyGamma/.style={draw=sedorange, line width=1.05pt},
  policyPhi/.style={draw=sedblue, line width=1.05pt},
  policyPoint/.style={only marks, mark=*, mark size=1.7pt, draw=sedblack, fill=sedblack},
  openPoint/.style={only marks, mark=*, mark size=1.5pt, draw=sedgray, fill=sedgray},
}

\begin{document}
\pagecolor{white}
\begin{tikzpicture}
\begin{groupplot}[
  group style={
    group size=2 by 2,
    horizontal sep=1.65cm,
    vertical sep=1.45cm,
  },
  phaseaxis,
]
""")
end

function write_panel(io, prefix, mechanism, data, sol)
    println(io, "\\nextgroupplot")

    if mechanism.focus == :selection
        band_y = 1.0 - mechanism.regulation
        @printf(io, "\\path[fill=sedblue!7, draw=none] (axis cs:0,%.5f) rectangle (axis cs:1,1);\n", band_y)
    end

    write_table(io, "draw=none", data.y, data.open_gamma; name_path="$(prefix)OpenGamma")
    write_table(io, "draw=none", data.y, data.policy_gamma; name_path="$(prefix)PolicyGamma")
    write_table(io, "draw=none", data.y, data.open_phi; name_path="$(prefix)OpenPhi")
    write_table(io, "draw=none", data.y, data.policy_phi; name_path="$(prefix)PolicyPhi")

    if mechanism.focus == :gamma
        println(io, "\\addplot[fill=sedorange!15, draw=none, opacity=0.75] fill between[of=$(prefix)OpenGamma and $(prefix)PolicyGamma, soft clip={domain=0:1}];")
    elseif mechanism.focus == :spillover
        println(io, "\\addplot[fill=sedblue!15, draw=none, opacity=0.80] fill between[of=$(prefix)OpenPhi and $(prefix)PolicyPhi, soft clip={domain=0:1}];")
    end

    write_table(io, "openGamma", data.y, data.open_gamma)
    write_table(io, "openPhi", data.y, data.open_phi)
    write_table(io, "policyGamma", data.y, data.policy_gamma)
    write_table(io, "policyPhi", data.y, data.policy_phi)

    yo, po = data.open_point
    yp, pp = data.policy_point
    @printf(io, "\\addplot[openPoint] coordinates {(%.5f,%.5f)};\n", yo, po)
    @printf(io, "\\addplot[policyPoint] coordinates {(%.5f,%.5f)};\n", yp, pp)
    @printf(io, "\\draw[sedblack!35, dashed, line width=0.45pt] (axis cs:%.5f,0) -- (axis cs:%.5f,%.5f);\n", yp, yp, pp)

    println(io, "\\path[fill=white, opacity=0.88, draw=none] (rel axis cs:0.015,0.815) rectangle (rel axis cs:0.955,0.985);")
    @printf(io, "\\node[anchor=north west, font=\\bfseries\\large, text=sedblack] at (rel axis cs:0.03,0.96) {%s};\n", mechanism.tag)
    @printf(io, "\\node[anchor=north west, font=\\bfseries\\footnotesize, text=sedblack, text width=5.2cm] at (rel axis cs:0.13,0.955) {%s};\n", mechanism.title)
    @printf(io, "\\node[anchor=north west, font=\\scriptsize, text=sedgray, align=left, text width=5.2cm] at (rel axis cs:0.13,0.895) {%s};\n", mechanism.subtitle)

    if mechanism.focus == :gamma
        x0 = 0.52
        y0 = interp(data.y, data.open_gamma, x0)
        y1 = interp(data.y, data.policy_gamma, x0)
        @printf(io, "\\draw[-{Stealth[length=2.1mm]}, sedorange, line width=0.75pt] (axis cs:%.3f,%.5f) -- (axis cs:%.3f,%.5f) node[pos=0.55, right, font=\\scriptsize] {\$\\Delta\\Gamma\$};\n", x0, y0, x0, y1)
    elseif mechanism.focus == :spillover
        x0 = 0.42
        y0 = interp(data.y, data.open_phi, x0)
        y1 = interp(data.y, data.policy_phi, x0)
        p = sol.prob.p
        x = state_at(sol)
        impact_ratio = sum(p.limit(x, p, 0.0)) / sum(sol.prob.p.ū)
        reduction = clamp(1 - impact_ratio, 0.0, 1.0)
        @printf(io, "\\draw[-{Stealth[length=2.1mm]}, sedblue, line width=0.75pt] (axis cs:%.3f,%.5f) -- (axis cs:%.3f,%.5f);\n", x0, y0, x0, y1)
        @printf(io, "\\node[anchor=west, font=\\scriptsize, text=sedblue, align=left] at (axis cs:0.60,0.63) {spillover\\\\impact \$-%d\\%%\$};\n", round(Int, 100 * reduction))
    elseif mechanism.focus == :selection
        @printf(io, "\\node[anchor=west, font=\\scriptsize, text=sedblue] at (axis cs:0.56,0.17) {%d\\%% selected out};\n", round(Int, 100 * mechanism.regulation))
        println(io, "\\draw[-{Stealth[length=2mm]}, sedblue, line width=0.65pt] (axis cs:0.55,0.20) -- (axis cs:0.45,0.73);")
    elseif mechanism.focus == :rent
        inc = incomes(sol)
        positive = sum(max.(inc.trade, 0.0))
        negative = -sum(min.(inc.trade, 0.0))
        scale = 0.17 / max(positive, negative, eps())
        @printf(io, "\\path[fill=sedpurple!60, draw=none] (axis cs:0.07,0.135) rectangle (axis cs:%.5f,0.165);\n", 0.07 + positive * scale)
        @printf(io, "\\path[fill=sedorange!45, draw=none] (axis cs:0.07,0.090) rectangle (axis cs:%.5f,0.120);\n", 0.07 + negative * scale)
        println(io, "\\node[anchor=west, font=\\scriptsize, text=sedpurple] at (axis cs:0.07,0.195) {trade rents};")
        println(io, "\\node[anchor=west, font=\\scriptsize, text=sedpurple] at (axis cs:0.25,0.150) {+};")
        println(io, "\\node[anchor=west, font=\\scriptsize, text=sedorange] at (axis cs:0.25,0.105) {-};")
    end
end

function write_axis_footer(io)
    print(io, raw"""
\end{groupplot}

\coordinate (plotTop) at (current bounding box.north);
\node[anchor=south, font=\bfseries\Large, text=sedblack] at ([yshift=0.85cm]plotTop)
  {Policy implementation as geometric transformations};
\node[anchor=south, font=\small, text=sedgray] at ([yshift=0.52cm]plotTop)
  {Model-generated phase geometry, redrawn with TikZ/PGFPlots for annotation-heavy manuscript layout};

\coordinate (legendAnchor) at ([yshift=-0.50cm]current bounding box.south);
\draw[sedgray!58, line width=0.8pt] ([xshift=-4.35cm]legendAnchor) -- ++(0.55cm,0)
  node[right, text=sedblack, font=\scriptsize] {open $\Gamma$};
\draw[sedgray!45, dashed, line width=0.8pt] ([xshift=-2.60cm]legendAnchor) -- ++(0.55cm,0)
  node[right, text=sedblack, font=\scriptsize] {open $\Phi$};
\draw[sedorange, line width=1.05pt] ([xshift=-0.85cm]legendAnchor) -- ++(0.55cm,0)
  node[right, text=sedblack, font=\scriptsize] {policy $\Gamma$};
\draw[sedblue, line width=1.05pt] ([xshift=1.05cm]legendAnchor) -- ++(0.55cm,0)
  node[right, text=sedblack, font=\scriptsize] {policy $\Phi$};
\fill[sedblack] ([xshift=3.10cm]legendAnchor) circle (1.6pt)
  node[right, text=sedblack, font=\scriptsize] {policy attractor};
\end{tikzpicture}
\end{document}
""")
end

"""
    figure4_policy_geometry_tikz(; outdir=joinpath(@__DIR__, "figures"), compile=true)

Generate a standalone TikZ/PGFPlots draft of Figure 4. Curves and attractors
come from SED simulations; annotations and fills are TikZ-native.
"""
function figure4_policy_geometry_tikz(; outdir=joinpath(@__DIR__, "figures"), compile=true)
    open_sol, mechanisms, policy_sols = tikz_scenarios()
    data = [curve_data(open_sol, sol) for sol in policy_sols]

    isdir(outdir) || mkpath(outdir)
    tex_path = joinpath(outdir, "figure4_policy_geometry_tikz.tex")

    open(tex_path, "w") do io
        write_axis_header(io)
        for (i, (mechanism, d, sol)) in enumerate(zip(mechanisms, data, policy_sols))
            prefix = Char('A' + i - 1)
            write_panel(io, string(prefix), mechanism, d, sol)
        end
        write_axis_footer(io)
    end

    pdf_path = replace(tex_path, ".tex" => ".pdf")
    if compile
        latex = something(Sys.which("lualatex"), Sys.which("pdflatex"), nothing)
        if latex === nothing
            @warn "No lualatex or pdflatex found; wrote TeX only" tex_path
        else
            cd(outdir) do
                run(`$latex -interaction=nonstopmode -halt-on-error $(basename(tex_path))`)
            end
        end
    end

    return tex_path, pdf_path
end

if abspath(PROGRAM_FILE) == @__FILE__
    tex, pdf = figure4_policy_geometry_tikz()
    println("Wrote:")
    println("  ", tex)
    println("  ", pdf)
end
