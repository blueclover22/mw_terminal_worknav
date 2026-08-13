#!/usr/bin/env zsh
# mtw (mw-terminal-worknav) 설치 스크립트 - macOS (zsh)
#
# ~/.mtw/ 를 만들고 기능 본체를 복사한 뒤 ~/.zshrc 끝에 로더 블록을 추가한다.
# src/ 는 스크립트 위치 기준으로 찾으므로 호출 디렉터리와 무관하다.
#
# 기본 설치는 이동·목록 명령만 넣는다. --with-tmux 를 주면 tmux 애드온까지 설치해
# 에이전트 세션 명령(mtw_claude 등)이 함께 생긴다. 재실행이 곧 상태 선언이므로
# --with-tmux 없이 다시 실행하면 이미 설치된 애드온은 제거된다.
#
# 호출 예: zsh ./macos/install.sh [--with-tmux]

emulate -L zsh -o no_aliases

typeset -r MTW_DIR="$HOME/.mtw"
typeset -r MTW_BODY="$MTW_DIR/mtw.zsh"
typeset -r MTW_ADDON="$MTW_DIR/mtw-tmux.zsh"
typeset -r PROJECTS_FILE="$MTW_DIR/projects"
typeset -r PROFILE="$HOME/.zshrc"
typeset -r MARKER_START="# >>> mtw (mw-terminal-worknav) >>>"
typeset -r MARKER_END="# <<< mtw (mw-terminal-worknav) <<<"

typeset -r SCRIPT_DIR="${0:A:h}"
typeset -r SRC_FILE="$SCRIPT_DIR/src/mtw.zsh"
typeset -r SRC_ADDON="$SCRIPT_DIR/src/mtw-tmux.zsh"

typeset -i with_tmux=0
typeset arg
for arg in "$@"; do
  case "$arg" in
    --with-tmux) with_tmux=1 ;;
    *)
      print -ru2 -- "mtw: 알 수 없는 옵션입니다: $arg"
      exit 1
      ;;
  esac
done

if [[ ! -f "$SRC_FILE" ]]; then
  print -ru2 -- "mtw: 오류: 기능 본체를 찾을 수 없습니다: $SRC_FILE"
  exit 1
fi

if (( with_tmux )) && [[ ! -f "$SRC_ADDON" ]]; then
  print -ru2 -- "mtw: 오류: tmux 애드온을 찾을 수 없습니다: $SRC_ADDON"
  exit 1
fi

# 설치 전 주요 명령 이름이 이미 사용 중인지 확인하고 경고 (설치는 계속 진행)
typeset -a fixed_commands
fixed_commands=(mtw_list mtw_new mtw_rm mtw_help)
typeset cmd
for cmd in "${fixed_commands[@]}"; do
  if command -v -- "$cmd" >/dev/null 2>&1; then
    print -ru2 -- "mtw: 경고: '${cmd}' 명령이 이미 사용 중입니다. 설치 후 충돌할 수 있습니다."
  fi
done

# 1. ~/.mtw/ 생성 (없을 때만)
if [[ ! -d "$MTW_DIR" ]]; then
  if ! command mkdir -p -- "$MTW_DIR"; then
    print -ru2 -- "mtw: 오류: 설치 디렉터리를 만들지 못했습니다: $MTW_DIR"
    exit 1
  fi
fi

# 2. src/mtw.zsh → ~/.mtw/mtw.zsh (기존 파일은 덮어씀)
if ! command cp -- "$SRC_FILE" "$MTW_BODY"; then
  print -ru2 -- "mtw: 오류: 기능 본체를 복사하지 못했습니다: $MTW_BODY"
  exit 1
fi

# 2-1. tmux 애드온 — --with-tmux 면 복사, 아니면 이미 있는 것을 제거한다.
# 남겨 두면 플래그 없이 재설치한 뒤에도 에이전트 명령이 살아 있어 설치 상태를
# 명령만 보고는 알 수 없게 된다. 재실행이 곧 상태 선언이 되도록 맞춘다.
if (( with_tmux )); then
  if ! command cp -- "$SRC_ADDON" "$MTW_ADDON"; then
    print -ru2 -- "mtw: 오류: tmux 애드온을 복사하지 못했습니다: $MTW_ADDON"
    exit 1
  fi
  print -r -- "mtw: tmux 애드온을 설치했습니다: $MTW_ADDON"
elif [[ -f "$MTW_ADDON" ]]; then
  if ! command rm -f -- "$MTW_ADDON"; then
    print -ru2 -- "mtw: 오류: tmux 애드온을 제거하지 못했습니다: $MTW_ADDON"
    exit 1
  fi
  print -r -- "mtw: tmux 애드온을 제거했습니다 (다시 설치하려면 --with-tmux 를 주세요)."
fi

# 3. ~/.mtw/projects — 없으면 빈 파일로 생성, 있으면 보존
if [[ ! -f "$PROJECTS_FILE" ]]; then
  if ! : > "$PROJECTS_FILE"; then
    print -ru2 -- "mtw: 오류: projects 파일을 생성하지 못했습니다: $PROJECTS_FILE"
    exit 1
  fi
fi

