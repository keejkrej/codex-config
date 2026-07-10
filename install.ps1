# Apply Codex configuration from this repo (Windows / PowerShell).
# Links the global AGENTS.md guidance, config.toml, and custom agent TOML
# files into ~/.codex so the main thread orchestrates Codex subagents.
[CmdletBinding()]
param(
  [string]$CodexDir = (Join-Path $HOME ".codex")
)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot

function Link-File($Src, $Dest) {
  $destParent = Split-Path -Parent $Dest
  if (-not (Test-Path $destParent)) { New-Item -ItemType Directory -Path $destParent -Force | Out-Null }

  if (Test-Path $Dest) {
    $item = Get-Item $Dest -Force
    if ($item.LinkType -ne "SymbolicLink") {
      $backup = "$Dest.bak.$([int][double]::Parse((Get-Date -UFormat %s)))"
      Move-Item $Dest $backup -Force
      Write-Host "    backed up existing $(Split-Path -Leaf $Dest)"
    }
  }

  try {
    New-Item -ItemType SymbolicLink -Path $Dest -Value $Src -ErrorAction Stop | Out-Null
  } catch {
    Copy-Item $Src $Dest -Force
  }
  Write-Host "    linked $(Split-Path -Leaf $Dest)"
}

Write-Host "==> Applying Codex config from $Here -> $CodexDir"
foreach ($d in @($CodexDir, (Join-Path $CodexDir "agents"))) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# 1. Global guidance: symlink AGENTS.md and config.toml into ~/.codex
Link-File (Join-Path $Here "AGENTS.md")   (Join-Path $CodexDir "AGENTS.md")
Link-File (Join-Path $Here "config.toml") (Join-Path $CodexDir "config.toml")

# 2. Custom agent TOML files: symlink each into ~/.codex/agents/
$agentsDir = Join-Path $Here "agents"
if (Test-Path $agentsDir) {
  Get-ChildItem -Path $agentsDir -Filter *.toml | ForEach-Object {
    Link-File $_.FullName (Join-Path $CodexDir "agents" $_.Name)
  }
}

Write-Host ""
Write-Host "==> Done. Configuration applied:"
Write-Host "    ~/.codex/AGENTS.md          -> $Here\AGENTS.md"
Write-Host "    ~/.codex/config.toml        -> $Here\config.toml"
Write-Host "    ~/.codex/agents/*.toml      -> $Here\agents\*.toml"
Write-Host ""
Write-Host "==> Verify with:"
Write-Host "    codex --ask-for-approval never 'Summarize the current instructions.'"
Write-Host "    codex --ask-for-approval never 'List the custom agents you have loaded.'"
