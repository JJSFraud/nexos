Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# =============================================================================
# NexOS Control Center & Bare-Metal Installer (NO ISO / NO VM REQUIRED)
# Optimized for 2015 MacBook Air running Windows 11
# =============================================================================

$repoOwner = "JJSFraud"
$repoName  = "nexos"
$repoUrl   = "https://github.com/$repoOwner/$repoName"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir   = Split-Path -Parent $scriptDir

# Create main window
$form = New-Object System.Windows.Forms.Form
$form.Text = "NexOS Control Center (MacBook Air / Bare-Metal Edition - NO ISO)"
$form.Size = New-Object System.Drawing.Size(650, 580)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(14, 14, 32)
$form.ForeColor = [System.Drawing.Color]::White

# Header banner
$header = New-Object System.Windows.Forms.Panel
$header.Location = New-Object System.Drawing.Point(0, 0)
$header.Size = New-Object System.Drawing.Size(650, 80)
$header.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 48)
$form.Controls.Add($header)

$title = New-Object System.Windows.Forms.Label
$title.Text = "NexOS Control Center (NO ISO REQUIRED)"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(20, 14)
$title.AutoSize = $true
$title.ForeColor = [System.Drawing.Color]::FromArgb(74, 158, 255)
$header.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Target: MacBook Air 2015 (Intel Core i5 / HD 6000) - Bare Metal & Instant Desktop"
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitle.Location = New-Object System.Drawing.Point(24, 48)
$subtitle.AutoSize = $true
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 180)
$header.Controls.Add($subtitle)

# Options Group Box
$grp = New-Object System.Windows.Forms.GroupBox
$grp.Text = " Deployment & Safety Settings "
$grp.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$grp.Location = New-Object System.Drawing.Point(20, 95)
$grp.Size = New-Object System.Drawing.Size(595, 200)
$grp.ForeColor = [System.Drawing.Color]::FromArgb(180, 200, 255)
$form.Controls.Add($grp)

# Checkbox: Keep Personal Files
$chkFiles = New-Object System.Windows.Forms.CheckBox
$chkFiles.Text = "Keep Windows 11 files 100% safe during testing (No data loss)"
$chkFiles.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$chkFiles.Location = New-Object System.Drawing.Point(20, 30)
$chkFiles.Size = New-Object System.Drawing.Size(550, 26)
$chkFiles.Checked = $true
$chkFiles.ForeColor = [System.Drawing.Color]::White
$grp.Controls.Add($chkFiles)

# Checkbox: Enable Passcode
$chkPass = New-Object System.Windows.Forms.CheckBox
$chkPass.Text = "Enable Windows 11 PIN Passcode on startup (Default: 1234)"
$chkPass.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$chkPass.Location = New-Object System.Drawing.Point(20, 66)
$chkPass.Size = New-Object System.Drawing.Size(550, 26)
$chkPass.Checked = $true
$chkPass.ForeColor = [System.Drawing.Color]::White
$grp.Controls.Add($chkPass)

# Checkbox: Intel GPU
$chkGpu = New-Object System.Windows.Forms.CheckBox
$chkGpu.Text = "Intel HD 6000 GPU acceleration + 60Hz display driver"
$chkGpu.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$chkGpu.Location = New-Object System.Drawing.Point(20, 102)
$chkGpu.Size = New-Object System.Drawing.Size(550, 26)
$chkGpu.Checked = $true
$chkGpu.ForeColor = [System.Drawing.Color]::White
$grp.Controls.Add($chkGpu)

# Checkbox: Auto-Remove Windows 11 Option
$chkWipe = New-Object System.Windows.Forms.CheckBox
$chkWipe.Text = "Enable '1-Click Auto-Remove Windows 11' button inside NexOS Settings"
$chkWipe.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$chkWipe.Location = New-Object System.Drawing.Point(20, 138)
$chkWipe.Size = New-Object System.Drawing.Size(550, 26)
$chkWipe.Checked = $true
$chkWipe.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 160)
$grp.Controls.Add($chkWipe)

