# SPR-009 Scenario Matrix

Legacy scenarios execute in `src/Local/Synthesis/tests/SynthesisTests.ps1` and each
legacy row maps to one runtime assertion. Gate-remediation scenarios execute in
`src/Local/Synthesis/tests/SynthesisGateRemediationTests.ps1`; their 25 scenario
rows use 31 assertions, including 6 additional numerical non-regression checks.
Result: **93/93 scenarios PASS; 99 actual assertions; 17 numerical assertions**
on 2026-09-23.

Turn D reran both focused suites unchanged and confirmed the same 93/93 scenario,
99 assertion, and 17 numerical-assertion result before the Final Gate PASS. The
remaining SPR-006 artifact-availability risk does not alter these SPR-009 results.

## Turn B coverage finding and Turn C closure

The existing assertions pass, but the Final Gate found material requirements that
the matrix does not exercise: execution/rejection of a selected dependency
strategy, mandatory derivation metadata, explicit model/estimator selection,
complete Analysis Dataset-to-Paper lineage, persistence of sensitivity runs, and
rejection of missing moderator values. Turn C added scenarios 69–93 below to close
those coverage gaps. Turn C itself did not perform Final Gate; the later Turn D
gate reran and accepted this matrix. See `docs/RISK-REGISTER.md` for current risk
state.

| Test | Requirement | Assertion evidence | Result |
|---:|---|---|---|
| 01 | Confirmation gate | dataset contains confirmed rows only | PASS |
| 02 | AI-only rejection | `RESEARCHER_CONFIRMATION_REQUIRED` | PASS |
| 03 | Project boundary | `PROJECT_SCOPE_MISMATCH` | PASS |
| 04 | Library trace | row retains `LibraryId` | PASS |
| 05 | Multiple effects | two stable effect IDs retained | PASS |
| 06 | Missing input | required identity rejection | PASS |
| 07 | Invalid sample | negative N rejected | PASS |
| 08 | Invalid variance | zero variance rejected | PASS |
| 09 | Conversion safety | unsupported type rejected | PASS |
| 10 | Conflict gate | unresolved conflict rejected | PASS |
| 11 | Direct effect | value unchanged | PASS |
| 12 | Derived effect | Hedges' g ≈ 0.4961 | PASS |
| 13 | Source inputs | six group inputs retained | PASS |
| 14 | Effect origin | reported/derived distinct | PASS |
| 15 | Numerical tolerance | SE identity within 1e-12 | PASS |
| 16 | Direction metadata | action retained | PASS |
| 17 | No silent reversal | required action rejected | PASS |
| 18 | Approved reversal | +0.4 becomes -0.4 | PASS |
| 19 | Original preserved | original remains +0.4 | PASS |
| 20 | Deterministic builder | canonical dataset built | PASS |
| 21 | Stable dataset hash | reordered inputs same hash | PASS |
| 22 | Changed dataset hash | changed value changes hash | PASS |
| 23 | Upstream IDs | coding/outcome/provenance retained | PASS |
| 24 | Spec persistence | SQLite reload count | PASS |
| 25 | Config hash | identical config same hash | PASS |
| 26 | Config mutation | model change changes hash | PASS |
| 27 | Version preservation | two specs/runs retained | PASS |
| 28 | Pooled estimate | random-effects estimate = 0.6 | PASS |
| 29 | Confidence interval | lower CI within 1e-5 | PASS |
| 30 | Counts | 3 studies/3 effects | PASS |
| 31 | Model record | RANDOM retained | PASS |
| 32 | Estimator record | DL retained | PASS |
| 33 | Cochran Q | Q = 15.5 ± 1e-10 | PASS |
| 34 | I² | 87.096774 ± 1e-5 | PASS |
| 35 | tau² | 0.27 ± 1e-12 | PASS |
| 36 | No interpretation | no qualitative field emitted | PASS |
| 37 | Dependency detection | shared group detected | PASS |
| 38 | No independence assumption | missing strategy rejected | PASS |
| 39 | Strategy retained | RVE recorded | PASS |
| 40 | Moderator approval | Region linked | PASS |
| 41 | Subgroup identity | A/B groups retained | PASS |
| 42 | No variable fishing | automatic selection false | PASS |
| 43 | Sensitivity | three leave-one-out runs | PASS |
| 44 | Parent analysis | parent ID retained | PASS |
| 45 | Exclusion audit | three excluded IDs retained | PASS |
| 46 | Primary immutable | primary result unchanged | PASS |
| 47 | Bias diagnostic | three funnel points | PASS |
| 48 | No bias conclusion | interpretation null | PASS |
| 49 | Result lineage | three effect links | PASS |
| 50 | Evidence lineage | evidence reference retained | PASS |
| 51 | Input lineage | derived inputs retained | PASS |
| 52 | Project lineage | all links remain PR001 | PASS |
| 53 | Idempotent replay | no duplicate run | PASS |
| 54 | Payload conflict | conflict rejected | PASS |
| 55 | Spec reload | configuration survives | PASS |
| 56 | Result reload | run survives | PASS |
| 57 | Provenance reload | evidence survives | PASS |
| 58 | Reproducibility | estimate equal within 1e-12 | PASS |
| 59 | Analysis versioning | run IDs distinct | PASS |
| 60 | HUMAN_OWNED | populated field rejected | PASS |
| 61 | Blank HUMAN_OWNED | blank field rejected | PASS |
| 62 | Interpretation firewall | result interpretation null | PASS |
| 63 | AI safety | production AI false | PASS |
| 64 | Notion safety | production Notion false | PASS |
| 65 | Zotero safety | production Zotero false | PASS |
| 66 | Drive safety | production Drive false | PASS |
| 67 | External deferral | AIReview false/write disabled | PASS |
| 68 | Zero production change | fixture audit only | PASS |

