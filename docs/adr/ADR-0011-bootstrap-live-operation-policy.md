# ADR-0011 — Bootstrap & Live Operation Policy

- Status: Approved
- Date: 2026-09-22

RAP has exactly two operating modes: `Bootstrap` for the one-time conversion of an existing research library and `Live` for continuous processing of new papers.

Bootstrap runs Production Clean Reset, library scan, Drive and linked-attachment verification, Library_ID assignment, Research Library Master construction, Notion review creation, final integrity verification, report generation, then switches to Live. A guided wizard must complete Scan, Report, Dry Run, explicit User Approval, Backup Snapshot, Execute, Verify, and Report in that order.

Production Clean Reset removes only RAP test registry, test queue, test automation logs, and test sequence state. It preserves Zotero metadata, Drive PDFs, collections, tags, notes, and linked attachments. Research assets are never deletion targets.

Live mode handles only new papers through the established connectors and transaction pipeline. Google Drive remains the only PDF repository; Zotero Storage is prohibited.

