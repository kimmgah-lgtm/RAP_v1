Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Initialize-RapZoteroSqliteProvider {
    if ('Rap.ZoteroReadOnlySqlite' -as [type]) { return }
    if (-not $IsWindows) { throw 'The SPR-002 SQLite reader currently requires Windows.' }
    $source = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
namespace Rap {
  public static class ZoteroReadOnlySqlite {
    const string Lib="winsqlite3.dll"; const int OK=0, ROW=100, DONE=101;
    [DllImport(Lib,CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_open_v2(byte[] f,out IntPtr db,int flags,IntPtr vfs);
    [DllImport(Lib,CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_close_v2(IntPtr db);
    [DllImport(Lib,CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_busy_timeout(IntPtr db,int ms);
    [DllImport(Lib,CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_prepare_v2(IntPtr db,byte[] sql,int n,out IntPtr stmt,IntPtr tail);
    [DllImport(Lib,CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_step(IntPtr stmt);
    [DllImport(Lib,CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_finalize(IntPtr stmt);
    [DllImport(Lib,CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_errmsg(IntPtr db);
    [DllImport(Lib,CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_column_count(IntPtr stmt);
    [DllImport(Lib,CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_column_name(IntPtr stmt,int col);
    [DllImport(Lib,CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_column_text(IntPtr stmt,int col);
    static byte[] U(string s){var b=Encoding.UTF8.GetBytes(s);var r=new byte[b.Length+1];Buffer.BlockCopy(b,0,r,0,b.Length);return r;}
    static string E(IntPtr db){return Marshal.PtrToStringUTF8(sqlite3_errmsg(db))??"Unknown SQLite error";}
    public static List<Dictionary<string,string>> Query(string path,string sql,int timeout){IntPtr db;int rc=sqlite3_open_v2(U(path),out db,1,IntPtr.Zero);if(rc!=OK)throw new InvalidOperationException("SQLite read-only open failed: "+E(db));try{sqlite3_busy_timeout(db,timeout);IntPtr st;rc=sqlite3_prepare_v2(db,U(sql),-1,out st,IntPtr.Zero);if(rc!=OK)throw new InvalidOperationException(E(db));try{var rows=new List<Dictionary<string,string>>();while((rc=sqlite3_step(st))==ROW){var row=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);for(int i=0;i<sqlite3_column_count(st);i++){var n=Marshal.PtrToStringUTF8(sqlite3_column_name(st,i));var v=sqlite3_column_text(st,i);row[n]=v==IntPtr.Zero?null:Marshal.PtrToStringUTF8(v);}rows.Add(row);}if(rc!=DONE)throw new InvalidOperationException(E(db));return rows;}finally{sqlite3_finalize(st);}}finally{sqlite3_close_v2(db);}}
  }
}
'@
    Add-Type -TypeDefinition $source -Language CSharp -ErrorAction Stop
}

function Invoke-RapZoteroSqliteRead {
    <#
    .SYNOPSIS Executes one read-only query against a Zotero SQLite database.
    .DESCRIPTION Opens SQLite with SQLITE_OPEN_READONLY and accepts SELECT or
    read-only PRAGMA statements only. This is an internal connector boundary.
    .PARAMETER DatabasePath Path to zotero.sqlite or an isolated test fixture.
    .PARAMETER Sql A trusted SELECT or read-only PRAGMA statement.
    .PARAMETER BusyTimeoutMilliseconds Lock wait timeout from 0 through 60000 ms.
    .OUTPUTS Dictionary rows containing internal reader data.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DatabasePath,
        [Parameter(Mandatory)][string]$Sql,
        [ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds = 5000
    )
    if (-not (Test-Path -LiteralPath $DatabasePath -PathType Leaf)) { throw "Zotero database not found: $DatabasePath" }
    $statement = $Sql.TrimStart()
    if ($statement -notmatch '^(?is)(SELECT|PRAGMA\s+(?:integrity_check|quick_check|table_info|user_version)\b)') { throw 'Only read-only SELECT and approved PRAGMA statements are allowed.' }
    if ($statement -match '(?is)\b(INSERT|UPDATE|DELETE|REPLACE|CREATE|ALTER|DROP|VACUUM|ATTACH|DETACH|REINDEX)\b') { throw 'A write-capable SQLite keyword was rejected.' }
    Initialize-RapZoteroSqliteProvider
    return @([Rap.ZoteroReadOnlySqlite]::Query([IO.Path]::GetFullPath($DatabasePath), $Sql, $BusyTimeoutMilliseconds))
}

function Test-RapZoteroSqliteConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DatabasePath, [ValidateRange(0,60000)][int]$BusyTimeoutMilliseconds = 5000)
    try {
        $result = @(Invoke-RapZoteroSqliteRead -DatabasePath $DatabasePath -Sql 'PRAGMA quick_check;' -BusyTimeoutMilliseconds $BusyTimeoutMilliseconds)
        return $result.Count -eq 1 -and $result[0].Values -contains 'ok'
    } catch { return $false }
}

Export-ModuleMember -Function Invoke-RapZoteroSqliteRead, Test-RapZoteroSqliteConnection
