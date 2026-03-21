@test "format tokens: zero" (
    __agent_stats_format tokens 0
) = 0

@test "format tokens: null string" (
    __agent_stats_format tokens null
) = 0

@test "format tokens: empty" (
    __agent_stats_format tokens ""
) = 0

@test "format tokens: small number" (
    __agent_stats_format tokens 892
) = 892

@test "format tokens: exactly 1000" (
    __agent_stats_format tokens 1000
) = 1K

@test "format tokens: thousands with decimal" (
    __agent_stats_format tokens 45300
) = 45.3K

@test "format tokens: thousands no decimal" (
    __agent_stats_format tokens 12000
) = 12K

@test "format tokens: exactly 1M" (
    __agent_stats_format tokens 1000000
) = 1M

@test "format tokens: millions with decimal" (
    __agent_stats_format tokens 2100000
) = 2.1M

@test "format tokens: millions no decimal" (
    __agent_stats_format tokens 5000000
) = 5M

@test "format tokens: large millions" (
    __agent_stats_format tokens 66900000
) = 66.9M

@test "format tokens: just under 1K" (
    __agent_stats_format tokens 999
) = 999

@test "format tokens: just under 1M" (
    __agent_stats_format tokens 999000
) = 999K

@test "format tokens: 1500 shows 1.5K" (
    __agent_stats_format tokens 1500
) = 1.5K
