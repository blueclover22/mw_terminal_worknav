# mtw-tmux v1.0.0
# mw-terminal-worknav - macOS (zsh) tmux 애드온
#
# 설치 스크립트를 --with-tmux 로 실행했을 때만 ~/.mtw/mtw-tmux.zsh 로 복사되고,
# 기능 본체(mtw.zsh)가 마지막에 source 한다. 본체와 같은 스코프에서 실행되므로
# MTW_PROJECTS 와 __mtw_complete 를 그대로 쓴다.

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

# ── 내부 함수 ────────────────────────────────────────────────────────

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
  local target_path session key matched_key

  if [[ -n "$name" ]]; then
    # 이름 매칭은 대소문자를 무시한다 — mtw_new 중복 검사 · mtw_rm 과 같은 규칙.
    # 세션명도 입력 표기가 아니라 등록된 표기를 쓴다.
    matched_key=""
    for key in ${(k)MTW_PROJECTS}; do
      if [[ "${key:l}" == "${name:l}" ]]; then
        matched_key="$key"
        break
      fi
    done
    if [[ -z "$matched_key" ]]; then
      print -ru2 -- "mtw: 오류: 등록되지 않은 이름입니다: $name"
      return 1
    fi
    target_path="${MTW_PROJECTS[$matched_key]}"
    session="$matched_key"
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

# mtw_help 확장 훅 — 본체의 mtw_help 가 이 함수의 존재를 확인하고 호출한다.
__mtw_help_agents() {
  print -r -- ""
  print -r -- "에이전트 명령 (tmux 애드온)"
  local key
  for key in ${(ko)MTW_AGENTS}; do
    (( ${MTW_RESERVED[(Ie)$key]} )) && continue
    print -r -- "  mtw_${key} [이름]        세션 생성 후 '${MTW_AGENTS[$key]}' 실행"
  done
}

# 자동완성 등록 — 레지스트리에서 생성된 에이전트 명령만. mtw_rm 은 본체가 맡는다.
# 후보 제공 함수(__mtw_complete)는 본체 것을 그대로 쓴다.
__mtw_register_agent_completion() {
  (( $+functions[compdef] )) || return 0

  local -a targets
  targets=()
  local key
  for key in ${(k)MTW_AGENTS}; do
    (( ${MTW_RESERVED[(Ie)$key]} )) && continue
    targets+=("mtw_${key}")
  done
  (( ${#targets} == 0 )) && return 0

  compdef __mtw_complete $targets
}

# ── 초기화 ───────────────────────────────────────────────────────────
# 에이전트 함수 생성 → 에이전트 자동완성 등록
__mtw_register_agents
__mtw_register_agent_completion
