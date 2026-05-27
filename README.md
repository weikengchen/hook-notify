# hook-notify

Get a **loud, acknowledge-required push notification** on your phone the moment
Claude Code needs your attention — a permission prompt, a question, or a
finished task. It wires a tiny shell script to a
[Claude Code hook](https://code.claude.com/docs/en/hooks) and delivers the alert
through [Pushover](https://pushover.net).

The alert is sent at **Pushover priority 2 ("emergency")**: it repeats every 60
seconds for up to an hour and plays a siren until you acknowledge it on your
phone — so you can walk away from the keyboard and trust you'll be pulled back.

A built-in **silencer** lets you mute it with a single file, no config edits.

---

## How it works

```
Claude Code event  ──►  hook in settings.json  ──►  pushover-notify.sh  ──►  Pushover API  ──►  your phone
  (Notification /                                    (silencer check,
   Stop)                                              creds, curl)
```

1. Claude Code fires a **hook event**. The two useful ones here:
   - **`Notification`** — Claude needs you: it's requesting permission or waiting
     for input. *(primary)*
   - **`Stop`** — Claude finished responding and is now idle. *(optional)*
2. Your `settings.json` maps that event to a command that runs
   `pushover-notify.sh "<title>" "<message>"`.
3. The script, in order:
   - exits silently if the **silencer** file exists,
   - exits silently if Pushover credentials aren't set,
   - otherwise POSTs an emergency notification to the Pushover API.

   It **exits `0` on every path** — a failed or skipped notification can never
   block Claude Code.

Hooks also receive a JSON payload on **stdin** (`session_id`, `cwd`,
`transcript_path`, `hook_event_name`, …). This script ignores stdin and uses
static positional arguments for the title/message to stay simple. If you want
messages built from event data, parse stdin in the script — see *Customizing*.

---

## Prerequisites

- **A Pushover account** and the Pushover app on your phone (one-time ~$5 per
  platform after the trial).
- A Pushover **Application API token** — create one at
  <https://pushover.net/apps/build> — and your **User key**, shown on your
  <https://pushover.net> dashboard.
- **zsh** (the default shell on macOS) and **curl**.

---

## Install

### 1. Drop in the script

```sh
mkdir -p ~/.claude/scripts
cp pushover-notify.sh ~/.claude/scripts/pushover-notify.sh
chmod +x ~/.claude/scripts/pushover-notify.sh
```

### 2. Add your Pushover credentials

Put these in **`~/.zshenv`** (not `~/.zshrc` — see *Why `~/.zshenv`* below), then
open a new terminal so they take effect:

```sh
export PUSHOVER_TOKEN="your-application-api-token"
export PUSHOVER_USER="your-user-key"
```

> **Never commit these.** The script reads them from the environment; no secrets
> belong in this repo.

### 3. Wire the hook

Merge this into **`~/.claude/settings.json`** (full version in
[`examples/settings.json`](examples/settings.json)):

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/scripts/pushover-notify.sh \"Claude Code\" \"Needs your attention\""
          }
        ]
      }
    ]
  }
}
```

That's the minimum — you'll get a push whenever Claude is waiting on you. To also
be pinged when Claude *finishes* a turn, add the `Stop` block from the example
file. Heads up: priority 2 keeps nagging until you acknowledge, so many people
keep only the `Notification` hook (or lower the priority for `Stop`; see
*Customizing*).

### 4. Test it

```sh
# Direct test — this should reach your phone:
~/.claude/scripts/pushover-notify.sh "Test" "hook-notify is working"

# Confirm the hook fires inside Claude Code:
claude --debug
# …then trigger a permission prompt and watch the debug log for the hook running.
```

---

## The silencer

Mute notifications without touching any config by creating the sentinel file:

```sh
touch ~/.claude/claude-pushover-silence   # mute
rm    ~/.claude/claude-pushover-silence   # unmute
```

While it exists, the script exits before sending. It lives under `~/.claude`, so
a mute **persists across reboots** until you remove it. Override the path with
the `HOOK_NOTIFY_SILENCE_FILE` environment variable.

> Tip: it's easy to put a one-click web toggle in front of this file — any small
> web app that `touch`/`rm`s the sentinel works. Left out here to keep the repo
> focused on the hook itself.

---

## Why `~/.zshenv` (not `~/.zshrc`)?

Claude Code spawns hooks with a minimal, non-interactive environment. `~/.zshrc`
is sourced only for *interactive* shells, so credentials placed there are **not**
visible to the hook. **`~/.zshenv` is sourced on *every* zsh invocation** —
interactive or not — which is exactly why the script uses a `#!/usr/bin/env zsh`
shebang. Put the `export`s there and they're always available.

**Not using zsh?** Either (a) `source` a credentials file at the top of the
script (e.g. `. ~/.config/hook-notify.env`), or (b) inline the variables in the
hook command itself:

```
PUSHOVER_TOKEN=… PUSHOVER_USER=… $HOME/.claude/scripts/pushover-notify.sh "Claude Code" "Needs your attention"
```

---

## Customizing

- **Title / message** — the first two arguments in the hook `command`.
- **Sound** — third argument (`"siren"` by default; see the
  [Pushover sounds list](https://pushover.net/api#sounds)), e.g. `… "Done" "magic"`.
- **Priority / retry / expire** — edit the `--form-string` lines in the script.
  Lower `priority` to `1` (high) or `0` (normal) if you don't want the emergency
  repeat-until-acknowledged behavior.
- **Messages from event data** — read the JSON on stdin and pull fields like
  `cwd` or `transcript_path`, then build the message dynamically.

---

## Files

| File | Purpose |
|---|---|
| [`pushover-notify.sh`](pushover-notify.sh) | The hook script. |
| [`examples/settings.json`](examples/settings.json) | Ready-to-merge Claude Code hook config. |
