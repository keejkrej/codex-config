# Apply Codex configuration from this repo (Windows / PowerShell).
# Links AGENTS.md and custom agent TOML into ~/.codex, and merges orchestration
# essentials from config.toml into ~/.codex/config.toml (Codex owns the rest).
[CmdletBinding()]
param(
  [string]$CodexDir = (Join-Path $HOME ".codex"),
  [switch]$NoElevate
)

# ---------------------------------------------------------------------------
# Self-elevation: if not running as admin, relaunch with -Verb RunAs (UAC
# prompt). If the user denies the UAC prompt, continue non-elevated and fall
# back to copy mode for symlinks.
# ---------------------------------------------------------------------------
if (-not $NoElevate) {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = (Get-Process -Id $PID).Path
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($PSBoundParameters.ContainsKey("CodexDir")) {
      $psi.Arguments += " -CodexDir `"$CodexDir`""
    }
    $psi.Verb = "RunAs"
    $psi.UseShellExecute = $true
    $psi.WorkingDirectory = $PSScriptRoot
    try {
      $proc = [System.Diagnostics.Process]::Start($psi)
      $proc.WaitForExit()
      exit $proc.ExitCode
    } catch {
      Write-Host "!! UAC denied or unavailable ($($_.Exception.Message)); continuing non-elevated (symlinks will fall back to copies)." -ForegroundColor Yellow
    }
  }
}

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot

function Merge-ConfigFile($Essentials, $Dest) {
  $modules = Join-Path $Here "node_modules/smol-toml"
  if (-not (Test-Path $modules)) {
    npm install --prefix $Here --omit=dev --no-fund --no-audit
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  $mergeScript = Join-Path $Here "scripts/merge_config.mjs"
  & node $mergeScript $Essentials $Dest
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Link-File($Src, $Dest) {
  $destParent = Split-Path -Parent $Dest
  if (-not (Test-Path $destParent)) { New-Item -ItemType Directory -Path $destParent -Force | Out-Null }

  $srcFull = (Resolve-Path $Src).Path
  if (Test-Path $Dest) {
    $item = Get-Item $Dest -Force
    if ($item.LinkType -eq "SymbolicLink") {
      $target = if ($item.Target -is [array]) { $item.Target[0] } else { $item.Target }
      # Resolve relative link targets against the dest directory
      if (-not [System.IO.Path]::IsPathRooted($target)) {
        $target = [System.IO.Path]::GetFullPath((Join-Path $destParent $target))
      }
      if ([string]::Equals($target, $srcFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "    already linked $(Split-Path -Leaf $Dest)"
        return
      }
      # Wrong target: remove so we can recreate
      Remove-Item $Dest -Force
    } else {
      $backup = "$Dest.bak.$([int][double]::Parse((Get-Date -UFormat %s)))"
      Move-Item $Dest $backup -Force
      Write-Host "    backed up existing $(Split-Path -Leaf $Dest)"
    }
  }

  try {
    New-Item -ItemType SymbolicLink -Path $Dest -Value $srcFull -ErrorAction Stop | Out-Null
  } catch {
    # Symlink creation failed (e.g. no admin / Developer Mode). Fall back to a real copy.
    try {
      if (Test-Path $Dest) { Remove-Item $Dest -Force -ErrorAction Stop }
      Copy-Item $srcFull $Dest -Force -ErrorAction Stop
    } catch {
      Write-Host "!! failed to link or copy $(Split-Path -Leaf $Dest): $($_.Exception.Message)" -ForegroundColor Red
      Write-Host "   Close any app holding the file (Codex, editors) and re-run with -NoElevate if needed." -ForegroundColor Yellow
      throw
    }
  }
  Write-Host "    linked $(Split-Path -Leaf $Dest)"
}

Write-Host "==> Applying Codex config from $Here -> $CodexDir"
foreach ($d in @($CodexDir, (Join-Path $CodexDir "agents"))) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# 1. Global guidance: symlink AGENTS.md; merge orchestration essentials
Link-File (Join-Path $Here "AGENTS.md") (Join-Path $CodexDir "AGENTS.md")
Merge-ConfigFile (Join-Path $Here "config.toml") (Join-Path $CodexDir "config.toml")

# 2. Custom agent TOML files: symlink each into ~/.codex/agents/
$agentsDir = Join-Path $Here "agents"
if (Test-Path $agentsDir) {
  $codexAgents = Join-Path $CodexDir "agents"
  Get-ChildItem -Path $agentsDir -Filter *.toml | ForEach-Object {
    Link-File $_.FullName (Join-Path $codexAgents $_.Name)
  }
}

Write-Host ""
Write-Host "==> Done. Configuration applied:"
Write-Host "    ~/.codex/AGENTS.md          -> $Here\AGENTS.md"
Write-Host "    ~/.codex/config.toml        (merged orchestration essentials from $Here\config.toml)"
Write-Host "    ~/.codex/agents/*.toml      -> $Here\agents\*.toml"
Write-Host ""
Write-Host "==> Verify with:"
Write-Host "    codex --ask-for-approval never 'Summarize the current instructions.'"
Write-Host "    codex --ask-for-approval never 'List the custom agents you have loaded.'"
