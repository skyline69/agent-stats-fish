@test "usage_color: low usage is green (32)" (
    set -g agent_stats_alert_threshold 80
    __agent_stats_usage_color 30 | string match -rq '32'
    echo $status
) = 0

@test "usage_color: medium usage is bright yellow (93)" (
    set -g agent_stats_alert_threshold 80
    __agent_stats_usage_color 50 | string match -rq '93'
    echo $status
) = 0

@test "usage_color: high usage is bright red (91)" (
    set -g agent_stats_alert_threshold 80
    __agent_stats_usage_color 85 | string match -rq '91'
    echo $status
) = 0

@test "usage_color: exactly at threshold is red" (
    set -g agent_stats_alert_threshold 80
    __agent_stats_usage_color 80 | string match -rq '91'
    echo $status
) = 0

@test "usage_color: 49% is green not yellow" (
    set -g agent_stats_alert_threshold 80
    __agent_stats_usage_color 49 | string match -rq '32'
    echo $status
) = 0
