function fish_right_prompt
    # When Tide is active, it renders agent_stats via _tide_item_agent_stats.
    # Skip here to avoid duplicate output (e.g. after fisher update re-sources this file).
    functions -q _tide_print_item; and return
    __agent_stats_prompt
end
