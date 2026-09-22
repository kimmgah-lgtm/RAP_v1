Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Initialize-RapSqliteProvider {
    if ('Rap.NativeSqlite' -as [type]) { return }
    if (-not $IsWindows) { throw 'SPR-001 local SQLite provider requires Windows.' }
    $source = @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace Rap {
  public static class NativeSqlite {
    private const string Lib = "winsqlite3.dll";
    private const int OK = 0, ROW = 100, DONE = 101;
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_open_v2(byte[] file, out IntPtr db, int flags, IntPtr vfs);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_close_v2(IntPtr db);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_busy_timeout(IntPtr db, int ms);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int bytes, out IntPtr stmt, IntPtr tail);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_step(IntPtr stmt);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_finalize(IntPtr stmt);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_errmsg(IntPtr db);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_column_text(IntPtr stmt, int col);
    static byte[] Utf8(string value) { var raw=Encoding.UTF8.GetBytes(value); var result=new byte[raw.Length+1]; Buffer.BlockCopy(raw,0,result,0,raw.Length); return result; }
    static string Error(IntPtr db) { return Marshal.PtrToStringUTF8(sqlite3_errmsg(db)) ?? "Unknown SQLite error"; }
    static IntPtr Open(string path, int timeout) { IntPtr db; int rc=sqlite3_open_v2(Utf8(path),out db,6,IntPtr.Zero); if(rc!=OK) throw new InvalidOperationException("SQLite open failed: "+Error(db)); sqlite3_busy_timeout(db,timeout); return db; }
    public static void Execute(string path, string sql, int timeout) { IntPtr db=Open(path,timeout); try { foreach(string part in sql.Split(new[]{';'},StringSplitOptions.RemoveEmptyEntries)) { IntPtr stmt; int rc=sqlite3_prepare_v2(db,Utf8(part),-1,out stmt,IntPtr.Zero); if(rc!=OK) throw new InvalidOperationException(Error(db)); try { rc=sqlite3_step(stmt); if(rc!=DONE && rc!=ROW) throw new InvalidOperationException(Error(db)); } finally { sqlite3_finalize(stmt); } } } finally { sqlite3_close_v2(db); } }
    public static string Scalar(string path, string sql, int timeout) { IntPtr db=Open(path,timeout); try { IntPtr stmt; int rc=sqlite3_prepare_v2(db,Utf8(sql),-1,out stmt,IntPtr.Zero); if(rc!=OK) throw new InvalidOperationException(Error(db)); try { rc=sqlite3_step(stmt); if(rc==ROW) { IntPtr value=sqlite3_column_text(stmt,0); return value==IntPtr.Zero ? null : Marshal.PtrToStringUTF8(value); } if(rc==DONE) return null; throw new InvalidOperationException(Error(db)); } finally { sqlite3_finalize(stmt); } } finally { sqlite3_close_v2(db); } }
  }
}
'@
    Add-Type -TypeDefinition $source -Language CSharp -ErrorAction Stop
}

