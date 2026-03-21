function __agent_stats_cost --description "Calculate token cost for a provider/model"
    # Usage: __agent_stats_cost <provider> <model> <input> <output> <cache> [think]
    # Returns cost as a decimal number (e.g. "4.27") or empty if no rates configured

    if test (count $agent_stats_cost_rates) -eq 0
        return 1
    end

    set -l provider $argv[1]
    set -l model $argv[2]
    set -l input_tokens (test -n "$argv[3]"; and echo $argv[3]; or echo 0)
    set -l output_tokens (test -n "$argv[4]"; and echo $argv[4]; or echo 0)
    set -l cache_tokens (test -n "$argv[5]"; and echo $argv[5]; or echo 0)
    set -l think_tokens (test -n "$argv[6]"; and echo $argv[6]; or echo 0)

    set -l rate_in 0
    set -l rate_out 0
    set -l rate_cache 0
    set -l rate_think 0
    set -l found false

    # Look up rates: exact match first, then prefix match
    for entry in $agent_stats_cost_rates
        set -l kv (string split "=" $entry)
        test (count $kv) -ne 2; and continue
        set -l key $kv[1]
        set -l rate $kv[2]
        set -l parts (string split ":" $key)
        test (count $parts) -ne 3; and continue

        set -l e_provider $parts[1]
        set -l e_model $parts[2]
        set -l e_type $parts[3]

        # Provider must match exactly
        test "$e_provider" != "$provider"; and continue

        # Model: exact match or prefix match (config model is prefix of data model)
        if test "$e_model" != "$model"
            if not string match -q "$e_model*" -- "$model"
                continue
            end
        end

        set found true
        switch $e_type
            case in
                set rate_in $rate
            case out
                set rate_out $rate
            case cache
                set rate_cache $rate
            case think
                set rate_think $rate
        end
    end

    if test "$found" = false
        return 1
    end

    # Calculate: (tokens * rate_per_mtok) / 1,000,000
    set -l cost (math "$input_tokens * $rate_in / 1000000 + $output_tokens * $rate_out / 1000000 + $cache_tokens * $rate_cache / 1000000 + $think_tokens * $rate_think / 1000000")

    echo $cost
end
