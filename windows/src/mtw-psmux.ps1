# mtw-psmux v2.0.1
# mw-terminal-worknav - Windows (PowerShell 7) psmux 애드온
#
# 설치 스크립트를 -WithPsmux 로 실행했을 때만 ~/.mtw/mtw-psmux.ps1 로 복사되고,
# 기능 본체(mtw.ps1)가 마지막에 dot-source 한다. 본체와 같은 스코프에서 실행되므로
# $script:MTW_PROJECTS 와 __mtw_complete 를 그대로 쓴다.
#
# 호출하는 명령은 psmux 가 아니라 tmux 다 — psmux 는 psmux · pmux · tmux 세 실행
# 명령을 모두 제공하며, tmux 를 쓰면 세션 생성 명령이 macOS 판과 한 글자도 다르지
# 않게 된다. 애드온 이름만 OS 별 멀티플렉서를 따른다.

# ── 에이전트 레지스트리 ──────────────────────────────────────────────
# "키 = 실행명령" 한 줄 추가로 mtw_<키> 명령이 생긴다. 키는 함수 이름이 되므로
# 예약어(아래 MTW_RESERVED)는 쓸 수 없다.
$script:MTW_AGENTS = [ordered]@{
    claude = 'claude'
    codex  = 'codex'
}

# 고정 명령과 겹치면 안 되는 예약어 (에이전트 레지스트리 키 금지 목록)
$script:MTW_RESERVED = @('list', 'new', 'rm', 'help', 'cd')

# ── 내부 함수 ────────────────────────────────────────────────────────

# 레지스트리(MTW_AGENTS) → mtw_<에이전트> 함수 생성.
function __mtw_register_agents {
    foreach ($key in $script:MTW_AGENTS.Keys) {
        if ($script:MTW_RESERVED -contains $key) {
            $host.UI.WriteErrorLine("mtw: 경고: 에이전트 키 '$key' 는 예약어($($script:MTW_RESERVED -join ' ')) 와 겹쳐 건너뜁니다.")
            continue
        }
        $cmd = $script:MTW_AGENTS[$key]
        $sb = {
            param([string]$Name)
            __mtw_session -AgentCmd $cmd -Name $Name
        }.GetNewClosure()
        New-Item -Path "function:global:mtw_$key" -Value $sb -Force | Out-Null
    }
}

# 에이전트 공통 실행 로직 — 세션명/경로 결정 후 psmux 의 tmux 명령으로 세션(또는 창) 생성.
# 종료 상태 — 실패 시 $LASTEXITCODE = 1. 성공 경로에서는 되돌리지 않는다.
# 마지막 동작이 네이티브 tmux 라 그 종료 코드가 담기고, 이것이 zsh 판과 같은 동작이다.
function __mtw_session {
    param(
        [Parameter(Mandatory)] [string]$AgentCmd,
        [string]$Name
    )

    if (-not [string]::IsNullOrEmpty($Name)) {
        # 이름 매칭은 대소문자를 무시한다 — mtw_new 중복 검사 · mtw_rm 과 같은 규칙.
        # 세션명도 입력 표기가 아니라 등록된 표기를 쓴다.
        $matchedKey = ''
        foreach ($existingKey in $script:MTW_PROJECTS.Keys) {
            if ($existingKey.ToLowerInvariant() -eq $Name.ToLowerInvariant()) {
                $matchedKey = $existingKey
                break
            }
        }
        if ([string]::IsNullOrEmpty($matchedKey)) {
            $host.UI.WriteErrorLine("mtw: 오류: 등록되지 않은 이름입니다: $Name")
            $global:LASTEXITCODE = 1
            return
        }
        $targetPath = $script:MTW_PROJECTS[$matchedKey]
        $session = $matchedKey
    }
    else {
        $targetPath = (Get-Location).Path
        $session = Split-Path -Leaf $targetPath
    }

    $session = $session -replace '[^A-Za-z0-9_-]', '_'

    if ($env:TMUX) {
        tmux new-window -n $session -c $targetPath $AgentCmd
    }
    else {
        tmux new-session -A -s $session -c $targetPath $AgentCmd
    }
}

# mtw_help 확장 훅 — 본체의 mtw_help 가 이 함수의 존재를 확인하고 호출한다.
function __mtw_help_agents {
    Write-Output ''
    Write-Output '에이전트 명령 (psmux 애드온)'

    # 본체 고정 명령 절과 같은 23열에 설명을 맞춘다. 표시 폭은 "mtw_" + 키 +
    # " [이름]" 이고 한글이 두 칸을 차지하므로 11 + 키 길이다. 고정 여백이면
    # 키 길이가 다를 때 열이 어긋나므로, 가장 긴 키에 맞춰 절 전체를 넓힌다.
    $width = 23
    foreach ($key in $script:MTW_AGENTS.Keys) {
        if ($script:MTW_RESERVED -contains $key) { continue }
        if ($key.Length + 13 -gt $width) { $width = $key.Length + 13 }
    }

    foreach ($key in ($script:MTW_AGENTS.Keys | Sort-Object)) {
        if ($script:MTW_RESERVED -contains $key) { continue }
        $pad = ' ' * ($width - $key.Length - 11)
        Write-Output "  mtw_$key [이름]${pad}세션 생성 후 '$($script:MTW_AGENTS[$key])' 실행"
    }
}

# 자동완성 등록 — 레지스트리에서 생성된 에이전트 명령만. mtw_rm 은 본체가 맡는다.
# 후보 제공 함수(__mtw_complete)는 본체 것을 그대로 쓴다.
function __mtw_register_agent_completion {
    $targets = [System.Collections.Generic.List[string]]::new()
    foreach ($key in $script:MTW_AGENTS.Keys) {
        if ($script:MTW_RESERVED -contains $key) { continue }
        $targets.Add("mtw_$key")
    }
    if ($targets.Count -eq 0) { return }

    Register-ArgumentCompleter -CommandName $targets -ParameterName 'Name' -ScriptBlock ${function:__mtw_complete}
}

# ── 초기화 ───────────────────────────────────────────────────────────
# 에이전트 함수 생성 → 에이전트 자동완성 등록
__mtw_register_agents
__mtw_register_agent_completion
