@test "bar: 0% is all empty" (
    __agent_stats_bar 0 | string replace -ra '\e\[[^m]*m' ''
) = "░░░░░░░░░░"

@test "bar: 100% is all filled" (
    __agent_stats_bar 100 | string replace -ra '\e\[[^m]*m' ''
) = "██████████"

@test "bar: 50% is half filled" (
    __agent_stats_bar 50 | string replace -ra '\e\[[^m]*m' ''
) = "█████░░░░░"

@test "bar: 25% rounds to 3 filled" (
    __agent_stats_bar 25 | string replace -ra '\e\[[^m]*m' ''
) = "███░░░░░░░"

@test "bar: null treated as 0%" (
    __agent_stats_bar null | string replace -ra '\e\[[^m]*m' ''
) = "░░░░░░░░░░"

@test "bar: empty treated as 0%" (
    __agent_stats_bar "" | string replace -ra '\e\[[^m]*m' ''
) = "░░░░░░░░░░"
