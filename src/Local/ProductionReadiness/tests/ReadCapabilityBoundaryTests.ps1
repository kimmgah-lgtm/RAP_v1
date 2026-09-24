. (Join-Path $PSScriptRoot 'TestHarness.ps1')
$script:N=0;function A([string]$id,[bool]$ok,[string]$m){$script:N++;if(!$ok){throw "$id failed: $m"};Write-Host "$id PASS $m"}
$snapshot=New-RapPrActual;$safe=New-RapPrProbe Zotero $snapshot
A A ((Invoke-RapExternalReadProbe $safe).Status-eq'PASS') 'normal sealed GET/read probe passes'
$script:mutations=0;$message=Get-RapPrThrown {New-RapExternalReadAdapter -System Zotero -Endpoint 'https://api.zotero.org/' -CredentialEnvironmentVariable RAP_TEST_CREDENTIAL -ResourcePath 'users/1/items?limit=1' -ReadProbe {$script:mutations++}}
A B ($message-match'parameter.*ReadProbe'-and$script:mutations-eq0) 'callback write attempt cannot bind or execute'
$safe.AllowedMethod='POST';$safe.ProductionWrite='ENABLED';$result=Invoke-RapExternalReadProbe $safe
A C ($result.Status-eq'PASS'-and$script:mutations-eq0) 'forged metadata cannot change sealed capability'
$script:nestedMutationCount=0;$nestedCallback={& {$script:nestedMutationCount++}};$message=Get-RapPrThrown {New-RapExternalReadAdapter -System GoogleDrive -Endpoint 'https://www.googleapis.com/' -CredentialEnvironmentVariable RAP_TEST_CREDENTIAL -ResourcePath 'drive/v3/about' -ReadProbe $nestedCallback}
A D ($message-match'parameter.*ReadProbe'-and$script:nestedMutationCount-eq0) 'indirect nested write callback cannot enter boundary'
$fake=[pscustomobject]@{PSTypeName='Rap.ReadOnlyCapabilityToken';CapabilityId=('a'*64);System='Zotero';AllowedMethod='GET';ProductionWrite='DISABLED'}
A E ((Get-RapPrThrown {Invoke-RapExternalReadProbe $fake})-match'UNTRUSTED_ADAPTER') 'forged adapter capability rejected'
$failure=New-RapFixtureReadAdapter Zotero $null EXTERNAL_FAILURE;$first=Invoke-RapExternalReadProbe $failure;$second=Invoke-RapExternalReadProbe $failure
A F ($first.Status-eq'EXTERNAL_FAILURE'-and$second.Status-eq'EXTERNAL_FAILURE'-and$script:mutations-eq0) 'exception and retry expose no write capability'
$command=Get-Command New-RapExternalReadAdapter;$tokenProperties=@($safe.PSObject.Properties.Name)
A G (-not$command.Parameters.ContainsKey('ReadProbe')-and'ReadProbe'-notin$tokenProperties-and'Write'-notin$tokenProperties-and$script:mutations-eq0) 'ReadProbe callback cannot obtain or invoke mutation capability; production mutations 0/0/0'
if($script:N-ne7){throw "Expected 7 boundary assertions, got $script:N"};Write-Host "SPR-012 Turn-C read capability boundary: A-G 7/7 PASS; production mutations: 0/0/0"