## Turn C Gate-remediation scenarios

| Test | Requirement | Assertion evidence | Result |
|---:|---|---|---|
| 69 (A) | Derived source inputs | missing source statistics raise `DERIVED_EFFECT_SOURCE_INPUTS_REQUIRED` | PASS |
| 70 (B) | Derived transformation | missing transformation raises `DERIVED_EFFECT_TRANSFORMATION_REQUIRED` | PASS |
| 71 (C) | Valid derived eligibility | complete inputs and method/version remain intact | PASS |
| 72 (D) | No empty moderator group | subgroup call raises `MISSING_MODERATOR_VALUE` | PASS |
| 73 (E) | Missing state preservation | primary dataset retains null moderator | PASS |
| 74 (F) | Unsupported RVE | `UNSUPPORTED_DEPENDENCY_STRATEGY`; no pooled result | PASS |
| 75 (G) | Unapproved dependency | shared group with `NONE` raises `DEPENDENCY_STRATEGY_REQUIRED` | PASS |
| 76 (H) | Independent non-regression | valid independent fixture still pools to `0.6` | PASS |
| 77 (I) | Sensitivity identity | every child has a distinct Analysis ID | PASS |
| 78 (J) | Parent relationship | every child retains parent Analysis ID | PASS |
| 79 (K) | Sensitivity hashes | child dataset/configuration hashes present | PASS |
| 80 (L) | Sensitivity version/provenance | engine version and upstream lineage retained | PASS |
| 81 (M) | Restart/reload | separate writer and reader processes recover three child runs | PASS |
| 82 (N) | Complete SPR-008 lineage | result links dataset, effect, evidence, and paper identities | PASS |
| 83 (O) | Broken analysis/effect path | missing `HAS_EFFECT_SIZE` edge blocks dataset | PASS |
| 84 (P) | Broken paper path | missing Paper node blocks dataset | PASS |
| 85 (Q) | Derived transformation lineage | derived node and six statistical inputs retained | PASS |
| 86 (R) | Missing model | `ANALYSIS_MODEL_REQUIRED` | PASS |
| 87 (S) | Missing estimator | `ANALYSIS_ESTIMATOR_REQUIRED` | PASS |
| 88 (T) | Explicit scientific decision | researcher-specified RANDOM/DL retained | PASS |
| 89 (U) | HUMAN_OWNED non-regression | blank Reviewer Memo remains blocked | PASS |
| 90 (V) | Project boundary non-regression | PR002 record rejected by PR001 analysis | PASS |
| 91 (W) | Production safety | all production capabilities and synthesis write remain disabled | PASS |
| 92 (X) | Sensitivity idempotent replay | same operation/payload adds no child runs | PASS |
| 93 (Y) | Sensitivity payload conflict | changed dataset with same operation raises `PAYLOAD_CONFLICT` | PASS |

## Numerical fixtures

- Hedges' g: equal group SDs, means 12 and 10, N=50+50; expected `g ≈ 0.4961`, tolerance `0.0002`.
- Random-effects fixture: effects `0.1, 0.5, 1.2`, each variance `0.04`, DerSimonian–Laird estimator.
- Expected pooled effect `0.6` (tolerance `1e-12`), Q `15.5` (`1e-10`), I² `87.096774%` (`1e-5`), tau² `0.27` (`1e-12`), and lower 95% CI `-0.0300529` (`1e-5`).
- Turn C independently reasserts Hedges' g `0.4961636828644501`, variance `0.04125601224588579`, SE `0.20311576070282136`, fixed pooled effect `0.6`, fixed SE `0.11547005383792516`, and fixed lower CI `0.37367869447766666`, each at tolerance `1e-12`.
