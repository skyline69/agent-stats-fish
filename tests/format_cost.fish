@test "format cost: standard amount" (
    set -g agent_stats_cost_currency USD
    __agent_stats_format cost 4.27
) = '$4.27'

@test "format cost: large amount rounds to integer" (
    set -g agent_stats_cost_currency USD
    __agent_stats_format cost 847.123
) = '$847'

@test "format cost: very small shows <0.01" (
    set -g agent_stats_cost_currency USD
    __agent_stats_format cost 0.001
) = '<$0.01'

@test "format cost: zero returns empty (status 0)" (
    set -g agent_stats_cost_currency USD
    set -l out (__agent_stats_format cost 0)
    test -z "$out"
    echo $status
) = 0

@test "format cost: EUR currency" (
    set -g agent_stats_cost_currency EUR
    __agent_stats_format cost 3.50
) = '€3.50'

@test "format cost: GBP currency" (
    set -g agent_stats_cost_currency GBP
    __agent_stats_format cost 12.99
) = '£12.99'

@test "format cost: JPY currency" (
    set -g agent_stats_cost_currency JPY
    __agent_stats_format cost 1500
) = '¥1500'

@test "format cost: exactly 100 shows integer" (
    set -g agent_stats_cost_currency USD
    __agent_stats_format cost 100
) = '$100'

@test "format cost: 1.50 shows two decimals" (
    set -g agent_stats_cost_currency USD
    __agent_stats_format cost 1.50
) = '$1.50'
