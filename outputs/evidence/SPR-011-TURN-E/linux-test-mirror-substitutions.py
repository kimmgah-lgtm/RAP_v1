# Test-only substitutions applied to a throwaway copy of the repository for Linux execution (Turn E). Not applied to repository source.
# Test-only Linux substitutions (repo source NOT modified). Each is a Windows-path/Windows-DLL artifact.
import sys,re,pathlib
m=pathlib.Path(sys.argv[1])
subs=[
 ("src/Local/ResearchAutomation.Local/modules/Queue.psm1", "if (-not $IsWindows) { throw 'SPR-001 local SQLite provider requires Windows.' }", "# LINUX-MIRROR guard bypassed"),
 ("src/Local/Connectors/Zotero/SQLiteReader.psm1", "if (-not $IsWindows) { throw 'The SPR-002 SQLite reader currently requires Windows.' }", "# LINUX-MIRROR guard bypassed"),
 ("src/Local/Write/ResearchAutomation.Write/tests/AcceptanceTests.ps1", "'C:\\Sandbox\\paper.pdf'", "'/Sandbox/paper.pdf'"),
 ("src/Local/Output/tests/OutputTests.ps1", "'C:\\escape'", "'/escape'"),
 ("src/Local/Output/tests/OutputGateTests.ps1", "-LogicalDestination 'C:\\escape'", "-LogicalDestination '/escape'"),
]
for f,a,b in subs:
    p=m/f; t=p.read_text(encoding='utf-8-sig') if p.read_bytes().startswith(b'\xef\xbb\xbf') else p.read_text()
    if a not in t: print("MIRROR PATCH MISSING:",f,a); sys.exit(2)
    p.write_text(t.replace(a,b)); print("mirror-patched:",f)
