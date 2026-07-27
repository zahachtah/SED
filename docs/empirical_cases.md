## Zanzibar & Philippines: Translating Empirical Ranges into SED Distributions

This guide summarizes how field-based envelopes for prices, time allocation, efficiency, and biomass are converted into the distributions used by the SED examples. Two case studies are covered:

- **Zanzibar (Unguja / Pemba)** – abbreviated `ZNZ`
- **Philippines (Concepcion)** – abbreviated `PH`

The target is a reef–seagrass fishery represented entirely in kg ha⁻¹ units, so ecological and socio-economic quantities remain comparable.

---

### Ecological Baselines (per habitat `h` = reef or seagrass)

- Carrying capacity: `Kₕ` (kg ha⁻¹)
- Observed biomass: `Bₕ` (kg ha⁻¹)
- Fraction of capacity: `xₕ = Bₕ / Kₕ = f_K`
- Surplus production (logistic):  
  `H*ₕ = rₕ · Kₕ · xₕ · (1 − xₕ)` kg ha⁻¹ yr⁻¹

All ranges below stay within Indo-Pacific / WIO survey bounds and keep inputs per-hectare.

| Site | Habitat | `r` (yr⁻¹) | `K` (t ha⁻¹) | `x` | Approx. MSY (kg ha⁻¹ yr⁻¹) |
| --- | --- | --- | --- | --- | --- |
| ZNZ | Reef | 0.05–0.12 | 0.6–1.0 | 0.4–0.6 | 7–30 |
| ZNZ | Seagrass | 0.05–0.12* | 0.3–1.0 | 0.3–0.5 | 4–30 |
| PH | Reef | 0.07–0.17 | 1.0–1.5 | 0.4–0.6 | 18–64 |
| PH | Seagrass | 0.07–0.15 | 0.4–1.2 | 0.3–0.5 | 7–45 |

`*` Seagrass `r` is assumed to be in the same order as the reef estimates.

> **MSY note:** at `x = 0.5`, `H*ₕ ≈ rₕ · Kₕ / 4`. Seagrass `K` values follow published biomass benchmarks (hundreds to ~1,000 kg ha⁻¹).

---

### Socio-economic Distributions & Gender Gaps

We model:

- price `p` (USD kg⁻¹),
- time `t` (effort per hectare, hours or days),
- efficiency `η` (kg person⁻¹ day⁻¹),

and apply gender-specific offsets to reflect market access and gear restrictions. Alternative income opportunities (AIO) enter as `α`.

#### Zanzibar (ZNZ)

| Quantity | Men | Women | Notes |
| --- | --- | --- | --- |
| Price `p` | \$0.45–1.80 | ~50 % lower | Tide window + market segregation |
| Time `t` | 6–8 h day⁻¹ | 2–3 h day⁻¹ | ≈ −60 % for women |
| Efficiency `η` | 6–12 kg person⁻¹ day⁻¹ | 2–4 kg person⁻¹ day⁻¹ | Women ~35 % of men |
| Income anchor | \$2.1 day⁻¹ | — | used for AIO scale |

#### Philippines (PH)

| Quantity | Men | Women | Notes |
| --- | --- | --- | --- |
| Price `p` | \$1.10–3.60 | ≈ 35 % lower | Women often sell lower-value fish |
| Time `t` | 5–6 d week⁻¹ | 2–3 d week⁻¹ | ≈ −50 % |
| Efficiency `η` | 8–13 kg person⁻¹ day⁻¹ | 5–9 kg person⁻¹ day⁻¹ | Women ~70 % of men |
| Income anchor | \$3.5 day⁻¹ | — | calibrates AIO |

#### Parental / Household Economic Status (daily USD)

- **ZNZ:** `LogNormal(μ = −0.5, σ = 1.0)` → median ≈ \$1, mean ≈ \$1 (Gini ≈ 0.52).
- **PH:** `LogNormal(μ = 0.92, σ = 0.6)` → median ≈ \$3, mean ≈ \$3.5 (Gini ≈ 0.33).

These feed the AIO (outside option) term in the SED contexts.

---

### Incentives that Sum to `(1 − f_K)`

Non-dimensional incentives `Iₕ,g` for habitat `h` and group `g` satisfy:

```
Σg Iₕ,g = 1 − xₕ      where xₕ = Bₕ / Kₕ.
```

Steady-state harvest density splits as:

```
Hₕ,g = Iₕ,g · rₕ · Kₕ · xₕ  [kg ha⁻¹ yr⁻¹].
```

Raw propensities:

```
Sₕ,g = pₕ,g · tₕ,g · ηₕ,g · (1 − αₕ,g)
```

Normalized incentives:

```
Iₕ,g = (1 − xₕ) · Sₕ,g / Σ_{g′} Sₕ,g′
```

This guarantees Σg Iₕ,g = 1 − xₕ and Σg Hₕ,g matches the logistic harvest `H*ₕ`. Ecology (r, K, x) pins the total while socio-economic inputs determine the split.

---

### Minimal Calibration Checklist (per habitat)

1. Select `xₕ` (reefs ≈ 0.4–0.6, seagrass ≈ 0.3–0.5) from surveys.
2. Pick `rₕ`, `Kₕ` from the ranges above and compute `H*ₕ`.
3. Specify `p`, `t`, `η`, `α` distributions for each group (women vs men; gear classes).
4. Compute `Sₕ,g`, normalize to `Iₕ,g`, and recover `Hₕ,g`.
5. Sanity-check at the system scale: sum `H*ₕ` over habitat areas `Aₕ`, apply a mixed-fishery scaler `s ∈ (0,1]`, and compare with reported landings; adjust `A_eff`, `s`, or `(r,K)` within documented bounds if needed.

---

### Consistency & Connectivity Notes

- Aggregate production from efficiency × effort × number of fishers matches reported totals (ZNZ ≈ 40–45 kt yr⁻¹; Concepcion ≈ 19 kt yr⁻¹).
- Reef biomass fractions of 40–60 % of `K` and seagrass fractions of 30–50 % align with observed biomass surveys and recovery trends.
- Seascape configuration matters: juvenile snappers, emperors, rabbitfish, and some parrotfish use seagrass nurseries before recruiting to reefs, which motivates keeping reef vs seagrass parameter sets separate.

**Quick references:** Caldwell et al. 2024 (PNAS); Drury O’Neill et al. 2018 (Ecology & Society); de la Torre-Castro et al. 2017 (Marine Policy); Russ & Alcala 2010; McClanahan & Graham 2015; regional biomass surveys cited in the manuscript.
