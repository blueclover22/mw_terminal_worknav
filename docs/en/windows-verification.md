# Windows verification and test procedure

[한국어](../ko/windows-verification.md) | **English**

This document is **the procedure for verifying mtw on real Windows hardware**. Every item states what to do, what to expect, and what separates a pass from a failure — all written out here. You can complete the verification from this document alone, without consulting anything else.

Related: [README](../../README.en.md) · [Installing psmux](install-psmux.md) · [Configuration](configuration.md) · [Troubleshooting](troubleshooting.md)

> Runtime messages are Korean in v1.0.0. Expected strings are quoted verbatim in Korean because **byte equality with the macOS implementation is exactly what is being verified**; an English gloss follows where it helps.

---

## 0. Read this first — the scope is narrower than you think

**"Do I have to verify the whole Windows implementation from scratch?" — No.**

The Windows implementation (`windows/src/mtw.ps1`, `windows/install.ps1`, `windows/uninstall.ps1`) has already been verified extensively using PowerShell 7 installed on macOS, the development environment. That covered syntax checks, real execution of the scenarios below, **byte-level comparison** of messages and exit codes against the macOS implementation, and failure injection (backup, copy, delete and write failures). In other words, **"it behaves as specified at the PowerShell language level" is already established**.

What remains are **the items that can only be observed on Windows itself — the OS, its console, and the psmux binary**. Those are the six below (W1–W6), and W1 and W2 come first because they verify **a design premise itself**.

The full scenario list (chapter 3) is provided for regression checking, but **the priority order is chapter 1 → chapter 2 → chapter 3**.

> ### ⚠ Back up before you start
>
> **From chapter 2 onward you are touching real data.** Chapter 2 (W4, W5, W6) and most of chapter 3 run `mtw_*` commands **in the session you are sitting in**, so they use your real `~\.mtw\`. `$HOME` is a read-only variable fixed when the session starts, so the isolation in 3.0 (setting `$env:USERPROFILE`) only applies to **the install and uninstall scripts, which run as child processes**.
>
> In particular, W5 **overwrites** the list file and scenario 34 **deletes `~\.mtw` entirely**. Back up these three first.
>
> ```powershell
> Copy-Item "$HOME\.mtw\projects" "$HOME\.mtw\projects.verify-backup" -ErrorAction SilentlyContinue
> Copy-Item "$HOME\.mtw\mtw.ps1"  "$HOME\.mtw\mtw.ps1.verify-backup"  -ErrorAction SilentlyContinue
> Copy-Item $PROFILE "$PROFILE.verify-backup" -ErrorAction SilentlyContinue
> ```
>
> When you are done, restore from the backups or re-run the install script to get back to your original state.

---

## 1. Top-priority premise checks (before anything else)

The three items below do not verify an individual feature; they verify the premise that **"both operating systems drive the multiplexer through the single command `tmux`"**. If 1 or 2 fails, passing any number of individual scenarios means nothing and **a follow-up design adding a Windows-specific call form is required**. Please open an issue if either fails.

### Premise 1 — does psmux support the `-A` / `-c` flags of `new-session`?

```powershell
mkdir $env:TEMP\mtw-precheck -Force | Out-Null
tmux new-session -A -s mtwtest -c $env:TEMP\mtw-precheck pwsh
```

| Expected | A session `mtwtest` is created, its starting directory is `$env:TEMP\mtw-precheck`, and `pwsh` is running |
|---|---|
| **Pass criterion** | Pass if `Get-Location` inside the session prints `...\mtw-precheck`. Fail if it exits with an error or does not recognize the flags |
| **What breaks on failure** | Session creation and start-path selection do not work on Windows at all. `mtw_claude` and `mtw_codex` become useless and the "same command on both operating systems" premise collapses |

Clean up afterwards — `tmux kill-session -t mtwtest`.

### Premise 2 — is the `TMUX` environment variable set inside a psmux session?

Run this inside a session.

```powershell
$env:TMUX
```

| Expected | A non-empty value (a socket path or similar) is printed |
|---|---|
| **Pass criterion** | Pass if a value is printed. Fail if nothing is printed (empty) |
| **What breaks on failure** | The branch "inside a session, open a new window instead of a new session" is **always false**, so calling an agent from inside a session tries to create another session. Using two agents on one project stops working. A follow-up design is required to find an alternative detection mechanism (a psmux-specific environment variable, for example) |

### Premise 3 — is the `tmux` command installed by psmux equivalent to psmux itself?

```powershell
tmux -V
psmux -V
Get-Command tmux | Select-Object Source
```

| Expected | `tmux -V` and `psmux -V` report the same version, and the `tmux` executable lives under the psmux install directory |
|---|---|
| **Pass criterion** | Pass if the two versions match. If they differ, **just record it** and judge by the results of premises 1 and 2 (a separate tmux may be installed) |

---

## 2. Items observable only on real Windows (W1–W6)

These are the "genuinely unverified areas" mentioned in chapter 0. There are exactly six.

### W1 — psmux support for `new-session -A` / `-c`

Same as premise 1 in chapter 1. The psmux binary exists only on Windows, so it could not be reproduced in the development environment. **Reuse the result of premise 1.**

### W2 — the `TMUX` environment variable inside a psmux session

Same as premise 2 in chapter 1. **Reuse the result of premise 2.**

### W3 — does the Korean in error messages survive the Windows console?

Error messages are written with `$host.UI.WriteErrorLine`. The macOS terminal is always UTF-8 so code pages are a non-issue there, but the Windows console can be affected.

```powershell
mtw_new                        # missing name -> two error lines
mtw_rm 없는이름                # unregistered name -> one error line
chcp                           # current code page (for the record)
```

| Expected | The strings below are printed **without a single broken character** |
|---|---|
| | `오류: 이름을 입력하세요.` / `사용법: mtw_new <이름>` / `오류: 등록되지 않은 이름입니다: 없는이름` |
| **Pass criterion** | Pass if they render exactly, with no question marks, boxes or mojibake. On failure, record the code page (`chcp` output) and the console type (Windows Terminal / legacy console / VS Code terminal) |

Please check both Windows Terminal and the legacy console host (`conhost`). Record both if the results differ.

### W4 — do paths containing backslashes survive unchanged?

**On Windows the path separator itself is a backslash** (`C:\Users\...`), so **every registered path is subject to this item**. On macOS it was an edge case; on Windows it is the norm. The procedure is in "Backslash literal preservation" in chapter 5.

### W5 — are line contents preserved when the list file is rewritten?

`mtw_rm` rewrites the list file and must **preserve everything except the target line**. What to check is **line contents, order, comments and blank lines**.

> **Line endings get unified — this is known behavior, not a defect.** The PowerShell implementation of `mtw_rm` reads the file line by line and writes it back, so **the resulting file's line endings are unified to the platform default**. Running `mtw_rm` on a CRLF list file under PowerShell on macOS was measured to produce LF throughout, and **on Windows the opposite is expected — an LF file becoming CRLF**. The macOS implementation (zsh) preserves the original line endings, so the two implementations differ here.
>
> It was left as is for two reasons. (1) The list file is **per-OS local data** and is not meant to be shared across operating systems anyway, since path notation differs. (2) Within one OS it is self-consistent — the install script and `mtw_new` also write with that platform's default line ending, and both implementations read either LF or CRLF. All that is lost is line-ending bytes; line contents are preserved.
>
> **Therefore CR appearing or disappearing is not by itself a failure.** It is a failure if a line disappears, the order changes, comments or blank lines vanish, or characters within a line are altered.

```powershell
# This overwrites the list file, so back it up first (skip if you did it in chapter 0)
$p = "$HOME\.mtw\projects"
Copy-Item $p "$p.verify-backup" -ErrorAction SilentlyContinue

