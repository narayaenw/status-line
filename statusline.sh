#!/bin/bash
# Claude Code status line — context bar + cost + duration + git branch + rate limits.
#
# Adapted from the statusline shown in Leonardo Grigorio's tutorial
#   "My actual Claude Code workflow" — https://www.youtube.com/watch?v=Hhiwq1aHK7o
#   (channel: Build & Ship with AI — https://www.youtube.com/@leonardogrig)
# Substantially modified:
#   - primarily reads .context_window.used_percentage (exact, accounts for cache),
#     with a manual fallback when the field is missing
#   - a single jq pass instead of five (faster)
#   - custom color thresholds + 10-segment progress bar
#   - rate-limit segment (5h/7d used %) from .rate_limits; hides itself when the
#     fields are absent (Console API keys, or before the first API response)
#
# Install: point .claude/settings.json -> statusLine at this file, then chmod +x.
# Requires: jq, git (git is optional — falls back to "no-git").

input=$(cat)

# One jq pass: model, effort, context %, cost, duration, rate limits.
# Delimiter = unit separator \x1f (not whitespace) so an empty field
# (e.g. missing effort) does not collapse into its neighbour.
# Rate limits use -1 as a "missing" sentinel (fields absent on API keys
# and until the first API response arrives).
IFS=$'\x1f' read -r MODEL EFFORT PERCENT COST DURATION_MS RL5 RL7 <<EOF
$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "?"),
    (.effort.level // ""),
    ((.context_window.used_percentage
        // (if (.context_window.context_window_size // 0) > 0
            then (.context_window.total_input_tokens // 0) * 100 / .context_window.context_window_size
            else 0 end)) | floor),
    (.cost.total_cost_usd // 0),
    ((.cost.total_duration_ms // 0) | floor),
    ((.rate_limits.five_hour.used_percentage // -1) | floor),
    ((.rate_limits.seven_day.used_percentage // -1) | floor)
  ] | map(tostring) | join("")' 2>/dev/null)
EOF

# Numeric defaults — guards against jq being absent or failing.
[ -z "$PERCENT" ]      && PERCENT=0
[ -z "$COST" ]         && COST=0
[ -z "$DURATION_MS" ]  && DURATION_MS=0
[ -z "$MODEL" ]        && MODEL="?"
[ -z "$RL5" ]          && RL5=-1
[ -z "$RL7" ]          && RL7=-1

# Model label + effort (·xhigh); effort hides itself when .effort.level is absent (e.g. API key).
if [ -n "$EFFORT" ]; then MODEL_LABEL="${MODEL} ·${EFFORT}"; else MODEL_LABEL="$MODEL"; fi

# Duration: "Xh Ym" above an hour, "Ym Zs" below.
TOTAL_SEC=$((DURATION_MS / 1000)); H=$((TOTAL_SEC / 3600)); M=$(((TOTAL_SEC % 3600) / 60)); S=$((TOTAL_SEC % 60))
if   [ "$H" -gt 0 ]; then DUR="${H}h ${M}m"
elif [ "$M" -gt 0 ]; then DUR="${M}m ${S}s"
else DUR="${S}s"; fi

# Git branch + dirty flag.
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

# Shared color thresholds (context % and rate limits).
pct_color() {
  if   [ "$1" -ge 90 ]; then printf '%s' "$C_RED"
  elif [ "$1" -ge 70 ]; then printf '%s' "$C_ORANGE"
  elif [ "$1" -ge 50 ]; then printf '%s' "$C_YELLOW"
  else                       printf '%s' "$C_GREEN"; fi
}
PC=$(pct_color "$PERCENT")

# 10-segment progress bar.
FILLED=$((PERCENT / 10)); [ "$FILLED" -gt 10 ] && FILLED=10
BAR=""
for i in $(seq 1 10); do
  if [ "$i" -le "$FILLED" ]; then BAR="${BAR}█"; else BAR="${BAR}░"; fi
done

# Rate-limit segment — hides itself entirely when both fields are missing.
RL=""
if [ "$RL5" -ge 0 ]; then
  RL="$(pct_color "$RL5")5h:${RL5}%${C_RESET}"
fi
if [ "$RL7" -ge 0 ]; then
  [ -n "$RL" ] && RL="${RL} · "
  RL="${RL}$(pct_color "$RL7")7d:${RL7}%${C_RESET}"
fi

printf "%s[%s]%s 📁 %s | 🌿 %s | %s%s%s %s%d%%%s | %s\$%.2f%s | 🕐 %s" \
  "$C_CYAN" "$MODEL_LABEL" "$C_RESET" "$DIR" "$GIT" \
  "$PC" "$BAR" "$C_RESET" "$PC" "$PERCENT" "$C_RESET" "$C_GREEN" "$COST" "$C_RESET" "$DUR"
[ -n "$RL" ] && printf " | ⏳ %s" "$RL"
exit 0
