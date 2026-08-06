# Installing psmux (Windows)

[한국어](../ko/install-psmux.md) | **English**

Related: [README](../../README.en.md) · [macOS side](install-tmux.md) · [Troubleshooting](troubleshooting.md)

psmux is a Windows-native, tmux-compatible multiplexer. `mtw_claude` and `mtw_codex` use it to create sessions. Without psmux the jump and list commands still work fine, but the agent commands are unusable.

## 1. First — you need PowerShell 7

What ships with Windows is **Windows PowerShell 5.1** (`powershell.exe`); what this tool requires is **PowerShell 7 or later** (`pwsh.exe`). They are separate programs and install side by side.

```powershell
winget install Microsoft.PowerShell
```

Verify afterwards.

```powershell
pwsh -NoProfile -Command '$PSVersionTable.PSVersion'
# Major must be 7 or greater
```

psmux also runs `pwsh` by default, so without PowerShell 7 the `mtw_*` commands will not be visible inside a session. This is a frequent source of confusion.

## 2. Installing psmux

### winget (recommended)

```powershell
winget install psmux
```

### scoop

```powershell
scoop install psmux
```

### chocolatey

```powershell
choco install psmux
```

### cargo (build from source)

Requires the Rust toolchain.

```powershell
cargo install psmux
```

### GitHub Releases

You can also download the binary directly and drop it in a directory on PATH. Check the Releases page of the [psmux/psmux](https://github.com/psmux/psmux) repository for artifacts and the latest version.

## 3. Verifying the install — the `tmux` command is the point

psmux installs **all three executables: `psmux`, `pmux` and `tmux`**. This tool calls the multiplexer **only under the name `tmux`** on both operating systems, so `tmux` is what you need to check.

```powershell
tmux -V
```

If a version prints, you are ready. If not, check the following.

```powershell
Get-Command tmux          # the executable path
$env:PATH -split ';'      # is the psmux install directory on PATH?
```

PATH changes often require opening a new terminal.

**Why depend on the `tmux` command?** Using the same command name on both operating systems keeps the execution logic and the usage documentation from splitting per OS. This tool takes that benefit. If psmux ever stops providing the `tmux` command, this part has to be redesigned.

## 4. What mtw actually calls

```powershell
tmux new-session -A -s <session> -c <path> <agent command>    # called from outside a session
tmux new-window     -n <session> -c <path> <agent command>    # called from inside a session
```

- `-A` — **attaches** to a session of the same name instead of creating a new one, if it already exists. In that case the trailing agent command **is not executed**.
- `-c` — the starting directory of the session (window).
- Being inside or outside a session is detected from whether the `TMUX` environment variable is set. You can check it inside a session by printing `$env:TMUX`.

> **psmux supports both of these (`-A` / `-c` flag support, and `TMUX` being set inside a session)** — confirmed on real hardware with Windows 11 and psmux 3.3.7. If either one does not work in the psmux version you are running, it is not an individual command that breaks but a design premise — please open an issue and include your psmux version.

## 5. Basic operations

psmux is tmux-compatible, so it is operated the same way and reads an existing `.tmux.conf` as is. The default prefix is `Ctrl-b`.

| What you want | How |
|---|---|
| Leave the session (detach) | `Ctrl-b` then `d` |
| List sessions | `tmux ls` |
| Return to a session (attach) | `tmux attach -t <session>` |
| List windows / next / previous | `Ctrl-b` then `w` / `n` / `p` |
| End a window or session | `exit` inside it |

To use Claude Code and Codex CLI on the same project, call the second command **from inside the session**. Inside a session a new window opens instead of a new session.

```powershell
mtw_claude myApp     # creates the myApp session, runs Claude Code
mtw_codex myApp      # inside a session, so Codex CLI runs in a new window
```

## 6. Installing and uninstalling mtw (for reference)

Once psmux is installed, installing mtw looks like this.

```powershell
git clone https://github.com/blueclover22/mw-terminal-worknav.git
cd mw-terminal-worknav
pwsh -NoProfile -File .\windows\install.ps1
```

Uninstalling looks like this.

```powershell
pwsh -NoProfile -File .\windows\uninstall.ps1                    # keeps the project list
pwsh -NoProfile -File .\windows\uninstall.ps1 -RemoveProjects    # deletes all of ~\.mtw\
```

**Why `-NoProfile`.** PowerShell resolves commands in the order `Alias -> Function -> Cmdlet -> external command`. A function defined in your profile can shadow even a cmdlet's canonical name such as `Copy-Item`, and `pwsh script.ps1` loads your profile unless `-NoProfile` is given. The install and uninstall scripts defend themselves by calling file-manipulating cmdlets through their **module-qualified names** (`Microsoft.PowerShell.Management\Copy-Item` and friends), but `-NoProfile` is one more layer on top of that.

## 7. Uninstalling psmux

```powershell
winget uninstall psmux
```

Removing psmux leaves `mtw_cd_*`, `mtw_list`, `mtw_new` and `mtw_rm` working. Only the agent commands become unusable.
