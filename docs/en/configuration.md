# Configuration files and adding agents

[한국어](../ko/configuration.md) | **English**

Related: [README](../../README.en.md) · [Troubleshooting](troubleshooting.md)

Everything lives under `~/.mtw/`. Uninstalling then means deleting a single directory, and you can symlink the whole thing into a dotfiles repository.

| Path | Contents | Created by |
|---|---|---|
| `~/.mtw/projects` | the registered project list | the install script, as an empty file (kept as is if it already exists) |
| `~/.mtw/mtw.zsh` (macOS) | the implementation | the install script, copied from `macos/src/mtw.zsh` |
| `~/.mtw/mtw.ps1` (Windows) | the implementation | the install script, copied from `windows/src/mtw.ps1` |

---

## 1. `~/.mtw/projects` — the project list

### Format

```
# comment
myApp=/Users/minwoo/workspace/projects/myApp
project=/Users/minwoo/workspace/projects/project
```

- The form is `name=path`, with **no spaces around the `=`**.
- The first `=` separates the name from the path. A `=` inside the path is fine.
- The name format is **`^[A-Za-z_][A-Za-z0-9_-]*$`** — it starts with a letter or underscore, followed by letters, digits, underscores or hyphens.
- Both operating systems use the same format, but **do not share the file itself, because path notation differs.** On Windows an entry looks like `myApp=C:\Users\minwoo\projects\myApp`.
- A missing file is not an error. It is treated as an empty list, and `mtw_new` creates both the directory and the file before registering.
- Either LF or CRLF works. **Saving with CRLF does not leak a trailing CR into the path** — both operating systems strip it when loading.

### Editing it by hand is fine

It is an ordinary text file, so you can open it in an editor. After editing, open a new terminal or reload your profile (`source ~/.zshrc` / `. $PROFILE`) to pick up the change.

When `mtw_rm` rewrites the file it **removes only the target line and preserves comments, blank lines and the order of the remaining entries**. A file you have organized by hand stays organized.

One caveat: **line endings may be normalized to the platform default.** The macOS implementation preserves the original line endings, but on Windows `mtw_rm` unifies them when it rewrites the file. Since the list file is not meant to be shared across operating systems anyway (path notation differs) and both implementations read either LF or CRLF, this has no practical effect.

### Ignored lines — silently skipped

Lines matching any of the following are skipped **without a message**, because loading the profile has to stay quiet. If an entry you added does not show up in `mtw_list`, it hit one of these rules.

| Ignored line | Example |
|---|---|
| Blank line | |
| Line starting with `#` | `# comment` |
| Line with no `=` | `myApp` |
| Line with an empty name | `=/path/x` |
| Name not matching the format | `1abc=/path/x`, `my app=/path/x`, `my.app=/path/x` |

Name validation covers **the entire string**, and a line is ignored if the name contains even one control character, including NUL. The name is used directly as a function name, so loose validation would turn a single line of the list file into a code-execution path.

### Duplicate names

Two cases are distinguished, and **both operating systems behave identically**.

| Duplicate type | Result |
|---|---|
| **Exactly the same name** — `myApp=/path/ONE` and `myApp=/path/TWO` | **The later line wins.** `mtw_cd_myApp` jumps to `/path/TWO` |
| **Names differing only in case** — `Foo=/path/first` and `foo=/path/second` | **Only the first line is loaded**; the later one is silently ignored. `mtw_list` shows a single row, `mtw_cd_Foo` |

The case rule is first-come-first-served because **PowerShell function names are case-insensitive**, so `mtw_cd_Foo` and `mtw_cd_foo` cannot coexist. To keep both operating systems identical, the macOS implementation follows the same rule.

The duplicate check in `mtw_new` is also case-insensitive, so names differing only in case never get registered through the command in the first place. The rule above defines the behavior **when the file is edited by hand**.

---

## 2. The agent registry — adding an agent

`mtw_claude` and `mtw_codex` differ only in the command they run; everything else (session naming, path resolution, in-session detection, error handling) is identical. Rather than writing separate functions, the tool **generates them from a single registry line**. Adding an agent is a one-line change.

### macOS — top of `~/.mtw/mtw.zsh`

```zsh
typeset -gA MTW_AGENTS
MTW_AGENTS=(
  claude claude
  codex  codex
  aider  aider      # added: mtw_aider runs aider
)
```

Keys and values are listed separated by whitespace. The left side is the key (which becomes the `mtw_<key>` command), the right side is the command to run.

### Windows — top of `~/.mtw/mtw.ps1`

```powershell
$script:MTW_AGENTS = [ordered]@{
    claude = 'claude'
    codex  = 'codex'
    aider  = 'aider'      # added: mtw_aider runs aider
}
```

### Applying the change

Open a new terminal or reload your profile.

```bash
source ~/.zshrc      # macOS
```

```powershell
. $PROFILE           # Windows
```

The `mtw_aider` command appears, and `mtw_help` output and tab-completion targets pick it up automatically.

### Rules

- **Reserved words cannot be used as keys** — `list`, `new`, `rm`, `help`, `cd`. They would collide with the fixed commands (`mtw_list`, `mtw_new`, `mtw_rm`, `mtw_help`, `mtw_cd_*`).
  A reserved key produces a warning on stderr at load time and **only that entry's function is skipped**. The fixed command is never overwritten, and the entry is left out of `mtw_help` output and tab completion as well.

  ```
  mtw: 경고: 에이전트 키 'rm' 는 예약어(list new rm help cd) 와 겹쳐 건너뜁니다.
  ```

  (Messages are Korean in v1.0.0. This one reads: "warning: agent key 'rm' collides with a reserved word (list new rm help cd), skipping.")

- **The value must be a single command name.** The registry value is passed to tmux as one argument without word splitting, so multi-token commands containing spaces, such as `claude --model x`, are not supported in v1.0.0. If you want to add options, write a wrapper script and register its name instead.
- **The command must be on PATH.** This tool does not participate in installing, authenticating or adding agent CLIs to PATH.

### Making your edits survive

`~/.mtw/mtw.zsh` and `~/.mtw/mtw.ps1` are copies the install script made from the repository, so **re-running the install script overwrites them.** To keep an added agent, edit the repository original as well.

| OS | Repository original |
|---|---|
| macOS | `macos/src/mtw.zsh` |
| Windows | `windows/src/mtw.ps1` |

---

## 3. The loader block in your profile

The install script appends the following block to the end of your profile. The two marker lines are how the uninstall script finds the block, so **do not change their text.**

**macOS** — `~/.zshrc`

```zsh
# >>> mtw (mw-terminal-worknav) >>>
[[ -f "$HOME/.mtw/mtw.zsh" ]] && source "$HOME/.mtw/mtw.zsh"
# <<< mtw (mw-terminal-worknav) <<<
```

**Windows** — `$PROFILE`

```powershell
# >>> mtw (mw-terminal-worknav) >>>
if (Test-Path "$HOME\.mtw\mtw.ps1") { . "$HOME\.mtw\mtw.ps1" }
# <<< mtw (mw-terminal-worknav) <<<
```

- **On macOS this block must be at the end of `.zshrc`.** Registering tab completion requires `compdef`, which only exists after `compinit` has run. Moving the block higher up leaves everything else working and **breaks tab completion only** (see [Troubleshooting](troubleshooting.md)).
- If the markers are not exactly one pair (one start, one end, start first), the install and uninstall scripts **abort without touching the profile** and only tell you to clean it up yourself.
