#!/usr/bin/env bash
# Apply Codex configuration from this repo.
# Links AGENTS.md and custom agent TOML into ~/.codex, and merges orchestration
# essentials from config.toml into ~/.codex/config.toml (Codex owns the rest).
set -euo pipefail

CODEX_DIR="${CODEX_DIR:-$HOME/.codex}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Applying Codex config from $HERE -> $CODEX_DIR"
mkdir -p "$CODEX_DIR" "$CODEX_DIR/agents"

# 1. Global guidance: symlink AGENTS.md into ~/.codex
link_file() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.bak.$(date +%s)"
    echo "    backed up existing $(basename "$dest")"
  fi
  ln -sf "$src" "$dest"
  echo "    linked $(basename "$dest")"
}

merge_config_file() {
  if [ ! -d "$HERE/node_modules/smol-toml" ]; then
    npm install --prefix "$HERE" --omit=dev --no-fund --no-audit
  fi
  node "$HERE/scripts/merge_config.mjs" "$HERE/config.toml" "$CODEX_DIR/config.toml"
}

link_file "$HERE/AGENTS.md" "$CODEX_DIR/AGENTS.md"
merge_config_file

# 2. Custom agent TOML files: symlink each into ~/.codex/agents/
for agent_file in "$HERE"/agents/*.toml; do
  [ -e "$agent_file" ] || continue
  name="$(basename "$agent_file")"
  link_file "$agent_file" "$CODEX_DIR/agents/$name"
done

echo
echo "==> Done. Configuration applied:"
echo "    ~/.codex/AGENTS.md          -> $HERE/AGENTS.md"
echo "    ~/.codex/config.toml        (merged orchestration essentials from $HERE/config.toml)"
echo "    ~/.codex/agents/*.toml      -> $HERE/agents/*.toml"
echo
echo "==> Verify with:"
echo "    codex --ask-for-approval never 'Summarize the current instructions.'"
echo "    codex --ask-for-approval never 'List the custom agents you have loaded.'"
