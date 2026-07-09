#!/bin/bash
# Claude Code status line — model, folder, git branch, context bar, rate limits.
#
# Adapted from the statusline shown in Leonardo Grigorio's tutorial
#   "My actual Claude Code workflow" — https://www.youtube.com/watch?v=Hhiwq1aHK7o
#   (channel: Build & Ship with AI — https://www.youtube.com/@leonardogrig)
# Substantially modified:
#   - primarily reads .context_window.used_percentage (exact, accounts for cache),
#     with a manual fallback when the field is missing
#   - a single jq pass instead of five (faster)
#   - custom color thresholds + 10-segment progress bar
#   - labelled segments (Context:/Limits:); the rate-limit segment hides itself
#     when the fields are absent (Console API keys, or before the first API response)
#
# Install: point .claude/settings.json -> statusLine at this file, then chmod +x.
# Requires: jq, git (git is optional — falls back to "no-git").
# Portable: integer-only math and git plumbing/porcelain output, so it is
# independent of the system language/locale.

input=$(cat)

# One jq pass: model, effort, context %, rate limits.
# Delimiter = unit separator (), not whitespace, so an empty field
# (e.g. missing effort) does not collapse into its neighbour.
# Rate limits use -1 as a "missing" sentinel (fields absent on API keys
# and until the first API response arrives).
IFS=$'\x1f' read -r MODEL EFFORT PERCENT RL5 RL7 <<EOF
$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "?"),
    (.effort.level // ""),
    ((.context_window.used_percentage
        // (if (.context_window.context_window_size // 0) > 0
            then (.context_window.total_input_tokens // 0) * 100 / .context_window.context_window_size
            else 0 end)) | floor),
    ((.rate_limits.five_hour.used_percentage // -1) | floor),
    ((.rate_limits.seven_day.used_percentage // -1) | floor)
  ] | map(tostring) | join("")' 2>/dev/null)
EOF

# Defaults — guard against jq being absent or failing.
[ -z "$PERCENT" ] && PERCENT=0
[ -z "$MODEL" ]   && MODEL="?"
[ -z "$RL5" ]     && RL5=-1
[ -z "$RL7" ]     && RL7=-1

# Model label + effort (·xhigh); effort hides itself when .effort.level is absent (e.g. API key).
if [ -n "$EFFORT" ]; then MODEL_LABEL="${MODEL} ·${EFFORT}"; else MODEL_LABEL="$MODEL"; fi

# Git branch + dirty flag (plumbing/porcelain — not localized).
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$BRANCH" ]; then
  [ -n "$(git status --porcelain 2>/dev/null)" ] && GIT="${BRANCH}±" || GIT="${BRANCH}"
else
  GIT="no-git"
fi
DIR=$(basename "$(pwd)")

# Colors.
C_RESET=$'\033[0m'; C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'; C_ORANGE=$'\033[38;5;208m'; C_RED=$'\033[31m'
C_LABEL=$'\033[90m'   # dim grey for the miniature Context:/Limits: labels

# Shared color thresholds (context % and rate limits).
pct_color() {
  if   [ "$1" -ge 90 ]; then printf '%s' "$C_RED"
  elif [ "$1" -ge 70 ]; then printf '%s' "$C_ORANGE"
  elif [ "$1" -ge 50 ]; then printf '%s' "$C_YELLOW"
  else                       printf '%s' "$C_GREEN"; fi
}
PC=$(pct_color "$PERCENT")

# 10-segment progress bar (pure bash — no `seq` dependency).
FILLED=$((PERCENT / 10)); [ "$FILLED" -gt 10 ] && FILLED=10
BAR=""
for ((i = 1; i <= 10; i++)); do
  if [ "$i" -le "$FILLED" ]; then BAR="${BAR}█"; else BAR="${BAR}░"; fi
done

# Rate-limit value — empty when both fields are missing (segment hides itself).
RL=""
if [ "$RL5" -ge 0 ]; then
  RL="$(pct_color "$RL5")5h:${RL5}%${C_RESET}"
fi
if [ "$RL7" -ge 0 ]; then
  [ -n "$RL" ] && RL="${RL} · "
  RL="${RL}$(pct_color "$RL7")7d:${RL7}%${C_RESET}"
fi

# Assemble: [model ·effort] | 📁 dir | 🌿 branch | Context: <bar> % | Limits: 5h/7d
printf "%s[%s]%s | 📁 %s | 🌿 %s | %sContext:%s %s%s%s %s%d%%%s" \
  "$C_CYAN" "$MODEL_LABEL" "$C_RESET" "$DIR" "$GIT" \
  "$C_LABEL" "$C_RESET" "$PC" "$BAR" "$C_RESET" "$PC" "$PERCENT" "$C_RESET"
[ -n "$RL" ] && printf " | %sLimits:%s %s" "$C_LABEL" "$C_RESET" "$RL"
exit 0
