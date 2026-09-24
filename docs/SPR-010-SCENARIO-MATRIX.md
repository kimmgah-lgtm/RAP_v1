# SPR-010 Scenario Matrix

Executable evidence: `src/Local/Output/tests/OutputTests.ps1` and `OutputAdversarialTests.ps1`.

The 92 required core scenarios are implemented with 101 executable assertions. Production-safety scenarios 84–92 are separate assertions rather than inferred labels. Ten Turn-A adversarial scenarios add 10 assertions. Fifteen independent Turn-B Gate scenarios add 62 assertions. Result: **117/117 scenarios PASS; 173 assertions**.

| Requirement | Test | Actual executable assertion | Result |
|---|---:|---|---|
| Stable specification identity | 01 | `OutputSpecId == OUT-CORE` | PASS |
| Deterministic configuration | 02 | equivalent specifications have equal `ConfigHash` | PASS |
| Project identity required | 03 | invalid project identity throws validation error | PASS |
| Project isolation | 04 | PR002 input under PR001 spec throws scope mismatch | PASS |
| Deterministic dataset | 05 | reverse-ordered inputs produce equal dataset ID | PASS |
| Stable dataset hash | 06 | reverse-ordered inputs produce equal source hash | PASS |
| Source-change detection | 07 | changed effect changes source hash | PASS |
| Stable artifact identity/version | 08 | equivalent artifacts have equal artifact ID | PASS |
| Deterministic content hash | 09 | equivalent artifacts have equal content hash | PASS |
| Idempotency | 10 | replay returns `ALREADY_COMPLETED` without duplicate | PASS |
| Confirmed coding eligibility | 11 | confirmed Meta Coding row is present | PASS |
| AI-only exclusion | 12 | AI-assisted record throws `OUTPUT_SOURCE_NOT_VERIFIED` | PASS |
| Conflict preservation | 13 | conflicting record yields `CONFLICTING_INPUT` | PASS |
| Missingness preservation | 14 | missing sample becomes explicit `NOT_REPORTED` | PASS |
| Unverified synthesis exclusion | 15 | pending analysis is rejected | PASS |
| Verified synthesis inclusion | 16 | verified pooled estimate is emitted | PASS |
| Study-table determinism | 17 | repeated study artifact has equal content hash | PASS |
| Meta Coding project scope | 18 | output row retains PR001 | PASS |
| Effect identity | 19 | effect table retains ES-1 | PASS |
| Effect origin | 20 | reported and derived origins remain distinct | PASS |
| Authoritative synthesis | 21 | output estimate equals SPR-009 fixture result | PASS |
| Heterogeneity fidelity | 22 | Q, I2, and tau2 equal verified values | PASS |
| Moderator missingness | 23 | structured moderator value is preserved without fabricated grouping | PASS |
| Sensitivity parent | 24 | child result retains `ParentAnalysisId` | PASS |
| Screening counts | 25 | verified screened count equals 8 | PASS |
| Missing screening history | 26 | returns `MISSING_REQUIRED_DATA` | PASS |
| No invented PRISMA data | 27 | missing-flow response has no generated content | PASS |
| Forest effect data | 28 | figure effect equals source effect | PASS |
| Forest pooled result | 29 | pooled figure value equals SPR-009 value | PASS |
| Funnel identity | 30 | diagnostic point retains ES-1 | PASS |
| Figure analysis identity | 31 | figure dataset retains AN-PRIMARY | PASS |
| Renderer separation | 32 | figure dataset remains READY without renderer | PASS |
| Introduction protection | 33 | field presence throws HUMAN_OWNED block | PASS |
| Discussion protection | 34 | field presence throws HUMAN_OWNED block | PASS |
| Conclusion protection | 35 | field presence throws HUMAN_OWNED block | PASS |
| Reviewer interpretation protection | 36 | field presence throws HUMAN_OWNED block | PASS |
| Blank narrative protection | 37 | blank Introduction is still blocked | PASS |
| No causal interpretation | 38 | factual text excludes causal/effectiveness claims | PASS |
| No magnitude interpretation | 39 | factual text excludes large/small/important labels | PASS |
| No bias conclusion | 40 | diagnostic interpretation remains null | PASS |
| Specification lineage | 41 | artifact references Output Specification | PASS |
| Dataset lineage | 42 | artifact references Output Dataset | PASS |
| Source-record lineage | 43 | artifact retains every source record ID | PASS |
| Analysis lineage | 44 | synthesis artifact retains AN-PRIMARY | PASS |
| Effect lineage | 45 | effect artifact retains ES-1 | PASS |
| Evidence Graph lineage | 46 | upstream Paper identity exists | PASS |
| Transformation provenance | 47 | derived effect retains Effect Size node reference | PASS |
| Broken-lineage gate | 48 | missing effect lineage is rejected | PASS |
| Manifest creation | 49 | manifest has stable MAN identity | PASS |
| Manifest dataset hash | 50 | manifest hash equals dataset hash | PASS |
| Manifest config hash | 51 | manifest hash equals specification hash | PASS |
| Generator version | 52 | manifest records spr-010.1 | PASS |
| Analysis versions/config | 53 | manifest records SPR-009 engine/config values | PASS |
| Canonical equivalence | 54 | equivalent content hashes match | PASS |
| Configuration versioning | 55 | changed included fields change artifact version | PASS |
| Historical preservation | 56 | prior artifact remains READY and versioned | PASS |
| Analysis staleness | 57 | changed analysis dataset returns STALE | PASS |
| Coding staleness | 58 | changed coding hash returns STALE | PASS |
| Cross-project stale isolation | 59 | PR002 change is NOT_APPLICABLE to PR001 | PASS |
| Current-status safety | 60 | only matching hashes return CURRENT | PASS |
| Stable package ID | 61 | package ID uses deterministic PKG identity | PASS |
| Complete artifact listing | 62 | package lists expected artifact count | PASS |
| Package hashes | 63 | listed hash equals artifact content hash | PASS |
| Credential exclusion | 64 | credential-like extra is rejected | PASS |
| Token exclusion | 65 | token-like extra is rejected | PASS |
| PDF exclusion | 66 | PDF extra is rejected | PASS |
| Private-note exclusion | 67 | private-note extra is rejected | PASS |
| Missing artifact validation | 68 | package validation returns invalid | PASS |
| Hash-mismatch validation | 69 | tampered hash returns invalid | PASS |
| Failed package state | 70 | tampered package status is FAILED | PASS |
| Traversal safety | 71 | `../escape` is rejected | PASS |
| Absolute-path safety | 72 | absolute destination is rejected | PASS |
| Collision determinism | 73 | repeated package construction keeps same ID | PASS |
| Approved-root boundary | 74 | default destination is local fixture and production write is disabled | PASS |
| Partial-failure safety | 75 | invalid/tampered package cannot become READY | PASS |
| Specification persistence | 76 | latest specification hash reloads from SQLite | PASS |
| Artifact persistence | 77 | artifact identity reloads from SQLite | PASS |
| Manifest persistence | 78 | manifest identity reloads from SQLite | PASS |
| Lineage persistence | 79 | output dataset lineage reloads | PASS |
| Artifact history | 80 | two versions survive reload | PASS |
| Audit persistence | 81 | audit count and operation record reload | PASS |
| Persistent replay | 82 | same operation/payload is idempotent | PASS |
| Persistent conflict | 83 | same operation/different payload throws conflict | PASS |
| AI production safety | 84 | `ProductionAIProvider == false` | PASS |
| Zotero production safety | 85 | `ProductionZoteroWrite == false` | PASS |
| Drive production safety | 86 | `ProductionDriveMigration == false` | PASS |
| Notion production safety | 87 | `ProductionNotionWrite == false` | PASS |
| Synthesis production safety | 88 | `SynthesisProductionWrite == false` | PASS |
| Output production safety | 89 | `OutputProductionWrite == false` | PASS |
| External-test boundary | 90 | Local environment and empty Drive target enforce deferred route | PASS |
| Zero production mutation | 91 | write layer and production migration/write flags are disabled | PASS |
| No PDF transmission | 92 | package exclusions contain `CANONICAL_PDF` | PASS |

