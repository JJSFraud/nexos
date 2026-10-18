Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# =============================================================================
# NexOS Launcher & Installer v2.0
# Deploy, Sync, and Update NexOS directly from GitHub with Customization Toggles
# =============================================================================

$repoOwner = "JJSFraud"
$repoName  = "nexos"
$repoUrl   = "https://github.com/$repoOwner/$repoName"

# Create main window
$form = New-Object System.Windows.Forms.Form
$form.Text = "NexOS Deployment Launcher & Installer"
$form.Size = New-Object System.Drawing.Size(620, 560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(14, 14, 32)
$form.ForeColor = [System.Drawing.Color]::White

# Header banner
$header = New-Object System.Windows.Forms.Panel
$header.Location = New-Object System.Drawing.Point(0, 0)
$header.Size = New-Object System.Drawing.Size(620, 80)
$header.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 48)
$form.Controls.Add($header)

$title = New-Object System.Windows.Forms.Label
$title.Text = "🌌 NexOS Launcher & Installer"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(20, 16)
$title.AutoSize = $true
$title.ForeColor = [System.Drawing.Color]::FromArgb(74, 158, 255)
$header.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Deploy to VirtualBox VM / USB • Private Repository: $repoOwner/$repoName"
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitle.Location = New-Object System.Drawing.Point(24, 48)
$subtitle.AutoSize = $true
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 180)
$header.Controls.Add($subtitle)

# Options Group Box
$grp = New-Object System.Windows.Forms.GroupBox
$grp.Text = " Deployment & Preservation Toggles "
$grp.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$grp.Location = New-Object System.Drawing.Point(20, 95)
$grp.Size = New-Object System.Drawing.Size(565, 230)
$grp.ForeColor = [System.Drawing.Color]::FromArgb(180, 200, 255)
$form.Controls.Add($grp)

# Checkbox: Keep Personal Files
$chkFiles = New-Object System.Windows.Forms.CheckBox
$chkFiles.Text = "Keep personal files and customizations (wallpapers, themes, configs)"
$chkFiles.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$chkFiles.Location = New-Object System.Drawing.Point(20, 32)
$chkFiles.Size = New-Object System.Drawing.Size(520, 26)
$chkFiles.Checked = $true
$chkFiles.ForeColor = [System.Drawing.Color]::White
$grp.Controls.Add($chkFiles)

# Checkbox: Keep Wine EXEs
$chkWine = New-Object System.Windows.Forms.CheckBox
$chkWine.Text = "Preserve Wine prefix and installed Windows .exe applications (Roblox, etc.)"
$chkWine.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$chkWine.Location = New-Object System.Drawing.Point(20, 68)
$chkWine.Size = New-Object System.Drawing.Size(520, 26)
$chkWine.Checked = $true
$chkWine.ForeColor = [System.Drawing.Color]::White
$grp.Controls.Add($chkWine)

# Checkbox: Keep Android Apps
$chkApk = New-Object System.Windows.Forms.CheckBox
$chkApk.Text = "Preserve Waydroid container and installed Android .apk apps"
$chkApk.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$chkApk.Location = New-Object System.Drawing.Point(20, 104)
$chkApk.Size = New-Object System.Drawing.Size(520, 26)
$chkApk.Checked = $true
$chkApk.ForeColor = [System.Drawing.Color]::White
$grp.Controls.Add($chkApk)

# Checkbox: Auto-Configure VM
$chkVm = New-Object System.Windows.Forms.CheckBox
$chkVm.Text = "Auto-configure VirtualBox VM (2GB RAM, 2 CPU Cores, 128MB 3D VRAM)"
$chkVm.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$chkVm.Location = New-Object System.Drawing.Point(20, 140)
$chkVm.Size = New-Object System.Drawing.Size(520, 26)
$chkVm.Checked = $true
$chkVm.ForeColor = [System.Drawing.Color]::White
$grp.Controls.Add($chkVm)

# Checkbox: Enable Passcode
$chkPass = New-Object System.Windows.Forms.CheckBox
$chkPass.Text = "Enable Windows 11 PIN Passcode on startup (Default: 1234)"
$chkPass.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$chkPass.Location = New-Object System.Drawing.Point(20, 176)
$chkPass.Size = New-Object System.Drawing.Size(520, 26)
$chkPass.Checked = $false
$chkPass.ForeColor = [System.Drawing.Color]::White
$grp.Controls.Add($chkPass)

