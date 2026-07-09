#!/usr/bin/env bash
# Apply Codex configuration from this repo.
# Links the global AGENTS.md guidance, config.toml, and custom agent TOML
# files into ~/.codex so the main thread orchestrates Codex subagents.
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

link_file "$HERE/AGENTS.md"   "$CODEX_DIR/AGENTS.md"
link_file "$HERE/config.toml" "$CODEX_DIR/config.toml"

# 2. Custom agent TOML files: symlink each into ~/.codex/agents/
for agent_file in "$HERE"/agents/*.toml; do
  [ -e "$agent_file" ] || continue
  name="$(basename "$agent_file")"
  link_file "$agent_file" "$CODEX_DIR/agents/$name"
done

echo
echo "==> Done. Configuration applied:"
echo "    ~/.codex/AGENTS.md          -> $HERE/AGENTS.md"
echo "    ~/.codex/config.toml        -> $HERE/config.toml"
echo "    ~/.codex/agents/*.toml      -> $HERE/agents/*.toml"
echo
echo "==> Verify with:"
echo "    codex --ask-for-approval never 'Summarize the current instructions.'"
echo "    codex --ask-for-approval never 'List the custom agents you have loaded.'"
