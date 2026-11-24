# codex-config

Portable config for [Codex CLI](https://github.com/openai/codex), copied into `~/.codex/`.

## Files

| File | Purpose | Installed as |
| --- | --- | --- |
| `AGENTS.md` | Global instructions for every session: the Ambient memory block plus a short "review before done" rule | `~/.codex/AGENTS.md` |
| `config.toml` | Essentials merged into the live config: `multi_agent` on, the `reviewer` agent registration, and the MCP servers (paper, ambient, mobbin through `mcp-remote`, browse) | merged into `~/.codex/config.toml` |
| `agents/reviewer.toml` | `reviewer` agent: an independent, read-only code reviewer with the same brief as the other agents' reviewers | `~/.codex/agents/reviewer.toml` |
| `scripts/merge_config.mjs` | Deep-merges `config.toml` into `~/.codex/config.toml` and backs up the live file first; needs `npm install` in this folder | not installed |

Nothing is linked. `install.sh` (Git Bash, macOS, Linux) and `install.ps1` (PowerShell) copy the
files and back up anything they replace as `*.bak.<timestamp>`; re-run the installer after editing.
Codex owns `~/.codex/config.toml` and rewrites it itself, so that one file is merged key by key
rather than copied; keys it holds that are not listed here are left alone, so a key this repo stops
setting has to be removed from the live file by hand.

## New machine

Run `./install.sh` or `./install.ps1`. Both need Node.js for the TOML merge.

The `paper` server runs the `paper` CLI that Paper Desktop installs into `~/.paper/bin`; add that
directory to `PATH` (on Windows: `%USERPROFILE%\.paper\bin` in the user `Path`).
The `browse` server runs the `browse` CLI from `~/.local/bin`; keep that directory on `PATH`
(on Windows: `%USERPROFILE%\.local\bin`) and install the browse extension in your Chrome-family browser.

`mobbin` runs through [`mcp-remote`](https://github.com/geelen/mcp-remote). The first time an agent
starts it, a browser opens for the Mobbin login (Pro/Team/Enterprise plan required). The token is
stored once in `~/.mcp-auth` and shared by every agent that starts the same `mcp-remote` command,
so there is no `codex mcp login`. On Windows, `npx` must resolve to a real executable (mise shims
do this); npm's own `npx.cmd` cannot be spawned without a shell, and the documented workaround is
`cmd /c npx -y mcp-remote …`.

Check everything with `codex mcp list`.

## Reviewer

`reviewer` is a Codex agent that inherits the session model (high reasoning, `read-only` sandbox)
and that the main thread
spawns with `spawn_agent`; its prompt tells it to report, never fix. The read-only sandbox blocks
build artifacts, so switch `sandbox_mode` to `workspace-write` if you want it to run test suites
that need to write. `AGENTS.md` asks the main thread to run it on the diff before reporting any
non-trivial change done. If a custom agent name ever matches a built-in one, the custom agent wins.

## Ambient memory

The `ambient` server is the MCP endpoint inside the running [Ambient](https://alexandria.so)
desktop app (`http://127.0.0.1:8765/mcp`); its tools are unavailable when the app is closed.

`AGENTS.md` carries the same "always check Ambient memory" block Ambient writes into this file
itself, with the same `ambient-memory:begin/end` markers, so Ambient keeps managing it. The
Ambient app also installs a Codex plugin that provides the same MCP server; if that plugin stays
enabled you may see the ambient server twice in `codex mcp list`, so disable one of the two routes.
