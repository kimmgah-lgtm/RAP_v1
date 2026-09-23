# SPR-007 Meta Coding Engine Scenario Matrix

Executable source: `src/Local/MetaCoding/tests/MetaCodingTests.ps1`

| Test | Requirement | Executable assertion |
|---|---|---|
| 01 | Project boundary | Same Library_ID in PR001 and PR002 creates two scope records. |
| 02 | Stable context | Same Library_ID and Project_ID resolve to the same scope and operation identity. |
| 03 | Global identity firewall | Project coding contains no canonical paper mutation. |
| 04 | Common Review firewall | Common Review update payload is rejected before upsert. |
| 05 | Multiple outcomes | Two Outcome IDs coexist in one project record. |
| 06 | Multiple comparisons | Two Comparison IDs coexist without flattening. |
| 07 | Multiple time points | Post-test and follow-up IDs remain distinct. |
| 08 | Multiple effects | Two Effect Size IDs remain distinct. |
| 09 | Study arms | Effect records retain arm references and arm identity. |
| 10 | Dependency identity | Within-study effects retain their DependencyGroupId. |
| 11 | Effect Size Type | Hedges g and Cohen d types are preserved. |
| 12 | Statistical linkage | Effect value remains linked to its statistical input IDs. |
| 13 | Reported sample size | Total, group, and analytic N are retained. |
| 14 | Missing sample size | Missing N is null with NOT_REPORTED. |
| 15 | Conflicting evidence | Conflicting statistical evidence is not silently resolved. |
| 16 | Uncertain evidence | Unclear statistical evidence remains UNCERTAIN. |
| 17 | Ownership distinction | AiAssisted and ResearcherConfirmed branches remain separate. |
| 18 | No silent confirmation | AI output remains AI_ASSISTED and cannot create human confirmation. |
| 19 | Confirmed protection | Existing researcher memo survives automated extraction. |
| 20 | Existing HUMAN_OWNED | Appraisal and interpretation survive automated extraction. |
| 21 | Blank HUMAN_OWNED | Blank reviewer memo is still rejected as an AI field. |
| 22 | Inclusion decision | AI EffectSizeInclusion is blocked. |
| 23 | Outcome decision | AI OutcomeSelection is blocked. |
| 24 | Comparison decision | AI ComparisonSelection is blocked. |
| 25 | Dependency decision | AI DependencyHandling is blocked. |
| 26 | Exclusion decision | AI StudyExclusion is blocked. |
| 27 | Transformation decision | AI StatisticalTransformationDecision is blocked. |
| 28 | Quantitative provenance | Source, location, method, confidence, prompt, and schema metadata survive. |
| 29 | Derived/direct distinction | Derived and directly reported flags remain distinct. |
| 30 | Transformation provenance | Method, formula version, and source references survive. |
| 31 | Equivalent replay | Same OperationID and payload causes no extraction or upsert. |
| 32 | Payload conflict | Same OperationID with changed payload is rejected. |
| 33 | Effect replay | Replay does not duplicate Effect Size IDs. |
| 34 | SQLite reload | Project coding survives store reconstruction. |
| 35 | Confirmation reload | Researcher confirmation survives store reconstruction. |
| 36 | Provenance reload | Evidence and derivation provenance survive store reconstruction. |
| 37 | Independent restart | Process B resumes Process A's PATCH_PREPARED ledger state without re-extraction. |
| 38 | Notion safety | Production Notion Write capability is false. |
| 39 | Zotero safety | Production Zotero Write capability is false. |
| 40 | Drive safety | Production Drive Migration capability is false. |
| 41 | AI safety | Production AI Provider and AI Review capabilities are false. |
| 42 | Zero production changes | Fixture counters and result flags prove no production mutation. |

Result: **42/42 PASS; 42 direct scenario assertions.** Real external integrations remain `TEST_DEFERRED`.
