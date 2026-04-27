#!/usr/bin/env bash
# Claude Code status line - inspired by robbyrussell Oh My Zsh theme

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hr_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Current directory basename (like %c in robbyrussell)
dir_name=$(basename "$cwd")

# Git branch (skip lock to be safe)
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Build output with ANSI colors (dimmed-friendly)
CYAN='\033[0;36m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Directory
output=$(printf "${CYAN}%s${RESET}" "$dir_name")

# Git branch
if [ -n "$git_branch" ]; then
  output="$output $(printf "${BLUE}git:(${RED}%s${BLUE})${RESET}" "$git_branch")"
fi

# Model
if [ -n "$model" ]; then
  output="$output $(printf "${YELLOW}[%s]${RESET}" "$model")"
fi

# Context usage
if [ -n "$used_pct" ]; then
  printf_pct=$(printf "%.0f" "$used_pct" 2>/dev/null)
  output="$output $(printf "${YELLOW}ctx:%s%%${RESET}" "$printf_pct")"
fi

# Rate limit progress bar function
# Builds a 10-char bar: filled blocks vs empty blocks
make_bar() {
  local pct="$1"
  local filled=$(printf "%.0f" "$(echo "$pct * 10 / 100" | bc -l 2>/dev/null || echo 0)" 2>/dev/null)
  [ -z "$filled" ] && filled=0
  [ "$filled" -gt 10 ] && filled=10
  local empty=$((10 - filled))
  local bar=""
  local i
  for i in $(seq 1 "$filled"); do bar="${bar}█"; done
  for i in $(seq 1 "$empty"); do bar="${bar}░"; done
  echo "$bar"
}

# Rate limits line
rate_line=""
if [ -n "$five_hr_pct" ]; then
  five_int=$(printf "%.0f" "$five_hr_pct" 2>/dev/null)
  five_bar=$(make_bar "$five_hr_pct")
  # Color the bar: green < 60, yellow < 85, red >= 85
  if [ "$five_int" -ge 85 ]; then
    bar_color="$RED"
  elif [ "$five_int" -ge 60 ]; then
    bar_color="$YELLOW"
  else
    bar_color='\033[0;32m'
  fi
  rate_line="$rate_line$(printf "${CYAN}5h:${RESET}${bar_color}%s${RESET}${CYAN}%s%%${RESET}" "$five_bar" "$five_int")"
fi

if [ -n "$seven_day_pct" ]; then
  seven_int=$(printf "%.0f" "$seven_day_pct" 2>/dev/null)
  seven_bar=$(make_bar "$seven_day_pct")
  if [ "$seven_int" -ge 85 ]; then
    bar_color="$RED"
  elif [ "$seven_int" -ge 60 ]; then
    bar_color="$YELLOW"
  else
    bar_color='\033[0;32m'
  fi
  [ -n "$rate_line" ] && rate_line="$rate_line  "
  rate_line="$rate_line$(printf "${CYAN}7d:${RESET}${bar_color}%s${RESET}${CYAN}%s%%${RESET}" "$seven_bar" "$seven_int")"
fi

if [ -n "$rate_line" ]; then
  printf "%b\n" "$output"
  printf "%b\n" "$rate_line"
else
  printf "%b\n" "$output"
fi
