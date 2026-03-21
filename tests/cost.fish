@test "cost: returns 1 when no rates configured" (
    set -e agent_stats_cost_rates
    __agent_stats_cost claude sonnet-4 1000000 500000 0
    echo $status
) = 1

@test "cost: basic input+output calculation" (
    set -g agent_stats_cost_rates claude:sonnet-4:in=3 claude:sonnet-4:out=15
    # 1M input * 3/MTok + 500K output * 15/MTok = 3 + 7.5 = 10.5
    __agent_stats_cost claude sonnet-4 1000000 500000 0
) = 10.5

@test "cost: with cache tokens" (
    set -g agent_stats_cost_rates claude:sonnet-4:in=3 claude:sonnet-4:out=15 claude:sonnet-4:cache=0.3
    # 1M in * 3 + 0 out + 2M cache * 0.3 = 3 + 0.6 = 3.6
    __agent_stats_cost claude sonnet-4 1000000 0 2000000
) = 3.6

@test "cost: prefix matching works" (
    set -g agent_stats_cost_rates claude:sonnet-4:in=3 claude:sonnet-4:out=15
    # Model "sonnet-4-5-20250929" should match prefix "sonnet-4"
    __agent_stats_cost claude sonnet-4-5-20250929 1000000 0 0
) = 3

@test "cost: narrower prefix overrides broader" (
    set -g agent_stats_cost_rates claude:opus-4:in=15 claude:opus-4:out=75 claude:opus-4-5:in=5 claude:opus-4-5:out=25
    # Model "opus-4-5" matches both "opus-4" and "opus-4-5", narrower wins (last match)
    __agent_stats_cost claude opus-4-5 1000000 0 0
) = 5

@test "cost: wrong provider returns 1" (
    set -g agent_stats_cost_rates claude:sonnet-4:in=3
    __agent_stats_cost codex sonnet-4 1000000 0 0
    echo $status
) = 1

@test "cost: unknown model returns 1" (
    set -g agent_stats_cost_rates claude:sonnet-4:in=3
    __agent_stats_cost claude unknown-model 1000000 0 0
    echo $status
) = 1

@test "cost: with thinking tokens" (
    set -g agent_stats_cost_rates codex:o3:in=2 codex:o3:out=8 codex:o3:think=8
    # 1M in * 2 + 1M out * 8 + 500K think * 8 = 2 + 8 + 4 = 14
    __agent_stats_cost codex o3 1000000 1000000 0 500000
) = 14

@test "cost: zero tokens returns 0" (
    set -g agent_stats_cost_rates claude:sonnet-4:in=3 claude:sonnet-4:out=15
    __agent_stats_cost claude sonnet-4 0 0 0
) = 0
