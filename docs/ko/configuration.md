# 설정 파일과 에이전트 추가

**한국어** | [English](../en/configuration.md)

관련 문서: [README](../../README.md) · [문제 해결](troubleshooting.md)

모든 설정은 `~/.mtw/` 한 곳에 모입니다. 제거할 때 디렉터리 하나만 지우면 되고, dotfiles 저장소에 심볼릭 링크로 통째로 연결할 수도 있습니다.

| 경로 | 내용 | 만든 주체 |
|---|---|---|
| `~/.mtw/projects` | 등록된 프로젝트 목록 | 설치 스크립트가 빈 파일로 생성 (이미 있으면 보존) |
| `~/.mtw/mtw.zsh` (macOS) | 기능 본체 | 설치 스크립트가 `macos/src/mtw.zsh` 를 복사 |
| `~/.mtw/mtw.ps1` (Windows) | 기능 본체 | 설치 스크립트가 `windows/src/mtw.ps1` 을 복사 |
| `~/.mtw/mtw-tmux.zsh` (macOS) | tmux 애드온 | `--with-tmux` 로 설치했을 때만 복사 |
| `~/.mtw/mtw-psmux.ps1` (Windows) | psmux 애드온 | `-WithPsmux` 로 설치했을 때만 복사 |

---

## 1. `~/.mtw/projects` — 프로젝트 목록

### 형식

```
# 주석
myApp=/Users/minwoo/workspace/projects/myApp
project=/Users/minwoo/workspace/projects/project
```

- `이름=경로` 형식이며 **`=` 앞뒤에 공백을 넣지 않습니다.**
- 첫 번째 `=` 를 기준으로 좌측이 이름, 우측이 경로입니다. 경로 안에 `=` 가 있어도 문제없습니다.
- 이름 형식은 **`^[A-Za-z_][A-Za-z0-9_-]*$`** 입니다 — 영문자나 밑줄로 시작하고, 이후에는 영문자·숫자·밑줄·하이픈만 옵니다.
- 양쪽 OS 가 같은 형식을 쓰지만 **경로 표기가 다르므로 파일 자체를 공유하지는 마세요.** Windows 는 `myApp=C:\Users\minwoo\projects\myApp` 형태가 됩니다.
- 파일이 아예 없어도 오류가 나지 않습니다. 빈 목록으로 처리되며, `mtw_new` 를 실행하면 디렉터리와 파일을 함께 만든 뒤 등록합니다.
- 개행은 LF·CRLF 어느 쪽이든 됩니다. **CRLF 로 저장해도 줄 끝의 CR 은 경로에 포함되지 않습니다** — 양 OS 모두 적재 시 제거합니다.

### 직접 편집해도 됩니다

평범한 텍스트 파일이므로 편집기로 열어 고쳐도 됩니다. 편집 후에는 새 터미널을 열거나 프로필을 다시 읽으면(`source ~/.zshrc` / `. $PROFILE`) 반영됩니다.

`mtw_rm` 은 파일을 다시 쓸 때 **대상 줄만 빼고 주석·빈 줄·나머지 항목의 순서를 그대로 보존**합니다. 손으로 정리해 둔 파일이 흐트러지지 않습니다.

다만 **개행 문자는 그 OS 의 기본 개행으로 통일될 수 있습니다** — macOS 판은 원본 개행을 유지하지만, Windows 판은 `mtw_rm` 이 파일을 다시 쓰면서 개행을 통일합니다. 목록 파일은 경로 표기가 달라 어차피 OS 간 공유 대상이 아니고, 양쪽 구현 모두 LF·CRLF 어느 쪽이든 읽으므로 실사용에 영향은 없습니다.

### 무시되는 줄 — 조용히 건너뜁니다

아래에 해당하는 줄은 **아무 메시지 없이** 건너뜁니다. 프로필 로드가 조용해야 하기 때문입니다. 넣은 항목이 `mtw_list` 에 보이지 않는다면 이 규칙에 걸린 것입니다.

| 무시되는 줄 | 예 |
|---|---|
| 빈 줄 | |
| `#` 으로 시작하는 줄 | `# 주석` |
| `=` 가 없는 줄 | `myApp` |
| 이름이 비어 있는 줄 | `=/path/x` |
| 이름이 형식에 맞지 않는 줄 | `1abc=/path/x`, `my app=/path/x`, `my.app=/path/x` |

이름 검증은 **문자열 전체**를 대상으로 하며, NUL 을 포함한 제어문자가 하나라도 섞이면 그 줄은 무시됩니다. 이름이 그대로 함수 이름으로 쓰이는 구조라서, 검증을 느슨하게 두면 목록 파일 한 줄이 코드 실행 경로가 되기 때문입니다.

### 중복된 이름을 넣었을 때

두 경우를 구분하며, **양쪽 OS 에서 동일하게 동작**합니다.

| 중복 유형 | 결과 |
|---|---|
| **완전히 같은 이름** — `myApp=/path/ONE` 과 `myApp=/path/TWO` | **나중 줄이 이깁니다.** `mtw_cd_myApp` 은 `/path/TWO` 로 이동합니다 |
| **대소문자만 다른 이름** — `Foo=/path/first` 와 `foo=/path/second` | **먼저 나온 줄만 적재되고** 뒤 줄은 조용히 무시됩니다. `mtw_list` 에도 `Foo` 한 행만 나옵니다 |

대소문자 규칙이 선착순인 이유는 **PowerShell 의 함수 이름이 대소문자를 구분하지 않아** `mtw_cd_Foo` 와 `mtw_cd_foo` 를 동시에 가질 수 없기 때문입니다. 양쪽 OS 동작을 일치시키기 위해 macOS 판도 같은 규칙을 따릅니다.

