#!/usr/bin/env zsh
# hook-notify — send a loud, acknowledge-required push notification via Pushover.
#
# Designed to be wired as a Claude Code hook so your phone alerts you the moment
# Claude needs your attention or finishes a task. See README.md for setup.
#
# Usage: pushover-notify.sh "<title>" "<message>" [<sound>]
#
# Exits 0 on EVERY path (sent, missing creds, or network error) so a
# notification failure can never block or crash Claude Code.
#
# The shebang is zsh on purpose: zsh auto-sources ~/.zshenv on every invocation
# — interactive or not — so PUSHOVER_TOKEN / PUSHOVER_USER exported there are
# visible even when the hook is spawned with a minimal environment.
# (See the "Why ~/.zshenv" section of the README.)

set -u
TITLE="${1:-Claude Code}"
MESSAGE="${2:-(no message)}"
SOUND="${3:-siren}"

# --- Credentials ----------------------------------------------------------
# Set these in ~/.zshenv:
#     export PUSHOVER_TOKEN="your-application-api-token"
#     export PUSHOVER_USER="your-user-key"
if [ -z "${PUSHOVER_TOKEN:-}" ] || [ -z "${PUSHOVER_USER:-}" ]; then
  exit 0
fi

# --- Send -----------------------------------------------------------------
# priority=2 is "emergency": Pushover repeats the alert every <retry> seconds
# until you acknowledge it on your phone, giving up after <expire> seconds.
curl -s --max-time 10 \
  --form-string "token=${PUSHOVER_TOKEN}" \
  --form-string "user=${PUSHOVER_USER}" \
  --form-string "title=${TITLE}" \
  --form-string "message=${MESSAGE}" \
  --form-string "priority=2" \
  --form-string "retry=60" \
  --form-string "expire=3600" \
  --form-string "sound=${SOUND}" \
  https://api.pushover.net/1/messages.json > /dev/null 2>&1 || true

exit 0
