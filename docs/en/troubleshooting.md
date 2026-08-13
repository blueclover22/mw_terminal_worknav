# Troubleshooting

[한국어](../ko/troubleshooting.md) | **English**

Related: [README](../../README.en.md) · [Configuration](configuration.md) · [Installing tmux](install-tmux.md) · [Installing psmux](install-psmux.md)

Entries about the agent commands (`mtw_claude`, `mtw_codex`) and the multiplexer apply **only if you installed the add-on** — the tmux add-on on macOS, the psmux add-on on Windows.

> Runtime messages are Korean in v1.0.0. Where a message is quoted below, an English gloss follows in parentheses.

---

## No `mtw_` command exists right after installing

The install script **runs in a separate process, so it has no effect on the terminal you launched it from.** Open a new terminal or reload your profile.

```bash
source ~/.zshrc      # macOS
```

```powershell
. $PROFILE           # Windows
```

If they are still missing, check that the loader block actually made it into your profile.

```bash
tail -5 ~/.zshrc                              # macOS
```

```powershell
Get-Content -Tail 5 $PROFILE                  # Windows
```

You should see three lines starting with `# >>> mtw (mw-terminal-worknav) >>>`. If not, the install aborted — re-read the install script's output.

Check that the implementation was copied too; the loader block silently does nothing if the file is missing.

```bash
ls -l ~/.mtw/                                 # macOS: mtw.zsh must be there
```

```powershell
Get-ChildItem ~/.mtw/                         # Windows: mtw.ps1 must be there
```

---

## `mtw_claude` and `mtw_codex` disappeared after reinstalling

**That is the intended behavior.** The agent commands come from the multiplexer add-on, and the add-on is installed **only when you pass the flag**. Reinstalling without it removes an add-on that was already there — rerunning the installer declares the installed state.

It prints this when removing:

```
mtw: tmux 애드온을 제거했습니다 (다시 설치하려면 --with-tmux 를 주세요).      # macOS
mtw: psmux 애드온을 제거했습니다 (다시 설치하려면 -WithPsmux 를 주세요).     # Windows
```

**Fix** — reinstall with the flag.

```bash
zsh ./macos/install.sh --with-tmux                          # macOS
```

```powershell
pwsh -NoProfile -File .\windows\install.ps1 -WithPsmux      # Windows
```

Check `~/.mtw/` for the add-on file itself — `mtw-tmux.zsh` on macOS, `mtw-psmux.ps1` on Windows. If the file is there but the commands are not, you have not reloaded your profile.

> **Agents you added by editing the add-on file directly disappear with it.** Edit `macos/src/mtw-tmux.zsh` / `windows/src/mtw-psmux.ps1` in the repository to keep them across reinstalls.

---

## Tab completion does not work (macOS)

`mtw_cd_<Tab>` is the shell's own function-name completion and works almost always. If **only `mtw_rm <Tab>`, `mtw_claude <Tab>` and `mtw_codex <Tab>` fail**, it is the position of the loader block.

Registering completion requires `compdef`, which only exists after `compinit` has run. This tool **silently skips registration** when `compdef` is absent (so that loading never fails). If the loader block sits **before** `compinit`, everything else works and only completion is missing.

**Check**

```bash
grep -n 'compinit\|mtw (mw-terminal-worknav)' ~/.zshrc
```

The line number of the `mtw` marker must be greater than that of `compinit`. With oh-my-zsh, `compinit` runs inside `source $ZSH/oh-my-zsh.sh`, so being after that line is enough.

**Fix** — move the three loader-block lines to the **very end** of `.zshrc` and open a new terminal. The install script appends the block at the end of the file, so this never happens unless the block was moved.

---

## An entry just added with `mtw_new` is not offered by completion

Completion candidates are read from **the in-memory list at completion time**, so a new entry appearing without a restart is the expected behavior. If it does not appear, check the previous section first.

---

## Re-running `mtw_claude` does not launch the agent

**This is normal.** When `-A` attaches to an existing session, tmux does not run the trailing command. This tool does not work around it.

```
tmux new-session -A -s myApp -c /path/myApp claude
```

If the session `myApp` already exists, the command above **only attaches** and does not run `claude`.

**What to do**

- Just use the agent already running inside that session.
- To start fresh, end the session first — `tmux kill-session -t myApp`.
- To add a **different agent** to the same session, call it **from inside the session**. Inside a session a new window opens instead of a new session.

  ```
  mtw_claude myApp     # creates the session and drops you inside
  mtw_codex myApp      # inside a session, so it runs in a new window
  ```

---

## Called from inside a session, but it tries to create a new session instead of a new window

Being inside a session is detected from whether the `TMUX` environment variable is set. If it is empty inside a session, that branch never fires.

```bash
echo $TMUX          # macOS — should print a socket path
```

```powershell
$env:TMUX           # Windows — should have a value
```

If it is empty on Windows (psmux), psmux is not setting `TMUX`. That is not a usage problem but a broken design premise. It was confirmed working on psmux 3.3.7, so check your version with `psmux -V` and open an issue.

---

## The session name differs from the name I gave

Characters outside `[A-Za-z0-9_-]` in the session name are replaced with `_`. A folder named `my.app` becomes the session `my_app`, and a non-ASCII folder name becomes a run of `_`. Check the actual session name with `tmux ls`.

To keep a name as is, register it with `mtw_new` and call `mtw_claude <registered name>`.

---

## A line I added to the list file does not appear in `mtw_list`

Lines that do not match the format are **ignored without any message**. Check the following.

