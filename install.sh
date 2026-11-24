#!/usr/bin/env bash
# Apply Codex configuration from this repo.
# Copies AGENTS.md and the reviewer agent into ~/.codex, and merges config.toml
# (reviewer registration + MCP servers) into ~/.codex/config.toml. Codex owns the
# live config; the merge only adds or overrides the keys listed here.
set -euo pipefail

CODEX_DIR="${CODEX_DIR:-$HOME/.codex}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

copy_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"

  if [ ! -f "$src" ]; then
    echo "!! source missing: $src" >&2
    exit 1
  fi
  if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    echo "    unchanged $(basename "$dest")"
    return
  fi
  if [ -e "$dest" ]; then
    mv "$dest" "$dest.bak.$(date +%s)"
    echo "    backed up existing $(basename "$dest")"
  fi
  cp "$src" "$dest"
  echo "    copied $(basename "$dest")"
}

merge_config_file() {
  if [ ! -d "$HERE/node_modules/smol-toml" ]; then
    npm install --prefix "$HERE" --omit=dev --no-fund --no-audit
  fi
  node "$HERE/scripts/merge_config.mjs" "$HERE/config.toml" "$CODEX_DIR/config.toml"
}

echo "==> Applying Codex config from $HERE -> $CODEX_DIR"
mkdir -p "$CODEX_DIR/agents"

# 1. Global guidance
copy_file "$HERE/AGENTS.md" "$CODEX_DIR/AGENTS.md"

# 2. Reviewer registration + MCP servers (merged, never copied wholesale)
merge_config_file

# 3. Reviewer agent
for agent_file in "$HERE"/agents/*.toml; do
  [ -e "$agent_file" ] || continue
  copy_file "$agent_file" "$CODEX_DIR/agents/$(basename "$agent_file")"
done

echo
echo "==> Done. Installed:"
echo "    $CODEX_DIR/AGENTS.md          <- $HERE/AGENTS.md"
echo "    $CODEX_DIR/agents/*.toml      <- $HERE/agents/*.toml"
echo "    $CODEX_DIR/config.toml        (merged reviewer registration + MCP servers from $HERE/config.toml)"
echo
echo "==> Notes:"
echo "    mobbin runs through mcp-remote: the first time an agent starts it, a browser opens"
echo "    for the Mobbin login; the token is then shared by every agent via ~/.mcp-auth."
echo "    Nothing is linked: re-run this script after editing files here."
echo
echo "==> Verify with:"
echo "    codex mcp list"
