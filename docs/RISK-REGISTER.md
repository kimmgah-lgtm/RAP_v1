# RAP Risk Register

Last verified: 2026-09-23, SPR-009 Turn B Final Gate

Open-risk summary: **P0 = 0, P1 = 6, P2 = 2**.

| Risk ID | Priority | Description and evidence | Impact | Affected component | Gate blocking |
|---|---|---|---|---|---|
| RISK-SPR009-001 | P1 | A dataset containing two effects in one dependency group is accepted with `DependencyStrategy=RVE`, but `Invoke-RapSynthesis` still applies the ordinary independent inverse-variance model and returns a pooled result. | A claimed dependency strategy is recorded but not executed, so dependent effects can be analysed as independent. | SPR-009 dependency handling and primary synthesis | YES |
| RISK-SPR009-002 | P1 | `New-RapAnalysisSpecification` silently defaults to `Model=RANDOM` and `Estimator=DL` when the caller omits both parameters. | A scientifically consequential researcher decision can be finalized by a runtime default. | SPR-009 analysis specification / researcher decision firewall | YES |
| RISK-SPR009-003 | P1 | A `DERIVED_EFFECT` record with null `StatisticalInputs` and null `Transformation` is accepted into an analysis dataset. | A derived effect can lose the source-statistic and formula lineage required for audit and reproduction. | SPR-009 dataset validation / effect provenance | YES |
| RISK-SPR009-004 | P1 | Synthesis lineage contains effect, project, evidence text, and optional input data, but no Analysis Dataset node/link or Paper node/link and does not emit validated SPR-008 graph edges. | The required result → dataset → effect → input → evidence → paper chain cannot be verified from the analysis result. | SPR-008/SPR-009 lineage integration | YES |
| RISK-SPR009-005 | P1 | Leave-one-out results contain only parent analysis ID, method, excluded effect ID, pooled estimate, and timestamp; they are not saved by synthesis persistence and contain no config/dataset hash, engine version, or provenance. | Sensitivity analyses cannot be fully reloaded, versioned, or reproduced from persisted state. | SPR-009 sensitivity and persistence | YES |
| RISK-SPR009-006 | P1 | An approved moderator with a missing value is accepted and analysed as a subgroup whose identity is an empty string. | Invalid moderator input does not fail explicitly and can create an anonymous subgroup. | SPR-009 moderator validation | YES |
| RISK-SPR009-007 | P2 | The 68-scenario suite passes but does not assert the six Final Gate conditions above; scenario 38 checks only a missing dependency strategy, not execution of a selected strategy. | Existing green test evidence overstates coverage of several scientific safety boundaries. | SPR-009 tests and Scenario Matrix | NO (underlying P1 risks block the Gate) |
| RISK-BASELINE-001 | P2 | No SPR-006 executable source/test artifacts are present in this checkout. | The historical SPR-006 baseline cannot be rerun locally as part of the safe regression. | Repository regression evidence | NO |

No P0 risk was observed. All risks above were derived from the current repository and deterministic local fixture probes; no historical count was inherited.
