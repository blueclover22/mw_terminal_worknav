# mtw (mw-terminal-worknav) 설치 스크립트 - Windows (PowerShell 7)
#
# ~\.mtw\ 를 만들고 기능 본체를 복사한 뒤 $PROFILE 끝에 로더 블록을 추가한다.
# src\ 는 스크립트 위치 기준으로 찾으므로 호출 디렉터리와 무관하다.
#
# 기본 설치는 이동·목록 명령만 넣는다. -WithPsmux 를 주면 psmux 애드온까지 설치해
# 에이전트 세션 명령(mtw_claude 등)이 함께 생긴다. 재실행이 곧 상태 선언이므로
# -WithPsmux 없이 다시 실행하면 이미 설치된 애드온은 제거된다.
#
# 호출 예: pwsh -NoProfile -File .\windows\install.ps1 [-WithPsmux]
# 파일 조작 cmdlet 은 모듈 한정 이름으로 호출한다 — 명령 해석 우선순위가
# Alias -> Function -> Cmdlet 이라 사용자 프로필의 함수가 Copy-Item 같은 정식
# 이름까지 가로챈다. -NoProfile 은 호출자 쪽 플래그라 이중 방어일 뿐이다.

$ErrorActionPreference = 'Stop'

# 프로필은 사용자 파일이므로 바이트를 그대로 보존한다. Latin1 은 바이트 ↔ 문자가
# 1:1 이라 어떤 인코딩(UTF-8 BOM · CP949 등)이든 왕복이 무손실이다. ReadAllText 는
# 인코딩을 지정해도 BOM 을 감지해 벗겨내므로 GetString/GetBytes 로 직접 다룬다.
# Get-Content/Set-Content 는 개행까지 플랫폼 기본값으로 재작성해 쓰지 않는다.
$script:MTW_RAW_ENCODING = [System.Text.Encoding]::Latin1

# zsh 의 "$(<file)" + "${(@f)}" 와 같은 방식으로 줄 배열을 만든다. 끝쪽 개행을
# 전부 제거한 뒤 LF 로만 분리하며, CRLF 의 \r 는 줄 내용에 남는다.
function __mtw_read_lines {
    param([string]$Path)
    if (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $Path -PathType Leaf)) { return [string[]]@() }
    try { $raw = $script:MTW_RAW_ENCODING.GetString([System.IO.File]::ReadAllBytes($Path)) }
    catch {
        $host.UI.WriteErrorLine("mtw: 오류: 프로필을 읽지 못했습니다: $Path")
        exit 1
    }
    $raw = $raw -replace '\n+\z', ''
    return ,($raw -split "`n")
}

# 프로필 쓰기 — 읽기와 같은 인코딩으로 바이트를 되돌린다.
function __mtw_write_text {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllBytes($Path, $script:MTW_RAW_ENCODING.GetBytes($Text))
}

function __mtw_append_text {
    param([string]$Path, [string]$Text)
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
    try {
        $bytes = $script:MTW_RAW_ENCODING.GetBytes($Text)
        $fs.Write($bytes, 0, $bytes.Length)
    }
    finally { $fs.Dispose() }
}

# 유일한 백업 경로를 만든다 (*.bak-YYYYMMDD-HHMMSS, 이미 있으면 -2, -3 ... 접미사).
# 문화권 의존을 피하기 위해 불변 문화권으로 타임스탬프를 만든다.
function __mtw_unique_backup_path {
    param([string]$Path)
    $stamp = [datetime]::Now.ToString('yyyyMMdd-HHmmss', [cultureinfo]::InvariantCulture)
    $backup = "$Path.bak-$stamp"
    if (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $backup)) { return $backup }
    $n = 2
    while (Microsoft.PowerShell.Management\Test-Path -LiteralPath "$backup-$n") { $n++ }
    return "$backup-$n"
}

$MTW_DIR = Microsoft.PowerShell.Management\Join-Path $HOME '.mtw'
$MTW_BODY = Microsoft.PowerShell.Management\Join-Path $MTW_DIR 'mtw.ps1'
$MTW_ADDON = Microsoft.PowerShell.Management\Join-Path $MTW_DIR 'mtw-psmux.ps1'
$PROJECTS_FILE = Microsoft.PowerShell.Management\Join-Path $MTW_DIR 'projects'
$MARKER_START = '# >>> mtw (mw-terminal-worknav) >>>'
$MARKER_END = '# <<< mtw (mw-terminal-worknav) <<<'

$SRC_FILE = Microsoft.PowerShell.Management\Join-Path $PSScriptRoot 'src' 'mtw.ps1'
$SRC_ADDON = Microsoft.PowerShell.Management\Join-Path $PSScriptRoot 'src' 'mtw-psmux.ps1'