## Adversarial matrix

| Case | Requirement | Actual executable assertion | Result |
|---|---|---|---|
| A | Wrong project | cross-project verified effect is blocked | PASS |
| B | Broken lineage | missing effect lineage is blocked | PASS |
| C | Stale analysis | changed upstream hash returns STALE | PASS |
| D | Missing screening | no flow content is fabricated | PASS |
| E | Interpretation request boundary | factual statement has null interpretation | PASS |
| F | Credential fixture | credential-like package content is rejected | PASS |
| G | Same Library, other project | project contamination is blocked | PASS |
| H | AI-only coding | unconfirmed coding is rejected | PASS |
| I | Partial failure | tampered package remains FAILED | PASS |
| J | Tampered artifact | content-hash validation returns invalid | PASS |

## Turn-B independent Gate matrix

Executable evidence: `src/Local/Output/tests/OutputGateTests.ps1`.

| Gate | Requirement | Meaningful executable verification | Assertions | Result |
|---|---|---|---:|---|
| A | Bidirectional project isolation | Same Library_ID with PR001/PR002 produces only its own effect; both mixed directions throw | 4 | PASS |
| B | Reverse traceability and broken lineage | Samples seven output families through dataset/spec/source/Analysis/Effect/Evidence/Paper/transformation inputs; empty evidence lineage blocks | 9 | PASS |
| C | SPR-009 equivalence and Analysis scope | Runs actual SPR-009 random-effects fixture; compares pooled effect, SE, CI, Q, I², tau² at `1e-12`, plus model/estimator/counts; wrong Analysis_ID blocks | 9 | PASS |
| D | Actual-content tamper | Mutates scientific content without changing stored metadata hash; package validation and manifest construction both fail | 2 | PASS |
| E | Stale isolation | Meaningful PR001 source change returns STALE; unrelated PR002 change returns NOT_APPLICABLE | 2 | PASS |
| F | AI-assisted firewall | AI_ASSISTED coding is rejected from confirmed output | 1 | PASS |
| G | Researcher-owned firewall | Six blank narrative/judgment fields remain protected | 6 | PASS |
| H | Missing screening / PRISMA boundary | Missing history yields explicit requirement and no count/compliance content | 2 | PASS |
| I | Interpretation and figure-data boundary | Bias/factual text stays non-interpretive; forest/funnel values retain authoritative identities | 4 | PASS |
| J | Export private-content safety | Five fake secret/private/PDF paths reject; package identity/version/validation metadata verified | 6 | PASS |
| K | Path and collision safety | Traversal and absolute path reject; local-only boundary and deterministic collision identity verified | 4 | PASS |
| L | Atomic failure safety | Injected commit failure propagates and leaves zero READY artifacts | 2 | PASS |
| M | Idempotency, persistence, audit, history | Replay deduplicates; spec/dataset/artifact/manifest/package/lineage/status/audit reload; two artifact versions survive | 7 | PASS |
| N | Payload conflict | Same operation with changed configuration/payload throws conflict | 1 | PASS |
| O | Regeneration/version behavior | Equivalent regeneration is stable; source and configuration changes create distinct dataset/version identity | 3 | PASS |

Turn-B independent result: **15/15 PASS; 62 executable assertions**.
