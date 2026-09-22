# ADR-001 — Typed Zotero Connector Interface

- Status: Proposed — approval required
- Date: 2026-09-21
- Decision owner: RAP architecture

## Context

PowerShell modules do not provide a native interface construct equivalent to a C# interface. SPR-002 therefore implements `IZoteroConnector` as a strict module facade: platform code calls only normalized public commands, while SQLite and Web API readers remain behind the facade.

## Proposal

In a future architecture sprint, evaluate a small compiled .NET `IZoteroConnector` interface with typed asynchronous methods and PowerShell adapter implementations. The normalized models could also move to immutable .NET records.

## Benefits

- Compile-time adapter conformance
- Easier dependency injection and mocking
- Stronger return-type guarantees

## Costs and risks

- Adds a build toolchain and binary artifact
- Changes module loading and packaging
- May reduce the current script-only portability

## Decision

No architecture change is made in SPR-002. Approval is required before implementing this proposal.

