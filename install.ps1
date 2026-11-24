# Apply Codex configuration from this repo (Windows / PowerShell).
# Copies AGENTS.md and the reviewer agent into ~/.codex, and merges config.toml
# (reviewer registration + MCP servers) into ~/.codex/config.toml. Codex owns the
# live config; the merge only adds or overrides the keys listed here.
[CmdletBinding()]
param(
  [string]$CodexDir = (Join-Path $HOME ".codex")
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$Here = $PSScriptRoot

function Copy-File($Src, $Dest) {
  $destParent = Split-Path -Parent $Dest
  if (-not (Test-Path $destParent)) { New-Item -ItemType Directory -Path $destParent -Force | Out-Null }

  if (-not (Test-Path $Src)) {
    Write-Host "!! source missing: $Src" -ForegroundColor Red
    throw "source path does not exist: $Src"
  }
  $leaf = Split-Path -Leaf $Dest
  if (Test-Path $Dest) {
    if ((Get-FileHash $Src).Hash -eq (Get-FileHash $Dest).Hash) {
      Write-Host "    unchanged $leaf"
      return
    }
    $backup = "$Dest.bak.$([int][double]::Parse((Get-Date -UFormat %s)))"
    Move-Item $Dest $backup -Force
    Write-Host "    backed up existing $leaf"
  }
  Copy-Item $Src $Dest -Force
  Write-Host "    copied $leaf"
}

function Merge-ConfigFile($Essentials, $Dest) {
  $modules = Join-Path $Here "node_modules/smol-toml"
  if (-not (Test-Path $modules)) {
    & npm install --prefix $Here --omit=dev --no-fund --no-audit
    if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
  }
  $mergeScript = Join-Path $Here "scripts/merge_config.mjs"
  & node $mergeScript $Essentials $Dest
  if ($LASTEXITCODE -ne 0) { throw "merge_config.mjs failed" }
}

Write-Host "==> Applying Codex config from $Here -> $CodexDir"
foreach ($d in @($CodexDir, (Join-Path $CodexDir "agents"))) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# 1. Global guidance
Copy-File (Join-Path $Here "AGENTS.md") (Join-Path $CodexDir "AGENTS.md")

# 2. Reviewer registration + MCP servers (merged, never copied wholesale)
Merge-ConfigFile (Join-Path $Here "config.toml") (Join-Path $CodexDir "config.toml")

# 3. Reviewer agent
$agentsDir = Join-Path $Here "agents"
if (Test-Path $agentsDir) {
  Get-ChildItem -Path $agentsDir -Filter *.toml | ForEach-Object {
    Copy-File $_.FullName (Join-Path $CodexDir "agents\$($_.Name)")
  }
}

Write-Host ""
Write-Host "==> Done. Installed:"
Write-Host "    $CodexDir\AGENTS.md          <- $Here\AGENTS.md"
Write-Host "    $CodexDir\agents\*.toml      <- $Here\agents"
Write-Host "    $CodexDir\config.toml        (merged reviewer registration + MCP servers from $Here\config.toml)"
Write-Host ""
Write-Host "==> Notes:"
Write-Host "    mobbin runs through mcp-remote: the first time an agent starts it, a browser opens"
Write-Host "    for the Mobbin login; the token is then shared by every agent via ~/.mcp-auth."
Write-Host "    Nothing is linked: re-run this script after editing files here."
Write-Host ""
Write-Host "==> Verify with:"
Write-Host "    codex mcp list"
