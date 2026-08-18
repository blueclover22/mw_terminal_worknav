# mw-terminal-worknav

[한국어](README.md) | **English**

A set of shell shortcuts that jump straight to a registered project folder. The macOS (zsh) and Windows (PowerShell 7) implementations produce **the same commands, the same messages, and the same exit codes**.

The default install adds **jump and list commands only**. A multiplexer is not a requirement — run agent sessions with a dedicated tool, and let mtw concentrate on "which folder do I go to". For those who still use a multiplexer (tmux on macOS, psmux on Windows), the agent-session commands remain available as an **optional add-on** ([6. The multiplexer add-on](#6-the-multiplexer-add-on-optional)).

## Table of contents

1. [What it does](#1-what-it-does)
2. [Requirements](#2-requirements)
3. [Installing](#3-installing)
4. [Usage](#4-usage)
5. [Configuration files](#5-configuration-files)
6. [The multiplexer add-on (optional)](#6-the-multiplexer-add-on-optional)
7. [Adding an agent](#7-adding-an-agent)
8. [Uninstalling](#8-uninstalling)
9. [Troubleshooting](#9-troubleshooting)
10. [License](#10-license)

---

## 1. What it does

```
mtw_new myApp       # register the current folder as myApp
mtw_list            # show registered projects
mtw_rm myApp        # unregister (the folder itself is kept)
mtw_cd_myApp        # jump to the myApp path
mtw_help            # show every command
```

Every command starts with `mtw_`, so **`mtw_<Tab>` lists every command** and **`mtw_cd_<Tab>` lists every registered project**. `mtw_rm` suggests registered project names when you press `<Tab>` in the argument position.

The jump command uses the double prefix `mtw_cd_` so that commands generated from project names live in their own namespace. Registering a folder named `list` only creates `mtw_cd_list`; the management command `mtw_list` is untouched.

## 2. Requirements

| Item | macOS | Windows |
|---|---|---|
| OS | macOS 12 or later | Windows 10 / 11 |
| Shell | zsh (the default shell) | PowerShell 7 or later |
| Multiplexer | not needed (tmux only for the add-on) | not needed (psmux only for the add-on) |
| Verification status | verified on real hardware (macOS 26 · zsh 5.9 · tmux 3.7) | verified on real hardware (Windows 11 · PowerShell 7) |

The default install requires nothing beyond the shell.

## 3. Installing

```bash
git clone https://github.com/blueclover22/mw-terminal-worknav.git
cd mw-terminal-worknav
```

**macOS**

```bash
zsh ./macos/install.sh
```

**Windows**

```powershell
pwsh -NoProfile -File .\windows\install.ps1
```

> **Run it with `-NoProfile`.** The script already defends itself against aliases and functions defined in your profile (it calls file-manipulating cmdlets by their module-qualified names), but `-NoProfile` is one more layer on top of that.

The install script does exactly five things.

1. Creates `~/.mtw/`
2. Copies the implementation (`mtw.zsh` / `mtw.ps1`) into `~/.mtw/` (**overwrites the existing file — rerunning the script is how you update**)
3. Installs or removes the multiplexer add-on (see [6. The multiplexer add-on](#6-the-multiplexer-add-on-optional))
4. Creates `~/.mtw/projects` as an empty file if it does not exist (**keeps it as is if it does**)
5. Appends a loader block to your profile (`~/.zshrc` / `$PROFILE`)

If your profile already has content, the script **makes a `.bak-YYYYMMDD-HHMMSS` backup before modifying it**, and aborts without touching the profile if the backup fails. If the loader block is already present it skips the profile edit, so **running it repeatedly is safe**.

> **Open a new terminal or reload your profile after installing.** The install script runs in a separate process, so it has no effect on the terminal you launched it from.
>
> - macOS: `source ~/.zshrc`
> - Windows: `. $PROFILE`

Check the installed version from the comment at the top of the implementation file.

```bash
head -5 ~/.mtw/mtw.zsh                        # macOS
```

```powershell
Get-Content -TotalCount 5 ~/.mtw/mtw.ps1      # Windows
```

## 4. Usage

### Register, list, unregister

```
mtw_new <name>      register the current folder. Name format: ^[A-Za-z_][A-Za-z0-9_-]*$
mtw_list            print registered projects in ascending name order
mtw_rm <name>       unregister (the folder is not deleted)
mtw_help            show every command
```

```
$ mtw_new myApp
등록되었습니다: myApp -> /Users/minwoo/workspace/projects/myApp

$ mtw_list
myApp       /Users/minwoo/workspace/projects/myApp

$ mtw_rm myApp
등록 해제되었습니다: myApp (폴더는 그대로 남아 있습니다: /Users/minwoo/workspace/projects/myApp)
```

> **Messages are in Korean in v2.0.2.** Both implementations emit byte-identical Korean strings; that byte equality is what the cross-OS verification is built on. Localizing the messages is out of scope for v2.0.2.

- **Usable immediately after registering.** `mtw_new` reloads the list and regenerates the jump functions, so `mtw_cd_myApp` and tab completion work without restarting the terminal.
- **The duplicate check is case-insensitive.** With `myApp` registered, `mtw_new MYAPP` is rejected. The name is stored exactly as you typed it.
- **`mtw_rm` matches names case-insensitively too**, and its messages use the registered spelling. `mtw_rm` has no confirmation prompt — all that disappears is one bookmark line, and the folder stays.
- A failed command prints an error, ends with **exit code 1**, and leaves the list file unchanged.

### Jumping

```
mtw_cd_<name>       jump to the registered path
```

One function is generated per registered entry. Functions for entries that disappear from the list are removed on the next load.

## 5. Configuration files

Everything lives under `~/.mtw/`.

| Path | Contents |
|---|---|
| `~/.mtw/projects` | the registered project list |
| `~/.mtw/mtw.zsh` (macOS) / `~/.mtw/mtw.ps1` (Windows) | the implementation, copied there by the install script |
| `~/.mtw/mtw-tmux.zsh` (macOS) / `~/.mtw/mtw-psmux.ps1` (Windows) | the multiplexer add-on. **Present only when installed with the flag** |

`~/.mtw/projects` is an ordinary text file in `name=path` form, so you can edit it by hand.

```
# comment
myApp=/Users/minwoo/workspace/projects/myApp
project=/Users/minwoo/workspace/projects/project
```

The editing rules and the things to watch out for when editing by hand (duplicate keys, ignored lines) are in [`docs/en/configuration.md`](docs/en/configuration.md).

## 6. The multiplexer add-on (optional)

Installing the add-on adds commands that **open a multiplexer session named after the folder and run an AI coding agent inside it**.

```
mtw_claude [name]   create a session, then run Claude Code
mtw_codex  [name]   create a session, then run Codex CLI
```

The multiplexer differs per OS, and **the add-on file and the install flag are split accordingly.**

| | macOS | Windows |
|---|---|---|
| Multiplexer | tmux | psmux |
| Install | `brew install tmux` | `winget install psmux` |
| Add-on flag | `zsh ./macos/install.sh --with-tmux` | `pwsh -NoProfile -File .\windows\install.ps1 -WithPsmux` |
| Add-on file | `~/.mtw/mtw-tmux.zsh` | `~/.mtw/mtw-psmux.ps1` |
| Setup docs | [`docs/en/install-tmux.md`](docs/en/install-tmux.md) | [`docs/en/install-psmux.md`](docs/en/install-psmux.md) |

**Rerunning the installer declares the state.** Running it again without the flag **removes** an already-installed add-on. Pass the flag on every reinstall if you want to keep it.

```
mtw: tmux 애드온을 제거했습니다 (다시 설치하려면 --with-tmux 를 주세요).      # macOS
mtw: psmux 애드온을 제거했습니다 (다시 설치하려면 -WithPsmux 를 주세요).     # Windows
```

The add-on is a separate file from the implementation, which loads it at the very end if the file exists. The loader block in your profile stays a single line either way, so **toggling the add-on on an existing install needs no profile edit.**

Installing, authenticating and adding the agent CLIs (Claude Code, Codex CLI) to PATH is your responsibility; this tool does not touch any of that.

### Behavior

| Call | Session name | Start path |
|---|---|---|
| `mtw_claude` | current folder name | current folder |
| `mtw_claude myApp` (registered name) | `myApp` | the registered path |
| `mtw_claude MYAPP` (differs only in case) | `myApp` | the registered path |
| `mtw_claude tmp` (unregistered name) | — | prints an error and stops, exit code 1 |

Internally one of these two forms is invoked. Both operating systems use exactly the same command.

```
tmux new-session -A -s <session> -c <path> <agent command>    # called from outside a session
tmux new-window     -n <session> -c <path> <agent command>    # called from inside a session
```

**On Windows the command invoked is `tmux` as well.** psmux ships all three executables — `psmux`, `pmux` and `tmux` — so the session-creation command is byte-identical on both operating systems. Only the add-on's name follows the per-OS multiplexer.

Five behaviors you must know about.

- **Quitting the agent ends the session too.** The agent command is the window's root process, so typing `/exit` in Claude Code closes the window — and the session with it if that was the last window. That is normal tmux behavior. To keep the session alive, detach (`Ctrl-b d`) instead of quitting. When called from inside a session it is a new window, so only that window closes.
- **An unregistered name produces an error and stops.** No session is created.
- **When `-A` attaches to an existing session, the trailing agent command is not executed.** That is normal tmux behavior and this tool does not work around it. So running `mtw_claude myApp` a second time simply returns you to the existing session; Claude Code is not launched again.
- **The session name comes from the project name only, never from the agent.** So running `mtw_codex myApp` after `mtw_claude myApp` attaches to the same session and Codex is not launched. **To use both agents on one project, call the second one from inside the session** — inside a session a **new window** is opened instead of a new session. (Being inside a session is detected from whether the `TMUX` environment variable is set.)
- **Characters outside `[A-Za-z0-9_-]` in the session name are replaced with `_`.** A folder named `my.app` yields the session name `my_app`.

## 7. Adding an agent

**This applies only if you installed the multiplexer add-on.** **Add one line to the agent registry** at the top of the add-on file. A `mtw_<key>` command appears, and `mtw_help` and tab completion pick it up automatically.

**macOS** — `~/.mtw/mtw-tmux.zsh`

```zsh
MTW_AGENTS=(
  claude claude
  codex  codex
  aider  aider      # the added line
)
```

**Windows** — `~/.mtw/mtw-psmux.ps1`

```powershell
$script:MTW_AGENTS = [ordered]@{
    claude = 'claude'
    codex  = 'codex'
    aider  = 'aider'      # the added line
}
```

Open a new terminal or reload your profile and `mtw_aider` is available.

- The key becomes the `mtw_<key>` function name, so **`list`, `new`, `rm`, `help` and `cd` cannot be used as keys.** The check is case-insensitive, so `List` and `RM` are filtered out too. A reserved key produces a warning on stderr at load time and **only that entry is skipped** (the fixed command is never overwritten).
- The value must be a **single command name**. Multi-token commands containing spaces, such as `claude --model x`, are not supported in v2.0.2.
- Edit `macos/src/mtw-tmux.zsh` / `windows/src/mtw-psmux.ps1` in the repository as well if you want the change to survive a reinstall. Editing only the copy under `~/.mtw/` means the next run of the install script overwrites it.

See [`docs/en/configuration.md`](docs/en/configuration.md) for details.

## 8. Uninstalling

**macOS**

```bash
zsh ./macos/uninstall.sh                     # keeps the project list
zsh ./macos/uninstall.sh --remove-projects   # deletes all of ~/.mtw/
```

**Windows**

```powershell
pwsh -NoProfile -File .\windows\uninstall.ps1                    # keeps the project list
pwsh -NoProfile -File .\windows\uninstall.ps1 -RemoveProjects    # deletes all of ~\.mtw\
```

- The default is to **keep the list**. Reinstalling restores your registered projects exactly as they were. Both the implementation and the multiplexer add-on are deleted.
- Editing the profile and deleting all of `~/.mtw/` are done **after making a backup**, and abort without touching the target if the backup fails.
- **Functions stay in memory in terminals that are already open.** To clean those up, run `exec zsh` on macOS or start a new PowerShell session on Windows.

## 9. Troubleshooting

Common situations and their fixes are collected in [`docs/en/troubleshooting.md`](docs/en/troubleshooting.md).

- Tab completion does not work (macOS — loader block position)
- `mtw_claude` disappeared after reinstalling (the add-on flag)
- Re-running `mtw_claude` does not launch the agent (attach behavior)
- Commands are still there after uninstalling
- A line added to the list file is ignored
- The install aborts with "cannot safely determine the loader-block markers"

## 10. License

MIT License. See [`LICENSE`](LICENSE).
