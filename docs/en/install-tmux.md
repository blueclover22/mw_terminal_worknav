# Installing tmux and basic operations (macOS)

[한국어](../ko/install-tmux.md) | **English**

Related: [README](../../README.en.md) · [Windows side](install-psmux.md) · [Troubleshooting](troubleshooting.md)

`mtw_claude` and `mtw_codex` create a tmux session and run the agent inside it. Without tmux the jump and list commands still work fine, but the agent commands are unusable.

## 1. Install

Install with Homebrew.

```bash
brew install tmux
```

If you do not have Homebrew, follow the instructions at [brew.sh](https://brew.sh) first.

Verify the install.

```bash
tmux -V
# e.g. tmux 3.7b
```

You can also check the executable path with `command -v tmux`. This tool **looks up `tmux` on PATH and calls it directly**, so nothing else needs configuring as long as the command above works.

## 2. What mtw actually calls

These two forms are all this tool ever passes to tmux.

```bash
tmux new-session -A -s <session> -c <path> <agent command>    # called from outside a session
tmux new-window     -n <session> -c <path> <agent command>    # called from inside a session
```

- `-A` — **attaches** to a session of the same name instead of creating a new one, if it already exists.
- `-s` / `-n` — session name / window name.
- `-c` — the starting directory of the session (window).
- The final argument — the command to run in the session (window). A single command such as `claude` or `codex`.

Being inside or outside a session is detected from whether the `TMUX` environment variable is set. Inside a session, `echo $TMUX` prints a socket path.

**When `-A` attaches, the command in the final argument is not executed.** That is normal tmux behavior and this tool does not work around it. See [Troubleshooting](troubleshooting.md) for details.

## 3. The basics worth knowing

Every tmux shortcut is entered **after the prefix key**. The default prefix is `Ctrl-b`.

| What you want | How |
|---|---|
| Leave the session (detach) | `Ctrl-b` then `d` — the session keeps running in the background |
| List sessions | `tmux ls` |
| Return to a session (attach) | `tmux attach -t <session>` |
| End a session | `exit` inside it, or `tmux kill-session -t <session>` from outside |
| List windows | `Ctrl-b` then `w` |
| Next / previous window | `Ctrl-b` then `n` / `p` |
| Jump to a window by number | `Ctrl-b` then `0`–`9` |
| Close a window | `exit` inside it |
| Enter scroll mode | `Ctrl-b` then `[` — leave with `q` |

Running `mtw_claude myApp` creates a session named `myApp`, so you can come back to it any time with `tmux attach -t myApp`.

## 4. Using two agents on the same project

The session name is derived from the **project name**, not the agent. So running `mtw_codex myApp` after `mtw_claude myApp` from outside a session just attaches to the same session; Codex is not launched.

To use both, **call the second one from inside the session**.

```bash
mtw_claude myApp     # creates the myApp session, runs Claude Code, drops you inside
mtw_codex myApp      # inside a session, so a new window opens and runs Codex CLI there
```

Switch between the two windows with `Ctrl-b` then `n` / `p`.

## 5. Configuration file (optional)

tmux configuration lives in `~/.tmux.conf`. This tool neither reads nor writes tmux configuration, so your existing setup applies unchanged. If you have remapped the prefix, read `Ctrl-b` in the table above as your own prefix.

Official documentation: [the tmux wiki](https://github.com/tmux/tmux/wiki)

## 6. Uninstalling

```bash
brew uninstall tmux
```

Removing tmux leaves `mtw_cd_*`, `mtw_list`, `mtw_new` and `mtw_rm` working. Only the agent commands become unusable.
