---
permalink: /blogs/ai-workflow/ring-terminal-bell-when-claude-code-pauses
layout: post
title: How to ring the terminal bell when Claude Code pauses and is waiting for the user to approve a tool use or is waiting for next instructions
---

### The Problem

You give Claude Code a task, switch to another tab to read something, and by the time you come back Claude has been sitting idle for five minutes waiting for your next message. Or worse, it was waiting on a permission prompt and the whole run stalled.

Would be nice if it could just beep at you.

### The Fix

Claude Code has a feature called **hooks**. They are basically shell commands that run when certain events happen inside a session. Two events are useful here:

1. `Stop` runs when Claude finishes a turn and is idle, waiting for your next message.
2. `Notification` runs when Claude needs your attention in the middle of a task, like a permission prompt or an idle reminder.

On a Mac, the easiest way to make a sound is the built-in `afplay` command. It plays any audio file you point it at. macOS already ships with a bunch of system sounds in `/System/Library/Sounds/`, so you do not need to download anything.

Open `~/.claude/settings.json` (create it if it does not exist) and add this:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "afplay /System/Library/Sounds/Glass.aiff &" }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          { "type": "command", "command": "afplay /System/Library/Sounds/Funk.aiff &" }
        ]
      }
    ]
  }
}
```

Restart Claude Code so it picks up the new settings. Done.

### Why two different sounds

If both events used the same noise, you would not know whether Claude finished or got stuck waiting for permission. With two sounds your ear tells you which one without having to look at the screen.

- Glass is a soft chime. It means "I am done, your move."
- Funk is more urgent. It means "I need you right now."

You can pick any sound you want. To see what is available on your Mac:

```bash
ls /System/Library/Sounds/
```

You will see Basso, Blow, Bottle, Frog, Glass, Hero, Ping, Pop, Submarine, Tink and a few more. Preview any of them by running:

```bash
afplay /System/Library/Sounds/Hero.aiff
```

### Why not just the terminal bell

The obvious way to do this is `printf '\a'`, which sends a BEL character to the terminal. The problem is every terminal handles BEL differently. iTerm might flash. Terminal.app might beep. Ghostty might do nothing depending on your config. tmux might swallow it entirely. `afplay` does not care which terminal you are in, it just plays the file.

The `&` at the end of the command is important. It runs the player in the background so the hook returns instantly. Without it the hook would block Claude for the length of the sound, which is short but annoying.

### Small tweaks

**Quieter sound.** `afplay` takes a volume flag from 0.0 to 1.0:

```json
{ "type": "command", "command": "afplay -v 0.4 /System/Library/Sounds/Glass.aiff &" }
```

**Different sound per project.** Drop a `.claude/settings.json` inside a project folder with its own hooks block. Project settings override the global ones.

**Mute one event.** Just remove the `Stop` or `Notification` array from the config.

### More on hooks

Hooks can do way more than play sounds. You can run scripts before tool calls, log every prompt, block risky commands, post to Slack when a task finishes, or anything else you can do in a shell. The full list of events and what payload each one sends is in the official docs:

[Claude Code hooks reference](https://code.claude.com/docs/en/hooks)