# 인자 파싱 — param([switch]) 는 접두어 매칭·대소문자 무시가 기본이고 pwsh -File
# 은 모르는 인자를 조용히 무시한다. $args 를 정확 일치·대소문자 구분으로 검사한다.
$WithPsmux = $false
foreach ($arg in $args) {
    if ($arg -ceq '-WithPsmux') {
        $WithPsmux = $true
    }
    else {
        $host.UI.WriteErrorLine("mtw: 알 수 없는 옵션입니다: $arg")
        exit 1
    }
}

if (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $SRC_FILE)) {
    $host.UI.WriteErrorLine("mtw: 오류: 기능 본체를 찾을 수 없습니다: $SRC_FILE")
    exit 1
}

if ($WithPsmux -and -not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $SRC_ADDON)) {
    $host.UI.WriteErrorLine("mtw: 오류: psmux 애드온을 찾을 수 없습니다: $SRC_ADDON")
    exit 1
}

# 설치 전 주요 명령 이름이 이미 사용 중인지 확인하고 경고 (설치는 계속 진행)
foreach ($cmd in @('mtw_list', 'mtw_new', 'mtw_rm', 'mtw_help')) {
    if (Microsoft.PowerShell.Core\Get-Command -Name $cmd -ErrorAction SilentlyContinue) {
        $host.UI.WriteErrorLine("mtw: 경고: '$cmd' 명령이 이미 사용 중입니다. 설치 후 충돌할 수 있습니다.")
    }
}

# 1. ~\.mtw\ 생성 (없을 때만)
if (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $MTW_DIR -PathType Container)) {
    try {
        Microsoft.PowerShell.Management\New-Item -ItemType Directory -Path $MTW_DIR -ErrorAction Stop | Microsoft.PowerShell.Core\Out-Null
    }
    catch {
        $host.UI.WriteErrorLine("mtw: 오류: 설치 디렉터리를 만들지 못했습니다: $MTW_DIR")
        exit 1
    }
}

# 2. src\mtw.ps1 -> ~\.mtw\mtw.ps1 (기존 파일은 덮어씀)
try {
    Microsoft.PowerShell.Management\Copy-Item -LiteralPath $SRC_FILE -Destination $MTW_BODY -Force -ErrorAction Stop
}
catch {
    $host.UI.WriteErrorLine("mtw: 오류: 기능 본체를 복사하지 못했습니다: $MTW_BODY")
    exit 1
}

# 2-1. psmux 애드온 - -WithPsmux 면 복사, 아니면 이미 있는 것을 제거한다.
# 남겨 두면 플래그 없이 재설치한 뒤에도 에이전트 명령이 살아 있어 설치 상태를
# 명령만 보고는 알 수 없게 된다. 재실행이 곧 상태 선언이 되도록 맞춘다.
if ($WithPsmux) {
    try {
        Microsoft.PowerShell.Management\Copy-Item -LiteralPath $SRC_ADDON -Destination $MTW_ADDON -Force -ErrorAction Stop
    }
    catch {
        $host.UI.WriteErrorLine("mtw: 오류: psmux 애드온을 복사하지 못했습니다: $MTW_ADDON")
        exit 1
    }
    Write-Output "mtw: psmux 애드온을 설치했습니다: $MTW_ADDON"
}
elseif (Microsoft.PowerShell.Management\Test-Path -LiteralPath $MTW_ADDON -PathType Leaf) {
    try {
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $MTW_ADDON -Force -ErrorAction Stop
    }
    catch {
        $host.UI.WriteErrorLine("mtw: 오류: psmux 애드온을 제거하지 못했습니다: $MTW_ADDON")
        exit 1
    }
    Write-Output 'mtw: psmux 애드온을 제거했습니다 (다시 설치하려면 -WithPsmux 를 주세요).'
}

# 3. ~\.mtw\projects - 없으면 빈 파일로 생성, 있으면 보존
if (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $PROJECTS_FILE)) {
    try {
        [System.IO.File]::WriteAllText($PROJECTS_FILE, '')
    }
    catch {
        $host.UI.WriteErrorLine("mtw: 오류: projects 파일을 생성하지 못했습니다: $PROJECTS_FILE")
        exit 1
    }
}

# 4. 프로필 파일이 없으면 생성 ($PROFILE 의 상위 디렉터리가 없을 수 있다)
if (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $PROFILE -PathType Leaf)) {
    $profileParent = Microsoft.PowerShell.Management\Split-Path -Parent $PROFILE
    try {
        if (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $profileParent)) {
            Microsoft.PowerShell.Management\New-Item -ItemType Directory -Path $profileParent -ErrorAction Stop | Microsoft.PowerShell.Core\Out-Null
        }
        __mtw_write_text $PROFILE ''
    }
    catch {
        $host.UI.WriteErrorLine("mtw: 오류: 프로필 파일을 생성하지 못했습니다: $PROFILE")
        exit 1
    }
}

