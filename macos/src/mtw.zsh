# mtw v1.0.0
# mw-terminal-worknav - macOS (zsh + tmux) 기능 본체
#
# 설치 스크립트가 ~/.mtw/mtw.zsh 로 복사하고 ~/.zshrc 의 로더 블록이 source 한다.

# ── 에이전트 레지스트리 ──────────────────────────────────────────────
# "키 실행명령" 한 줄 추가로 mtw_<키> 명령이 생긴다. 키는 함수 이름이 되므로
# 예약어(아래 MTW_RESERVED)는 쓸 수 없다.
typeset -gA MTW_AGENTS
MTW_AGENTS=(
  claude claude
  codex  codex
)

# 고정 명령과 겹치면 안 되는 예약어 (에이전트 레지스트리 키 금지 목록)
typeset -ga MTW_RESERVED
MTW_RESERVED=(list new rm help cd)

# ── 설정 ─────────────────────────────────────────────────────────────
typeset -g MTW_PROJECTS_FILE="$HOME/.mtw/projects"
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

# 레지스트리(MTW_AGENTS) → mtw_<에이전트> 함수 생성.
__mtw_register_agents() {
  local key cmd
  for key in ${(k)MTW_AGENTS}; do
    if (( ${MTW_RESERVED[(Ie)$key]} )); then
      print -ru2 -- "mtw: 경고: 에이전트 키 '${key}' 는 예약어(${MTW_RESERVED}) 와 겹쳐 건너뜁니다."
      continue
    fi
    cmd="${MTW_AGENTS[$key]}"
    eval "mtw_${key}() { __mtw_session ${(qq)cmd} \"\$@\" }"
  done
}

# 에이전트 공통 실행 로직 — 세션명/경로 결정 후 tmux 로 세션(또는 창) 생성.
__mtw_session() {
  local agent_cmd="$1"
  local name="$2"
  local target_path session

  if [[ -n "$name" ]]; then
    if (( ! ${+MTW_PROJECTS[$name]} )); then
      print -ru2 -- "mtw: 오류: 등록되지 않은 이름입니다: $name"
      return 1
    fi
    target_path="${MTW_PROJECTS[$name]}"
    session="$name"
  else
    target_path="$PWD"
    session="${PWD:t}"
  fi

  session="${session//[^A-Za-z0-9_-]/_}"

  if [[ -n "$TMUX" ]]; then
    tmux new-window -n "$session" -c "$target_path" "$agent_cmd"
  else
    tmux new-session -A -s "$session" -c "$target_path" "$agent_cmd"
  fi
}

# 자동완성 후보 제공(zsh 컴플리션 컨텍스트) 및 등록(--register 호출 시).
__mtw_complete() {
  if [[ "$1" == "--register" ]]; then
    (( $+functions[compdef] )) || return 0

    local -a targets
    targets=(mtw_rm)
    local key
    for key in ${(k)MTW_AGENTS}; do
      (( ${MTW_RESERVED[(Ie)$key]} )) && continue
      targets+=("mtw_${key}")
    done

    compdef __mtw_complete $targets
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

  # 가장 긴 명령 이름에 맞춰 폭을 잡는다 — 고정 폭이면 긴 이름에서 여백이 사라진다.
  local key width=20
  for key in ${(k)MTW_PROJECTS}; do
    (( ${#key} + 9 > width )) && width=$(( ${#key} + 9 ))
  done

  for key in ${(ko)MTW_PROJECTS}; do
    printf '%-*s%s\n' "$width" "mtw_cd_${key}" "${MTW_PROJECTS[$key]}"
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

  print -r -- "등록되었습니다: mtw_cd_${name} -> ${PWD}"
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

  print -r -- "등록 해제되었습니다: $name (폴더는 그대로 남아 있습니다: $removed_path)"
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
  print -r -- ""
  print -r -- "에이전트 명령"
  local key
  for key in ${(ko)MTW_AGENTS}; do
    (( ${MTW_RESERVED[(Ie)$key]} )) && continue
    print -r -- "  mtw_${key} [이름]        세션 생성 후 '${MTW_AGENTS[$key]}' 실행"
  done
}

# ── 초기화 ───────────────────────────────────────────────────────────
# 목록 적재 → 이동 함수 생성 → 에이전트 함수 생성 → 자동완성 등록
__mtw_load
__mtw_register
__mtw_register_agents
__mtw_complete --register