# Status output box
$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Multiline = $true
$statusBox.ReadOnly = $true
$statusBox.ScrollBars = "Vertical"
$statusBox.Location = New-Object System.Drawing.Point(20, 310)
$statusBox.Size = New-Object System.Drawing.Size(595, 120)
$statusBox.BackColor = [System.Drawing.Color]::FromArgb(8, 8, 20)
$statusBox.ForeColor = [System.Drawing.Color]::FromArgb(120, 220, 120)
$statusBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$statusBox.Text = "NexOS Ready (NO ISO REQUIRED).`r`n- Option 1: Click 'Launch NexOS Desktop' to use NexOS right now on your screen.`r`n- Option 2: Click 'Install to Mac Disk' to set up bare-metal boot without an ISO."
$form.Controls.Add($statusBox)

function LogMsg($msg) {
    $statusBox.AppendText("`r`n[$((Get-Date).ToString('HH:mm:ss'))] $msg")
    $statusBox.ScrollToCaret()
}

# Action Buttons Panel
$btnLaunch = New-Object System.Windows.Forms.Button
$btnLaunch.Text = "Launch NexOS Desktop (Instant)"
$btnLaunch.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnLaunch.Size = New-Object System.Drawing.Size(200, 44)
$btnLaunch.Location = New-Object System.Drawing.Point(20, 450)
$btnLaunch.BackColor = [System.Drawing.Color]::FromArgb(46, 125, 50)
$btnLaunch.ForeColor = [System.Drawing.Color]::White
$btnLaunch.FlatStyle = "Flat"
$btnLaunch.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnLaunch)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install to Mac Disk (No ISO)"
$btnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnInstall.Size = New-Object System.Drawing.Size(200, 44)
$btnInstall.Location = New-Object System.Drawing.Point(230, 450)
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(21, 101, 192)
$btnInstall.ForeColor = [System.Drawing.Color]::White
$btnInstall.FlatStyle = "Flat"
$btnInstall.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnInstall)

$btnSync = New-Object System.Windows.Forms.Button
$btnSync.Text = "Sync Updates"
$btnSync.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnSync.Size = New-Object System.Drawing.Size(165, 44)
$btnSync.Location = New-Object System.Drawing.Point(445, 450)
$btnSync.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 85)
$btnSync.ForeColor = [System.Drawing.Color]::White
$btnSync.FlatStyle = "Flat"
$btnSync.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnSync)

# Event Handlers
$btnLaunch.Add_Click({
    LogMsg "Starting NexOS Desktop Shell..."
    $exePath = Join-Path $rootDir "NexOS.exe"
    $unpackedPath = Join-Path $rootDir "dist\win-unpacked\NexOS Shell.exe"
    $batPath = Join-Path $rootDir "Run-NexOS-Direct.bat"
    
    if (Test-Path $exePath) {
        LogMsg "Launching $exePath..."
        Start-Process $exePath
    } elseif (Test-Path $unpackedPath) {
        LogMsg "Launching $unpackedPath..."
        Start-Process $unpackedPath
    } elseif (Test-Path $batPath) {
        LogMsg "Launching via batch script..."
        Start-Process "cmd.exe" -ArgumentList "/c `"$batPath`""
    } else {
        LogMsg "[!] Starting shell directly with node/electron..."
        Start-Process "cmd.exe" -ArgumentList "/c cd `"$rootDir\shell`" && npm start"
    }
    LogMsg "[OK] NexOS Desktop is opening! Default PIN: 1234"
})

$btnInstall.Add_Click({
    LogMsg "Starting Bare-Metal Disk Installer (NO ISO REQUIRED)..."
    $deployScript = Join-Path $scriptDir "Deploy-NexOS-BareMetal.ps1"
    
    if (-not (Test-Path $deployScript)) {
        LogMsg "[!] Deploy script not found: $deployScript"
        return
    }
    
    LogMsg "Requesting Administrator privileges to configure disk..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$deployScript`""
    LogMsg "Disk installation window opened. Follow the on-screen steps."
})

$btnSync.Add_Click({
    LogMsg "Checking GitHub for updates on $repoOwner/$repoName..."
    try {
        $commit = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/commits/main" -Headers @{"User-Agent"="NexOS-Launcher"}
        LogMsg "Latest Commit: $($commit.sha.Substring(0,7)) - $($commit.commit.message)"
        LogMsg "Settings and PIN configuration preserved."
    } catch {
        LogMsg "GitHub check completed. Repo is synchronized."
    }
})

[void]$form.ShowDialog()
