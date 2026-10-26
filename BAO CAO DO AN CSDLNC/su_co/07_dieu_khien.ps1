param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Setup','Start','Crash','Verify','Stop','Logs')]
    [string]$Action
)
$ErrorActionPreference = 'Stop'
$labRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'may_chu_thu_nghiem'))
$labData = [IO.Path]::GetFullPath((Join-Path $labRoot 'data'))
$labMarker = Join-Path $labRoot 'lab.json'
$labLog = Join-Path $labRoot 'postgresql.log'
$labPort = 55490
$labDb = 'ketoan_demo_crash'
$labUser = 'demo_crash'
$labConnection = @('-X','-w','-h','127.0.0.1','-p',"$labPort",'-U',$labUser)

function Invoke-LabSql([string[]]$SqlArguments) {
    $labOutput = & (Join-Path $script:labBin 'psql.exe') @script:labConnection -d $script:labDb -v ON_ERROR_STOP=1 @SqlArguments
    if ($LASTEXITCODE -ne 0) { throw 'Lenh SQL demo that bai. Xem thong bao o tren.' }
    return $labOutput
}

function Assert-LabPaths {
    if (-not (Test-Path -LiteralPath $script:labMarker)) { throw 'Chua chuan bi. Chay 01_CHUAN_BI_VA_MO.cmd.' }
    $script:labInfo = Get-Content -LiteralPath $script:labMarker -Raw | ConvertFrom-Json
    if ($script:labInfo.purpose -ne 'task4-crash-only' -or $script:labInfo.port -ne $script:labPort -or
        [IO.Path]::GetFullPath($script:labInfo.data_dir) -ne $script:labData) {
        throw 'Marker khong khop; dung lai de tranh tac dong nham server.'
    }
    if (-not $script:labData.StartsWith($script:labRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Data directory nam ngoai thu muc demo.'
    }
    $script:labBin = $script:labInfo.bin_dir
    if (-not (Test-Path -LiteralPath (Join-Path $script:labBin 'pg_ctl.exe'))) { throw 'Khong tim thay PostgreSQL binaries.' }
    if (Test-Path -LiteralPath $script:labData) {
        $labResolved = (Resolve-Path -LiteralPath $script:labData).Path
        if ($labResolved -ne $script:labData) { throw 'Duong dan data da thay doi.' }
    }
    $labPidFile = Join-Path $script:labData 'postmaster.pid'
    if (Test-Path -LiteralPath $labPidFile) {
        $labPidLines = Get-Content -LiteralPath $labPidFile
        if ($labPidLines.Count -lt 4 -or [IO.Path]::GetFullPath($labPidLines[1]) -ne $script:labData -or
            [int]$labPidLines[3] -ne $script:labPort) { throw 'PID file khong khop data/port demo.' }
    }
}

function Start-Lab {
    Assert-LabPaths
    & (Join-Path $script:labBin 'pg_ctl.exe') -D $script:labData status *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host 'May chu demo da mo.'; return }
    $labWatch = [Diagnostics.Stopwatch]::StartNew()
    & (Join-Path $script:labBin 'pg_ctl.exe') -D $script:labData -l $script:labLog -t 30 -w start
    if ($LASTEXITCODE -ne 0) { Get-Content -LiteralPath $script:labLog -Tail 25; throw 'Khong khoi dong duoc server demo.' }
    $labWatch.Stop()
    $script:labStartSeconds = [Math]::Round($labWatch.Elapsed.TotalSeconds, 3)
    [IO.File]::WriteAllText((Join-Path $script:labRoot 'lan_khoi_dong_moi_nhat.json'),
        (@{at=(Get-Date).ToString('o'); start_wait_seconds=$script:labStartSeconds} | ConvertTo-Json))
    Write-Host ('Thoi gian goi khoi dong den khi san sang: ' + $script:labStartSeconds + ' giay.')
}