# Create a list file that uses LF only
[System.IO.File]::WriteAllText($p, "# 주석`nalpha=C:\tmp\alpha`nbeta=C:\tmp\beta`n")
(Get-Item $p).Length                     # note this down

. $PROFILE                               # reload
mtw_rm beta

# Inspect the result byte by byte
[System.IO.File]::ReadAllBytes($p) | ForEach-Object { $_ }
```

| Expected | The remaining lines are `# 주석` and `alpha=C:\tmp\alpha`, in that order and with their characters intact |
|---|---|
| **Pass criterion** | Pass if the **contents and order** of the two lines are preserved and only the `beta` line is gone. Line endings turning into `13 10` (CRLF) pairs is **the known behavior described above and is not a failure**. Fail if more lines disappear or characters are altered |

**Check the profile as well.** After an install → uninstall round trip the profile must be **byte-identical**.

```powershell
$b = (Get-FileHash $PROFILE -Algorithm MD5).Hash
pwsh -NoProfile -File .\windows\install.ps1   | Out-Null
pwsh -NoProfile -File .\windows\uninstall.ps1 | Out-Null
(Get-FileHash $PROFILE -Algorithm MD5).Hash -eq $b     # must be True
```

Repeat the same procedure with a CRLF list file and check that **line contents are preserved**. Whichever way the line endings are unified does not affect the verdict. Please **record which line ending actually resulted** — that value is being observed on real Windows for the first time.

### W6 — are sorting and tab completion as expected in a real console?

**Sorting** — `mtw_list` prints entries in ascending name order. If sorting depends on the system locale, the order of `I` / `i` changes under a Turkish locale, for example.

```powershell
# With several names of mixed case registered
mtw_list
```

| Pass criterion | The output order is identical on every run; record the locale in use. If you can switch locales, record whether the order changes |
|---|---|

**Tab completion** — observable only in a real console (PSReadLine).

```powershell
mtw_rm <Tab>
mtw_claude <Tab>
mtw_cd_<Tab>
```

| Pass criterion | Pass if the first two suggest registered project names and the last suggests `mtw_cd_*` function names |
|---|---|

---

## 3. Scenario list

### 3.0 Preparing the environment — avoiding damage to your real `HOME`

The install and uninstall scenarios (1–4, 29–31) **actually modify your profile and `~/.mtw/`**. Running them isolated in a temporary directory is recommended.

```powershell
$iso = Join-Path $env:TEMP 'mtw-verify'
New-Item -ItemType Directory -Path $iso -Force | Out-Null
$env:USERPROFILE = $iso

# Confirm in a child process that the isolation actually took effect
pwsh -NoProfile -Command '$HOME; $PROFILE'
```

