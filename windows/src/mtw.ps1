# mtw v1.0.0
# mw-terminal-worknav - Windows (PowerShell 7 + tmux/psmux) 기능 본체
#
# 설치 스크립트가 ~/.mtw/mtw.ps1 로 복사하고 $PROFILE 의 로더 블록이 dot-source 한다.

# ── 에이전트 레지스트리 ──────────────────────────────────────────────
# "키 = 실행명령" 한 줄 추가로 mtw_<키> 명령이 생긴다. 키는 함수 이름이 되므로
# 예약어(아래 MTW_RESERVED)는 쓸 수 없다.
$script:MTW_AGENTS = [ordered]@{
    claude = 'claude'
    codex  = 'codex'
}

# 고정 명령과 겹치면 안 되는 예약어 (에이전트 레지스트리 키 금지 목록)
$script:MTW_RESERVED = @('list', 'new', 'rm', 'help', 'cd')

# ── 설정 ─────────────────────────────────────────────────────────────
$script:MTW_PROJECTS_FILE = Join-Path $HOME '.mtw' 'projects'
$script:MTW_PROJECTS = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)

# ── 내부 함수 ────────────────────────────────────────────────────────

# 이름/키 형식 검증 — __mtw_load 와 mtw_new 가 공유한다.
# -cmatch 필수: -match 는 대소문자 접기로 U+212A(KELVIN) 등 비ASCII 문자까지
# [A-Za-z] 에 매칭시킨다. \A~\z 는 NUL 포함 전체 문자열을 검사한다.
function __mtw_test_valid_name {
    param([string]$Value)
    return ($Value -cmatch '\A[A-Za-z_][A-Za-z0-9_-]*\z')
}

# ~/.mtw/projects → 메모리(MTW_PROJECTS). 파일이 없으면 오류 없이 빈 목록.
function __mtw_load {
    $script:MTW_PROJECTS = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)

    if (-not (Test-Path -LiteralPath $script:MTW_PROJECTS_FILE)) {
        return
    }

    # PowerShell 함수 이름은 대소문자를 구분하지 않아 mtw_cd_Foo 와 mtw_cd_foo 가
    # 공존할 수 없다. 대소문자 무시 기준으로 먼저 나온 키를 유지한다.
    $seenKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($line in (Get-Content -LiteralPath $script:MTW_PROJECTS_FILE)) {
        if ([string]::IsNullOrEmpty($line)) { continue }
        if ($line.StartsWith('#')) { continue }
        if (-not $line.Contains('=')) { continue }

        $idx = $line.IndexOf('=')
        $key = $line.Substring(0, $idx)
        $value = $line.Substring($idx + 1)

        if ([string]::IsNullOrEmpty($key)) { continue }
        if (-not (__mtw_test_valid_name $key)) { continue }

        # 완전 동일 키는 last-wins, 대소문자만 다른 키는 first-wins.
        # 순서가 뒤바뀌면 last-wins 가 깨진다.
        if ($script:MTW_PROJECTS.ContainsKey($key)) {
            $script:MTW_PROJECTS[$key] = $value
            continue
        }
        if (-not $seenKeys.Add($key)) { continue }

        $script:MTW_PROJECTS[$key] = $value
    }
}

# 메모리(MTW_PROJECTS) → mtw_cd_* 함수 생성. 목록에 없는 함수는 제거.
function __mtw_register {
    foreach ($fname in (Get-ChildItem -Path 'function:mtw_cd_*' -Name)) {
        $key = $fname.Substring('mtw_cd_'.Length)
        if (-not $script:MTW_PROJECTS.ContainsKey($key)) {
            Remove-Item -Path "function:$fname" -Force -ErrorAction SilentlyContinue
        }
    }

    foreach ($key in $script:MTW_PROJECTS.Keys) {
        $path = $script:MTW_PROJECTS[$key]
        $sb = {
            Set-Location -LiteralPath $path
        }.GetNewClosure()
        New-Item -Path "function:global:mtw_cd_$key" -Value $sb -Force | Out-Null
    }
}

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

