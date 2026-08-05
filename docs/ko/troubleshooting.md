# 문제 해결

**한국어** | [English](../en/troubleshooting.md)

관련 문서: [README](../../README.md) · [설정 파일](configuration.md) · [tmux 설치](install-tmux.md) · [psmux 설치](install-psmux.md)

---

## 설치 직후 `mtw_` 명령이 하나도 없다

설치 스크립트는 **별도 프로세스에서 실행되므로 호출한 터미널에는 반영되지 않습니다.** 새 터미널을 열거나 프로필을 다시 읽으세요.

```bash
source ~/.zshrc      # macOS
```

```powershell
. $PROFILE           # Windows
```

그래도 없다면 프로필에 로더 블록이 실제로 들어갔는지 확인합니다.

```bash
tail -5 ~/.zshrc                              # macOS
```

```powershell
Get-Content -Tail 5 $PROFILE                  # Windows
```

`# >>> mtw (mw-terminal-worknav) >>>` 로 시작하는 세 줄이 보여야 합니다. 없다면 설치가 중단된 것이므로 설치 스크립트의 출력을 다시 확인하세요.

기능 본체가 복사되었는지도 확인합니다 — 로더 블록은 파일이 없으면 조용히 넘어갑니다.

```bash
ls -l ~/.mtw/                                 # macOS: mtw.zsh 가 있어야 합니다
```

```powershell
Get-ChildItem ~/.mtw/                         # Windows: mtw.ps1 이 있어야 합니다
```

---

## 탭 자동완성이 동작하지 않는다 (macOS)

`mtw_cd_<Tab>` 은 셸의 기본 함수명 완성이라 거의 항상 동작하지만, **`mtw_rm <Tab>` · `mtw_claude <Tab>` · `mtw_codex <Tab>` 만 동작하지 않는다면 로더 블록의 위치 문제**입니다.

자동완성 등록에는 `compdef` 가 필요하고, `compdef` 는 `compinit` 이 실행된 뒤에만 존재합니다. 이 도구는 `compdef` 가 없으면 **조용히 건너뜁니다**(로드 실패로 이어지지 않게 하기 위해서입니다). 그래서 로더 블록이 `compinit` 보다 **앞**에 있으면 다른 기능은 모두 정상인데 자동완성만 빠집니다.

**확인**

```bash
grep -n 'compinit\|mtw (mw-terminal-worknav)' ~/.zshrc
```

`mtw` 마커의 줄 번호가 `compinit` 보다 커야 합니다. oh-my-zsh 를 쓴다면 `source $ZSH/oh-my-zsh.sh` 안에서 `compinit` 이 실행되므로, 그 줄보다 뒤에 있으면 됩니다.

**해결** — 로더 블록 세 줄을 `.zshrc` 의 **맨 끝**으로 옮기고 새 터미널을 엽니다. 설치 스크립트는 원래 파일 끝에 추가하므로, 블록을 위로 옮긴 적이 없다면 이 문제는 발생하지 않습니다.

---

## `mtw_new` 로 방금 등록했는데 자동완성에 안 나온다

자동완성 후보는 **호출 시점의 메모리 목록**을 읽으므로 재시작 없이 즉시 반영되는 것이 정상입니다. 나오지 않는다면 위의 "탭 자동완성이 동작하지 않는다" 항목을 먼저 확인하세요.

---

## `mtw_claude` 를 다시 실행했는데 에이전트가 뜨지 않는다

**정상 동작입니다.** `-A` 옵션으로 기존 세션에 attach 되는 경우, tmux 는 뒤에 붙인 명령을 실행하지 않습니다. 이 도구는 이를 우회하지 않습니다.

```
tmux new-session -A -s myApp -c /path/myApp claude
```

세션 `myApp` 이 이미 있으면 위 명령은 **attach 만** 하고 `claude` 는 실행하지 않습니다.

**대응**

