# mw-terminal-worknav

**한국어** | [English](README.en.md)

터미널에서 등록해 둔 프로젝트 폴더로 즉시 이동하고, 폴더 이름을 세션명으로 삼아 멀티플렉서 세션을 띄운 뒤 AI 코딩 에이전트(Claude Code, Codex CLI)를 실행하는 셸 단축 명령 모음입니다. macOS(zsh + tmux)와 Windows(PowerShell 7 + psmux)에서 **같은 명령·같은 메시지·같은 종료 코드**로 동작합니다.

## 목차

1. [무엇을 하는가](#1-무엇을-하는가)
2. [요구 사항](#2-요구-사항)
3. [멀티플렉서 설치](#3-멀티플렉서-설치)
4. [mtw 설치](#4-mtw-설치)
5. [사용법](#5-사용법)
6. [설정 파일](#6-설정-파일)
7. [에이전트 추가](#7-에이전트-추가)
8. [제거](#8-제거)
9. [문제 해결](#9-문제-해결)
10. [라이선스](#10-라이선스)

---

## 1. 무엇을 하는가

```
mtw_new myApp       # 현재 폴더를 myApp 으로 등록
mtw_list            # 등록 목록 확인
mtw_rm myApp        # 등록 해제 (폴더는 그대로)
mtw_cd_myApp        # myApp 경로로 이동
mtw_claude          # 현재 폴더명으로 세션 생성 후 Claude Code 실행
mtw_claude myApp    # 등록된 myApp 경로에서 실행
mtw_codex           # 현재 폴더명으로 세션 생성 후 Codex CLI 실행
mtw_codex myApp     # 등록된 myApp 경로에서 실행
```

모든 명령이 `mtw_` 로 시작하므로 **`mtw_<Tab>` 하나로 전체 명령**을, **`mtw_cd_<Tab>` 으로 등록된 프로젝트 전체**를 확인할 수 있습니다. `mtw_rm` · `mtw_claude` · `mtw_codex` 는 인자 자리에서 `<Tab>` 을 누르면 등록된 프로젝트 이름을 제안합니다.

이동 명령이 `mtw_cd_` 라는 이중 접두사를 쓰는 이유는 프로젝트 이름에서 만들어지는 명령을 별도 네임스페이스로 격리하기 위해서입니다. `list` 라는 이름의 폴더를 등록해도 `mtw_cd_list` 가 생길 뿐, 관리 명령인 `mtw_list` 는 영향을 받지 않습니다.

## 2. 요구 사항

| 항목 | macOS | Windows |
|---|---|---|
| OS | macOS 12 이상 | Windows 10 / 11 |
| 셸 | zsh (기본 셸) | PowerShell 7 이상 |
| 멀티플렉서 | tmux | psmux |
| 에이전트 | Claude Code / Codex CLI 중 사용하는 것 (PATH 등록 필요) | 동일 |
| 검증 상태 | 개발·실기 검증 완료 | 실기 검증 완료 (Windows 11 · PowerShell 7.6.4 · psmux 3.3.7) |

에이전트 CLI(Claude Code, Codex CLI)의 설치·인증·PATH 등록은 사용자 책임이며 이 도구가 관여하지 않습니다. 등록하지 않아도 이동·목록 명령은 정상 동작합니다.

## 3. 멀티플렉서 설치

### macOS — tmux

```bash
brew install tmux
tmux -V          # 설치 확인
```

상세한 설치 방법과 기본 조작(세션 목록·detach·attach·창 전환)은 [`docs/ko/install-tmux.md`](docs/ko/install-tmux.md) 를 보세요.

### Windows — psmux

```powershell
winget install psmux
tmux -V          # 설치 확인
```

두 가지를 유의하세요.

- **PowerShell 7 은 별도 설치 대상입니다.** Windows 에 기본 탑재된 것은 Windows PowerShell 5.1 이며, 이 도구는 PowerShell 7 이상(`pwsh`)을 요구합니다. psmux 도 기본적으로 `pwsh` 를 실행하므로 이 부분에서 혼선이 잦습니다.
- **psmux 를 설치하면 `tmux` 명령도 함께 설치됩니다.** psmux 는 `psmux` · `pmux` · `tmux` 세 실행 명령을 모두 제공하므로, 이후 이 문서의 **사용법 안내는 양쪽 OS 공통**입니다.

scoop · cargo · chocolatey · GitHub Releases 등 다른 설치 경로와 `tmux` 명령에 대한 설명은 [`docs/ko/install-psmux.md`](docs/ko/install-psmux.md) 에 있습니다.

## 4. mtw 설치

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

> **`-NoProfile` 을 붙여 실행하세요.** 스크립트 자신도 사용자 프로필의 alias·함수에 가로채이지 않도록 방어하고 있지만(파일 조작 cmdlet 을 모듈 한정 이름으로 호출합니다), `-NoProfile` 은 그 위의 한 겹 더입니다.

설치 스크립트가 하는 일은 다음 네 가지뿐입니다.

1. `~/.mtw/` 생성
2. 기능 본체(`mtw.zsh` / `mtw.ps1`)를 `~/.mtw/` 로 복사 (**기존 파일은 덮어씀 — 재실행이 곧 업데이트**)
3. `~/.mtw/projects` 가 없으면 빈 파일로 생성 (**있으면 그대로 보존**)
4. 프로필(`~/.zshrc` / `$PROFILE`) 끝에 로더 블록 추가

프로필에 기존 내용이 있으면 **수정 전에 `.bak-YYYYMMDD-HHMMSS` 백업을 먼저 만들고**, 백업에 실패하면 프로필을 건드리지 않고 중단합니다. 이미 로더 블록이 있으면 프로필 수정을 건너뛰므로 **여러 번 실행해도 안전**합니다.

> **설치 후 새 터미널을 열거나 프로필을 다시 읽어야 합니다.** 설치 스크립트는 별도 프로세스에서 실행되므로 호출한 터미널에는 반영되지 않습니다.
>
> - macOS: `source ~/.zshrc`
> - Windows: `. $PROFILE`

설치본의 버전은 기능 본체 상단의 주석으로 확인합니다.

```bash
head -5 ~/.mtw/mtw.zsh                        # macOS
```

```powershell
Get-Content -TotalCount 5 ~/.mtw/mtw.ps1      # Windows
```

## 5. 사용법

### 등록 · 조회 · 해제

```
mtw_new <이름>      현재 폴더를 등록. 이름 형식은 ^[A-Za-z_][A-Za-z0-9_-]*$
mtw_list            등록된 프로젝트를 이름 오름차순으로 출력
mtw_rm <이름>       등록 해제 (폴더는 삭제하지 않음)
mtw_help            전체 명령 안내
```

```
$ mtw_new myApp
등록되었습니다: mtw_cd_myApp -> /Users/minwoo/workspace/projects/myApp

$ mtw_list
myApp       /Users/minwoo/workspace/projects/myApp

$ mtw_rm myApp
등록 해제되었습니다: myApp (폴더는 그대로 남아 있습니다: /Users/minwoo/workspace/projects/myApp)
```

- **등록 직후 바로 쓸 수 있습니다.** `mtw_new` 는 등록 후 목록을 다시 읽고 이동 함수를 다시 만들므로, 터미널을 재시작하지 않아도 `mtw_cd_myApp` 과 탭 자동완성이 즉시 동작합니다.
- **중복 검사는 대소문자를 무시합니다.** `myApp` 이 등록된 상태에서 `mtw_new MYAPP` 은 거부됩니다. 저장은 입력한 표기 그대로 합니다.
- **`mtw_rm` 의 이름 매칭도 대소문자를 무시합니다.** 별도 확인 절차는 없습니다 — 사라지는 것은 북마크 한 줄뿐이고 폴더는 그대로이기 때문입니다.
- 실패한 명령은 오류 메시지를 내고 **종료 코드 1** 로 끝나며, 목록 파일은 변경되지 않습니다.

### 이동

```
mtw_cd_<이름>       등록된 경로로 이동
```

등록된 항목 수만큼 자동으로 만들어집니다. 목록에서 사라진 항목의 함수는 다음 적재 시점에 제거됩니다.

### 에이전트 실행

```
mtw_claude [이름]   세션 생성 후 Claude Code 실행
mtw_codex  [이름]   세션 생성 후 Codex CLI 실행
```

| 호출 | 세션명 | 시작 경로 |
|---|---|---|
| `mtw_claude` | 현재 폴더명 | 현재 폴더 |
| `mtw_claude myApp` (등록된 이름) | `myApp` | 등록된 경로 |
| `mtw_claude tmp` (등록되지 않은 이름) | — | 오류 출력 후 중단, 종료 코드 1 |

내부적으로는 아래 두 형태 중 하나를 호출합니다. 양쪽 OS 가 완전히 같은 명령을 씁니다.

```
tmux new-session -A -s <세션명> -c <경로> <에이전트 명령>    # 세션 밖에서 호출했을 때
tmux new-window     -n <세션명> -c <경로> <에이전트 명령>    # 세션 안에서 호출했을 때
```

반드시 알아 두어야 할 동작 다섯 가지입니다.

- **에이전트를 종료하면 세션도 함께 종료됩니다.** 에이전트 명령이 창의 루트 프로세스이므로, Claude Code 에서 `/exit` 를 치면 창이 닫히고 마지막 창이면 세션까지 끝납니다. tmux 의 정상 동작입니다. 세션을 남기려면 종료 대신 detach 하세요 (`Ctrl-b d`). 세션 안에서 호출한 경우에는 새 창이므로 그 창만 닫힙니다.
- **등록되지 않은 이름을 주면 오류를 내고 중단합니다.** 세션은 만들어지지 않습니다.
- **이미 있는 세션에 `-A` 로 attach 되는 경우, 뒤에 붙인 에이전트 명령은 실행되지 않습니다.** tmux 의 정상 동작이며 우회하지 않습니다. 즉 `mtw_claude myApp` 을 두 번째로 실행하면 기존 세션으로 돌아갈 뿐 Claude Code 가 새로 뜨지 않습니다.
- **세션명은 에이전트와 무관하게 프로젝트 이름만 씁니다.** 따라서 `mtw_claude myApp` 뒤에 `mtw_codex myApp` 을 실행하면 같은 세션에 attach 되며 Codex 는 실행되지 않습니다. **같은 프로젝트에서 두 에이전트를 함께 쓰려면 세션 안에서 호출하세요** — 세션 내부에서는 새 세션 대신 **새 창**이 열립니다. (세션 내부 판별은 환경변수 `TMUX` 의 설정 여부로 합니다.)
- **세션명에서 `[A-Za-z0-9_-]` 이외의 문자는 `_` 로 치환됩니다.** 예를 들어 폴더 이름이 `my.app` 이면 세션명은 `my_app` 이 됩니다.

## 6. 설정 파일

모든 설정은 `~/.mtw/` 한 곳에 모입니다.

| 경로 | 내용 |
|---|---|
| `~/.mtw/projects` | 등록된 프로젝트 목록 |
| `~/.mtw/mtw.zsh` (macOS) / `~/.mtw/mtw.ps1` (Windows) | 기능 본체. 설치 스크립트가 복사한 파일 |

`~/.mtw/projects` 는 `이름=경로` 형식의 평범한 텍스트 파일이라 직접 편집해도 됩니다.

```
# 주석
myApp=/Users/minwoo/workspace/projects/myApp
project=/Users/minwoo/workspace/projects/project
```

편집 규칙과 손편집 시의 주의 사항(중복 키 처리, 무시되는 줄)은 [`docs/ko/configuration.md`](docs/ko/configuration.md) 에 있습니다.

## 7. 에이전트 추가

기능 본체 상단의 **에이전트 레지스트리에 한 줄만 추가**하면 `mtw_<키>` 명령이 생기고 `mtw_help` 와 탭 자동완성에도 자동 반영됩니다.

**macOS** — `~/.mtw/mtw.zsh`

```zsh
MTW_AGENTS=(
  claude claude
  codex  codex
  aider  aider      # 추가한 줄
)
```

**Windows** — `~/.mtw/mtw.ps1`

```powershell
$script:MTW_AGENTS = [ordered]@{
    claude = 'claude'
    codex  = 'codex'
    aider  = 'aider'      # 추가한 줄
}
```

편집 후 새 터미널을 열거나 프로필을 다시 읽으면 `mtw_aider` 를 쓸 수 있습니다.

- 키는 `mtw_<키>` 함수 이름이 되므로 **`list` · `new` · `rm` · `help` · `cd` 는 키로 쓸 수 없습니다.** 예약어를 쓰면 로드 시 stderr 로 경고가 나오고 **해당 항목만 건너뜁니다**(고정 명령이 덮어써지지 않습니다).
- 값은 **단일 명령 이름**이어야 합니다. `claude --model x` 처럼 공백이 포함된 다중 토큰 명령은 v1.0.0 에서 지원하지 않습니다.
- 저장소의 `macos/src/mtw.zsh` · `windows/src/mtw.ps1` 을 함께 고쳐 두면 재설치 후에도 유지됩니다. `~/.mtw/` 쪽만 고치면 설치 스크립트를 다시 실행할 때 덮어써집니다.

자세한 내용은 [`docs/ko/configuration.md`](docs/ko/configuration.md) 를 보세요.

## 8. 제거

**macOS**

```bash
zsh ./macos/uninstall.sh                     # 프로젝트 목록은 보존
zsh ./macos/uninstall.sh --remove-projects   # ~/.mtw/ 전체 삭제
```

**Windows**

```powershell
pwsh -NoProfile -File .\windows\uninstall.ps1                    # 프로젝트 목록은 보존
pwsh -NoProfile -File .\windows\uninstall.ps1 -RemoveProjects    # ~\.mtw\ 전체 삭제
```

- 기본값은 **목록 보존**입니다. 재설치하면 등록해 둔 프로젝트가 그대로 복구됩니다.
- 프로필 수정과 `~/.mtw/` 전체 삭제는 **백업을 먼저 만든 뒤** 수행하며, 백업에 실패하면 대상을 건드리지 않고 중단합니다.
- **이미 열려 있는 터미널에는 함수가 메모리에 남아 있습니다.** 정리하려면 macOS 는 `exec zsh`, Windows 는 새 PowerShell 세션을 시작하세요.

## 9. 문제 해결

자주 겪는 상황과 해결 방법은 [`docs/ko/troubleshooting.md`](docs/ko/troubleshooting.md) 에 정리해 두었습니다.

- 탭 자동완성이 동작하지 않는다 (macOS — 로더 블록 위치 문제)
- `mtw_claude` 를 다시 실행했는데 에이전트가 뜨지 않는다 (attach 동작)
- 제거했는데 명령이 아직 남아 있다
- 목록 파일에 넣은 줄이 무시된다
- 설치가 중단되고 "마커를 안전하게 판별할 수 없습니다" 가 나온다

## 10. 라이선스

MIT License. 자세한 내용은 [`LICENSE`](LICENSE) 를 보세요.
