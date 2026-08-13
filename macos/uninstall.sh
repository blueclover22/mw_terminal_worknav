#!/usr/bin/env zsh
# mtw (mw-terminal-worknav) 제거 스크립트 - macOS (zsh)
#
# ~/.zshrc 에서 로더 블록을 제거하고 ~/.mtw/mtw.zsh 와 tmux 애드온을 삭제한다.
# --remove-projects 지정 시 ~/.mtw/ 전체를 삭제한다 (기본값은 목록 보존).

emulate -L zsh -o no_aliases

typeset -r MTW_DIR="$HOME/.mtw"
typeset -r MTW_BODY="$MTW_DIR/mtw.zsh"
typeset -r MTW_ADDON="$MTW_DIR/mtw-tmux.zsh"
typeset -r PROFILE="$HOME/.zshrc"
typeset -r MARKER_START="# >>> mtw (mw-terminal-worknav) >>>"
typeset -r MARKER_END="# <<< mtw (mw-terminal-worknav) <<<"

typeset -i remove_projects=0
typeset arg
for arg in "$@"; do
  case "$arg" in
    --remove-projects) remove_projects=1 ;;
    *)
      print -ru2 -- "mtw: 알 수 없는 옵션입니다: $arg"
      exit 1
      ;;
  esac
done

# 1. 프로필에서 마커 블록 제거 (백업 선행, 블록 제거로 생긴 끝쪽 빈 줄 정리)
if [[ -f "$PROFILE" ]]; then
  if [[ ! -r "$PROFILE" ]]; then
    print -ru2 -- "mtw: 오류: 프로필을 읽지 못했습니다: $PROFILE"
    exit 1
  fi
  typeset -a lines
  lines=("${(@f)$(<"$PROFILE")}")

  typeset -i count_start=0 count_end=0 start_idx=0 end_idx=0 i
  # 마커 판정에서만 줄 끝 \r 을 무시한다 (CRLF 프로필 대응). 파일에 다시 쓰는
  # 것은 원본 lines 이므로 프로필 개행은 바뀌지 않는다.
  typeset marker_line
  for (( i = 1; i <= ${#lines}; i++ )); do
    marker_line="${lines[i]%$'\r'}"
    if [[ "$marker_line" == "$MARKER_START" ]]; then
      (( count_start++ ))
      (( start_idx == 0 )) && start_idx=$i
    elif [[ "$marker_line" == "$MARKER_END" ]]; then
      (( count_end++ ))
      (( end_idx == 0 )) && end_idx=$i
    fi
  done

  if (( count_start == 0 && count_end == 0 )); then
    print -r -- "mtw: 프로필에 로더 블록이 없어 건너뜁니다: $PROFILE"
  elif (( count_start == 1 && count_end == 1 && start_idx < end_idx )); then
    typeset -a new_lines
    new_lines=()
    (( start_idx > 1 )) && new_lines+=("${(@)lines[1,start_idx-1]}")
    (( end_idx < ${#lines} )) && new_lines+=("${(@)lines[end_idx+1,-1]}")

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

    while (( ${#new_lines} > 0 )) && [[ -z "${new_lines[-1]}" ]]; do
      new_lines[-1]=()
    done

    if (( ${#new_lines} > 0 )); then
      if ! print -rl -- "${new_lines[@]}" > "$PROFILE"; then
        print -ru2 -- "mtw: 오류: 프로필을 갱신하지 못했습니다: $PROFILE"
        exit 1
      fi
    else
      if ! : > "$PROFILE"; then
        print -ru2 -- "mtw: 오류: 프로필을 갱신하지 못했습니다: $PROFILE"
        exit 1
      fi
    fi
    print -r -- "mtw: 프로필에서 로더 블록을 제거했습니다: $PROFILE"
  else
    print -ru2 -- "mtw: 오류: 프로필에서 로더 블록 마커를 안전하게 판별할 수 없습니다: $PROFILE"
    print -ru2 -- "mtw: 자동으로 잘라내지 않고 중단합니다. 프로필을 직접 열어 아래 마커로 표시된 블록을 확인하고 정리하세요."
    print -ru2 -- "$MARKER_START"
    print -ru2 -- "$MARKER_END"
    exit 1
  fi
else
  print -r -- "mtw: 프로필 파일이 없어 건너뜁니다: $PROFILE"
fi

# 2. ~/.mtw/mtw.zsh 삭제
if [[ -f "$MTW_BODY" ]]; then
  if ! command rm -f -- "$MTW_BODY"; then
    print -ru2 -- "mtw: 오류: 기능 본체를 삭제하지 못했습니다: $MTW_BODY"
    exit 1
  fi
  print -r -- "mtw: 기능 본체를 삭제했습니다: $MTW_BODY"
fi

# 2-1. ~/.mtw/mtw-tmux.zsh 삭제 (--with-tmux 로 설치했을 때만 존재한다)
if [[ -f "$MTW_ADDON" ]]; then
  if ! command rm -f -- "$MTW_ADDON"; then
    print -ru2 -- "mtw: 오류: tmux 애드온을 삭제하지 못했습니다: $MTW_ADDON"
    exit 1
  fi
  print -r -- "mtw: tmux 애드온을 삭제했습니다: $MTW_ADDON"
fi

# 3. --remove-projects 지정 시 ~/.mtw/ 전체 삭제 (프로젝트 목록 포함, 백업 선행)
if (( remove_projects )); then
  if [[ -d "$MTW_DIR" ]]; then
    typeset dir_backup="${MTW_DIR}.bak-$(command date +%Y%m%d-%H%M%S)"
    if [[ -e "$dir_backup" ]]; then
      typeset -i n=2
      while [[ -e "${dir_backup}-${n}" ]]; do
        (( n++ ))
      done
      dir_backup="${dir_backup}-${n}"
    fi
    if ! command cp -R -- "$MTW_DIR" "$dir_backup"; then
      print -ru2 -- "mtw: 오류: ~/.mtw 를 백업하지 못해 중단합니다: $dir_backup"
      exit 1
    fi
    print -r -- "mtw: ~/.mtw 를 백업했습니다: $dir_backup"
    if ! command rm -rf -- "$MTW_DIR"; then
      print -ru2 -- "mtw: 오류: ~/.mtw 를 삭제하지 못했습니다: $MTW_DIR"
      exit 1
    fi
    print -r -- "mtw: ~/.mtw 를 삭제했습니다 (프로젝트 목록 포함)."
  fi
else
  print -r -- "mtw: 프로젝트 목록은 보존됩니다: $MTW_DIR/projects"
fi

# 4. 현재 세션 정리 안내
print -r -- ""
print -r -- "제거가 완료되었습니다."
print -r -- ""
print -r -- "이미 열려 있는 터미널에는 mtw 함수가 메모리에 남아 있습니다."
print -r -- "정리하려면 해당 터미널에서 다음을 실행하세요: exec zsh"
