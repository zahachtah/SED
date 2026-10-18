# SED

## Who exits, who extracts, who gains?

Two communities can have the same average income and harvesting technology,
yet very different resource futures. The difference can lie in **who has
alternatives, who can exert the greatest impact, and how those advantages
are paired**.

SED is a distributional social-ecological model for exploring that difference.
It connects heterogeneous people to renewable-resource dynamics, policy
outcomes, and the distribution of income.

**[Explore the interactive companion](https://zahachtah.github.io/SED/)** ·
[Read the manuscript](manuscript/Science_MS_compact.pdf) ·
[Read the supplement](SupplementaryMaterial/SED_Supplementary_Material.pdf)

The companion also runs entirely offline: download or clone this repository
and open [`index.html`](index.html) in your browser. No installation, account,
or server is needed.

<!-- companion-screenshot -->
[![Interactive SED companion: resource balance, policy controls, and income distributions](docs/assets/companion.png)](https://zahachtah.github.io/SED/)

### Start With a Question

- **Does inequality change the resource outcome?** Change the spread of exit
  thresholds while keeping their mean fixed.
- **Does it matter who has the best technology?** Reverse the pairing between
  exit thresholds and impact potentials without changing either marginal
  distribution.
- **Who gains from a policy?** Compare resource recovery, participation, and
  income under exclusive rights, tradable rights, protected areas, and
  economic instruments. Scan policy intensity to see the trade-offs.
- **Where do these distributions come from?** Open the population builder to
  explore illustrative pathways from health, gendered access, care obligations,
  and capital to outside opportunities, available time, and efficiency.

The population builder is a place to investigate hypotheses, not a calibrated
claim about any social group. Empirical applications require context-specific
data and defensible causal assumptions.

## The Model in One Minute

Each actor has an **exit threshold**: the resource density below which outside
opportunities become more attractive than harvesting. Each also has an
**impact potential**: the maximum extraction pressure they can exert relative
to resource renewal.

At any resource density, the joint distribution tells us who is willing to
harvest and how much pressure those actors can supply. The participation curve
and the sustainable-participation curve describe the balance between extraction
and renewal. Their crossing identifies the equilibrium resource density,
including a partially active marginal actor when needed.

The Julia package simulates the bounded actor dynamics and the resource
directly. Policies can change thresholds, impact potentials, access, or the
allocation of rents. The same population can therefore reveal both ecological
outcomes and **who receives resource income and who relies on alternatives**.

## Run a Study in Julia

The recorded environment uses **Julia 1.12.5**. From the repository root:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

```julia
using SED

population = base(N=300)
sample!(population; random=false)  # deterministic quantiles

open_access = sim(population)
rights = scenario(population;
    policy=TradableUseRights(:effort, 0.05, 0.0, false))
managed = sim(rights; regulation=0.40, start_from_OA=true)

incomes(managed)
```

Here, `regulation=0.40` leaves an aggregate effort quota of `0.60`. Both runs
use the same realized population, and the policy starts from its open-access
attractor. Ordered quantiles are useful for controlled comparisons; seeded
random samples describe finite-population variability.

For publication-quality output:

```julia
using CairoMakie
CairoMakie.activate!()

fig = Figure(size=(1100, 750))
phase_plot!(Axis(fig[1, 1]), managed; show_trajectory=true)
incomes_plot!(Axis(fig[2, 1]), managed; order=true)
save("outcomes.pdf", fig)
```

## Find Your Way

| Path | Purpose |
| --- | --- |
| [`index.html`](index.html) | Self-contained interactive companion; also the Pages entry point. |
| [`src/`](src/) | Julia model, distributions, policies, metrics, and plotting. |
| [`test/`](test/) | Scientific regression tests. |
| [`webapp/`](webapp/README.md) | Companion source, build instructions, and Julia-parity checks. |
| [`manuscript/`](manuscript/README.md) | Current paper, four figure scripts, and final figure outputs. |
| [`SupplementaryMaterial/`](SupplementaryMaterial/README.md) | Derivations, policy explainers, numerical records, and LaTeX source. |
| [`docs/`](docs/README.md) | Model conventions, distributions, policy extension, and reproducibility. |

**Reproduce the paper:** follow the [reproduction guide](docs/reproducibility.md).
**Extend the model:** start with the [policy guide](docs/policies.md) and
[custom policies](docs/custom_policies.md).

## Scientific Scope

The manuscript and supplement define the scientific interpretation; the tested
Julia implementation is the computational reference. The browser companion
checks its main mechanisms against fixed-population Julia runs. Its
[scientific contract](webapp/SCIENCE.md) explains sampling, accounting,
convergence, and reduced-form assumptions.

Exclusive rights use a binary strong-sanction specialization. Protected areas
use a one-resource equilibrium reduction. Generic Julia economic transforms
are not automatically literal gear subsidies or royalties; dimensional causal
mechanisms must be mapped explicitly. Experimental development and two-patch
workflows are not exposed in the companion.

## Citation and License

By John M. Anderies and Jon Norberg. Citation metadata is in
[`CITATION.cff`](CITATION.cff). For reproducible studies, record the exact commit
or release, the environment, population seed, policy settings, and convergence
diagnostics. A manuscript DOI and archived release DOI can be added when issued.

SED is available under the [MIT license](LICENSE). Bundled Lucide icons retain
their [ISC license](webapp/vendor/lucide.LICENSE).
