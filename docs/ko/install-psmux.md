# psmux 설치 (Windows)

**한국어** | [English](../en/install-psmux.md)

psmux 는 Windows 네이티브 tmux 호환 멀티플렉서입니다. `mtw_claude` · `mtw_codex` 가 세션을 만들 때 사용합니다. psmux 가 없어도 이동·목록 명령은 정상 동작하지만 에이전트 명령은 쓸 수 없습니다.

관련 문서: [README](../../README.md) · [macOS 쪽 설치](install-tmux.md) · [문제 해결](troubleshooting.md) · [Windows 검증 절차](windows-verification.md)

## 1. 먼저 — PowerShell 7 이 필요합니다

Windows 에 기본 탑재된 것은 **Windows PowerShell 5.1**(`powershell.exe`)이고, 이 도구가 요구하는 것은 **PowerShell 7 이상**(`pwsh.exe`)입니다. 둘은 별개의 프로그램이며 나란히 설치됩니다.

```powershell
winget install Microsoft.PowerShell
```

설치 후 확인합니다.

```powershell
pwsh -NoProfile -Command '$PSVersionTable.PSVersion'
# Major 가 7 이상이어야 합니다
```

psmux 도 기본적으로 `pwsh` 를 실행하므로, PowerShell 7 을 설치하지 않으면 세션 안에서 `mtw_*` 명령이 보이지 않습니다. 이 지점에서 혼선이 잦습니다.

## 2. psmux 설치

### winget (권장)

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

### cargo (소스 빌드)

Rust 툴체인이 설치되어 있어야 합니다.

```powershell
cargo install psmux
```

### GitHub Releases

바이너리를 직접 내려받아 PATH 가 걸린 디렉터리에 두어도 됩니다. 배포 파일과 최신 버전은 [psmux/psmux](https://github.com/psmux/psmux) 저장소의 Releases 에서 확인하세요.

## 3. 설치 확인 — `tmux` 명령이 핵심입니다

psmux 는 **`psmux` · `pmux` · `tmux` 세 실행 명령을 모두 설치**합니다. 이 도구는 양쪽 OS 에서 **`tmux` 라는 이름으로만** 멀티플렉서를 호출하므로, 확인해야 할 것은 `tmux` 입니다.

```powershell
tmux -V
```

버전이 출력되면 준비가 끝났습니다. 출력되지 않는다면 다음을 확인하세요.

```powershell
Get-Command tmux          # 실행 파일 경로 확인
$env:PATH -split ';'      # PATH 에 psmux 설치 경로가 있는지 확인
```

새 터미널을 열어야 PATH 변경이 반영되는 경우가 많습니다.

**`tmux` 명령에 의존하는 이유.** 양쪽 OS 에서 같은 명령 이름을 쓰면 실행 로직과 사용법 문서가 OS 별로 갈라지지 않습니다. 이 도구는 그 이점을 택했습니다. 만약 psmux 가 앞으로 `tmux` 명령 제공을 중단하면 이 부분은 다시 설계해야 합니다.

## 4. mtw 가 실제로 호출하는 명령

```powershell
tmux new-session -A -s <세션명> -c <경로> <에이전트 명령>    # 세션 밖에서 호출했을 때
tmux new-window     -n <세션명> -c <경로> <에이전트 명령>    # 세션 안에서 호출했을 때
```

- `-A` — 같은 이름의 세션이 이미 있으면 새로 만들지 않고 **attach** 합니다. 이때 마지막 인자의 에이전트 명령은 **실행되지 않습니다**.
- `-c` — 세션(창)의 시작 디렉터리.
- 세션 안인지 밖인지는 환경변수 `TMUX` 의 설정 여부로 판별합니다. 세션 안에서 `$env:TMUX` 를 출력해 확인할 수 있습니다.

> **psmux 에서 이 두 항목(`-A` / `-c` 플래그 지원, 세션 내부의 `TMUX` 설정)이 실제로 동작하는지는 Windows 실기 확인 대상입니다.** 확인 절차는 [`windows-verification.md`](windows-verification.md) 의 "최우선 전제 확인" 절에 있습니다. 둘 중 하나라도 실패하면 개별 명령이 아니라 설계 전제가 무너지므로, 이슈로 보고해 주세요.

## 5. 기본 조작

psmux 는 tmux 호환이므로 조작 방법이 같고, 기존 `.tmux.conf` 도 그대로 읽습니다. prefix 기본값은 `Ctrl-b` 입니다.

| 하고 싶은 것 | 방법 |
|---|---|
| 세션에서 빠져나오기 (detach) | `Ctrl-b` 다음 `d` |
| 세션 목록 보기 | `tmux ls` |
| 세션으로 돌아가기 (attach) | `tmux attach -t <세션명>` |
| 창 목록 / 다음 창 / 이전 창 | `Ctrl-b` 다음 `w` / `n` / `p` |
| 창·세션 종료 | 안에서 `exit` |

같은 프로젝트에서 Claude Code 와 Codex CLI 를 함께 쓰려면 **세션 안에서** 두 번째 명령을 호출하세요. 세션 안에서는 새 세션 대신 새 창이 열립니다.

```powershell
mtw_claude myApp     # myApp 세션 생성 + Claude Code 실행
mtw_codex myApp      # 세션 안이므로 새 창에서 Codex CLI 실행
```

## 6. mtw 설치·제거 명령 (참고)

psmux 설치가 끝났다면 mtw 설치는 다음과 같습니다.

```powershell
git clone https://github.com/blueclover22/mw-terminal-worknav.git
cd mw-terminal-worknav
pwsh -NoProfile -File .\windows\install.ps1
```

제거는 다음과 같습니다.

```powershell
pwsh -NoProfile -File .\windows\uninstall.ps1                    # 프로젝트 목록은 보존
pwsh -NoProfile -File .\windows\uninstall.ps1 -RemoveProjects    # ~\.mtw\ 전체 삭제
```

**`-NoProfile` 을 붙이는 이유.** PowerShell 의 명령 해석 우선순위는 `Alias -> Function -> Cmdlet -> 외부 명령` 입니다. 사용자 프로필이 정의한 함수는 `Copy-Item` 같은 cmdlet 정식 이름까지 가로챌 수 있고, `pwsh script.ps1` 은 `-NoProfile` 없이는 프로필을 로드합니다. 설치·제거 스크립트는 파일 조작 cmdlet 을 **모듈 한정 이름**(`Microsoft.PowerShell.Management\Copy-Item` 형태)으로 호출해 스스로 방어하고 있지만, `-NoProfile` 은 그 위의 한 겹 더입니다.

## 7. 제거

```powershell
winget uninstall psmux
```

psmux 를 지워도 `mtw_cd_*` · `mtw_list` · `mtw_new` · `mtw_rm` 은 그대로 동작합니다. 에이전트 명령만 쓸 수 없게 됩니다.
