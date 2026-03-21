@test "auth: unknown provider returns unknown" (
    set -e __agent_stats_auth_foobar
    __agent_stats_auth foobar
) = unknown

@test "auth: codex with OPENAI_API_KEY returns apikey" (
    set -e __agent_stats_auth_codex
    set -gx OPENAI_API_KEY "test-key-123"
    set -l result (__agent_stats_auth codex)
    set -e OPENAI_API_KEY
    echo $result
) = apikey

@test "auth: gemini with GEMINI_API_KEY returns apikey" (
    set -e __agent_stats_auth_gemini
    set -gx GEMINI_API_KEY "test-key-123"
    set -l result (__agent_stats_auth gemini)
    set -e GEMINI_API_KEY
    echo $result
) = apikey

@test "auth: gemini with GOOGLE_API_KEY returns apikey" (
    set -e __agent_stats_auth_gemini
    set -e GEMINI_API_KEY 2>/dev/null
    set -gx GOOGLE_API_KEY "test-key-123"
    set -l result (__agent_stats_auth gemini)
    set -e GOOGLE_API_KEY
    echo $result
) = apikey

@test "auth: cache is used on second call" (
    set -g __agent_stats_auth_codex "cached_value"
    set -l result (__agent_stats_auth codex)
    set -e __agent_stats_auth_codex
    echo $result
) = cached_value

@test "auth: clearing cache forces re-detection" (
    set -g __agent_stats_auth_codex "stale"
    set -e __agent_stats_auth_codex
    set -gx OPENAI_API_KEY "test-key"
    set -l result (__agent_stats_auth codex)
    set -e OPENAI_API_KEY
    set -e __agent_stats_auth_codex
    echo $result
) = apikey