- 원래 세션 안에서 이미 돌고 있는 에이전트를 그대로 쓰면 됩니다.
- 새로 띄우고 싶다면 세션을 먼저 종료하세요 — `tmux kill-session -t myApp`.
- 같은 세션에서 **다른 에이전트**를 추가로 띄우고 싶다면 **세션 안에서** 호출하세요. 세션 안에서는 새 세션 대신 새 창이 열립니다.

  ```
  mtw_claude myApp     # 세션 생성 후 그 안으로 들어감
  mtw_codex myApp      # 세션 안이므로 새 창에서 실행됨
  ```

---

## 세션 안에서 호출했는데 새 창이 아니라 새 세션을 만들려 한다

세션 내부 판별은 환경변수 `TMUX` 의 설정 여부로 합니다. 세션 안에서 값이 비어 있으면 이 분기가 동작하지 않습니다.

```bash
echo $TMUX          # macOS — 소켓 경로가 출력되어야 합니다
```

```powershell
$env:TMUX           # Windows — 값이 있어야 합니다
```

Windows(psmux)에서 값이 비어 있다면 psmux 가 `TMUX` 를 설정하지 않는 것이므로, 개별 사용 문제가 아니라 설계 전제가 어긋난 경우입니다. [`windows-verification.md`](windows-verification.md) 의 "최우선 전제 확인" 절차대로 확인한 뒤 이슈로 보고해 주세요.

---

## 세션 이름이 내가 준 이름과 다르다

세션명에서 `[A-Za-z0-9_-]` 이외의 문자는 `_` 로 치환됩니다. 폴더 이름이 `my.app` 이면 세션명은 `my_app` 이 되고, 한글 폴더명은 문자 수만큼의 `_` 가 됩니다. `tmux ls` 로 실제 세션명을 확인하세요.

이름을 그대로 쓰고 싶다면 `mtw_new` 로 원하는 이름을 등록한 뒤 `mtw_claude <등록한 이름>` 으로 호출하세요.

---

## 목록 파일에 넣은 줄이 `mtw_list` 에 안 나온다

형식에 맞지 않는 줄은 **아무 메시지 없이 무시**됩니다. 아래를 확인하세요.

- `이름=경로` 형식인지, `=` 앞뒤에 공백이 없는지
- 이름이 `^[A-Za-z_][A-Za-z0-9_-]*$` 에 맞는지 — 숫자로 시작하거나 공백·마침표가 들어가면 무시됩니다
- 같은 이름이 이미 앞줄에 있는지 — **대소문자만 다른 이름은 먼저 나온 줄이 이깁니다**
- 편집 후 프로필을 다시 읽었는지

전체 규칙은 [`configuration.md`](configuration.md) 의 "무시되는 줄" 표에 있습니다.

---

## "마커를 안전하게 판별할 수 없습니다" 가 나오고 설치·제거가 중단된다

```
mtw: 오류: 프로필에서 로더 블록 마커를 안전하게 판별할 수 없습니다: /Users/minwoo/.zshrc
```

프로필에서 마커가 **정확히 한 쌍(시작 1회 + 종료 1회, 시작이 앞)** 이 아닐 때 나옵니다. 마커가 두 쌍이거나, 한쪽만 있거나, 종료가 시작보다 앞에 있는 경우입니다. 이 상태에서 자동으로 잘라내면 사용자가 쓴 줄이 함께 지워질 수 있으므로 **프로필을 건드리지 않고 중단**합니다.

**해결** — 프로필을 직접 열어 아래 두 줄을 검색하고, 짝이 맞는 한 쌍만 남도록 정리한 뒤 다시 실행하세요.

```
# >>> mtw (mw-terminal-worknav) >>>
# <<< mtw (mw-terminal-worknav) <<<
```

