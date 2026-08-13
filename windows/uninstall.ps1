# mtw (mw-terminal-worknav) 제거 스크립트 - Windows (PowerShell 7)
#
# $PROFILE 에서 로더 블록을 제거하고 ~\.mtw\mtw.ps1 과 psmux 애드온을 삭제한다.
# -RemoveProjects 지정 시 ~\.mtw\ 전체를 삭제한다 (기본값은 목록 보존).
#
# 호출 예: pwsh -NoProfile -File .\windows\uninstall.ps1 [-RemoveProjects]
# 파일 조작 cmdlet 은 모듈 한정 이름으로 호출한다 — 명령 해석 우선순위가
# Alias -> Function -> Cmdlet 이라 사용자 프로필의 함수가 Remove-Item 같은 정식
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
$MARKER_START = '# >>> mtw (mw-terminal-worknav) >>>'
$MARKER_END = '# <<< mtw (mw-terminal-worknav) <<<'

# 인자 파싱 — param([switch]) 는 접두어 매칭·대소문자 무시가 기본이고 pwsh -File
# 은 모르는 인자를 조용히 무시한다. $args 를 정확 일치·대소문자 구분으로 검사한다.
$RemoveProjects = $false
foreach ($arg in $args) {
    if ($arg -ceq '-RemoveProjects') {
        $RemoveProjects = $true
    }
    else {
        $host.UI.WriteErrorLine("mtw: 알 수 없는 옵션입니다: $arg")
        exit 1
    }
}

# 1. 프로필에서 마커 블록 제거 (백업 선행, 블록 제거로 생긴 끝쪽 빈 줄 정리)
if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $PROFILE -PathType Leaf) {
    $lines = __mtw_read_lines $PROFILE

    $countStart = 0
    $countEnd = 0
    $startIdx = -1
    $endIdx = -1
    # 마커 판정에서만 줄 끝 `r 을 무시한다 (CRLF 프로필 대응). 파일에 다시 쓰는
    # 것은 원본 $lines 이므로 프로필 개행은 바뀌지 않는다.
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $markerLine = $lines[$i] -creplace "`r\z", ''
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
        Write-Output "mtw: 프로필에 로더 블록이 없어 건너뜁니다: $PROFILE"
    }
    elseif ($countStart -eq 1 -and $countEnd -eq 1 -and $startIdx -lt $endIdx) {
        $newLines = [System.Collections.Generic.List[string]]::new()
        if ($startIdx -gt 0) {
            $newLines.AddRange([string[]]$lines[0..($startIdx - 1)])
        }
        if ($endIdx -lt ($lines.Count - 1)) {
            $newLines.AddRange([string[]]$lines[($endIdx + 1)..($lines.Count - 1)])
        }

        $backup = __mtw_unique_backup_path $PROFILE
        try {
            Microsoft.PowerShell.Management\Copy-Item -LiteralPath $PROFILE -Destination $backup -ErrorAction Stop
        }
        catch {
            $host.UI.WriteErrorLine("mtw: 오류: 프로필을 백업하지 못해 중단합니다: $backup")
            exit 1
        }
        Write-Output "mtw: 프로필을 백업했습니다: $backup"

        while ($newLines.Count -gt 0 -and $newLines[$newLines.Count - 1].Length -eq 0) {
            $newLines.RemoveAt($newLines.Count - 1)
        }

        try {
            if ($newLines.Count -gt 0) {
                __mtw_write_text $PROFILE (($newLines -join "`n") + "`n")
            }
            else {
                __mtw_write_text $PROFILE ''
            }
        }
        catch {
            $host.UI.WriteErrorLine("mtw: 오류: 프로필을 갱신하지 못했습니다: $PROFILE")
            exit 1
        }
        Write-Output "mtw: 프로필에서 로더 블록을 제거했습니다: $PROFILE"
    }
    else {
        $host.UI.WriteErrorLine("mtw: 오류: 프로필에서 로더 블록 마커를 안전하게 판별할 수 없습니다: $PROFILE")
        $host.UI.WriteErrorLine('mtw: 자동으로 잘라내지 않고 중단합니다. 프로필을 직접 열어 아래 마커로 표시된 블록을 확인하고 정리하세요.')
        $host.UI.WriteErrorLine($MARKER_START)
        $host.UI.WriteErrorLine($MARKER_END)
        exit 1
    }
}
else {
    Write-Output "mtw: 프로필 파일이 없어 건너뜁니다: $PROFILE"
}

# 2. ~\.mtw\mtw.ps1 삭제
if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $MTW_BODY -PathType Leaf) {
    try {
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $MTW_BODY -Force -ErrorAction Stop
    }
    catch {
        $host.UI.WriteErrorLine("mtw: 오류: 기능 본체를 삭제하지 못했습니다: $MTW_BODY")
        exit 1
    }
    Write-Output "mtw: 기능 본체를 삭제했습니다: $MTW_BODY"
}

# 2-1. ~\.mtw\mtw-psmux.ps1 삭제 (-WithPsmux 로 설치했을 때만 존재한다)
if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $MTW_ADDON -PathType Leaf) {
    try {
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $MTW_ADDON -Force -ErrorAction Stop
    }
    catch {
        $host.UI.WriteErrorLine("mtw: 오류: psmux 애드온을 삭제하지 못했습니다: $MTW_ADDON")
        exit 1
    }
    Write-Output "mtw: psmux 애드온을 삭제했습니다: $MTW_ADDON"
}

# 3. -RemoveProjects 지정 시 ~\.mtw\ 전체 삭제 (프로젝트 목록 포함, 백업 선행)
if ($RemoveProjects) {
    if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $MTW_DIR -PathType Container) {
        $dirBackup = __mtw_unique_backup_path $MTW_DIR
        try {
            Microsoft.PowerShell.Management\Copy-Item -LiteralPath $MTW_DIR -Destination $dirBackup -Recurse -ErrorAction Stop
        }
        catch {
            $host.UI.WriteErrorLine("mtw: 오류: ~\.mtw 를 백업하지 못해 중단합니다: $dirBackup")
            exit 1
        }
        Write-Output "mtw: ~\.mtw 를 백업했습니다: $dirBackup"
        try {
            Microsoft.PowerShell.Management\Remove-Item -LiteralPath $MTW_DIR -Recurse -Force -ErrorAction Stop
        }
        catch {
            $host.UI.WriteErrorLine("mtw: 오류: ~\.mtw 를 삭제하지 못했습니다: $MTW_DIR")
            exit 1
        }
        Write-Output 'mtw: ~\.mtw 를 삭제했습니다 (프로젝트 목록 포함).'
    }
}
else {
    Write-Output "mtw: 프로젝트 목록은 보존됩니다: $(Microsoft.PowerShell.Management\Join-Path $MTW_DIR 'projects')"
}

# 4. 현재 세션 정리 안내
Write-Output ''
Write-Output '제거가 완료되었습니다.'
Write-Output ''
Write-Output '이미 열려 있는 세션에는 mtw 함수가 메모리에 남아 있습니다.'
Write-Output '정리하려면 해당 세션에서 새 PowerShell 세션을 시작하세요.'