function Initialize-RapQueue {
    <#
    .SYNOPSIS
    Initializes the local SQLite queue.
    .DESCRIPTION
    Creates the database directory and idempotently creates the SPR-001 queue
    tables and indexes, then validates database integrity and required tables.
    .PARAMETER DatabasePath
    Path to the local SQLite database file.
    .PARAMETER BusyTimeoutMilliseconds
    Maximum time SQLite waits for a locked database, from 0 through 60000 ms.
    .OUTPUTS
    String containing the absolute database path.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DatabasePath, [ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds = 5000)
    Initialize-RapSqliteProvider
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $DatabasePath))
    $schema = @'
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS Operations (Id INTEGER PRIMARY KEY AUTOINCREMENT, OperationKey TEXT NOT NULL UNIQUE, Type TEXT NOT NULL, Payload TEXT NOT NULL, Status TEXT NOT NULL DEFAULT 'Pending', CreatedUtc TEXT NOT NULL, UpdatedUtc TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS Events (Id INTEGER PRIMARY KEY AUTOINCREMENT, OperationId INTEGER, EventType TEXT NOT NULL, Payload TEXT, CreatedUtc TEXT NOT NULL, FOREIGN KEY(OperationId) REFERENCES Operations(Id));
CREATE TABLE IF NOT EXISTS Retry (Id INTEGER PRIMARY KEY AUTOINCREMENT, OperationId INTEGER NOT NULL UNIQUE, AttemptCount INTEGER NOT NULL DEFAULT 0, NextAttemptUtc TEXT NOT NULL, LastError TEXT, FOREIGN KEY(OperationId) REFERENCES Operations(Id));
CREATE TABLE IF NOT EXISTS History (Id INTEGER PRIMARY KEY AUTOINCREMENT, OperationId INTEGER NOT NULL, PreviousStatus TEXT, NewStatus TEXT NOT NULL, ChangedUtc TEXT NOT NULL, FOREIGN KEY(OperationId) REFERENCES Operations(Id));
CREATE TABLE IF NOT EXISTS Errors (Id INTEGER PRIMARY KEY AUTOINCREMENT, OperationId INTEGER, ErrorCode TEXT, Message TEXT NOT NULL, Details TEXT, CreatedUtc TEXT NOT NULL, FOREIGN KEY(OperationId) REFERENCES Operations(Id));
CREATE INDEX IF NOT EXISTS IX_Operations_Status_CreatedUtc ON Operations(Status, CreatedUtc);
CREATE INDEX IF NOT EXISTS IX_Retry_NextAttemptUtc ON Retry(NextAttemptUtc);
'@
    [Rap.NativeSqlite]::Execute([IO.Path]::GetFullPath($DatabasePath), $schema, $BusyTimeoutMilliseconds)
    if (-not (Test-RapQueue -DatabasePath $DatabasePath -BusyTimeoutMilliseconds $BusyTimeoutMilliseconds)) { throw 'SQLite queue schema validation failed.' }
    return [IO.Path]::GetFullPath($DatabasePath)
}

function Invoke-RapQueueScalar {
    <#
    .SYNOPSIS
    Executes a trusted scalar query against the local queue.
    .DESCRIPTION
    Runs caller-supplied SQLite text and returns the first column of the first
    row. This low-level function is intended only for trusted internal queries.
    .PARAMETER DatabasePath
    Path to the local SQLite database file.
    .PARAMETER Sql
    Trusted SQLite statement that returns at most one scalar value of interest.
    .PARAMETER BusyTimeoutMilliseconds
    Maximum time SQLite waits for a locked database, from 0 through 60000 ms.
    .OUTPUTS
    String containing the scalar value, or null when the query returns no row.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DatabasePath, [Parameter(Mandatory)][string]$Sql, [ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds = 5000)
    Initialize-RapSqliteProvider
    return [Rap.NativeSqlite]::Scalar([IO.Path]::GetFullPath($DatabasePath), $Sql, $BusyTimeoutMilliseconds)
}

function Test-RapQueue {
    <#
    .SYNOPSIS
    Tests the local SQLite queue.
    .DESCRIPTION
    Runs SQLite integrity validation and confirms that all five required queue
    tables exist.
    .PARAMETER DatabasePath
    Path to the local SQLite database file.
    .PARAMETER BusyTimeoutMilliseconds
    Maximum time SQLite waits for a locked database, from 0 through 60000 ms.
    .OUTPUTS
    Boolean indicating whether every queue check passed.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DatabasePath, [ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds = 5000)
    try {
        if (-not (Test-Path -LiteralPath $DatabasePath -PathType Leaf)) { return $false }
        if ((Invoke-RapQueueScalar $DatabasePath 'PRAGMA integrity_check;' $BusyTimeoutMilliseconds) -ne 'ok') { return $false }
        $count = Invoke-RapQueueScalar $DatabasePath "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('Operations','Events','Retry','History','Errors');" $BusyTimeoutMilliseconds
        return [int]$count -eq 5
    } catch { return $false }
}

Export-ModuleMember -Function Initialize-RapQueue, Test-RapQueue, Invoke-RapQueueScalar
