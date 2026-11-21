# Model and Study Guides

Start with the [interactive companion](https://zahachtah.github.io/SED/) or the
[root README](../README.md). Manuscript and supplementary material:
pending approval for release. The guides below describe the public model.

| Guide | What it answers |
| --- | --- |
| [Model-to-paper crosswalk](model-paper-crosswalk.md) | Which equations and notation does each function implement? |
| [Distributions](distributions.md) | How are actor populations, dependencies, and ordered/random draws specified? |
| [Policies](policies.md) | What does each policy actually change, and what are its limitations? |
| [Custom policies](custom_policies.md) | How can a study add a new policy through Julia dispatch? |
| [Reproducibility](reproducibility.md) | How do I run checks and regenerate the submitted figures? |
| [GitHub Pages](github-pages.md) | How is the interactive companion built and published? |

The Julia fields `w̃` and `ū` are legacy internal names for the paper's exit
threshold `θᵢ` and impact potential `ūᵢ`. They are not separate quantities.
Follow [AGENTS.md](../AGENTS.md) for AI-assisted studies.