try {
    if ($Action -eq 'Setup' -and -not (Test-Path -LiteralPath $labMarker)) {
        if (Test-Path -LiteralPath $labData) { throw 'Data da ton tai nhung khong co marker; khong ghi de.' }
        $labProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $labPort)
        try { $labProbe.Start() } catch { throw 'Port 55490 dang duoc dung; khong tac dong vao server do.' } finally { $labProbe.Stop() }
        $labBin = 'C:\Program Files\PostgreSQL\18\bin'
        if (-not (Test-Path -LiteralPath (Join-Path $labBin 'initdb.exe'))) { throw 'Can PostgreSQL 18 tai C:\Program Files\PostgreSQL\18.' }
        New-Item -ItemType Directory -Path $labRoot -Force | Out-Null
        @{purpose='task4-crash-only'; data_dir=$labData; bin_dir=$labBin; port=$labPort} |
            ConvertTo-Json | Set-Content -LiteralPath $labMarker -Encoding UTF8
    }
    Assert-LabPaths

    if ($Action -eq 'Setup') {
        if (-not (Test-Path -LiteralPath (Join-Path $labData 'PG_VERSION'))) {
            if (Test-Path -LiteralPath $labData) { throw 'Initdb truoc do chua hoan tat; khong ghi de thu muc.' }
            & (Join-Path $labBin 'initdb.exe') -D $labData -U $labUser --auth=trust --encoding=UTF8 --no-locale
            if ($LASTEXITCODE -ne 0) { throw 'Khong tao duoc cluster thu nghiem.' }
            @"

# Dedicated accounting crash lab
listen_addresses = '127.0.0.1'
port = 55490
cluster_name = 'task4_crash_lab'
max_connections = 20
shared_buffers = '16MB'
fsync = on
full_page_writes = on
synchronous_commit = on
checkpoint_timeout = '30min'
logging_collector = off
log_destination = 'stderr'
log_line_prefix = '%m [%p] '
log_timezone = 'Asia/Ho_Chi_Minh'
timezone = 'Asia/Ho_Chi_Minh'
lc_messages = 'C'
"@ | Add-Content -LiteralPath (Join-Path $labData 'postgresql.conf') -Encoding ASCII
        }
        Start-Lab
        $labDbExists = & (Join-Path $labBin 'psql.exe') @labConnection -d postgres -v ON_ERROR_STOP=1 -Atq -c "SELECT 1 FROM pg_database WHERE datname = 'ketoan_demo_crash'"
        if ($LASTEXITCODE -ne 0) { throw 'Khong ket noi duoc server demo.' }
        if (($labDbExists -join '').Trim() -ne '1') {
            & (Join-Path $labBin 'createdb.exe') -w -h 127.0.0.1 -p $labPort -U $labUser $labDb
            if ($LASTEXITCODE -ne 0) { throw 'Khong tao duoc database demo.' }
        }
        $labSchemaReady = (Invoke-LabSql @('-Atq','-c',"SELECT to_regclass('public.chung_tu') IS NOT NULL")) -join ''
        if ($labSchemaReady.Trim() -ne 't') {
            $labSeedArgs = @()
            foreach ($labSeedName in @('01_tao_bang.sql','02_rang_buoc_trigger_thu_tuc.sql','03_du_lieu_mau.sql')) {
                $labSeedPath = Join-Path (Join-Path $PSScriptRoot 'du_lieu_goc') $labSeedName
                if (-not (Test-Path -LiteralPath $labSeedPath)) { throw ('Thieu file: ' + $labSeedPath) }
                $labSeedArgs += @('-f',$labSeedPath)
            }
            Invoke-LabSql (@('-1') + $labSeedArgs) | Set-Content -LiteralPath (Join-Path $labRoot 'nap_du_lieu.log') -Encoding UTF8
        }
        Invoke-LabSql @('-f',(Join-Path $PSScriptRoot 'sql_ho_tro\chuan_bi.sql')) | Out-Host
        Write-Host 'SAN SANG. Dang ky server DEMO_SU_CO trong pgAdmin:'
        Write-Host 'Host: 127.0.0.1 | Port: 55490 | Username: demo_crash'
        Write-Host 'Maintenance database va database demo: ketoan_demo_crash'
        Write-Host 'Password: de trong (chi server du lieu gia lap, chi lang nghe tren may nay).'
    }
    elseif ($Action -eq 'Start') { Start-Lab }
    elseif ($Action -eq 'Crash') {
        $labActive = (Invoke-LabSql @('-Atq','-c',"SELECT count(*) FROM pg_stat_activity WHERE datname = 'ketoan_demo_crash' AND application_name = 'demo4_crash_pgadmin' AND xact_start IS NOT NULL AND backend_xid IS NOT NULL AND pid <> pg_backend_pid()")) -join ''
        if ([int]$labActive.Trim() -lt 1) { throw 'Chua co giao dich dang do. Chay khoi 6B trong pgAdmin va giu tab mo.' }
        $labRun = (Invoke-LabSql @('-Atq','-c','SELECT run_id FROM demo4_crash_current')) -join ''
        $labLogOffset = if (Test-Path -LiteralPath $labLog) { (Get-Item -LiteralPath $labLog).Length } else { 0 }
        @{run_id=$labRun.Trim(); at=(Get-Date).ToString('o'); log_offset=$labLogOffset} |
            ConvertTo-Json | Set-Content -LiteralPath (Join-Path $labRoot 'su_co_moi_nhat.json') -Encoding UTF8
        & (Join-Path $labBin 'pg_ctl.exe') -D $labData -t 30 -w stop -m immediate
        if ($LASTEXITCODE -ne 0) { throw 'Khong ngat duoc server demo.' }
        Write-Host 'DA NGAT BAT THUONG SERVER DEMO.'
    }
    elseif ($Action -eq 'Verify') {
        $labCrashFile = Join-Path $labRoot 'su_co_moi_nhat.json'
        if (-not (Test-Path -LiteralPath $labCrashFile)) { throw 'Chua co lan gay su co duoc ghi nhan.' }
        $labCrash = Get-Content -LiteralPath $labCrashFile -Raw | ConvertFrom-Json
        $labCurrentRun = ((Invoke-LabSql @('-Atq','-c','SELECT run_id FROM demo4_crash_current')) -join '').Trim()
        if ($labCurrentRun -ne $labCrash.run_id) { throw 'Luot SQL moi hon luot su co. Hay hoan tat 6B va gay su co cho luot nay.' }
        $labRead = [IO.File]::Open($labLog,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        try {
            [void]$labRead.Seek([long]$labCrash.log_offset,[IO.SeekOrigin]::Begin)
            $labReader = [IO.StreamReader]::new($labRead)
            $labRecovery = $labReader.ReadToEnd()
        } finally { if ($labReader) { $labReader.Dispose() }; $labRead.Dispose() }
        if ($labRecovery -notmatch 'automatic recovery in progress' -or $labRecovery -notmatch 'redo done at') {
            throw 'Chua tim thay minh chung WAL recovery hoan tat sau su co trong log.'
        }
        $labCheck = Invoke-LabSql @('-f',(Join-Path $PSScriptRoot 'sql_ho_tro\kiem_tra.sql'))
        Invoke-LabSql @('-c','SELECT loai, so_chung_tu, so_chi_tiet, so_dong_so_cai, tong_no, tong_co FROM demo4_crash_results ORDER BY loai') | Out-Host
        $labCheck | Out-Host
        $labStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
        $labResultDir = Join-Path (Join-Path $PSScriptRoot 'ket_qua') ('lan_' + $labCurrentRun + '_' + $labStamp)
        New-Item -ItemType Directory -Path $labResultDir -Force | Out-Null
        Invoke-LabSql @('-q','-c','COPY (SELECT * FROM demo4_crash_results ORDER BY loai) TO STDOUT WITH CSV HEADER') |
            Set-Content -LiteralPath (Join-Path $labResultDir 'sau_phuc_hoi.csv') -Encoding UTF8
        $labRecovery | Set-Content -LiteralPath (Join-Path $labResultDir 'log_su_co_va_phuc_hoi.txt') -Encoding UTF8
        $labCheck | Set-Content -LiteralPath (Join-Path $labResultDir 'kiem_tra.txt') -Encoding UTF8
        Copy-Item -LiteralPath $labCrashFile -Destination (Join-Path $labResultDir 'thong_tin_su_co.json')
        $labStartFile = Join-Path $labRoot 'lan_khoi_dong_moi_nhat.json'
        if (Test-Path -LiteralPath $labStartFile) { Copy-Item -LiteralPath $labStartFile -Destination (Join-Path $labResultDir 'thoi_gian_khoi_dong.json') }
        Write-Host ('Ket qua da luu tai: ' + $labResultDir)
    }
    elseif ($Action -eq 'Stop') {
        & (Join-Path $labBin 'pg_ctl.exe') -D $labData status *> $null
        if ($LASTEXITCODE -eq 0) {
            & (Join-Path $labBin 'pg_ctl.exe') -D $labData -t 30 -w stop -m fast
            if ($LASTEXITCODE -ne 0) { throw 'Khong tat duoc server demo.' }
        }
        Write-Host 'Server demo da tat. Du lieu van duoc giu.'
    }
    elseif ($Action -eq 'Logs') {
        Get-Content -LiteralPath $labLog -Tail 100 | Select-String 'immediate shutdown|interrupted|automatic recovery|redo starts|redo done|ready to accept'
        Write-Host ('Log day du: ' + $labLog)
    }
} catch {
    Write-Host ('LOI: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