설치 중 이 오류가 났다면 **기능 본체는 이미 복사되었고 프로필만 변경되지 않은 상태**입니다(메시지에도 그렇게 나옵니다). 프로필을 정리한 뒤 설치 스크립트를 다시 실행하면 됩니다.

---

## 제거했는데 명령이 아직 남아 있다

**이미 열려 있는 터미널에는 함수가 메모리에 남습니다.** 제거 스크립트는 파일과 프로필만 정리하며, 실행 중인 셸의 메모리는 건드리지 않습니다.

```bash
exec zsh            # macOS — 현재 셸을 새로 시작
```

Windows 에서는 새 PowerShell 세션을 시작하세요.

새 터미널에서도 명령이 남아 있다면 프로필에 로더 블록이 아직 있는 것입니다. 위의 "마커를 안전하게 판별할 수 없습니다" 항목을 확인하세요.

---

## 제거했는데 프로젝트 목록이 사라졌다 / 남아 있다

기본값은 **보존**입니다. `~/.mtw/projects` 는 그대로 두고 기능 본체만 지웁니다. 재설치하면 목록이 그대로 복구됩니다.

목록까지 지우려면 옵션을 주세요.

```bash
zsh ./macos/uninstall.sh --remove-projects                       # macOS
```

```powershell
pwsh -NoProfile -File .\windows\uninstall.ps1 -RemoveProjects    # Windows
```

이 옵션은 **백업을 먼저 만든 뒤** 삭제합니다. `~/.mtw.bak-YYYYMMDD-HHMMSS` 디렉터리에 목록이 남아 있으므로, 실수로 지웠다면 그 안의 `projects` 파일을 되돌리면 됩니다.

옵션 이름은 OS 별로 다릅니다 — macOS 는 `--remove-projects`, Windows 는 `-RemoveProjects` 이며 **정확히 일치해야 합니다.** 다른 값을 주면 아무것도 하지 않고 종료 코드 1 로 끝납니다.

```
mtw: 알 수 없는 옵션입니다: -Remove
```

---

## 백업 파일이 쌓인다

설치·제거 스크립트는 프로필을 수정하기 전에 `~/.zshrc.bak-YYYYMMDD-HHMMSS` 형태의 백업을 만듭니다. 같은 초에 두 번 실행하면 `-2`, `-3` 접미사가 붙어 **직전 백업을 덮어쓰지 않습니다.**

필요 없어진 백업은 직접 지우면 됩니다. 저장소의 `.gitignore` 는 `*.bak-*` 를 제외하므로 실수로 커밋될 걱정은 없습니다.

---

## Windows — `mtw_rm foo && echo ok` 가 예상과 다르게 동작한다

**알려진 차이이며 결함이 아닙니다.** PowerShell 의 `&&` / `||` 는 종료 코드가 아니라 `$?` 를 보는데, 함수의 비종료 오류는 `$?` 를 뒤집지 않습니다. 회피 수단이 없어 **`$LASTEXITCODE` 를 1 로 설정하는 것이 가능한 최선**입니다.

성공·실패를 판정해야 한다면 `$LASTEXITCODE` 를 직접 확인하세요.

```powershell
mtw_rm foo
if ($LASTEXITCODE -eq 0) { 'ok' } else { 'failed' }
```

같은 이유로 **PowerShell 판의 오류 출력은 `2>$null` 로 억제되거나 `2>&1` 로 캡처되지 않습니다.** macOS 판과 **문구가 한 글자도 다르지 않게** 맞추기 위해 `$host.UI.WriteErrorLine` 을 쓰기 때문입니다. 두 차이의 배경은 [`windows-verification.md`](windows-verification.md) 의 "알려진 차이" 절에 정리되어 있습니다.

---

## 그 밖의 문제

재현 절차와 함께 저장소 이슈로 남겨 주세요. Windows 환경에서 겪은 문제라면 [`windows-verification.md`](windows-verification.md) 의 해당 항목 결과를 함께 적어 주면 원인 파악이 빨라집니다.