- Is it in `name=path` form with no spaces around the `=`?
- Does the name match `^[A-Za-z_][A-Za-z0-9_-]*$`? Starting with a digit, or containing a space or a period, gets it ignored.
- Does the same name already appear on an earlier line? **Names differing only in case: the first one wins.**
- Did you reload your profile after editing?

The full rule set is in the "Ignored lines" table of [`configuration.md`](configuration.md).

---

## Install/uninstall aborts with "cannot safely determine the loader-block markers"

```
mtw: 오류: 프로필에서 로더 블록 마커를 안전하게 판별할 수 없습니다: /Users/minwoo/.zshrc
```

(“error: cannot safely determine the loader-block markers in the profile: …”)

This appears when the profile does not contain **exactly one marker pair** (one start, one end, start first) — two pairs, only one side, or the end marker before the start. Cutting automatically in that state could delete lines you wrote, so the script **aborts without touching the profile**.

**Fix** — open the profile, search for these two lines, keep exactly one matching pair, and re-run.

```
# >>> mtw (mw-terminal-worknav) >>>
# <<< mtw (mw-terminal-worknav) <<<
```

If this happened during install, **the implementation was already copied and only the profile was left unchanged** (the message says so too). Clean up the profile and run the install script again.

---

## Commands are still there after uninstalling

**Functions stay in memory in terminals that are already open.** The uninstall script only cleans up files and the profile; it does not touch the memory of a running shell.

```bash
exec zsh            # macOS — restart the current shell
```

On Windows, start a new PowerShell session.

If the commands persist in a brand-new terminal, the loader block is still in your profile. See the marker section above.

---

## The project list disappeared / survived the uninstall

The default is to **keep it**. `~/.mtw/projects` is left alone and only the implementation is deleted. Reinstalling restores the list exactly.

To delete the list too, pass the option.

```bash
zsh ./macos/uninstall.sh --remove-projects                       # macOS
```

```powershell
pwsh -NoProfile -File .\windows\uninstall.ps1 -RemoveProjects    # Windows
```

That option **makes a backup before deleting**. The list survives in `~/.mtw.bak-YYYYMMDD-HHMMSS`, so if you deleted it by accident, restore the `projects` file from there.

The option name differs per OS — `--remove-projects` on macOS, `-RemoveProjects` on Windows — and **must match exactly**. Any other value does nothing and exits with code 1.

```
mtw: 알 수 없는 옵션입니다: -Remove
```

(“unknown option: -Remove”)

---

## Backup files are piling up

The install and uninstall scripts make a `~/.zshrc.bak-YYYYMMDD-HHMMSS` style backup before modifying the profile. Running twice within the same second appends `-2`, `-3` so that **a previous backup is never overwritten**.

Delete the ones you no longer need. The repository's `.gitignore` excludes `*.bak-*`, so they will not be committed by accident.

---

## Windows — `mtw_rm foo && echo ok` behaves unexpectedly

**This is a known difference, not a defect.** PowerShell's `&&` / `||` look at `$?` rather than the exit code, and a function's non-terminating error does not flip `$?`. There is no way around it, so **setting `$LASTEXITCODE` to 1 is the closest possible approximation**.

Check `$LASTEXITCODE` directly when you need to branch on success or failure.

```powershell
mtw_rm foo
if ($LASTEXITCODE -eq 0) { 'ok' } else { 'failed' }
```

For the same reason, **the PowerShell implementation's error output is not suppressed by `2>$null` nor captured by `2>&1`.** It uses `$host.UI.WriteErrorLine` in order to keep the message **byte-identical** to the macOS implementation. Both differences were accepted in order to keep the messages and exit codes identical across the two operating systems; judging success or failure from `$LASTEXITCODE` is still guaranteed.

---

## Line endings change when a file is rewritten

**This is known behavior, not a defect.** It shows up in two places.

**1. When `mtw_rm` rewrites the list file** — the PowerShell implementation reads the file line by line and writes it back, so the line endings in the result are **unified to the platform default** (CRLF on Windows). The macOS implementation (zsh) preserves the original line endings, so this is the one point where the two differ. The list file is not meant to be shared across operating systems anyway because path notation differs, and it is self-consistent within one OS, so it was left as is.

- **Guaranteed**: only the target line is removed; the **contents, order, comments and blank lines** of the remaining lines are preserved.
- **Not guaranteed**: preservation of the original line-ending characters.

**2. When the uninstall script rewrites your profile** — after uninstalling, the profile **always ends with exactly one newline, and blank lines at the end of the file are gone.** Both operating systems behave the same way here.

```
abc\ndef      →  abc\ndef\n     one newline added
abc\n\n\n     →  abc\n          trailing blank lines lost
abc\ndef\n    →  abc\ndef\n     unchanged
```

The install script appends a newline if the profile does not already end with one — without it the loader block would run straight on from your last line. At uninstall time there is no information to tell whether that newline was originally there or was added by the install.

- **Guaranteed**: the **contents, order and encoding** of the lines you wrote are preserved. Any encoding (UTF-8 with BOM, CP949, latin-1, …) round-trips unchanged, and the line endings between lines are kept.
- **Not guaranteed**: the presence or absence of the newline at the very end of the file, and trailing blank lines.

> **Keep your own settings outside the marker block.** Lines you write between the markers (`# >>> mtw …` through `# <<< mtw …`) are deleted along with the block on uninstall. Content before and after the block is preserved as is.

A backup (`*.bak-YYYYMMDD-HHMMSS`) is always created before the profile is touched, so you can roll back if the result is not what you expected.

---

## Anything else

Please open an issue with the steps to reproduce. If you hit it on Windows, include your OS version, `pwsh -v` and the console type (Windows Terminal or the legacy console) — it makes the cause much easier to pin down. For anything involving the tmux add-on, add `psmux -V` as well.
