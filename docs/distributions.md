# Distributions

Explains independent vs dependent distributions, function vs string dependency functions, and the `independent` shorthand in strings.

Topics

- Independent: `dist(min/max/mean/median/sigma; distribution, random, normalize)`
- Dependent (function): `dist(dependent=(...), dependency_fun=(indep, dep)-> ...)`
- Dependent (string): `dist(dependency_fun="...")` with `independent` bound to the base vector
- Sampling: `sample!(dist, N; random)` vs `sample!(context; N, random)`
- Weighted dependents and broadcasting rules

