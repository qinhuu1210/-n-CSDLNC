$ErrorActionPreference = 'Stop'
$demoController = Join-Path $PSScriptRoot '07_dieu_khien.ps1'

function Invoke-DemoStep([string]$DemoAction) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:demoController -Action $DemoAction
    if ($LASTEXITCODE -ne 0) { throw ('Dung tai buoc ' + $DemoAction + '. Xem thong bao o tren.') }
}

try {
    Write-Host ''
    Write-Host 'DEMO NGAT VA PHUC HOI - CHI SERVER THU NGHIEM PORT 55490' -ForegroundColor Cyan
    Write-Host 'Truoc khi bam: da chay khoi 6A va 6B trong pgAdmin, chua COMMIT 6B.'
    Write-Host ''
    Write-Host 'BUOC 1/3: NGAT BAT THUONG MAY CHU DEMO' -ForegroundColor Yellow
    Invoke-DemoStep 'Crash'
    Write-Host ''
    Write-Host 'BUOC 2/3: TU DONG KHOI DONG LAI VA PHUC HOI' -ForegroundColor Yellow
    Invoke-DemoStep 'Start'
    Write-Host ''
    Write-Host 'BUOC 3/3: DOI CHIEU DU LIEU VA LUU LOG' -ForegroundColor Yellow
    Invoke-DemoStep 'Verify'
    Write-Host ''
    Write-Host 'XONG: DA_COMMIT VAN CON; CHUA_COMMIT KHONG CON; SO CAI CAN DOI.' -ForegroundColor Green
    Write-Host 'Ban co the chup cua so nay. Muon xem trong pgAdmin: mo Query Tool moi, chay khoi 6C.'
    Write-Host 'Muon demo lai: chay 6A -> 6B trong pgAdmin, roi bam lai file nay.'
} catch {
    Write-Host ('LOI: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
