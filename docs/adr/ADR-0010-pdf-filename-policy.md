# ADR-0010 — PDF Filename Policy

- Status: Approved
- Version: 1.0

PDF names are human-readable labels using `FirstAuthor_Year_ShortTitle.pdf`; they are not identifiers. Library_ID must never appear in a filename. RAP identifies a paper through Google Drive File ID, SHA-256, and Library_ID.

Components may analyze names and report recommendations, but may not automatically rename, move, or modify files or linked attachments. SPR-004 therefore requires Drive File ID for linked-attachment verification and uses filename only as a duplicate-reporting signal.
