function __agent_stats_auth --description "Detect auth method (account, apikey, unknown) for a provider"
    set -l provider $argv[1]

    set -l cache_var __agent_stats_auth_$provider
    if set -q $cache_var
        echo $$cache_var
        return
    end

    set -l result unknown

    switch $provider
        case claude
            # macOS: Keychain; Linux: credentials file
            set -l creds_json
            if command -q security
                set creds_json (security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
            end
            if test -z "$creds_json" -a -f ~/.claude/.credentials.json
                set creds_json (cat ~/.claude/.credentials.json 2>/dev/null)
            end
            if test -n "$creds_json"
                set -l token (echo $creds_json | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
                if test -n "$token"
                    set result account
                end
            end
            if test "$result" = unknown -a -n "$ANTHROPIC_API_KEY"
                set result apikey
            end
        case codex
            if test -n "$OPENAI_API_KEY"
                set result apikey
            else if test -d ~/.codex/sessions
                set result account
            end
        case gemini
            if test -d ~/.gemini/tmp; and count ~/.gemini/tmp/session-*.json >/dev/null 2>&1
                set result account
            else if test -n "$GEMINI_API_KEY" -o -n "$GOOGLE_API_KEY"
                set result apikey
            end
    end

    set -g $cache_var $result
    echo $result
end
