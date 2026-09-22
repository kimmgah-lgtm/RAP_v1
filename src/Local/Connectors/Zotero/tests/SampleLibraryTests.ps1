#Requires -Version 7.0
<# .SYNOPSIS Runs SPR-002 SQLite and sample-library acceptance tests. #>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$connectorRoot=Split-Path -Parent $PSScriptRoot
$localRoot=[IO.Path]::GetFullPath((Join-Path $connectorRoot '../../ResearchAutomation.Local'))
Import-Module (Join-Path $localRoot 'ResearchAutomation.Local.psd1') -Force
$fixture=Join-Path $localRoot ("temp/spr002-sample-{0}.db" -f [guid]::NewGuid().ToString('N'))
[void](Initialize-RapQueue -DatabasePath $fixture)
$schema=@'
CREATE TABLE itemTypes(itemTypeID INTEGER PRIMARY KEY,typeName TEXT);
CREATE TABLE items(itemID INTEGER PRIMARY KEY,itemTypeID INTEGER,libraryID INTEGER,key TEXT,version INTEGER);
CREATE TABLE deletedItems(itemID INTEGER);
CREATE TABLE fields(fieldID INTEGER PRIMARY KEY,fieldName TEXT);
CREATE TABLE itemDataValues(valueID INTEGER PRIMARY KEY,value TEXT);
CREATE TABLE itemData(itemID INTEGER,fieldID INTEGER,valueID INTEGER);
CREATE TABLE creatorTypes(creatorTypeID INTEGER PRIMARY KEY,creatorType TEXT);
CREATE TABLE creators(creatorID INTEGER PRIMARY KEY,firstName TEXT,lastName TEXT,fieldMode INTEGER);
CREATE TABLE itemCreators(itemID INTEGER,creatorID INTEGER,creatorTypeID INTEGER,orderIndex INTEGER);
CREATE TABLE tags(tagID INTEGER PRIMARY KEY,name TEXT);
CREATE TABLE itemTags(itemID INTEGER,tagID INTEGER,type INTEGER);
CREATE TABLE collections(collectionID INTEGER PRIMARY KEY,parentCollectionID INTEGER,collectionName TEXT,key TEXT,version INTEGER);
CREATE TABLE collectionItems(collectionID INTEGER,itemID INTEGER,orderIndex INTEGER);
CREATE TABLE itemNotes(itemID INTEGER,parentItemID INTEGER,note TEXT);
CREATE TABLE itemAttachments(itemID INTEGER,parentItemID INTEGER,linkMode INTEGER,contentType TEXT,path TEXT);
CREATE TABLE itemAnnotations(itemID INTEGER,parentItemID INTEGER,type TEXT,text TEXT,comment TEXT,color TEXT,pageLabel TEXT,position TEXT);
INSERT INTO itemTypes VALUES(1,'journalArticle');
INSERT INTO itemTypes VALUES(2,'attachment');
INSERT INTO itemTypes VALUES(3,'note');
INSERT INTO itemTypes VALUES(4,'annotation');
INSERT INTO items VALUES(1,1,NULL,'ITEM0001',7);
INSERT INTO items VALUES(2,2,NULL,'ATTACH01',2);
INSERT INTO items VALUES(3,3,NULL,'NOTE0001',1);
INSERT INTO items VALUES(4,4,NULL,'ANNOT001',1);
INSERT INTO items VALUES(5,2,NULL,'LINKED01',1);
INSERT INTO fields VALUES(1,'title');
INSERT INTO fields VALUES(2,'DOI');
INSERT INTO fields VALUES(3,'date');
INSERT INTO fields VALUES(4,'publicationTitle');
INSERT INTO fields VALUES(5,'extra');
INSERT INTO itemDataValues VALUES(1,'Sample Article');
INSERT INTO itemDataValues VALUES(2,'10.1000/sample');
INSERT INTO itemDataValues VALUES(3,'2026');
INSERT INTO itemDataValues VALUES(4,'Journal of Fixtures');
INSERT INTO itemDataValues VALUES(5,'Read only');
INSERT INTO itemDataValues VALUES(6,'Imported PDF');
INSERT INTO itemDataValues VALUES(7,'Linked PDF');
INSERT INTO itemData VALUES(1,1,1);
INSERT INTO itemData VALUES(1,2,2);
INSERT INTO itemData VALUES(1,3,3);
INSERT INTO itemData VALUES(1,4,4);
INSERT INTO itemData VALUES(1,5,5);
INSERT INTO itemData VALUES(2,1,6);
INSERT INTO itemData VALUES(5,1,7);
INSERT INTO creatorTypes VALUES(1,'author');
INSERT INTO creators VALUES(1,'Ada','Lovelace',0);
INSERT INTO itemCreators VALUES(1,1,1,0);
INSERT INTO tags VALUES(1,'automation');
INSERT INTO itemTags VALUES(1,1,0);
INSERT INTO collections VALUES(1,NULL,'Research','COLL0001',3);
INSERT INTO collectionItems VALUES(1,1,0);
INSERT INTO itemNotes VALUES(3,1,'<p>Fixture note</p>');
INSERT INTO itemAttachments VALUES(2,1,0,'application/pdf','storage:paper.pdf');
INSERT INTO itemAttachments VALUES(5,1,2,'application/pdf','C:\linked\paper.pdf');
INSERT INTO itemAnnotations VALUES(4,2,'highlight','Important','Review','#ffd400','1','{}');
'@
[Rap.NativeSqlite]::Execute([IO.Path]::GetFullPath($fixture),$schema,5000)

if(-not (Test-RapZoteroConnection -Connector SQLite -DatabasePath $fixture)){throw 'SQLite read-only connection test failed.'}
$items=@(Get-RapZoteroItems -Connector SQLite -DatabasePath $fixture -StorageRoot $localRoot)
if($items.Count -ne 1 -or $items[0].Title -ne 'Sample Article'){throw 'SQLite connector item test failed.'}
if($items[0].Creators.Count -ne 1 -or $items[0].Tags[0] -ne 'automation'){throw 'Creator or tag test failed.'}
if($items[0].Collections.Count -ne 1 -or $items[0].Notes.Count -ne 1){throw 'Collection or note test failed.'}
if($items[0].Attachments.Count -ne 2 -or @($items[0].Attachments|Where-Object IsLinked).Count -ne 1){throw 'Attachment/link detection test failed.'}
if($items[0].Attachments[0].Path -notmatch '[\\/]storage[\\/]ATTACH01[\\/]paper\.pdf$'){throw 'Storage path discovery test failed.'}
if($items[0].AnnotationSummary.Count -ne 1){throw 'Annotation metadata test failed.'}
$stats=Get-RapZoteroLibraryStatistics -Connector SQLite -DatabasePath $fixture
if($stats.Items -ne 1 -or $stats.Collections -ne 1 -or $stats.Attachments -ne 2){throw 'Library statistics test failed.'}
$rejected=$false;try{Import-Module (Join-Path $connectorRoot 'SQLiteReader.psm1') -Force;Invoke-RapZoteroSqliteRead $fixture 'DELETE FROM items;'|Out-Null}catch{$rejected=$true};if(-not $rejected){throw 'SQLite write rejection test failed.'}
foreach($fixtureFile in @($fixture,"$fixture-wal","$fixture-shm")){if(Test-Path -LiteralPath $fixtureFile){Remove-Item -LiteralPath $fixtureFile -Force}}
Write-Host 'SPR-002 SQLite/sample library/acceptance tests: PASS'
