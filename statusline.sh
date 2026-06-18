#!/bin/bash
# Claude Code status line — context bar + cost + duration + git branch.
#
# Adapted from the statusline shown in Leonardo Grigorio's tutorial
#   "My actual Claude Code workflow" — https://www.youtube.com/watch?v=Hhiwq1aHK7o
#   (channel: Build & Ship with AI — https://www.youtube.com/@leonardogrig)
# Substantially modified:
#   - primarily reads .context_window.used_percentage (exact, accounts for cache),
#     with a manual fallback when the field is missing
#   - a single jq pass instead of five (faster)
#   - custom color thresholds + 10-segment progress bar
#
# Install: point .claude/settings.json -> statusLine at this file, then chmod +x.
# Requires: jq, git (git is optional — falls back to "no-git").

input=$(cat)

# One jq pass: model, effort, context %, cost, duration.
# Delimiter = unit separator \x1f (not whitespace) so an empty field
# (e.g. missing effort) does not collapse into its neighbour.
IFS=$'\x1f' read -r MODEL EFFORT PERCENT COST DURATION_MS <<EOF
$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "?"),
    (.effort.level // ""),
    ((.context_window.used_percentage
        // (if (.context_window.context_window_size // 0) > 0
            then (.context_window.total_input_tokens // 0) * 100 / .context_window.context_window_size
            else 0 end)) | floor),
    (.cost.total_cost_usd // 0),
    ((.cost.total_duration_ms // 0) | floor)
  ] | map(tostring) | join("")' 2>/dev/null)
EOF

# Numeric defaults — guards against jq being absent or failing.
[ -z "$PERCENT" ]      && PERCENT=0
[ -z "$COST" ]         && COST=0
[ -z "$DURATION_MS" ]  && DURATION_MS=0
[ -z "$MODEL" ]        && MODEL="?"

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

# Context % color threshold.
if   [ "$PERCENT" -ge 90 ]; then PC=$C_RED
elif [ "$PERCENT" -ge 70 ]; then PC=$C_ORANGE
elif [ "$PERCENT" -ge 50 ]; then PC=$C_YELLOW
else PC=$C_GREEN; fi

# 10-segment progress bar.
FILLED=$((PERCENT / 10)); [ "$FILLED" -gt 10 ] && FILLED=10
BAR=""
for i in $(seq 1 10); do
  if [ "$i" -le "$FILLED" ]; then BAR="${BAR}█"; else BAR="${BAR}░"; fi
done

printf "%s[%s]%s 📁 %s | 🌿 %s | %s%s%s %s%d%%%s | %s\$%.2f%s | 🕐 %s" \
  "$C_CYAN" "$MODEL_LABEL" "$C_RESET" "$DIR" "$GIT" \
  "$PC" "$BAR" "$C_RESET" "$PC" "$PERCENT" "$C_RESET" "$C_GREEN" "$COST" "$C_RESET" "$DUR"