# 5~6. 마커 출현 횟수로 판정: 0/0 -> 추가, 1/1(정순) -> 이미 설치됨(건너뜀), 그 외 -> 중단
$lines = __mtw_read_lines $PROFILE

$countStart = 0
$countEnd = 0
$startIdx = -1
$endIdx = -1
# 마커 판정에서만 줄 끝 `r 을 무시한다 (CRLF 프로필 대응). 파일에 다시 쓰는
# 것은 원본 $lines 이므로 프로필 개행은 바뀌지 않는다.
# 추가할 블록의 개행은 프로필이 쓰고 있는 것에 맞춘다 — 항상 LF 로 넣으면
# CRLF 프로필에 혼합 개행이 생긴다. 줄 끝 CR 이 하나라도 있으면 CRLF 로 본다.
$eol = "`n"
for ($i = 0; $i -lt $lines.Count; $i++) {
    $markerLine = $lines[$i] -creplace "`r\z", ''
    if ($markerLine.Length -ne $lines[$i].Length) { $eol = "`r`n" }
    if ($markerLine -ceq $MARKER_START) {
        $countStart++
        if ($startIdx -eq -1) { $startIdx = $i }
    }
    elseif ($markerLine -ceq $MARKER_END) {
        $countEnd++
        if ($endIdx -eq -1) { $endIdx = $i }
    }
}

if ($countStart -eq 0 -and $countEnd -eq 0) {
    if ((Microsoft.PowerShell.Management\Get-Item -LiteralPath $PROFILE).Length -gt 0) {
        $backup = __mtw_unique_backup_path $PROFILE
        try {
            Microsoft.PowerShell.Management\Copy-Item -LiteralPath $PROFILE -Destination $backup -ErrorAction Stop
        }
        catch {
            $host.UI.WriteErrorLine("mtw: 오류: 프로필을 백업하지 못해 중단합니다: $backup")
            exit 1
        }
        Write-Output "mtw: 프로필을 백업했습니다: $backup"

        $profileBytes = [System.IO.File]::ReadAllBytes($PROFILE)
        if ($profileBytes[$profileBytes.Length - 1] -ne 10) {
            try {
                __mtw_append_text $PROFILE $eol
            }
            catch {
                $host.UI.WriteErrorLine("mtw: 오류: 프로필에 로더 블록을 추가하지 못했습니다: $PROFILE")
                exit 1
            }
        }
    }

    $loaderLine = 'if (Test-Path "$HOME\.mtw\mtw.ps1") { . "$HOME\.mtw\mtw.ps1" }'
    $block = $MARKER_START + $eol + $loaderLine + $eol + $MARKER_END + $eol
    try {
        __mtw_append_text $PROFILE $block
    }
    catch {
        $host.UI.WriteErrorLine("mtw: 오류: 프로필에 로더 블록을 추가하지 못했습니다: $PROFILE")
        exit 1
    }
    Write-Output "mtw: 로더 블록을 추가했습니다: $PROFILE"
}
elseif ($countStart -eq 1 -and $countEnd -eq 1 -and $startIdx -lt $endIdx) {
    Write-Output "mtw: 프로필에 이미 로더 블록이 있어 건너뜁니다: $PROFILE"
}
else {
    $host.UI.WriteErrorLine("mtw: 오류: 프로필에서 로더 블록 마커를 안전하게 판별할 수 없습니다: $PROFILE")
    $host.UI.WriteErrorLine('mtw: 자동으로 추가하지 않고 중단합니다. 프로필을 직접 열어 아래 마커로 표시된 블록을 확인하고 정리한 뒤 다시 실행하세요.')
    $host.UI.WriteErrorLine("mtw: 기능 본체는 이미 설치되었습니다: $MTW_BODY (프로필만 변경되지 않았습니다)")
    $host.UI.WriteErrorLine($MARKER_START)
    $host.UI.WriteErrorLine($MARKER_END)
    exit 1
}

# 7. 사용 가능한 명령 안내
Write-Output ''
Write-Output '설치가 완료되었습니다.'
Write-Output ''
Write-Output '사용 가능한 명령:'
Write-Output '  mtw_list               등록된 프로젝트 목록 출력'
Write-Output '  mtw_new <이름>         현재 폴더를 목록에 등록'
Write-Output '  mtw_rm <이름>          목록에서 등록 해제'
Write-Output '  mtw_help               전체 명령 안내'
Write-Output '  mtw_cd_<이름>          등록된 경로로 이동'
if ($WithPsmux) {
    Write-Output '  mtw_claude [이름]      psmux 세션 생성 후 Claude Code 실행'
    Write-Output '  mtw_codex [이름]       psmux 세션 생성 후 Codex CLI 실행'
}
Write-Output ''
Write-Output '이 스크립트는 별도 프로세스에서 실행되어 현재 세션에는 반영되지 않습니다.'
Write-Output '새 세션을 열거나 다음 명령으로 프로필을 다시 읽으세요: . $PROFILE'