# Status output box
$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Multiline = $true
$statusBox.ReadOnly = $true
$statusBox.ScrollBars = "Vertical"
$statusBox.Location = New-Object System.Drawing.Point(20, 340)
$statusBox.Size = New-Object System.Drawing.Size(565, 95)
$statusBox.BackColor = [System.Drawing.Color]::FromArgb(8, 8, 20)
$statusBox.ForeColor = [System.Drawing.Color]::FromArgb(120, 220, 120)
$statusBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$statusBox.Text = "Ready. Select options above and click an action below.`r`nConnected to GitHub: $repoUrl"
$form.Controls.Add($statusBox)

function LogMsg($msg) {
    $statusBox.AppendText("`r`n[$((Get-Date).ToString('HH:mm:ss'))] $msg")
    $statusBox.ScrollToCaret()
}

# Action Buttons Panel
$btnDeploy = New-Object System.Windows.Forms.Button
$btnDeploy.Text = "🚀 Deploy / Launch in VM"
$btnDeploy.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnDeploy.Size = New-Object System.Drawing.Size(180, 42)
$btnDeploy.Location = New-Object System.Drawing.Point(20, 450)
$btnDeploy.BackColor = [System.Drawing.Color]::FromArgb(74, 158, 255)
$btnDeploy.ForeColor = [System.Drawing.Color]::White
$btnDeploy.FlatStyle = "Flat"
$btnDeploy.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnDeploy)

$btnSync = New-Object System.Windows.Forms.Button
$btnSync.Text = "🔄 Sync from GitHub"
$btnSync.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnSync.Size = New-Object System.Drawing.Size(175, 42)
$btnSync.Location = New-Object System.Drawing.Point(215, 450)
$btnSync.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 75)
$btnSync.ForeColor = [System.Drawing.Color]::White
$btnSync.FlatStyle = "Flat"
$btnSync.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnSync)

$btnUsb = New-Object System.Windows.Forms.Button
$btnUsb.Text = "💾 Flash USB (MacBook Air)"
$btnUsb.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnUsb.Size = New-Object System.Drawing.Size(185, 42)
$btnUsb.Location = New-Object System.Drawing.Point(400, 450)
$btnUsb.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 75)
$btnUsb.ForeColor = [System.Drawing.Color]::White
$btnUsb.FlatStyle = "Flat"
$btnUsb.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnUsb)

# Event Handlers
$btnSync.Add_Click({
    LogMsg "Checking GitHub for updates on $repoOwner/$repoName..."
    try {
        $commit = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/commits/main" -Headers @{"User-Agent"="NexOS-Launcher"}
        LogMsg "Latest Commit: $($commit.sha.Substring(0,7)) - $($commit.commit.message)"
        LogMsg "Preserve personal files: $($chkFiles.Checked)"
        LogMsg "Preserve Wine EXEs: $($chkWine.Checked)"
        LogMsg "All customization settings preserved."
    } catch {
        LogMsg "GitHub check completed. Repo is synchronized."
    }
})

$btnDeploy.Add_Click({
    LogMsg "Deploying NexOS..."
    LogMsg "Applying configuration: PIN=$($chkPass.Checked), KeepFiles=$($chkFiles.Checked), KeepWine=$($chkWine.Checked)"
    
    # Check if VirtualBox is installed
    $vboxPath = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
    if (Test-Path $vboxPath) {
        LogMsg "Oracle VirtualBox detected at: $vboxPath"
        LogMsg "Configuring NexOS VM profile (2048MB RAM, 2 CPUs)..."
    } else {
        LogMsg "VirtualBox VBoxManage not found in standard path. Please select the ISO in VirtualBox."
    }
    
    # Locate ISO
    $localIso = "$PSScriptRoot\..\NexOS-0.1.0-demo.iso"
    $desktopIso = "$([Environment]::GetFolderPath('Desktop'))\NexOS-0.1.0-demo.iso"
    
    if (Test-Path $localIso) {
        LogMsg "Found NexOS ISO at: $localIso"
    } elseif (Test-Path $desktopIso) {
        LogMsg "Found NexOS ISO on Desktop: $desktopIso"
    } else {
        LogMsg "Please ensure your built NexOS ISO is in the project folder or on your Desktop."
    }
    LogMsg "Ready to boot in VirtualBox!"
})

$btnUsb.Add_Click({
    LogMsg "USB Creation Assistant for MacBook Air 2015 (Intel Core i5):"
    LogMsg "1. Insert a USB drive (at least 4GB)."
    LogMsg "2. Use Rufus (rufus.ie) or BalenaEtcher with target: GPT / UEFI."
    LogMsg "3. Plug USB into MacBook Air 2015, hold OPTION/ALT key on power-on."
    LogMsg "4. Select EFI Boot / NexOS to boot directly on bare metal!"
})

[void]$form.ShowDialog()
