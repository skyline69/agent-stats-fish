function _tide_item_agent_stats --description "Tide right-prompt item for agent-stats"
    set -l output (__agent_stats_prompt)
    test -n "$output"; and _tide_print_item agent_stats (set_color --dim)' │ '(set_color normal)$output
end
