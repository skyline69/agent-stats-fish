@test "format number: zero" (
    __agent_stats_format number 0
) = 0

@test "format number: null" (
    __agent_stats_format number null
) = 0

@test "format number: empty" (
    __agent_stats_format number ""
) = 0

@test "format number: small" (
    __agent_stats_format number 42
) = 42

@test "format number: thousands" (
    __agent_stats_format number 12435
) = 12,435

@test "format number: millions" (
    __agent_stats_format number 1234567
) = 1,234,567