# 에이전트 공통 실행 로직 — 세션명/경로 결정 후 tmux 로 세션(또는 창) 생성.
function __mtw_session {
    param(
        [Parameter(Mandatory)] [string]$AgentCmd,
        [string]$Name
    )

    if (-not [string]::IsNullOrEmpty($Name)) {
        if (-not $script:MTW_PROJECTS.ContainsKey($Name)) {
            $host.UI.WriteErrorLine("mtw: 오류: 등록되지 않은 이름입니다: $Name")
            $global:LASTEXITCODE = 1
            return
        }
        $targetPath = $script:MTW_PROJECTS[$Name]
        $session = $Name
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

# 자동완성 후보 제공(등록 시점이 아니라 호출 시점의 메모리 목록을 읽는다).
function __mtw_complete {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $script:MTW_PROJECTS.Keys |
        Where-Object { $_ -like "$wordToComplete*" } |
        Sort-Object |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# 자동완성 등록 — mtw_rm + 레지스트리에서 생성된 에이전트 명령 전체.
function __mtw_register_completion {
    $targets = [System.Collections.Generic.List[string]]::new()
    $targets.Add('mtw_rm')
    foreach ($key in $script:MTW_AGENTS.Keys) {
        if ($script:MTW_RESERVED -contains $key) { continue }
        $targets.Add("mtw_$key")
    }

    Register-ArgumentCompleter -CommandName $targets -ParameterName 'Name' -ScriptBlock ${function:__mtw_complete}
}

# ── 공개 명령 ────────────────────────────────────────────────────────
#
# 종료 상태 규칙 — 실패 시 $LASTEXITCODE = 1, 성공 시 0. 함수는 프로세스 종료
# 코드를 내지 않으므로 이 변수가 유일한 통보 수단이며, 성공 경로에서 되돌리지
# 않으면 직전 실패의 1 이 남는다. __mtw_session 은 예외 — 마지막 동작이 네이티브
# tmux 라 그 종료 코드가 담기고, 이것이 zsh 판과 같은 동작이다.

function mtw_list {
    if ($script:MTW_PROJECTS.Count -eq 0) {
        Write-Output '등록된 프로젝트가 없습니다. mtw_new <이름> 으로 현재 폴더를 등록하세요.'
        $global:LASTEXITCODE = 0
        return
    }

    # 가장 긴 명령 이름에 맞춰 폭을 잡는다 — 고정 폭이면 긴 이름에서 여백이 사라진다.
    $width = 20
    foreach ($key in $script:MTW_PROJECTS.Keys) {
        if ($key.Length + 9 -gt $width) { $width = $key.Length + 9 }
    }

    foreach ($key in ($script:MTW_PROJECTS.Keys | Sort-Object)) {
        Write-Output ("mtw_cd_$key".PadRight($width) + $script:MTW_PROJECTS[$key])
    }
    $global:LASTEXITCODE = 0
}

function mtw_new {
    param([string]$Name)

    if ([string]::IsNullOrEmpty($Name)) {
        $host.UI.WriteErrorLine('오류: 이름을 입력하세요.')
        $host.UI.WriteErrorLine('사용법: mtw_new <이름>')
        $global:LASTEXITCODE = 1
        return
    }

    if (-not (__mtw_test_valid_name $Name)) {
        $host.UI.WriteErrorLine("오류: 올바르지 않은 이름입니다: $Name (허용 형식: ^[A-Za-z_][A-Za-z0-9_-]*`$)")
        $global:LASTEXITCODE = 1
        return
    }

    foreach ($existingKey in $script:MTW_PROJECTS.Keys) {
        if ($existingKey.ToLowerInvariant() -eq $Name.ToLowerInvariant()) {
            $host.UI.WriteErrorLine("오류: 이미 등록된 이름입니다: $existingKey -> $($script:MTW_PROJECTS[$existingKey])")
            $global:LASTEXITCODE = 1
            return
        }
    }

    # 쓰기 실패를 확인한다 — 실패했는데 "등록되었습니다" + 0 으로 끝나면 안 된다.
    $mtwDir = Join-Path $HOME '.mtw'
    if (-not (Test-Path -LiteralPath $mtwDir -PathType Container)) {
        try { New-Item -ItemType Directory -Path $mtwDir -Force -ErrorAction Stop | Out-Null }
        catch {
            $host.UI.WriteErrorLine("오류: 설치 디렉터리를 만들지 못했습니다: $mtwDir")
            $global:LASTEXITCODE = 1
            return
        }
    }
    if (-not (Test-Path -LiteralPath $script:MTW_PROJECTS_FILE -PathType Leaf)) {
        try { New-Item -ItemType File -Path $script:MTW_PROJECTS_FILE -Force -ErrorAction Stop | Out-Null }
        catch {
            $host.UI.WriteErrorLine("오류: 목록 파일에 기록하지 못했습니다: $($script:MTW_PROJECTS_FILE)")
            $global:LASTEXITCODE = 1
            return
        }
    }

    $currentPath = (Get-Location).Path
    try {
        if ((Get-Item -LiteralPath $script:MTW_PROJECTS_FILE).Length -gt 0) {
            $bytes = [System.IO.File]::ReadAllBytes($script:MTW_PROJECTS_FILE)
            if ($bytes[$bytes.Length - 1] -ne 10) {
                Add-Content -LiteralPath $script:MTW_PROJECTS_FILE -Value '' -ErrorAction Stop
            }
        }
        Add-Content -LiteralPath $script:MTW_PROJECTS_FILE -Value "$Name=$currentPath" -ErrorAction Stop
    }
    catch {
        $host.UI.WriteErrorLine("오류: 목록 파일에 기록하지 못했습니다: $($script:MTW_PROJECTS_FILE)")
        $global:LASTEXITCODE = 1
        return
    }

    __mtw_load
    __mtw_register

    Write-Output "등록되었습니다: mtw_cd_$Name -> $currentPath"
    $global:LASTEXITCODE = 0
}

function mtw_rm {
    param([string]$Name)

    if ([string]::IsNullOrEmpty($Name)) {
        $host.UI.WriteErrorLine('오류: 이름을 입력하세요.')
        $host.UI.WriteErrorLine('사용법: mtw_rm <이름>')
        $global:LASTEXITCODE = 1
        return
    }

    if (-not (Test-Path -LiteralPath $script:MTW_PROJECTS_FILE)) {
        $host.UI.WriteErrorLine("오류: 등록되지 않은 이름입니다: $Name")
        $global:LASTEXITCODE = 1
        return
    }

    $targetLower = $Name.ToLowerInvariant()
    $found = $false
    $removedPath = ''
    $outLines = [System.Collections.Generic.List[string]]::new()

    foreach ($line in (Get-Content -LiteralPath $script:MTW_PROJECTS_FILE)) {
        if ([string]::IsNullOrEmpty($line) -or $line.StartsWith('#') -or (-not $line.Contains('='))) {
            $outLines.Add($line)
            continue
        }

        $idx = $line.IndexOf('=')
        $key = $line.Substring(0, $idx)
        if ($key -ne '' -and $key.ToLowerInvariant() -eq $targetLower) {
            $found = $true
            $removedPath = $line.Substring($idx + 1)
            continue
        }
        $outLines.Add($line)
    }

    if (-not $found) {
        $host.UI.WriteErrorLine("오류: 등록되지 않은 이름입니다: $Name")
        $global:LASTEXITCODE = 1
        return
    }

    # 임시 파일에 쓰고 옮긴다. 실패를 확인해야 목록을 잃고도 성공 메시지가 안 나온다.
    $tmpFile = Join-Path (Split-Path -Parent $script:MTW_PROJECTS_FILE) ('projects.' + [System.Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        Set-Content -LiteralPath $tmpFile -Value $outLines -ErrorAction Stop
        Move-Item -LiteralPath $tmpFile -Destination $script:MTW_PROJECTS_FILE -Force -ErrorAction Stop
    }
    catch {
        Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue
        $host.UI.WriteErrorLine("오류: 목록 파일을 갱신하지 못했습니다: $($script:MTW_PROJECTS_FILE)")
        $global:LASTEXITCODE = 1
        return
    }

    __mtw_load
    __mtw_register

    Write-Output "등록 해제되었습니다: $Name (폴더는 그대로 남아 있습니다: $removedPath)"
    $global:LASTEXITCODE = 0
}

function mtw_help {
    Write-Output 'mtw - mw-terminal-worknav'
    Write-Output ''
    Write-Output '고정 명령'
    Write-Output '  mtw_list               등록된 프로젝트 목록 출력'
    Write-Output '  mtw_new <이름>         현재 폴더를 목록에 등록'
    Write-Output '  mtw_rm <이름>          목록에서 등록 해제 (폴더는 삭제하지 않음)'
    Write-Output '  mtw_help               이 도움말 출력'
    Write-Output '  mtw_cd_<이름>          등록된 경로로 이동'
    Write-Output ''
    Write-Output '에이전트 명령'
    foreach ($key in ($script:MTW_AGENTS.Keys | Sort-Object)) {
        if ($script:MTW_RESERVED -contains $key) { continue }
        Write-Output "  mtw_$key [이름]        세션 생성 후 '$($script:MTW_AGENTS[$key])' 실행"
    }
    $global:LASTEXITCODE = 0
}

# ── 초기화 ───────────────────────────────────────────────────────────
# 목록 적재 → 이동 함수 생성 → 에이전트 함수 생성 → 자동완성 등록
__mtw_load
__mtw_register
__mtw_register_agents
__mtw_register_completion
