# tmux 설치와 기본 조작 (macOS)

**한국어** | [English](../en/install-tmux.md)

`mtw_claude` · `mtw_codex` 는 tmux 세션을 만들고 그 안에서 에이전트를 실행합니다. tmux 가 없으면 이동·목록 명령은 정상 동작하지만 에이전트 명령은 쓸 수 없습니다.

관련 문서: [README](../../README.md) · [Windows 쪽 설치](install-psmux.md) · [문제 해결](troubleshooting.md)

## 1. 설치

Homebrew 로 설치합니다.

```bash
brew install tmux
```

Homebrew 가 없다면 [brew.sh](https://brew.sh) 의 안내를 먼저 따르세요.

설치를 확인합니다.

```bash
tmux -V
# 예: tmux 3.7b
```

`command -v tmux` 로 실행 파일 경로도 확인할 수 있습니다. 이 도구는 `tmux` 를 **PATH 에서 찾아 그대로 호출**하므로, 별도 설정 없이 위 명령이 동작하면 됩니다.

## 2. mtw 가 실제로 호출하는 명령

이 도구가 tmux 에 넘기는 것은 아래 두 형태뿐입니다.

```bash
tmux new-session -A -s <세션명> -c <경로> <에이전트 명령>    # 세션 밖에서 호출했을 때
tmux new-window     -n <세션명> -c <경로> <에이전트 명령>    # 세션 안에서 호출했을 때
```

- `-A` — 같은 이름의 세션이 이미 있으면 새로 만들지 않고 **attach** 합니다.
- `-s` / `-n` — 세션 이름 / 창 이름.
- `-c` — 세션(창)의 시작 디렉터리.
- 마지막 인자 — 세션(창)에서 실행할 명령. `claude`, `codex` 같은 단일 명령입니다.

세션 안인지 밖인지는 환경변수 `TMUX` 의 설정 여부로 판별합니다. 세션 안에서는 `echo $TMUX` 가 소켓 경로를 출력합니다.

**`-A` 로 attach 되는 경우 마지막 인자의 명령은 실행되지 않습니다.** tmux 의 정상 동작이며, 이 도구는 이를 우회하지 않습니다. 자세한 내용은 [문제 해결](troubleshooting.md) 을 보세요.

## 3. 알아 두면 되는 기본 조작

tmux 의 모든 단축키는 **prefix 키를 먼저 누른 뒤** 입력합니다. 기본 prefix 는 `Ctrl-b` 입니다.

| 하고 싶은 것 | 방법 |
|---|---|
| 세션에서 빠져나오기 (detach) | `Ctrl-b` 다음 `d` — 세션은 백그라운드에 그대로 살아 있습니다 |
| 세션 목록 보기 | `tmux ls` |
| 세션으로 돌아가기 (attach) | `tmux attach -t <세션명>` |
| 세션 종료 | 세션 안에서 `exit`, 또는 밖에서 `tmux kill-session -t <세션명>` |
| 창 목록 보기 | `Ctrl-b` 다음 `w` |
| 다음 / 이전 창으로 이동 | `Ctrl-b` 다음 `n` / `p` |
| 번호로 창 이동 | `Ctrl-b` 다음 `0`~`9` |
| 창 닫기 | 창 안에서 `exit` |
| 스크롤 모드 진입 | `Ctrl-b` 다음 `[` — 종료는 `q` |

`mtw_claude myApp` 을 실행하면 `myApp` 이라는 이름의 세션이 만들어지므로, 나중에 `tmux attach -t myApp` 으로 언제든 돌아올 수 있습니다.

## 4. 같은 프로젝트에서 두 에이전트를 함께 쓰기

세션명은 에이전트가 아니라 **프로젝트 이름**으로 정해집니다. 그래서 세션 밖에서 `mtw_claude myApp` 에 이어 `mtw_codex myApp` 을 실행하면 같은 세션에 attach 될 뿐 Codex 는 실행되지 않습니다.

두 에이전트를 함께 쓰려면 **세션 안에서 호출**하세요.

```bash
mtw_claude myApp     # myApp 세션 생성 + Claude Code 실행 (세션 안으로 들어감)
mtw_codex myApp      # 세션 안이므로 새 창이 열리고 그 창에서 Codex CLI 실행
```

`Ctrl-b` 다음 `n` / `p` 로 두 창을 오갈 수 있습니다.

## 5. 설정 파일 (선택)

tmux 설정은 `~/.tmux.conf` 에 둡니다. 이 도구는 tmux 설정을 읽지도 쓰지도 않으므로 기존 설정을 그대로 쓰면 됩니다. prefix 를 바꿔 두었다면 위 표의 `Ctrl-b` 를 각자의 prefix 로 바꿔 읽으세요.

공식 문서: [tmux 위키](https://github.com/tmux/tmux/wiki)

## 6. 제거

```bash
brew uninstall tmux
```

tmux 를 지워도 `mtw_cd_*` · `mtw_list` · `mtw_new` · `mtw_rm` 은 그대로 동작합니다. 에이전트 명령만 쓸 수 없게 됩니다.
