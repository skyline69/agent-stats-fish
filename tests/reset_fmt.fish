@test "reset_fmt: empty returns nothing" (
    set -l out (__agent_stats_reset_fmt "")
    test -z "$out"
    echo $status
) = 0

@test "reset_fmt: null returns nothing" (
    set -l out (__agent_stats_reset_fmt null)
    test -z "$out"
    echo $status
) = 0

@test "reset_fmt: 30 minutes" (
    set -l now (date +%s)
    echo (__agent_stats_reset_fmt (math "$now + 1800"))
) = 30m

@test "reset_fmt: 2 hours 5 minutes" (
    set -l now (date +%s)
    echo (__agent_stats_reset_fmt (math "$now + 7500"))
) = "2h 5m"

@test "reset_fmt: exact 2 hours" (
    set -l now (date +%s)
    echo (__agent_stats_reset_fmt (math "$now + 7200"))
) = 2h

@test "reset_fmt: 2 days 2 hours" (
    set -l now (date +%s)
    echo (__agent_stats_reset_fmt (math "$now + 180000"))
) = "2d 2h"

@test "reset_fmt: exact 2 days" (
    set -l now (date +%s)
    echo (__agent_stats_reset_fmt (math "$now + 172800"))
) = 2d

@test "reset_fmt: past timestamp returns nothing" (
    set -l now (date +%s)
    set -l out (__agent_stats_reset_fmt (math "$now - 3600"))
    test -z "$out"
    echo $status
) = 0

@test "reset_fmt: 1 minute" (
    set -l now (date +%s)
    echo (__agent_stats_reset_fmt (math "$now + 30"))
) = 1m
