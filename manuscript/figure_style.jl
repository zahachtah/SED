if !isdefined(Main, :ManuscriptFigureStyle)
    Base.@kwdef struct ManuscriptFigureStyle
        size::Tuple{Int,Int} = (1040, 1500)
        font_scale::Float64 = 1.22
        px_per_unit::Int = 2
    end
end

paper_figure_style(; size=(1040, 1500), font_scale=1.22, px_per_unit=2) =
    ManuscriptFigureStyle(size=Tuple(size), font_scale=Float64(font_scale),
        px_per_unit=px_per_unit)

figsize(style::ManuscriptFigureStyle) = style.size
pt(style::ManuscriptFigureStyle, value) = Float64(value) * style.font_scale
px_per_unit(style::ManuscriptFigureStyle) = style.px_per_unit
