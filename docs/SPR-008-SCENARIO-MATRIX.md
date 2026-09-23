# SPR-008 Evidence Graph Scenario Matrix

Executable source: `src/Local/EvidenceGraph/tests/EvidenceGraphTests.ps1`

| Test | Requirement | Assertion |
|---|---|---|
| 01 | Paper identity | Paper node retains canonical Library_ID. |
| 02 | Multi-project paper | One Library_ID participates in PR001 and PR002. |
| 03 | Project boundary | Project-Paper scope keys remain distinct. |
| 04 | Global/project firewall | Project judgment is absent from the Paper node and paper edges. |
| 05 | Review/coding boundary | Common Review and Meta Coding remain distinct node types. |
| 06 | Paper evidence | Paper links to four independent Evidence nodes. |
| 07 | Project-Paper reference | Project-Paper references the correct Paper. |
| 08 | Meta Coding context | Project-Paper links only to its Meta Coding node. |
| 09 | Multiple outcomes | Meta Coding links to two outcomes. |
| 10 | Multiple effects | Meta Coding links to two effects. |
| 11 | Effect evidence | Effect links to supporting Evidence. |
| 12 | Statistical evidence | Statistical Input links to Evidence. |
| 13 | Derived lineage | Derived Value links to three source inputs. |
| 14 | Library query | Library_ID returns linked Evidence nodes. |
| 15 | Project coding query | Composite scope returns its Meta Coding node. |
| 16 | Effect trace query | Effect returns evidence and statistical inputs. |
| 17 | Derived trace query | Derived Value returns source inputs. |
| 18 | Reverse trace query | Evidence returns dependent records. |
| 19 | Project query | Project_ID returns Project-Paper relationships. |
| 20 | Provenance | Source, location, and prompt metadata survive linkage. |
| 21 | Uncertainty | UNCERTAIN is not promoted. |
| 22 | Missing evidence | NOT_REPORTED retains a null value. |
| 23 | Conflict | Both conflicting sources and values remain. |
| 24 | AI origin | AI_ASSISTED remains after explicit confirmation linkage. |
| 25 | HUMAN_OWNED | Critical Appraisal graph payload is rejected. |
| 26 | Blank HUMAN_OWNED | Blank Reviewer Memo graph payload is rejected. |
| 27 | Silent confirmation | AI node cannot acquire researcher-confirmed state implicitly. |
| 28 | Common Review firewall | Project Meta Coding cannot link as a Common Review. |
| 29 | Missing source | Edge with nonexistent source is rejected. |
| 30 | Missing target | Edge with nonexistent target is rejected. |
| 31 | Cross-project edge | PR001-to-PR002 Meta Coding edge is rejected. |
| 32 | Duplicate edge | Equivalent edge appears once. |
| 33 | Equivalent operation replay | Completed replay performs no upsert. |
| 34 | Payload conflict | Changed payload under the same OperationID is blocked. |
| 35 | Node persistence | All nodes survive SQLite reload. |
| 36 | Edge persistence | All edges survive SQLite reload. |
| 37 | Context persistence | PR001 and PR002 scopes survive reload. |
| 38 | Provenance persistence | Evidence provenance/status survive reload. |
| 39 | Confirmation persistence | AI and researcher-confirmed states remain distinct. |
| 40 | Reload replay | Replay after reload creates no duplicate edge. |
| 41 | AI safety | Production AI Provider remains disabled. |
| 42 | Notion safety | Production Notion Write remains disabled. |
| 43 | Zotero safety | Production Zotero Write remains disabled. |
| 44 | Drive safety | Production Drive Migration remains disabled. |
| 45 | External tests | Real external tests remain TEST_DEFERRED with zero calls. |
| 46 | Production data | Fixture run records zero production/Common Review writes. |
| 47 | Restart recovery | Independent Process B resumes PREPARED state without duplicates. |

Result: **47/47 PASS; 47 runtime assertions.** Final Gate was not performed in Turn A.