> **You must check this.** Both `$HOME` and `$PROFILE` in the output must point inside the temporary directory for the isolation to hold. The location of the Documents folder on Windows comes from the registry and is frequently redirected to OneDrive, so **`$HOME` may change while `$PROFILE` still points at your real Documents folder.**
>
> If `$PROFILE` points outside the temporary directory, give up on isolation and **back up your real profile first**.
>
> ```powershell
> Copy-Item $PROFILE "$PROFILE.manual-backup" -ErrorAction SilentlyContinue
> ```
>
> The install and uninstall scripts do make their own backup (`*.bak-YYYYMMDD-HHMMSS`) before modifying the profile, but during verification a second, manual backup is safer.

**This isolation applies to child processes only.** `$HOME` is a read-only variable fixed when the session starts, so changing `$env:USERPROFILE` as above leaves **the current session's `$HOME` unchanged**. To run the feature scenarios in isolation too, **set the variable and then start a new `pwsh` session**, and run the install, `. $PROFILE` and the `mtw_*` commands inside that session.

```powershell
$env:USERPROFILE = $iso
pwsh                      # this child session's $HOME is $iso — run the scenarios here
```

The feature scenarios (5–28, 32–35, 38–40) never touch the profile, but they do work on **all of `~/.mtw/`** — besides the list file they **edit the installed implementation (`mtw.ps1`)** (#27, #33 and the dummy note at the end of 3.2) and **delete the directory entirely** (#34). If you proceed without isolation, make the three backups from chapter 0 first.

### 3.1 Install / uninstall (1–4, 29–31)

| # | Scenario | Expected | Pass criterion |
|---|---|---|---|
| 1 | Run `pwsh -NoProfile -File .\windows\install.ps1` in a clean environment | `~\.mtw\` created, `mtw.ps1` copied, `projects` created empty, loader block appended once | `~\.mtw\mtw.ps1` exists, `(Get-Item ~\.mtw\projects).Length` is **0**, `# >>> mtw (mw-terminal-worknav) >>>` appears **exactly once** in the profile, exit code 0 |
| 2 | Run the install script twice in a row | No duplicate profile entry, implementation refreshed, `projects` preserved | The second run prints `mtw: 프로필에 이미 로더 블록이 있어 건너뜁니다: <path>` ("loader block already present, skipping"), the marker still appears **once**, `projects` is unchanged, exit code 0 |
| 3 | Install over a profile that already has content | Backup created, existing content preserved | A `<profile>.bak-YYYYMMDD-HHMMSS` file appears whose contents are **byte-identical** to the pre-install profile. Afterwards the profile is the original content plus the three loader-block lines |
| 4 | Move outside the repository (e.g. `C:\`) and call the install script by absolute path | Installs normally | Same criteria as #1. The script locates `src\mtw.ps1` relative to its own location, so the working directory must not matter |
| 29 | Open a new terminal after uninstalling | Commands unrecognized, profile intact | In a new session `Get-Command mtw_list -ErrorAction SilentlyContinue` **returns nothing**. The marker appears **zero** times in the profile and your own lines are untouched |
| 30 | Uninstall without options | Project list survives | `~\.mtw\projects` still exists with the same contents. Output includes `mtw: 프로젝트 목록은 보존됩니다: <path>` ("the project list is preserved") |
| 31 | Reinstall after uninstalling | The list is restored as it was | `mtw_list` output after reinstalling matches what it was before uninstalling |

The uninstall commands are:

```powershell
pwsh -NoProfile -File .\windows\uninstall.ps1                    # keep the list
pwsh -NoProfile -File .\windows\uninstall.ps1 -RemoveProjects    # delete all of ~\.mtw\
```

### 3.2 Features — always performed (5–18, 20, 22–28)

Start each scenario in a new session with the profile loaded (`. $PROFILE`). **Check exit status with `$LASTEXITCODE`** — PowerShell functions do not set a process exit code, so that variable is the criterion. The public commands set it to **1 on failure and 0 on success**, so a 1 from an earlier failure lingering past a later success is a defect.

| # | Scenario | Expected | Pass criterion |
|---|---|---|---|
| 5 | `mtw_new` with no name | Error plus usage, failure, list file unchanged | The two lines `오류: 이름을 입력하세요.` and `사용법: mtw_new <이름>`, `$LASTEXITCODE` is **1**, list file size and contents unchanged |
| 6 | `mtw_new 1abc` / `mtw_new "a b"` | Format error, failure | `오류: 올바르지 않은 이름입니다: 1abc (허용 형식: ^[A-Za-z_][A-Za-z0-9_-]*$)`, `$LASTEXITCODE` is **1**, list file unchanged |
| 7 | `mtw_new` with an already registered name | Reports the existing path and stops | `오류: 이미 등록된 이름입니다: myApp -> <existing path>`, `$LASTEXITCODE` is **1**, list file unchanged |
| 8 | `mtw_new myApp`, then `mtw_new MYAPP` from another folder | Rejected as a duplicate, case-insensitively | Same error as #7, `$LASTEXITCODE` is **1** |
| 9 | `mtw_new list` (same name as a fixed command) | Registers normally, `mtw_list` unaffected | Prints `등록되었습니다: mtw_cd_list -> <path>`, `mtw_list` still prints the list (does not jump), and the function `mtw_cd_list` exists |
| 10 | A normal `mtw_new myApp` | Usable immediately | Prints `등록되었습니다: mtw_cd_myApp -> <current path>`, and `mtw_cd_myApp` works **without a restart** |
| 11 | Register and jump using a path with spaces and non-ASCII characters (e.g. `C:\temp\한글 폴더`) | Registers and jumps normally | After `mtw_cd_<name>`, `Get-Location` matches that path **exactly** |
| 12 | `mtw_list` with an empty list — (a) file missing (b) empty file | An informational message, no error | Both cases print `등록된 프로젝트가 없습니다. mtw_new <이름> 으로 현재 폴더를 등록하세요.` with no error |
| 13 | `mtw_rm` with no name | Error plus usage, failure | `오류: 이름을 입력하세요.` / `사용법: mtw_rm <이름>`, `$LASTEXITCODE` is **1**, list file unchanged |
| 14 | `mtw_rm <unregistered name>` | Error, failure | `오류: 등록되지 않은 이름입니다: <name>`, `$LASTEXITCODE` is **1**, list file unchanged |
| 15 | `mtw_rm <registered name>` | Entry removed, function immediately gone | Prints `등록 해제되었습니다: <name> (폴더는 그대로 남아 있습니다: <path>)`, and `Get-Command mtw_cd_<name> -ErrorAction SilentlyContinue` **returns nothing** |
| 16 | `mtw_rm` on a list containing comments and blank lines | Only the target line removed, the rest preserved | Comparing before and after, **only the target line** is gone; comments, blank lines and the order of other entries are intact. Check the line-ending outcome together with W5 |
| 17 | Check the folder after `mtw_rm` | The folder is untouched | `Test-Path <path>` is **True** |
| 18 | `mtw_claude` with no argument inside a folder | Session created, named after the current folder | `tmux ls` shows a session named after the current folder (with special characters replaced by `_`), whose start path is that folder |
| 20 | `mtw_claude <unregistered name>` | Error, failure, no session | `mtw: 오류: 등록되지 않은 이름입니다: <name>`, `$LASTEXITCODE` is **1**, and `tmux ls` shows **no** session with that name |
| 22 | Run an agent command from inside a session | A **new window**, not a new session | The session count in `tmux ls` does not grow; the current session gains one window |
| 23 | Run again with an existing session name | Attaches to the existing session, agent not launched | No new session is created, you land in the existing one, and the agent is **not launched again** (this is correct behavior) |
| 24 | `mtw_cd_<Tab>` | Registered projects suggested | Registered names are suggested |
| 25 | `mtw_claude <Tab>` / `mtw_rm <Tab>` | Registered project names suggested | Registered names are suggested |
| 26 | `mtw_claude <Tab>` right after `mtw_new` | The new entry appears without a restart | The just-registered name is **among** the suggestions |
| 27 | Add an agent to the registry and reload | `mtw_<new>` created, help and completion updated | `mtw_help` shows a new line, `Get-Command mtw_<new>` returns a function, and `mtw_<new> <Tab>` suggests project names |
| 28 | Delete an entry from the list file and reload | The jump function is removed | `Get-Command mtw_cd_<deleted name> -ErrorAction SilentlyContinue` **returns nothing** |

**Scenarios 18, 20, 22 and 23 are performed without an agent CLI.** Temporarily add a dummy entry to the registry — add the line `dummy = 'pwsh'` in `~\.mtw\mtw.ps1` and reload your profile, and `mtw_dummy` lets you exercise session behavior alone. Remove the line when you are done.

### 3.3 Features — conditional (19, 21)

| # | Scenario | Precondition | Expected | Pass criterion |
|---|---|---|---|---|
| 19 | `mtw_claude <registered name>` | Only if Claude Code is on PATH | Session created at the registered path, Claude Code launched | The session name equals the registered name and Claude Code is running inside it |
| 21 | `mtw_codex <registered name>` | Only if Codex CLI is on PATH | Codex CLI launched at the registered path | Codex CLI is running inside the session |

> **An item skipped because the CLI is absent is recorded as "Not performed" and is never treated as a pass.** That is the rule in chapter 6.

### 3.4 Security and recovery (32–35) — check these first

These verify that the contents of the list file are **never executed as code**. This class of defect actually occurred during development, so please check it before anything else in chapter 3.

| # | Scenario | Expected | Pass criterion |
|---|---|---|---|
| 32 | Add malformed lines to the list file and reload | Those lines are **silently ignored**, no code runs, valid entries load normally | Nothing is printed, the lines do not appear in `mtw_list`, and the marker file below is **not created**. Valid entries are still there |
| 33 | Add a reserved key (`rm`) to the registry and reload | Warning on stderr, that key's function **skipped** | `mtw: 경고: 에이전트 키 'rm' 는 예약어(list new rm help cd) 와 겹쳐 건너뜁니다.` is printed, `Get-Command mtw_rm` returns **the original fixed command** (not overwritten), and it appears in neither `mtw_help` nor completion |
| 34 | Delete all of `~\.mtw` and run `mtw_new <name>` | Directory and list file created, then registered | `~\.mtw\projects` is recreated, the success message appears, and `mtw_cd_<name>` works immediately |
| 35 | NUL-byte bypass variants — (a) written directly into the list file (b) passed to `mtw_new` | (a) line silently ignored, no marker file (b) rejected as malformed, list file unchanged | See the criteria under each procedure below |

**Building the input for #32**

```powershell
$p = "$HOME\.mtw\projects"
Add-Content -LiteralPath $p -Value 'x() { : } ; echo "INJECTED-CODE-RAN" ; f=/tmp/y'
Add-Content -LiteralPath $p -Value '}; New-Item -ItemType File -Path "$env:TEMP\MTW_PWNED"; function _z {'
Remove-Item "$env:TEMP\MTW_PWNED" -ErrorAction SilentlyContinue   # guarantee it does not exist beforehand
. $PROFILE
```

Pass if the output contains no `INJECTED-CODE-RAN`, `Test-Path "$env:TEMP\MTW_PWNED"` is **False**, and neither line appears in `mtw_list`.

**Building the input for #35 (a)**

```powershell
$p = "$HOME\.mtw\projects"
$nul = [char]0
$payload = "x$nul}; New-Item -ItemType File -Path `"`$env:TEMP\MTW_NUL_PWNED`"; function _z {"
[System.IO.File]::AppendAllText($p, $payload + "`n")
Remove-Item "$env:TEMP\MTW_NUL_PWNED" -ErrorAction SilentlyContinue
. $PROFILE
```

Pass if `Test-Path "$env:TEMP\MTW_NUL_PWNED"` is **False**, the line does not appear in `mtw_list`, and valid entries in the same file still load.

**Building the input for #35 (b)**

```powershell
$nul = [char]0
$before = [System.IO.File]::ReadAllBytes("$HOME\.mtw\projects")
mtw_new "x$nul}; New-Item -ItemType File -Path `"`$env:TEMP\MTW_NUL_PWNED`"; function _z {"
$after = [System.IO.File]::ReadAllBytes("$HOME\.mtw\projects")
$LASTEXITCODE
Compare-Object $before $after
```

Pass if a format error is printed, `$LASTEXITCODE` is **1**, `Compare-Object` returns **nothing** (list file unchanged), and no marker file is created.

Remove the lines you added once you are done.

> **Restore the implementation after scenario 34.** `mtw_new` only recreates the directory and the list file — it **does not restore `mtw.ps1`**. Leave it missing and the loader block silently loads nothing from the next session on, so every later scenario fails with "command not found". Re-run the install script or restore your backup.
>
> ```powershell
> pwsh -NoProfile -File .\windows\install.ps1
> ```

### 3.5 Duplicate keys (39, 40)

This is the behavior when the list file is edited by hand. **The two items cover for each other, so do both** — checking only #40 would miss the regression #39 guards against.

| # | Scenario | Expected | Pass criterion |
|---|---|---|---|
| 39 | Put `myApp=C:\path\ONE` / `other=C:\path\o` / `myApp=C:\path\TWO` in the list file and reload | **The later value wins** | `mtw_list` shows **one** `myApp` row with the path `C:\path\TWO`, and `mtw_cd_myApp` jumps to `C:\path\TWO`. `other` loads normally |
| 40 | Put `Foo=C:\path\first` / `foo=C:\path\second` in the list file and reload | **The earlier line wins** | `mtw_list` shows **one** row whose value is `C:\path\first`. Only `mtw_cd_Foo` is generated and it jumps to `C:\path\first`. The `foo` line is ignored with no message |

#40 is first-come-first-served because **PowerShell function names are case-insensitive**, so `mtw_cd_Foo` and `mtw_cd_foo` cannot coexist. The macOS implementation follows the same rule so that both match.

### 3.6 Data preservation (38)

Backslash literal preservation. Its scope is much wider on Windows, so the procedure has its own section in chapter 5.

### 3.7 Repository level (36, 37)

Perform these in a repository cloned on Windows.

| # | Scenario | Expected | Pass criterion |
|---|---|---|---|
| 36 | Exclusion check — run `git check-ignore -v <path>` against `.claude/settings.local.json`, `*.bak-*` and the per-OS junk files (`.DS_Store`, `._*`, `.Spotlight-V100`, `.Trashes`, `Thumbs.db`, `ehthumbs.db`, `desktop.ini`, `$RECYCLE.BIN/`), and confirm tracked files (`README.md`, `LICENSE`, `windows/src/mtw.ps1`, …) are not ignored | All 10 exclusion targets ignored, tracked files not ignored | `git check-ignore` exits 0 with the matching rule for exclusion targets and exits 1 for tracked files |
| 37 | Line-ending check — clone with `core.autocrlf` set to `true`, `false` and `input` in turn | **The same working-tree line endings for all three settings** | `*.ps1` = **CRLF**; `*.sh`, `*.zsh`, `*.md`, `LICENSE`, `.gitignore` = **LF**. What is stored in the repository (the blob) is LF throughout |

An example of how to check #37.

```powershell
git config --global core.autocrlf true
git clone https://github.com/blueclover22/mw-terminal-worknav.git c1
# Does c1\windows\src\mtw.ps1 contain 13 10 pairs? Does c1\macos\install.sh contain no 13?
[System.IO.File]::ReadAllBytes("c1\windows\src\mtw.ps1") -contains 13     # must be True
[System.IO.File]::ReadAllBytes("c1\macos\install.sh")    -contains 13     # must be False
```

Repeat with `false` and `input`; pass if **all three produce the same result**.

---

## 4. Safety-net checks on failure (recommended)

The install and uninstall scripts must **not print a success message and must exit with code 1** when something fails. Normal-path scenarios never reveal this, so please check the following if you have time.

| Check | How | Pass criterion |
|---|---|---|
| Aborts when the profile backup fails | Make the folder containing the profile read-only, then install | Prints `mtw: 오류: 프로필을 백업하지 못해 중단합니다: <path>`, exit code 1, **profile unchanged** |
| Profile with two marker pairs / mismatched / reversed | Duplicate the marker lines by hand, then run install and uninstall separately | Prints `mtw: 오류: 프로필에서 로더 블록 마커를 안전하게 판별할 수 없습니다: <path>`, exit code 1, **profile unchanged** |
| Two runs within the same second | Install → uninstall → install → uninstall in quick succession | Backup files are not overwritten; they get `-2`, `-3` suffixes |
| Unknown option | Pass a wrong option, e.g. `pwsh -NoProfile -File .\windows\uninstall.ps1 -Remove` | Prints `mtw: 알 수 없는 옵션입니다: -Remove`, exit code 1, **nothing changed**. `-removeprojects` (lowercase), `-h` and an empty string must behave the same |
| Missing profile parent directory | Install in a clean environment where the profile folder does not exist at all | Creates the directory and the file and installs normally, exit code 0 |

---

## 5. Cross-checks against the macOS implementation

These judge whether "the two implementations produce the same commands, messages and exit codes". The **macOS expected values** below were observed on real macOS hardware; write the Windows result beside each one and compare.

| Cross-check | macOS expected value | How to check on Windows |
|---|---|---|
| Key validation — NUL and control characters blocked | Malformed lines are silently ignored and no code runs. `mtw_new` rejects with exit code 1 and leaves the list file unchanged | Follow procedures 32 and 35 in section 3.4. Judge by "no marker file" plus "list file unchanged" |
| Reserved registry keys skipped | Prints `mtw: 경고: 에이전트 키 'rm' 는 예약어(list new rm help cd) 와 겹쳐 건너뜁니다.` and does not create the function | Section 3.4 #33. Printing the warning is not enough — also confirm `Get-Command mtw_rm` returns the fixed command |
| `mtw_new` creating the directory | After deleting `~/.mtw`, it recreates directory and file and registers successfully | Section 3.4 #34 |
| The agent command passed as a single argument | The registry value is passed as one argument with no word splitting | Put `dummy = 'pwsh'` in the registry and run `mtw_dummy`. Pass if `pwsh` runs normally inside the session |
| Backslash literal preservation | The path you typed is unchanged in both display and storage | Separate procedure below |
| Commands, messages and exit codes match | See the message table below. Every failure is exit code 1 | Run each command and compare the strings **character by character**. Check exit status with `$LASTEXITCODE`. **The three "known differences" below are not defects** |
| Duplicate-key handling | Identical names: **later value wins**. Names differing only in case: **earlier line wins** | Section 3.5 #39 and #40 |

### Message table

The strings below must be **identical to the last character** on both operating systems (only the value parts such as `<path>` and `<name>` differ per OS).

| Situation | Expected string |
|---|---|
| `mtw_new` with no name | `오류: 이름을 입력하세요.` / `사용법: mtw_new <이름>` |
| `mtw_new` format violation | `오류: 올바르지 않은 이름입니다: <name> (허용 형식: ^[A-Za-z_][A-Za-z0-9_-]*$)` |
| `mtw_new` duplicate | `오류: 이미 등록된 이름입니다: <existing name> -> <existing path>` |
| `mtw_new` success | `등록되었습니다: mtw_cd_<name> -> <path>` |
| `mtw_rm` with no name | `오류: 이름을 입력하세요.` / `사용법: mtw_rm <이름>` |
| `mtw_rm` unregistered | `오류: 등록되지 않은 이름입니다: <name>` |
| `mtw_rm` success | `등록 해제되었습니다: <name> (폴더는 그대로 남아 있습니다: <path>)` |
| `mtw_new` — directory creation failed | `오류: 설치 디렉터리를 만들지 못했습니다: <path>` |
| `mtw_new` — list write failed | `오류: 목록 파일에 기록하지 못했습니다: <path>` |
| `mtw_rm` — list update failed | `오류: 목록 파일을 갱신하지 못했습니다: <path>` |
| `mtw_list` empty | `등록된 프로젝트가 없습니다. mtw_new <이름> 으로 현재 폴더를 등록하세요.` |
| Agent, unregistered name | `mtw: 오류: 등록되지 않은 이름입니다: <name>` |
| Reserved-key warning | `mtw: 경고: 에이전트 키 '<key>' 는 예약어(list new rm help cd) 와 겹쳐 건너뜁니다.` |
| Install — command name in use | `mtw: 경고: '<command>' 명령이 이미 사용 중입니다. 설치 후 충돌할 수 있습니다.` |
| Install — loader block added | `mtw: 로더 블록을 추가했습니다: <profile path>` |
| Install — already installed | `mtw: 프로필에 이미 로더 블록이 있어 건너뜁니다: <profile path>` |
| Install — directory creation failed | `mtw: 오류: 설치 디렉터리를 만들지 못했습니다: <path>` |
| Install/uninstall — backup | `mtw: 프로필을 백업했습니다: <backup path>` |
| Install/uninstall — profile unreadable | `mtw: 오류: 프로필을 읽지 못했습니다: <profile path>` |
| Uninstall — block removed | `mtw: 프로필에서 로더 블록을 제거했습니다: <profile path>` |
| Uninstall — no block found | `mtw: 프로필에 로더 블록이 없어 건너뜁니다: <profile path>` |
| Uninstall — no profile file | `mtw: 프로필 파일이 없어 건너뜁니다: <profile path>` |
| Uninstall — implementation deleted | `mtw: 기능 본체를 삭제했습니다: <path>` |
| Uninstall — list preserved | `mtw: 프로젝트 목록은 보존됩니다: <path>` |
| Uninstall — `~\.mtw` backed up | `mtw: ~\.mtw 를 백업했습니다: <backup path>` |
| Uninstall — `~\.mtw` deleted | `mtw: ~\.mtw 를 삭제했습니다 (프로젝트 목록 포함).` |
| Unknown option | `mtw: 알 수 없는 옵션입니다: <value>` |

`mtw_list` prints the command name **left-aligned in a 20-character field**, followed by the path.

```
mtw_cd_myApp        C:\Users\minwoo\projects\myApp
```

**The closing guidance strings differ on purpose.** Reloading a profile and restarting a session are platform-specific, so the differences below are expected — do not count them as mismatches.

| macOS | Windows |
|---|---|
| `이 스크립트는 별도 프로세스에서 실행되어 현재 터미널에는 반영되지 않습니다.` | `... 현재 세션에는 반영되지 않습니다.` |
| `새 터미널을 열거나 다음 명령으로 프로필을 다시 읽으세요: source ~/.zshrc` | `새 세션을 열거나 다음 명령으로 프로필을 다시 읽으세요: . $PROFILE` |
| `이미 열려 있는 터미널에는 mtw 함수가 메모리에 남아 있습니다.` | `이미 열려 있는 세션에는 ...` |
| `정리하려면 해당 터미널에서 다음을 실행하세요: exec zsh` | `정리하려면 해당 세션에서 새 PowerShell 세션을 시작하세요.` |
| Path notation `~/.mtw` · `mtw.zsh` | Path notation `~\.mtw` · `mtw.ps1` |

Also, **on failure the macOS implementation prints one extra line of raw error output from the underlying command (`cp:`, `rm:`) before the mtw message, while the Windows implementation prints only the mtw message.** That difference is expected too — what is being judged is **mtw's own message and exit code**.

### Known differences — no action required

The three items below are **differences whose cause and scope are settled**. Please do not report them as defects.

**Difference 1 — the PowerShell implementation's error output is not suppressed by `2>$null` nor captured by `2>&1`.**

It uses `$host.UI.WriteErrorLine` for error output. **PowerShell offers no way to satisfy byte-identical messages and redirectability at the same time** — `Write-Error` decorates output with the function name, file, line number, a `Line |` block and ANSI colors under every `$ErrorView` setting, and a custom `ErrorRecord` + `ErrorDetails` + `$PSCmdlet.WriteError` combination is decorated identically. What this tool requires is **that the message text match macOS**, so the text was chosen and redirectability given up.

- **Guaranteed**: the error text and the exit code match macOS.
- **Not guaranteed**: hiding errors with `mtw_rm foo 2>$null`.

**Difference 2 — `&&` / `||` chaining behaves differently from macOS.**

PowerShell's `&&` / `||` look at `$?` rather than `$LASTEXITCODE`, and **a function's non-terminating error does not flip `$?`** (`$? = True` was observed with `Write-Error` in all four placements tried). Only `throw` can flip `$?`, but it changes the control flow and the output format. So setting **`$LASTEXITCODE` to 1** on failure is the closest possible approximation.

- **Guaranteed**: you can judge success or failure from `$LASTEXITCODE`.
- **Not guaranteed**: chaining of the form `mtw_rm foo && echo ok`.

```powershell
mtw_rm foo
if ($LASTEXITCODE -eq 0) { 'ok' } else { 'failed' }
```

**Difference 3 — when `mtw_rm` rewrites the list file, line endings are unified to the platform default.**

The macOS implementation (zsh) preserves the original line endings, but the PowerShell implementation reads the file line by line and writes it back, so the result is unified (measured under PowerShell on macOS: CRLF became LF). The list file is **not meant to be shared across operating systems** because path notation differs, it is self-consistent within one OS (the install script and `mtw_new` also write with that platform's default), and both implementations read either LF or CRLF — so it was left as is.

- **Guaranteed**: only the target line is removed; the **contents, order, comments and blank lines** of the remaining lines are preserved.
- **Not guaranteed**: preservation of the original line-ending characters.

**Reading the list file is identical on both.** A trailing CR in a CRLF list file is **stripped from the path value on both operating systems**, so the registered path and the `mtw_cd_*` target agree.

**Your profile (`$PROFILE`) is not subject to this.** The install and uninstall scripts read and write the profile **byte for byte** — any encoding (UTF-8 with BOM, CP949, latin-1, …) round-trips unchanged, and the original line endings are preserved. The loader block is appended with **whatever line ending the profile already uses** (CRLF for a CRLF profile). Marker detection ignores a trailing CR, so it works on a CRLF profile too.

### Backslash literal preservation procedure (38 / W4)

**On Windows the path separator itself is a backslash, so every registered path is subject to this.** Do not settle for creating one exotic path; verify that **a perfectly ordinary path survives registration → listing → removal without a single character changing**. A wrong value written into the list file is not a display glitch but **data corruption**, so inspect the **file contents at the byte level**.

```powershell
# 1) An ordinary path
Set-Location C:\Users\minwoo\projects\myApp
mtw_new myApp

# 2) Inspect what was written, byte-wise
$p = "$HOME\.mtw\projects"
Get-Content -LiteralPath $p -Raw
[System.IO.File]::ReadAllText($p)      # both must equal the path you typed

# 3) Check the display
mtw_list                               # the path must appear unchanged

# 4) Check the jump
mtw_cd_myApp
(Get-Location).Path                    # must equal the registered path exactly

# 5) Check the removal message
mtw_rm myApp                           # the path in the message must be unchanged
```

Additionally, check a path that **could be misread as containing a tab escape**. Create a folder such as `C:\temp\a\tb`, repeat the same procedure, and verify at the byte level that the list file contains the **literal `a\tb`** rather than a tab character. If an actual tab (9) ended up in the file, that is a failure.

| Pass criterion | Pass if the path is **exactly identical** to the input at all five points, and the list-file bytes contain no unexpected transformation (tab 9, escape interpretation) |
|---|---|

---

## 6. Recording results

Record each item as **Pass / Fail / Not performed**.

> **Rule — "Not performed" is not a pass.** Anything skipped because an agent CLI was missing, the environment did not allow it, or time ran out must be recorded as "Not performed" with the reason. **If even one item is "Not performed", it is not "all items passed".**

- For **Fail**, write down the observed result exactly (message text, exit code, file state).
- Give a **Pass** only when the item's stated pass criterion is met. "Seems to work" is not a pass.

| Group | Item | Result | Observed result / reason not performed | Date |
|---|---|---|---|---|
| Premise | Premise 1 — `-A` / `-c` support | | | |
| Premise | Premise 2 — `TMUX` inside a session | | | |
| Premise | Premise 3 — `tmux` = psmux, same version | | | |
| Real HW | W3 — Korean output (Windows Terminal) | | | |
| Real HW | W3 — Korean output (legacy console) | | | |
| Real HW | W4 — backslash preservation | | | |
| Real HW | W5 — list-file line contents | | | |
| Real HW | W5 — profile encoding / line endings | | | |
| Real HW | W6 — sorting | | | |
| Real HW | W6 — tab completion | | | |
| Install | 1 clean install | | | |
| Install | 2 two consecutive installs | | | |
| Install | 3 existing profile + backup | | | |
| Install | 4 called from outside the repository | | | |
| Install | 29 new terminal after uninstall | | | |
| Install | 30 list preserved on uninstall | | | |
| Install | 31 reinstall after uninstall | | | |
| Feature | 5 missing name | | | |
| Feature | 6 invalid name | | | |
| Feature | 7 duplicate name | | | |
| Feature | 8 case-insensitive duplicate | | | |
| Feature | 9 name matching a fixed command | | | |
| Feature | 10 normal registration | | | |
| Feature | 11 path with spaces / non-ASCII | | | |
| Feature | 12 empty list | | | |
| Feature | 13 `mtw_rm` missing name | | | |
| Feature | 14 `mtw_rm` unregistered | | | |
| Feature | 15 `mtw_rm` normal | | | |
| Feature | 16 surrounding lines preserved | | | |
| Feature | 17 folder survives | | | |
| Feature | 18 agent call with no argument | | | |
| Feature | 20 unregistered name rejected | | | |
| Feature | 22 inside session → new window | | | |
| Feature | 23 attach does not launch the agent | | | |
| Feature | 24 `mtw_cd_<Tab>` | | | |
| Feature | 25 `mtw_rm` / agent `<Tab>` | | | |
| Feature | 26 completion updated right after registering | | | |
| Feature | 27 adding an agent | | | |
| Feature | 28 function removed after deleting an entry | | | |
| Conditional | 19 Claude Code launch | | | |
| Conditional | 21 Codex CLI launch | | | |
| Security | 32 malformed lines ignored | | | |
| Security | 33 reserved key skipped | | | |
| Security | 34 recovery after deleting `~\.mtw` | | | |
| Security | 35 NUL bypass (a) load path | | | |
| Security | 35 NUL bypass (b) `mtw_new` | | | |
| Duplicate | 39 identical keys | | | |
| Duplicate | 40 case-differing keys | | | |
| Repository | 36 ignore/track check | | | |
| Repository | 37 clone line endings | | | |
| Safety net | chapter 4, five checks | | | |
| Cross-check | chapter 5, messages and exit codes | | | |

---

## 7. After everything passes — remove the README notice

The "Requirements" table in the [README](../../README.en.md) marks Windows as **"awaiting verification on real Windows (developed and verified with PowerShell 7 on macOS)"**.

**Once every item in this document is recorded as "Pass", remove that notice.**

1. Confirm the table above contains **no "Fail" and no "Not performed"**.
2. In the README "Requirements" table, change the Windows cell of the `Verification status` row to `verified`, or delete the row entirely.
3. Clean up the "About the verification-status row" paragraph in the README as well.

**Do not remove it while a single item is still "Not performed"** — including the conditional items (19, 21) skipped because an agent CLI was missing. Either install the CLI and perform them, or leave the notice in place.
