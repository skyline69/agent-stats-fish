# Completions for agent-stats

# Subcommands (only when no subcommand given yet)
complete -c agent-stats -f -n __fish_use_subcommand -a enable -d "Enable a provider"
complete -c agent-stats -f -n __fish_use_subcommand -a disable -d "Disable a provider"
complete -c agent-stats -f -n __fish_use_subcommand -a providers -d "List enabled providers"
complete -c agent-stats -f -n __fish_use_subcommand -a refresh -d "Clear cache and re-display"
complete -c agent-stats -f -n __fish_use_subcommand -a cost -d "Show estimated API costs"

# Flags
complete -c agent-stats -f -n __fish_use_subcommand -s d -l detailed -d "Show detailed stats"
complete -c agent-stats -f -n __fish_use_subcommand -s h -l help -d "Show help"

# Provider names for enable (all available)
complete -c agent-stats -f -n "__fish_seen_subcommand_from enable" -a "claude codex gemini" -d "Provider"

# Provider names for cost (only enabled ones)
complete -c agent-stats -f -n "__fish_seen_subcommand_from cost" -a "(printf '%s\n' $agent_stats_providers)" -d "Provider"

# Provider names for disable (only enabled ones)
complete -c agent-stats -f -n "__fish_seen_subcommand_from disable" -a "(printf '%s\n' $agent_stats_providers)" -d "Provider"
