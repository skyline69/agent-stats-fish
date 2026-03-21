# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fish shell plugin that displays usage stats for Claude Code, OpenAI Codex, and Google Gemini CLI. Three display modes: right-prompt (minimal), compact (one-line), and detailed (daily breakdown). Installed via Fisher.

## Development Commands

```fish
fisher install .          # Install from local clone
agent-stats refresh       # Clear cache and re-fetch (tests fresh fetch path)
agent-stats -d            # Detailed mode (tests all formatting)
rm /tmp/agent_stats_cache_*  # Force cold cache for testing first-run path
```

No test suite exists. Manual testing against real provider data.

## Architecture

Four-layer design: **CLI → Cache → Providers → Formatters**

### Layer 1: CLI (`functions/agent-stats.fish`)
Entry point. Parses flags/subcommands (enable, disable, providers, refresh, -d, -h), validates input, iterates enabled providers calling the cache layer.

### Layer 2: Cache (`functions/__agent_stats_cache.fish`)
Three-path caching with files at `/tmp/agent_stats_cache_{provider}_{mode}`:
- **Fresh** (age < TTL): return cached data immediately
- **Stale** (age ≥ TTL): return stale data + background refresh via `__agent_stats_cache_refresh`
- **Missing**: synchronous fetch with "Fetching..." loading message, SIGINT handler for clean Ctrl+C

### Layer 3: Providers (`functions/__agent_stats_{claude,codex,gemini}.fish`)
Each provider function accepts a mode argument (`prompt`, `compact`, `detailed`) and dispatches internally. They parse local JSON/JSONL files from each agent's data directory — no API keys needed (Claude has an optional OAuth fallback).

### Layer 4: Formatters
- `__agent_stats_bar` — 10-char progress bar (█/░) with color
- `__agent_stats_usage_color` — green <50%, yellow 50-79%, red ≥80%
- `__agent_stats_format` — token formatting (1.2M, 45.3K, 892) and comma-separated numbers
- `__agent_stats_reset_fmt` — relative duration from timestamps (2h 15m)
- `__agent_stats_prompt` — right-prompt rendering with icons from `$agent_stats_icons`

### Right Prompt
`fish_right_prompt.fish` calls `__agent_stats_prompt`, which uses the same cache layer but with a shorter TTL (30s default vs 300s).

### Init
`conf.d/agent_stats.fish` sets default universal variables, checks for jq dependency, and defines Fisher install/uninstall event handlers.

## Conventions

- All internal functions are prefixed with `__agent_stats_`.
- Provider icons default to Nerd Font glyphs: `claude= codex=⬡ gemini=󰫣`.
- Cache TTLs are universal variables: `$agent_stats_cache_ttl` (300s) and `$agent_stats_prompt_cache_ttl` (30s).
- Output goes to stdout; loading/error messages go to stderr.
- jq is the sole dependency for JSON parsing.