# 4. 프로필 파일이 없으면 생성
if [[ ! -f "$PROFILE" ]]; then
  if ! : > "$PROFILE"; then
    print -ru2 -- "mtw: 오류: 프로필 파일을 생성하지 못했습니다: $PROFILE"
    exit 1
  fi
fi

# 5~6. 마커 출현 횟수로 판정: 0/0 → 추가, 1/1(정순) → 이미 설치됨(건너뜀), 그 외 → 중단
typeset -a lines
if [[ -f "$PROFILE" ]]; then
  if [[ ! -r "$PROFILE" ]]; then
    print -ru2 -- "mtw: 오류: 프로필을 읽지 못했습니다: $PROFILE"
    exit 1
  fi
  lines=("${(@f)$(<"$PROFILE")}")
fi

typeset -i count_start=0 count_end=0 start_idx=0 end_idx=0 i
# 마커 판정에서만 줄 끝 \r 을 무시한다 (CRLF 프로필 대응). 파일에 다시 쓰는
# 것은 원본 lines 이므로 프로필 개행은 바뀌지 않는다.
# 추가할 블록의 개행은 프로필이 쓰고 있는 것에 맞춘다 — 항상 LF 로 넣으면
# CRLF 프로필에 혼합 개행이 생긴다. 줄 끝 CR 이 하나라도 있으면 CRLF 로 본다.
typeset eol=$'\n'
typeset marker_line
for (( i = 1; i <= ${#lines}; i++ )); do
  marker_line="${lines[i]%$'\r'}"
  [[ "$marker_line" != "${lines[i]}" ]] && eol=$'\r\n'
  if [[ "$marker_line" == "$MARKER_START" ]]; then
    (( count_start++ ))
    (( start_idx == 0 )) && start_idx=$i
  elif [[ "$marker_line" == "$MARKER_END" ]]; then
    (( count_end++ ))
    (( end_idx == 0 )) && end_idx=$i
  fi
done

if (( count_start == 0 && count_end == 0 )); then
  if [[ -s "$PROFILE" ]]; then
    typeset backup="${PROFILE}.bak-$(command date +%Y%m%d-%H%M%S)"
    if [[ -e "$backup" ]]; then
      typeset -i n=2
      while [[ -e "${backup}-${n}" ]]; do
        (( n++ ))
      done
      backup="${backup}-${n}"
    fi
    if ! command cp -- "$PROFILE" "$backup"; then
      print -ru2 -- "mtw: 오류: 프로필을 백업하지 못해 중단합니다: $backup"
      exit 1
    fi
    print -r -- "mtw: 프로필을 백업했습니다: $backup"
    [[ -n "$(command tail -c 1 -- "$PROFILE")" ]] && printf '%s' "$eol" >> "$PROFILE"
  fi
  typeset loader_line='[[ -f "$HOME/.mtw/mtw.zsh" ]] && source "$HOME/.mtw/mtw.zsh"'
  if ! printf '%s' "${MARKER_START}${eol}${loader_line}${eol}${MARKER_END}${eol}" >> "$PROFILE"; then
    print -ru2 -- "mtw: 오류: 프로필에 로더 블록을 추가하지 못했습니다: $PROFILE"
    exit 1
  fi
  print -r -- "mtw: 로더 블록을 추가했습니다: $PROFILE"
elif (( count_start == 1 && count_end == 1 && start_idx < end_idx )); then
  print -r -- "mtw: 프로필에 이미 로더 블록이 있어 건너뜁니다: $PROFILE"
else
  print -ru2 -- "mtw: 오류: 프로필에서 로더 블록 마커를 안전하게 판별할 수 없습니다: $PROFILE"
  print -ru2 -- "mtw: 자동으로 추가하지 않고 중단합니다. 프로필을 직접 열어 아래 마커로 표시된 블록을 확인하고 정리한 뒤 다시 실행하세요."
  print -ru2 -- "mtw: 기능 본체는 이미 설치되었습니다: $MTW_BODY (프로필만 변경되지 않았습니다)"
  print -ru2 -- "$MARKER_START"
  print -ru2 -- "$MARKER_END"
  exit 1
fi

# 7. 사용 가능한 명령 안내
print -r -- ""
print -r -- "설치가 완료되었습니다."
print -r -- ""
print -r -- "사용 가능한 명령:"
print -r -- "  mtw_list               등록된 프로젝트 목록 출력"
print -r -- "  mtw_new <이름>         현재 폴더를 목록에 등록"
print -r -- "  mtw_rm <이름>          목록에서 등록 해제"
print -r -- "  mtw_help               전체 명령 안내"
print -r -- "  mtw_cd_<이름>          등록된 경로로 이동"
if (( with_tmux )); then
  print -r -- "  mtw_claude [이름]      tmux 세션 생성 후 Claude Code 실행"
  print -r -- "  mtw_codex [이름]       tmux 세션 생성 후 Codex CLI 실행"
fi
print -r -- ""
print -r -- "이 스크립트는 별도 프로세스에서 실행되어 현재 터미널에는 반영되지 않습니다."
print -r -- "새 터미널을 열거나 다음 명령으로 프로필을 다시 읽으세요: source ~/.zshrc"