`mtw_new` 의 중복 검사도 대소문자를 무시하므로, 명령을 통해서는 대소문자만 다른 이름이 애초에 등록되지 않습니다. 위 규칙은 **파일을 손으로 편집한 경우**의 동작을 정한 것입니다.

---

## 2. 에이전트 레지스트리 — 에이전트 추가

> **멀티플렉서 애드온(macOS = tmux · Windows = psmux)을 설치한 경우에만 해당합니다.** 기본 설치에는 에이전트 명령이 없습니다.

`mtw_claude` 와 `mtw_codex` 는 실행하는 명령만 다르고 나머지 로직(세션명 산출, 경로 결정, 세션 내부 판별, 오류 처리)이 완전히 같습니다. 그래서 함수를 따로 두지 않고 **레지스트리 한 줄에서 함수를 자동 생성**합니다. 에이전트 추가는 한 줄 추가로 끝납니다.

### macOS — `~/.mtw/mtw-tmux.zsh` 상단

```zsh
typeset -gA MTW_AGENTS
MTW_AGENTS=(
  claude claude
  codex  codex
  aider  aider      # 추가한 줄: mtw_aider 가 aider 를 실행
)
```

키와 값을 공백으로 구분해 나열합니다. 왼쪽이 키(`mtw_<키>` 명령이 됨), 오른쪽이 실행할 명령입니다.

### Windows — `~/.mtw/mtw-psmux.ps1` 상단

```powershell
$script:MTW_AGENTS = [ordered]@{
    claude = 'claude'
    codex  = 'codex'
    aider  = 'aider'      # 추가한 줄: mtw_aider 가 aider 를 실행
}
```

### 반영

편집 후 새 터미널을 열거나 프로필을 다시 읽으면 됩니다.

```bash
source ~/.zshrc      # macOS
```

```powershell
. $PROFILE           # Windows
```

`mtw_aider` 명령이 생기고, `mtw_help` 출력과 탭 자동완성 대상에도 자동으로 반영됩니다.

### 규칙

- **예약어를 키로 쓸 수 없습니다** — `list` · `new` · `rm` · `help` · `cd`. 고정 명령(`mtw_list` · `mtw_new` · `mtw_rm` · `mtw_help` · `mtw_cd_*`)과 충돌하기 때문입니다.
  예약어를 넣으면 로드 시 stderr 로 경고가 나오고 **그 항목의 함수 생성만 건너뜁니다.** 고정 명령은 덮어써지지 않으며, `mtw_help` 출력과 자동완성 대상에서도 함께 빠집니다.

  ```
  mtw: 경고: 에이전트 키 'rm' 는 예약어(list new rm help cd) 와 겹쳐 건너뜁니다.
  ```

- **값은 단일 명령 이름이어야 합니다.** 레지스트리 값은 단어 분할 없이 하나의 인자로 tmux 에 전달되므로, `claude --model x` 처럼 공백이 포함된 다중 토큰 명령은 v2.0.0 에서 지원하지 않습니다. 옵션을 붙이고 싶다면 래퍼 스크립트를 만들어 그 이름을 레지스트리에 등록하세요.
- **명령은 PATH 에 있어야 합니다.** 이 도구는 에이전트 CLI 의 설치·인증·PATH 등록에 관여하지 않습니다.

### 편집한 내용을 유지하려면

`~/.mtw/` 안의 파일은 설치 스크립트가 저장소에서 복사한 것이라, **설치 스크립트를 다시 실행하면 덮어써집니다.** 추가한 에이전트를 계속 쓰려면 저장소의 원본도 함께 고쳐 두세요.

| OS | 저장소 원본 |
|---|---|
| macOS | `macos/src/mtw-tmux.zsh` |
| Windows | `windows/src/mtw-psmux.ps1` |

애드온은 **플래그를 줄 때만** 복사됩니다. macOS 는 `--with-tmux`, Windows 는 `-WithPsmux` 없이 재설치하면 애드온 파일 자체가 삭제되므로, 편집한 내용도 함께 사라집니다.

---

## 3. 프로필의 로더 블록

설치 스크립트가 프로필 끝에 아래 블록을 추가합니다. 마커 두 줄은 제거 스크립트가 블록을 찾는 기준이므로 **문구를 바꾸지 마세요.**

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

- **애드온은 이 블록이 아니라 기능 본체가 읽습니다.** 본체 마지막 줄이 애드온 파일(`~/.mtw/mtw-tmux.zsh` · `~/.mtw/mtw-psmux.ps1`)의 존재를 확인하고 있으면 로드합니다. 그래서 로더 블록은 애드온 유무와 무관하게 늘 위 세 줄이며, 이미 설치된 환경에서 애드온만 켜고 끄는 데 프로필 수정이 필요 없습니다.
- **macOS 에서는 이 블록이 `.zshrc` 의 끝에 있어야 합니다.** 탭 자동완성 등록에 `compdef` 가 필요한데, `compdef` 는 `compinit` 이 실행된 뒤에만 존재하기 때문입니다. 블록을 위로 옮기면 다른 기능은 정상이고 **자동완성만 동작하지 않습니다**([문제 해결](troubleshooting.md) 참고).
- 마커가 한 쌍(시작 1회 + 종료 1회, 시작이 앞)이 아니면 설치·제거 스크립트는 **프로필을 건드리지 않고 중단**합니다. 사용자가 직접 정리하도록 안내만 합니다.
