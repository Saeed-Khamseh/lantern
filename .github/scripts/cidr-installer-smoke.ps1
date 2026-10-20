param(
  [Parameter(Mandatory=$true)][string]$InstallerPath,
  [Parameter(Mandatory=$true)][string]$CliPath
)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') {
  throw 'This installer smoke test may run only on a GitHub-hosted Windows runner.'
}
$installer = (Resolve-Path -LiteralPath $InstallerPath).Path
$cli = (Resolve-Path -LiteralPath $CliPath).Path
$installLog = Join-Path $env:RUNNER_TEMP 'lantern-cidr-install.log'
$setup = Start-Process -FilePath $installer -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
  '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=$installLog"
)
if ($setup.ExitCode -ne 0) { throw "Installer exited with $($setup.ExitCode); see $installLog" }
$ready = $false
for ($attempt = 0; $attempt -lt 40; $attempt++) {
  & $cli split-tunnel list *> $null
  if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  Start-Sleep -Milliseconds 500
}
if (-not $ready) { throw 'Installed daemon did not become ready.' }
foreach ($cidr in '127.0.0.1/8', '::1/128', '2001:db8::abcd/32') {
  & $cli split-tunnel add --type ip-cidr --value $cidr
  if ($LASTEXITCODE -ne 0) { throw "Could not add $cidr through installed IPC." }
}
& $cli split-tunnel add --type ip-cidr --value '10.0.0.0/33' *> $null
if ($LASTEXITCODE -eq 0) { throw 'Installed daemon accepted an invalid CIDR.' }
Restart-Service -Name LanternSvc
$ready = $false
for ($attempt = 0; $attempt -lt 40; $attempt++) {
  $items = & $cli split-tunnel list 2>&1 | Out-String
  if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  Start-Sleep -Milliseconds 500
}
if (-not $ready) { throw 'Daemon did not restart.' }
foreach ($cidr in '127.0.0.0/8', '::1/128', '2001:db8::/32') {
  if (-not $items.Contains($cidr)) { throw "Persisted CIDR missing after service restart: $cidr" }
}
& $cli split-tunnel remove --type ip-cidr --value '::1/128'
if ($LASTEXITCODE -ne 0) { throw 'Could not remove a persisted IPv6 CIDR.' }
$items = & $cli split-tunnel list | Out-String
if ($items.Contains('::1/128')) { throw 'Removed CIDR is still returned by the installed daemon.' }
$app = Start-Process -FilePath 'C:\Program Files\Lantern\lantern.exe' -WindowStyle Hidden -PassThru
try {
  Start-Sleep -Seconds 8
  $app.Refresh()
  if ($app.HasExited) { throw "Windows UI exited during startup: $($app.ExitCode)" }
} finally {
  if (-not $app.HasExited) { Stop-Process -Id $app.Id -Force }
}
Write-Output 'Installer, native IPC, CIDR persistence and Windows UI startup checks passed.'
