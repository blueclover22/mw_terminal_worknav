# mw-terminal-worknav

**한국어** | [English](README.en.md)

터미널에서 등록해 둔 프로젝트 폴더로 즉시 이동하는 셸 단축 명령 모음입니다. macOS(zsh)와 Windows(PowerShell 7)에서 **같은 명령·같은 메시지·같은 종료 코드**로 동작합니다.

기본 설치는 **이동·목록 명령만** 넣습니다. 멀티플렉서는 요구 조건이 아닙니다 — 에이전트 세션은 전용 도구로 따로 운영하고, mtw 는 "어느 폴더로 가느냐" 에만 집중합니다. 멀티플렉서(macOS = tmux · Windows = psmux)를 계속 쓰는 경우를 위해 에이전트 세션 명령은 **선택 애드온**으로 남겨 두었습니다([6. 멀티플렉서 애드온](#6-멀티플렉서-애드온-선택)).

## 목차

1. [무엇을 하는가](#1-무엇을-하는가)
2. [요구 사항](#2-요구-사항)
3. [설치](#3-설치)
4. [사용법](#4-사용법)
5. [설정 파일](#5-설정-파일)
6. [멀티플렉서 애드온 (선택)](#6-멀티플렉서-애드온-선택)
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
mtw_help            # 전체 명령 안내
```

모든 명령이 `mtw_` 로 시작하므로 **`mtw_<Tab>` 하나로 전체 명령**을, **`mtw_cd_<Tab>` 으로 등록된 프로젝트 전체**를 확인할 수 있습니다. `mtw_rm` 은 인자 자리에서 `<Tab>` 을 누르면 등록된 프로젝트 이름을 제안합니다.

이동 명령이 `mtw_cd_` 라는 이중 접두사를 쓰는 이유는 프로젝트 이름에서 만들어지는 명령을 별도 네임스페이스로 격리하기 위해서입니다. `list` 라는 이름의 폴더를 등록해도 `mtw_cd_list` 가 생길 뿐, 관리 명령인 `mtw_list` 는 영향을 받지 않습니다.

## 2. 요구 사항

| 항목 | macOS | Windows |
|---|---|---|
| OS | macOS 12 이상 | Windows 10 / 11 |
| 셸 | zsh (기본 셸) | PowerShell 7 이상 |
| 멀티플렉서 | 불필요 (애드온을 쓸 때만 tmux) | 불필요 (애드온을 쓸 때만 psmux) |
| 검증 상태 | 실기 검증 완료 (macOS 26 · zsh 5.9 · tmux 3.7) | 실기 검증 완료 (Windows 11 · PowerShell 7) |

기본 설치는 셸 외에 아무것도 요구하지 않습니다.

## 3. 설치

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

설치 스크립트가 하는 일은 다음 다섯 가지뿐입니다.

1. `~/.mtw/` 생성
2. 기능 본체(`mtw.zsh` / `mtw.ps1`)를 `~/.mtw/` 로 복사 (**기존 파일은 덮어씀 — 재실행이 곧 업데이트**)
3. 멀티플렉서 애드온을 설치하거나 제거 (아래 [6. 멀티플렉서 애드온](#6-멀티플렉서-애드온-선택) 참고)
4. `~/.mtw/projects` 가 없으면 빈 파일로 생성 (**있으면 그대로 보존**)
5. 프로필(`~/.zshrc` / `$PROFILE`) 끝에 로더 블록 추가

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

## 4. 사용법

### 등록 · 조회 · 해제

```
mtw_new <이름>      현재 폴더를 등록. 이름 형식은 ^[A-Za-z_][A-Za-z0-9_-]*$
mtw_list            등록된 프로젝트를 이름 오름차순으로 출력
mtw_rm <이름>       등록 해제 (폴더는 삭제하지 않음)
mtw_help            전체 명령 안내
```

```
$ mtw_new myApp
등록되었습니다: myApp -> /Users/minwoo/workspace/projects/myApp

$ mtw_list
myApp       /Users/minwoo/workspace/projects/myApp

$ mtw_rm myApp
등록 해제되었습니다: myApp (폴더는 그대로 남아 있습니다: /Users/minwoo/workspace/projects/myApp)
```

- **등록 직후 바로 쓸 수 있습니다.** `mtw_new` 는 등록 후 목록을 다시 읽고 이동 함수를 다시 만들므로, 터미널을 재시작하지 않아도 `mtw_cd_myApp` 과 탭 자동완성이 즉시 동작합니다.
- **중복 검사는 대소문자를 무시합니다.** `myApp` 이 등록된 상태에서 `mtw_new MYAPP` 은 거부됩니다. 저장은 입력한 표기 그대로 합니다.
- **`mtw_rm` 의 이름 매칭도 대소문자를 무시하며, 메시지에는 등록된 표기를 씁니다.** `mtw_rm` 에 별도 확인 절차는 없습니다 — 사라지는 것은 북마크 한 줄뿐이고 폴더는 그대로이기 때문입니다.
- 실패한 명령은 오류 메시지를 내고 **종료 코드 1** 로 끝나며, 목록 파일은 변경되지 않습니다.

### 이동

```
mtw_cd_<이름>       등록된 경로로 이동
```

등록된 항목 수만큼 자동으로 만들어집니다. 목록에서 사라진 항목의 함수는 다음 적재 시점에 제거됩니다.

## 5. 설정 파일

모든 설정은 `~/.mtw/` 한 곳에 모입니다.

| 경로 | 내용 |
|---|---|
| `~/.mtw/projects` | 등록된 프로젝트 목록 |
| `~/.mtw/mtw.zsh` (macOS) / `~/.mtw/mtw.ps1` (Windows) | 기능 본체. 설치 스크립트가 복사한 파일 |
| `~/.mtw/mtw-tmux.zsh` (macOS) / `~/.mtw/mtw-psmux.ps1` (Windows) | 멀티플렉서 애드온. **플래그를 주어 설치했을 때만 존재** |

`~/.mtw/projects` 는 `이름=경로` 형식의 평범한 텍스트 파일이라 직접 편집해도 됩니다.

```
# 주석
myApp=/Users/minwoo/workspace/projects/myApp
project=/Users/minwoo/workspace/projects/project
```

편집 규칙과 손편집 시의 주의 사항(중복 키 처리, 무시되는 줄)은 [`docs/ko/configuration.md`](docs/ko/configuration.md) 에 있습니다.

## 6. 멀티플렉서 애드온 (선택)

애드온을 설치하면 **폴더 이름을 세션명으로 삼아 멀티플렉서 세션을 띄우고 그 안에서 AI 코딩 에이전트를 실행**하는 명령이 추가됩니다.

```
mtw_claude [이름]   세션 생성 후 Claude Code 실행
mtw_codex  [이름]   세션 생성 후 Codex CLI 실행
```

멀티플렉서는 OS 별로 다르고, **애드온 파일과 설치 플래그도 그에 맞춰 나뉩니다.**

| | macOS | Windows |
|---|---|---|
| 멀티플렉서 | tmux | psmux |
| 설치 | `brew install tmux` | `winget install psmux` |
| 애드온 플래그 | `zsh ./macos/install.sh --with-tmux` | `pwsh -NoProfile -File .\windows\install.ps1 -WithPsmux` |
| 애드온 파일 | `~/.mtw/mtw-tmux.zsh` | `~/.mtw/mtw-psmux.ps1` |
| 설치·조작 문서 | [`docs/ko/install-tmux.md`](docs/ko/install-tmux.md) | [`docs/ko/install-psmux.md`](docs/ko/install-psmux.md) |

**재실행이 곧 상태 선언입니다.** 플래그 없이 설치 스크립트를 다시 실행하면 이미 설치된 애드온은 **제거됩니다**. 애드온을 유지하려면 재설치할 때마다 플래그를 함께 주세요.

```
mtw: tmux 애드온을 제거했습니다 (다시 설치하려면 --with-tmux 를 주세요).      # macOS
mtw: psmux 애드온을 제거했습니다 (다시 설치하려면 -WithPsmux 를 주세요).     # Windows
```

애드온은 기능 본체와 별개 파일이며, 본체가 마지막에 파일 존재 여부를 보고 읽어 들입니다. 프로필의 로더 블록은 애드온 유무와 무관하게 한 줄 그대로이므로, **이미 설치된 환경에서 애드온만 켜고 끄는 데 프로필 수정이 필요 없습니다.**

에이전트 CLI(Claude Code, Codex CLI)의 설치·인증·PATH 등록은 사용자 책임이며 이 도구가 관여하지 않습니다.

### 동작

| 호출 | 세션명 | 시작 경로 |
|---|---|---|
| `mtw_claude` | 현재 폴더명 | 현재 폴더 |
| `mtw_claude myApp` (등록된 이름) | `myApp` | 등록된 경로 |
| `mtw_claude MYAPP` (대소문자만 다른 이름) | `myApp` | 등록된 경로 |
| `mtw_claude tmp` (등록되지 않은 이름) | — | 오류 출력 후 중단, 종료 코드 1 |

내부적으로는 아래 두 형태 중 하나를 호출합니다. 양쪽 OS 가 완전히 같은 명령을 씁니다.

```
tmux new-session -A -s <세션명> -c <경로> <에이전트 명령>    # 세션 밖에서 호출했을 때
tmux new-window     -n <세션명> -c <경로> <에이전트 명령>    # 세션 안에서 호출했을 때
```

**Windows 에서도 호출하는 명령은 `tmux` 입니다.** psmux 가 `psmux` · `pmux` · `tmux` 세 실행 명령을 모두 제공하기 때문이며, 덕분에 세션 생성 명령이 양쪽 OS 에서 한 글자도 다르지 않습니다. 애드온의 이름만 OS 별 멀티플렉서를 따릅니다.

반드시 알아 두어야 할 동작 다섯 가지입니다.

- **에이전트를 종료하면 세션도 함께 종료됩니다.** 에이전트 명령이 창의 루트 프로세스이므로, Claude Code 에서 `/exit` 를 치면 창이 닫히고 마지막 창이면 세션까지 끝납니다. tmux 의 정상 동작입니다. 세션을 남기려면 종료 대신 detach 하세요 (`Ctrl-b d`). 세션 안에서 호출한 경우에는 새 창이므로 그 창만 닫힙니다.
- **등록되지 않은 이름을 주면 오류를 내고 중단합니다.** 세션은 만들어지지 않습니다.
- **이미 있는 세션에 `-A` 로 attach 되는 경우, 뒤에 붙인 에이전트 명령은 실행되지 않습니다.** tmux 의 정상 동작이며 우회하지 않습니다. 즉 `mtw_claude myApp` 을 두 번째로 실행하면 기존 세션으로 돌아갈 뿐 Claude Code 가 새로 뜨지 않습니다.
- **세션명은 에이전트와 무관하게 프로젝트 이름만 씁니다.** 따라서 `mtw_claude myApp` 뒤에 `mtw_codex myApp` 을 실행하면 같은 세션에 attach 되며 Codex 는 실행되지 않습니다. **같은 프로젝트에서 두 에이전트를 함께 쓰려면 세션 안에서 호출하세요** — 세션 내부에서는 새 세션 대신 **새 창**이 열립니다. (세션 내부 판별은 환경변수 `TMUX` 의 설정 여부로 합니다.)
- **세션명에서 `[A-Za-z0-9_-]` 이외의 문자는 `_` 로 치환됩니다.** 예를 들어 폴더 이름이 `my.app` 이면 세션명은 `my_app` 이 됩니다.

## 7. 에이전트 추가

**멀티플렉서 애드온을 설치한 경우에만 해당합니다.** 애드온 상단의 **에이전트 레지스트리에 한 줄만 추가**하면 `mtw_<키>` 명령이 생기고 `mtw_help` 와 탭 자동완성에도 자동 반영됩니다.

**macOS** — `~/.mtw/mtw-tmux.zsh`

```zsh
MTW_AGENTS=(
  claude claude
  codex  codex
  aider  aider      # 추가한 줄
)
```

**Windows** — `~/.mtw/mtw-psmux.ps1`

```powershell
$script:MTW_AGENTS = [ordered]@{
    claude = 'claude'
    codex  = 'codex'
    aider  = 'aider'      # 추가한 줄
}
```

편집 후 새 터미널을 열거나 프로필을 다시 읽으면 `mtw_aider` 를 쓸 수 있습니다.

- 키는 `mtw_<키>` 함수 이름이 되므로 **`list` · `new` · `rm` · `help` · `cd` 는 키로 쓸 수 없습니다.** 대소문자는 구분하지 않아 `List` · `RM` 도 걸러집니다. 예약어를 쓰면 로드 시 stderr 로 경고가 나오고 **해당 항목만 건너뜁니다**(고정 명령이 덮어써지지 않습니다).
- 값은 **단일 명령 이름**이어야 합니다. `claude --model x` 처럼 공백이 포함된 다중 토큰 명령은 v2.0.2 에서 지원하지 않습니다.
- 저장소의 `macos/src/mtw-tmux.zsh` · `windows/src/mtw-psmux.ps1` 을 함께 고쳐 두면 재설치 후에도 유지됩니다. `~/.mtw/` 쪽만 고치면 설치 스크립트를 다시 실행할 때 덮어써집니다.

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

- 기본값은 **목록 보존**입니다. 재설치하면 등록해 둔 프로젝트가 그대로 복구됩니다. 기능 본체와 멀티플렉서 애드온은 둘 다 삭제됩니다.
- 프로필 수정과 `~/.mtw/` 전체 삭제는 **백업을 먼저 만든 뒤** 수행하며, 백업에 실패하면 대상을 건드리지 않고 중단합니다.
- **이미 열려 있는 터미널에는 함수가 메모리에 남아 있습니다.** 정리하려면 macOS 는 `exec zsh`, Windows 는 새 PowerShell 세션을 시작하세요.

## 9. 문제 해결

자주 겪는 상황과 해결 방법은 [`docs/ko/troubleshooting.md`](docs/ko/troubleshooting.md) 에 정리해 두었습니다.

- 탭 자동완성이 동작하지 않는다 (macOS — 로더 블록 위치 문제)
- 재설치했더니 `mtw_claude` 가 사라졌다 (애드온 플래그)
- `mtw_claude` 를 다시 실행했는데 에이전트가 뜨지 않는다 (attach 동작)
- 제거했는데 명령이 아직 남아 있다
- 목록 파일에 넣은 줄이 무시된다
- 설치가 중단되고 "마커를 안전하게 판별할 수 없습니다" 가 나온다

## 10. 라이선스

MIT License. 자세한 내용은 [`LICENSE`](LICENSE) 를 보세요.
