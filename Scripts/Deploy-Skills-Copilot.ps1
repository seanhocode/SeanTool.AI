<#
.SYNOPSIS
自動備份 .copilot 中的 Skills 資料夾，並將 Repository 中的最新版本同步過去。
#>

# 1 & 2. 動態尋找使用者的 .copilot 資料夾，若無則請使用者手動輸入
$defaultCopilotPath = Join-Path -Path $env:USERPROFILE -ChildPath ".copilot"

if (Test-Path -Path $defaultCopilotPath) {
    $copilotPath = $defaultCopilotPath
    Write-Host "[SUCCESS] Automatically found .copilot folder at: $copilotPath" -ForegroundColor Green
} else {
    Write-Host "[INFO] Could not find the .copilot folder in the default path ($defaultCopilotPath)." -ForegroundColor Yellow
    $copilotPath = Read-Host "Please manually enter the absolute path to your .copilot folder (e.g., C:\Users\YourName\.copilot)"

    # 驗證手動輸入的路徑
    if (-not (Test-Path -Path $copilotPath)) {
        Write-Host "[ERROR] The entered folder path does not exist! Please check and run the script again." -ForegroundColor Red
        exit
    }
}

$targetSkillsPath = Join-Path -Path $copilotPath -ChildPath "skills"

# 3. 壓縮並備份現有的 skills 資料夾
if (Test-Path -Path $targetSkillsPath) {
    # 取得當下時間至秒 (格式: yyyyMMdd_HHmmss)
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupZipPath = Join-Path -Path $copilotPath -ChildPath "skills_bak_$timestamp.zip"

    Write-Host "[PROCESSING] Zipping and backing up the existing skills folder to: $backupZipPath ..." -ForegroundColor Cyan
    # 使用 PowerShell 內建的 Compress-Archive 進行 zip 壓縮
    Compress-Archive -Path $targetSkillsPath -DestinationPath $backupZipPath -Force
    Write-Host "[SUCCESS] Backup completed!" -ForegroundColor Green
} else {
    Write-Host "[INFO] No existing skills folder found in the target path. Skipping backup step." -ForegroundColor Yellow
}

# 4. 動態抓取目前 repo 專案中的 Skills 位置
# $PSScriptRoot 變數代表此腳本當前所在的目錄 (Scripts)，因此 Skills 資料夾在上一層
$repoSkillsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\Skills"
$repoSkillsPath = [System.IO.Path]::GetFullPath($repoSkillsPath) # 解析成絕對路徑

if (-not (Test-Path -Path $repoSkillsPath)) {
    Write-Host "[ERROR] Cannot find the source Skills folder in the Repo ($repoSkillsPath)." -ForegroundColor Red
    exit
}
Write-Host "[SUCCESS] Confirmed Repo Skills source folder: $repoSkillsPath" -ForegroundColor Green

# 5. 將 repo 的 Skills 複製至 .copilot 中 (使用 robocopy)
Write-Host "[PROCESSING] Starting robocopy to sync Repo Skills to .copilot..." -ForegroundColor Cyan

# 參數說明: 
# /E     : 複製所有子目錄 (包含空的)
# /MT:8  : 使用 8 個執行緒進行多執行緒複製 (加快速度)
# /R:3   : 失敗重試次數 3 次
# /W:1   : 重試等待時間 1 秒
# 註: 若想做到「完全鏡像」(來源刪除的檔案，目的端也跟著刪除)，可加上 /MIR 參數。這裡保守使用 /E 覆蓋。
$robocopyArgs = @("$repoSkillsPath", "$targetSkillsPath", "/E", "/MT:8", "/R:3", "/W:1")

# 執行 robocopy
& robocopy $robocopyArgs

# Robocopy 的 Exit Code 小於 8 都算是成功 (0=無變更, 1=有複製, 2=目標有額外檔案, 3=成功複製且有額外檔案 等)
if ($LASTEXITCODE -ge 8) {
    Write-Host "[ERROR] A critical error occurred during copying (Robocopy exit code: $LASTEXITCODE)." -ForegroundColor Red
} else {
    Write-Host "[SUCCESS] Skills copying and synchronization completed!" -ForegroundColor Green
}

Write-Host "==============================="
Write-Host "Script execution finished. Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")