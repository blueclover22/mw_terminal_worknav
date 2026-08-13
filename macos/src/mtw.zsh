# mtw v2.0.0
# mw-terminal-worknav - macOS (zsh) 기능 본체
#
# 설치 스크립트가 ~/.mtw/mtw.zsh 로 복사하고 ~/.zshrc 의 로더 블록이 source 한다.
# 이동·목록 명령만 담고 멀티플렉서에 의존하지 않는다. 에이전트 세션 명령은
# 선택 설치되는 tmux 애드온(mtw-tmux.zsh)이 제공하며 이 파일 마지막에서 로드된다.

# ── 설정 ─────────────────────────────────────────────────────────────
typeset -g MTW_PROJECTS_FILE="$HOME/.mtw/projects"
typeset -g MTW_ADDON_TMUX="$HOME/.mtw/mtw-tmux.zsh"
typeset -gA MTW_PROJECTS

# ── 내부 함수 ────────────────────────────────────────────────────────

# ~/.mtw/projects → 메모리(MTW_PROJECTS). 파일이 없으면 오류 없이 빈 목록.
__mtw_load() {
  MTW_PROJECTS=()
  [[ -f "$MTW_PROJECTS_FILE" ]] || return 0

  local line key key_lc value
  local -A seen_lc
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue
    [[ "$line" != *=* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    # CRLF 파일의 줄 끝 \r 제거 — 남기면 존재하지 않는 경로로 이동한다.
    value="${value%$'\r'}"
    [[ -z "$key" ]] && continue
    [[ "$key" == [A-Za-z_]* && "$key" == "${key//[^A-Za-z0-9_-]/}" ]] || continue

    # 완전 동일 키는 last-wins, 대소문자만 다른 키는 first-wins(PowerShell 함수
    # 이름이 대소문자를 구분하지 않는 제약). 순서가 뒤바뀌면 last-wins 가 깨진다.
    if (( ${+MTW_PROJECTS[$key]} )); then
      MTW_PROJECTS[$key]="$value"
      continue
    fi
    key_lc="${key:l}"
    (( ${+seen_lc[$key_lc]} )) && continue
    seen_lc[$key_lc]=1

    MTW_PROJECTS[$key]="$value"
  done < "$MTW_PROJECTS_FILE"
}

# 메모리(MTW_PROJECTS) → mtw_cd_* 함수 생성. 목록에 없는 함수는 제거.
__mtw_register() {
  local fname key
  for fname in ${(k)functions}; do
    [[ "$fname" == mtw_cd_* ]] || continue
    key="${fname#mtw_cd_}"
    (( ${+MTW_PROJECTS[$key]} )) || unfunction -- "$fname" 2>/dev/null
  done

  for key in ${(k)MTW_PROJECTS}; do
    eval "mtw_cd_${key}() { cd -- ${(qq)MTW_PROJECTS[$key]} }"
  done
}

# 자동완성 후보 제공(zsh 컴플리션 컨텍스트) 및 등록(--register 호출 시).
# 등록 대상은 본체가 제공하는 mtw_rm. 에이전트 명령은 애드온이 따로 등록한다.
__mtw_complete() {
  if [[ "$1" == "--register" ]]; then
    (( $+functions[compdef] )) || return 0
    compdef __mtw_complete mtw_rm
    return 0
  fi

  local -a names
  names=(${(k)MTW_PROJECTS})
  compadd -a names
}

# ── 공개 명령 ────────────────────────────────────────────────────────

mtw_list() {
  if (( ${#MTW_PROJECTS} == 0 )); then
    print -r -- "등록된 프로젝트가 없습니다. mtw_new <이름> 으로 현재 폴더를 등록하세요."
    return 0
  fi

  # 가장 긴 이름에 맞춰 폭을 잡는다 — 고정 폭이면 긴 이름에서 여백이 사라진다.
  local key width=12
  for key in ${(k)MTW_PROJECTS}; do
    (( ${#key} + 2 > width )) && width=$(( ${#key} + 2 ))
  done

  for key in ${(ko)MTW_PROJECTS}; do
    printf '%-*s%s\n' "$width" "$key" "${MTW_PROJECTS[$key]}"
  done
}

mtw_new() {
  local name="$1"

  if [[ -z "$name" ]]; then
    print -ru2 -- "오류: 이름을 입력하세요."
    print -ru2 -- "사용법: mtw_new <이름>"
    return 1
  fi

  if [[ ! ( "$name" == [A-Za-z_]* && "$name" == "${name//[^A-Za-z0-9_-]/}" ) ]]; then
    print -ru2 -- "오류: 올바르지 않은 이름입니다: $name (허용 형식: ^[A-Za-z_][A-Za-z0-9_-]*\$)"
    return 1
  fi

  local key
  for key in ${(k)MTW_PROJECTS}; do
    if [[ "${key:l}" == "${name:l}" ]]; then
      print -ru2 -- "오류: 이미 등록된 이름입니다: $key -> ${MTW_PROJECTS[$key]}"
      return 1
    fi
  done

  # 쓰기 실패를 확인한다 — 실패했는데 "등록되었습니다" + 0 으로 끝나면 안 된다.
  if [[ ! -d "$HOME/.mtw" ]]; then
    if ! mkdir -p "$HOME/.mtw"; then
      print -ru2 -- "오류: 설치 디렉터리를 만들지 못했습니다: $HOME/.mtw"
      return 1
    fi
  fi
  if [[ ! -f "$MTW_PROJECTS_FILE" ]]; then
    if ! : > "$MTW_PROJECTS_FILE"; then
      print -ru2 -- "오류: 목록 파일에 기록하지 못했습니다: $MTW_PROJECTS_FILE"
      return 1
    fi
  fi

  if [[ -s "$MTW_PROJECTS_FILE" ]]; then
    if [[ -n "$(tail -c 1 "$MTW_PROJECTS_FILE")" ]]; then
      if ! print -r -- "" >> "$MTW_PROJECTS_FILE"; then
        print -ru2 -- "오류: 목록 파일에 기록하지 못했습니다: $MTW_PROJECTS_FILE"
        return 1
      fi
    fi
  fi
  if ! print -r -- "${name}=${PWD}" >> "$MTW_PROJECTS_FILE"; then
    print -ru2 -- "오류: 목록 파일에 기록하지 못했습니다: $MTW_PROJECTS_FILE"
    return 1
  fi

  __mtw_load
  __mtw_register

  print -r -- "등록되었습니다: ${name} -> ${PWD}"
}

mtw_rm() {
  local name="$1"

  if [[ -z "$name" ]]; then
    print -ru2 -- "오류: 이름을 입력하세요."
    print -ru2 -- "사용법: mtw_rm <이름>"
    return 1
  fi

  if [[ ! -f "$MTW_PROJECTS_FILE" ]]; then
    print -ru2 -- "오류: 등록되지 않은 이름입니다: $name"
    return 1
  fi

  local target_lc="${name:l}"
  local found=0
  local removed_key=""
  local removed_path=""
  local -a out_lines
  out_lines=()

  local line key
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" || "$line" == \#* || "$line" != *=* ]]; then
      out_lines+=("$line")
      continue
    fi
    key="${line%%=*}"
    if [[ -n "$key" && "${key:l}" == "$target_lc" ]]; then
      found=1
      # 입력 표기가 아니라 등록된 표기를 알린다 — 매칭이 대소문자를 무시하기 때문.
      removed_key="$key"
      removed_path="${line#*=}"
      # __mtw_load 와 같은 규칙 — 남기면 완료 메시지 끝에 CR 이 붙는다.
      removed_path="${removed_path%$'\r'}"
      continue
    fi
    out_lines+=("$line")
  done < "$MTW_PROJECTS_FILE"

  if (( ! found )); then
    print -ru2 -- "오류: 등록되지 않은 이름입니다: $name"
    return 1
  fi

  # 임시 파일에 쓰고 옮긴다. 실패를 확인해야 목록을 잃고도 성공 메시지가 안 나온다.
  local tmp_file
  if ! tmp_file="$(mktemp "${MTW_PROJECTS_FILE}.XXXXXX")"; then
    print -ru2 -- "오류: 목록 파일을 갱신하지 못했습니다: $MTW_PROJECTS_FILE"
    return 1
  fi
  if (( ${#out_lines} > 0 )); then
    if ! print -rl -- "${out_lines[@]}" > "$tmp_file"; then
      rm -f "$tmp_file"
      print -ru2 -- "오류: 목록 파일을 갱신하지 못했습니다: $MTW_PROJECTS_FILE"
      return 1
    fi
  else
    if ! : > "$tmp_file"; then
      rm -f "$tmp_file"
      print -ru2 -- "오류: 목록 파일을 갱신하지 못했습니다: $MTW_PROJECTS_FILE"
      return 1
    fi
  fi
  if ! mv "$tmp_file" "$MTW_PROJECTS_FILE"; then
    rm -f "$tmp_file"
    print -ru2 -- "오류: 목록 파일을 갱신하지 못했습니다: $MTW_PROJECTS_FILE"
    return 1
  fi

  __mtw_load
  __mtw_register

  print -r -- "등록 해제되었습니다: $removed_key (폴더는 그대로 남아 있습니다: $removed_path)"
}

mtw_help() {
  print -r -- "mtw - mw-terminal-worknav"
  print -r -- ""
  print -r -- "고정 명령"
  print -r -- "  mtw_list               등록된 프로젝트 목록 출력"
  print -r -- "  mtw_new <이름>         현재 폴더를 목록에 등록"
  print -r -- "  mtw_rm <이름>          목록에서 등록 해제 (폴더는 삭제하지 않음)"
  print -r -- "  mtw_help               이 도움말 출력"
  print -r -- "  mtw_cd_<이름>          등록된 경로로 이동"

  # 애드온이 로드되어 있으면 자기 명령 절을 덧붙인다.
  (( $+functions[__mtw_help_agents] )) && __mtw_help_agents

  return 0
}

# ── 초기화 ───────────────────────────────────────────────────────────
# 목록 적재 → 이동 함수 생성 → 자동완성 등록 → 애드온(있으면) 로드
__mtw_load
__mtw_register
__mtw_complete --register

# tmux 애드온은 설치 스크립트를 --with-tmux 로 실행했을 때만 존재한다. 로더 블록이
# 아니라 여기서 읽는 이유는, 이미 프로필에 로더 블록이 있는 설치본에 줄을 더
# 넣으려면 프로필 재작성이 필요해서다 — 본체 갱신만으로 애드온 유무를 반영한다.
#
# && 가 아니라 if 를 쓰는 이유 — 애드온이 없을 때 source 된 파일의 종료 상태가
# 1 이 되고, 그것이 .zshrc 의 마지막 상태로 남아 첫 프롬프트에 실패로 보인다.
if [[ -f "$MTW_ADDON_TMUX" ]]; then
  source "$MTW_ADDON_TMUX"
fi
