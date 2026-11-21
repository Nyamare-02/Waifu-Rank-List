Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Konfiguration & Daten ---
if ($PSScriptRoot) {
    $script:scriptDir = $PSScriptRoot
} else {
    # Holt den Pfad der laufenden EXE-Datei, selbst wenn sie über ps2exe kompiliert wurde
    $exePath = [System.IO.Path]::GetFullPath([System.Environment]::GetCommandLineArgs()[0])
    $script:scriptDir = [System.IO.Path]::GetDirectoryName($exePath)
}
$script:dataFile = Join-Path $script:scriptDir "waifu_liste.json"
$script:configFile = Join-Path $script:scriptDir "waifu_config.json"

$script:iconMoon = [System.Char]::ConvertFromUtf32(0x1F319)
$script:iconSun  = [char]0x2600

function Get-ThemeConfig {
    if (Test-Path $script:configFile) {
        try {
            $cfg = Get-Content $script:configFile -Raw -Encoding UTF8 | ConvertFrom-Json
            return [bool]$cfg.DarkMode
        } catch {}
    }
    return $true
}

function Save-ThemeConfig([bool]$isDark) {
    [PSCustomObject]@{ DarkMode = $isDark } | ConvertTo-Json | Set-Content $script:configFile -Encoding UTF8
}

function Get-WaifuData {
    if (Test-Path $script:dataFile) {
        $raw = Get-Content $script:dataFile -Raw -Encoding UTF8
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $parsed = $raw | ConvertFrom-Json
            return @($parsed)
        }
    }
    return @(
        [PSCustomObject]@{
            Name     = "Beispiel-Charakter 1"
            Serie    = "Beispiel-Anime"
            BildLink = ""
            Infos    = "Hier stehen deine Notizen, Eigenschaften oder Tags."
        }
    )
}

function Save-WaifuData($list) {
    ConvertTo-Json -InputObject @($list) -Depth 3 | Set-Content $script:dataFile -Encoding UTF8
}

$script:isDarkMode = Get-ThemeConfig
$script:waifuList  = [System.Collections.ArrayList]::new()
$initialData = Get-WaifuData
foreach ($item in $initialData) {
    [void]$script:waifuList.Add($item)
}
$script:showAll = $false

# --- Farbpaletten ---
function Get-Palette {
    if ($script:isDarkMode) {
        return @{
            BgForm     = [System.Drawing.Color]::FromArgb(30, 30, 30)
            BgControl  = [System.Drawing.Color]::FromArgb(45, 45, 48)
            BgButton   = [System.Drawing.Color]::FromArgb(62, 62, 66)
            BgAdd      = [System.Drawing.Color]::FromArgb(42, 85, 52)
            BgDelete   = [System.Drawing.Color]::FromArgb(110, 42, 42)
            Border     = [System.Drawing.Color]::FromArgb(80, 80, 85)
            FgText     = [System.Drawing.Color]::FromArgb(241, 241, 241)
            FgMuted    = [System.Drawing.Color]::FromArgb(170, 170, 175)
            Link       = [System.Drawing.Color]::FromArgb(86, 176, 255)
        }
    } else {
        return @{
            BgForm     = [System.Drawing.SystemColors]::Control
            BgControl  = [System.Drawing.Color]::White
            BgButton   = [System.Drawing.SystemColors]::ControlLight
            BgAdd      = [System.Drawing.Color]::FromArgb(220, 240, 220)
            BgDelete   = [System.Drawing.Color]::FromArgb(245, 220, 220)
            Border     = [System.Drawing.Color]::FromArgb(180, 180, 180)
            FgText     = [System.Drawing.Color]::Black
            FgMuted    = [System.Drawing.Color]::DimGray
            Link       = [System.Drawing.Color]::Blue
        }
    }
}

function Set-ControlTheme($parent) {
    $p = Get-Palette
    $parent.BackColor = $p.BgForm
    $parent.ForeColor = $p.FgText

    foreach ($ctrl in $parent.Controls) {
        if ($ctrl -is [System.Windows.Forms.GroupBox]) {
            $ctrl.BackColor = $p.BgForm
            $ctrl.ForeColor = $p.FgText
            Set-ControlTheme $ctrl
        }
        elseif ($ctrl -is [System.Windows.Forms.ListBox]) {
            $ctrl.BackColor = $p.BgControl
            $ctrl.ForeColor = $p.FgText
            $ctrl.BorderStyle = "FixedSingle"
        }
        elseif ($ctrl -is [System.Windows.Forms.TextBox]) {
            $ctrl.BackColor = if ($ctrl.ReadOnly) { $p.BgForm } else { $p.BgControl }
            $ctrl.ForeColor = $p.FgText
            $ctrl.BorderStyle = "FixedSingle"
        }
        elseif ($ctrl -is [System.Windows.Forms.Button]) {
            $ctrl.FlatStyle = "Flat"
            $ctrl.FlatAppearance.BorderColor = $p.Border
            $ctrl.ForeColor = $p.FgText
            switch ($ctrl.Tag) {
                "Add"    { $ctrl.BackColor = $p.BgAdd }
                "Delete" { $ctrl.BackColor = $p.BgDelete }
                default  { $ctrl.BackColor = $p.BgButton }
            }
        }
        elseif ($ctrl -is [System.Windows.Forms.LinkLabel]) {
            $ctrl.LinkColor = $p.Link
            $ctrl.ActiveLinkColor = $p.Link
            $ctrl.VisitedLinkColor = $p.Link
        }
        elseif ($ctrl -is [System.Windows.Forms.PictureBox]) {
            $ctrl.BackColor = $p.BgControl
            foreach ($subCtrl in $ctrl.Controls) {
                $subCtrl.BackColor = $p.BgControl
                $subCtrl.ForeColor = $p.FgMuted
            }
        }
        elseif ($ctrl -is [System.Windows.Forms.Label]) {
            $ctrl.ForeColor = $p.FgText
        }
    }
}

# --- Hauptfenster ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Waifu Top-Liste"
$form.Size = New-Object System.Drawing.Size(680, 520)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# --- Linke Seite ---
$lblListHeader = New-Object System.Windows.Forms.Label
$lblListHeader.Text = "Top 10 Liste"
$lblListHeader.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblListHeader.Location = New-Object System.Drawing.Point(20, 15)
$lblListHeader.AutoSize = $true
$form.Controls.Add($lblListHeader)

$listBoxMain = New-Object System.Windows.Forms.ListBox
$listBoxMain.Location = New-Object System.Drawing.Point(20, 45)
$listBoxMain.Size = New-Object System.Drawing.Size(280, 360)
$listBoxMain.Font = New-Object System.Drawing.Font("Segoe UI", 10.5)
$form.Controls.Add($listBoxMain)

$btnToggleList = New-Object System.Windows.Forms.Button
$btnToggleList.Text = "Komplette Liste"
$btnToggleList.Location = New-Object System.Drawing.Point(20, 420)
$btnToggleList.Size = New-Object System.Drawing.Size(280, 42)
$form.Controls.Add($btnToggleList)

# --- Rechte Seite ---
$btnTheme = New-Object System.Windows.Forms.Button
$btnTheme.Text = if ($script:isDarkMode) { "$script:iconSun Light Mode" } else { "$script:iconMoon Dark Mode" }
$btnTheme.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$btnTheme.Location = New-Object System.Drawing.Point(540, 11)
$btnTheme.Size = New-Object System.Drawing.Size(105, 25)
$form.Controls.Add($btnTheme)

$grpInfo = New-Object System.Windows.Forms.GroupBox
$grpInfo.Text = "Infos"
$grpInfo.Location = New-Object System.Drawing.Point(320, 38)
$grpInfo.Size = New-Object System.Drawing.Size(325, 367)
$form.Controls.Add($grpInfo)

$picBox = New-Object System.Windows.Forms.PictureBox
$picBox.Location = New-Object System.Drawing.Point(15, 25)
$picBox.Size = New-Object System.Drawing.Size(295, 180)
$picBox.BorderStyle = "FixedSingle"
$picBox.SizeMode = "Zoom"
$grpInfo.Controls.Add($picBox)

$lblPicStatus = New-Object System.Windows.Forms.Label
$lblPicStatus.Location = New-Object System.Drawing.Point(10, 70)
$lblPicStatus.Size = New-Object System.Drawing.Size(275, 45)
$lblPicStatus.TextAlign = "MiddleCenter"
$lblPicStatus.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblPicStatus.Visible = $false
$picBox.Controls.Add($lblPicStatus)

$lblName = New-Object System.Windows.Forms.Label
$lblName.Text = "Name: -"
$lblName.Font = New-Object System.Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Bold)
$lblName.Location = New-Object System.Drawing.Point(15, 215)
$lblName.Size = New-Object System.Drawing.Size(295, 22)
$grpInfo.Controls.Add($lblName)

$lblSerie = New-Object System.Windows.Forms.Label
$lblSerie.Text = "Serie: -"
$lblSerie.Location = New-Object System.Drawing.Point(15, 240)
$lblSerie.Size = New-Object System.Drawing.Size(295, 22)
$grpInfo.Controls.Add($lblSerie)

$linkBild = New-Object System.Windows.Forms.LinkLabel
$linkBild.Text = "Bild-Link $([char]0x00F6)ffnen"
$linkBild.Location = New-Object System.Drawing.Point(15, 265)
$linkBild.Size = New-Object System.Drawing.Size(295, 20)
$linkBild.Visible = $false
$grpInfo.Controls.Add($linkBild)

$txtInfos = New-Object System.Windows.Forms.TextBox
$txtInfos.Location = New-Object System.Drawing.Point(15, 290)
$txtInfos.Size = New-Object System.Drawing.Size(295, 62)
$txtInfos.Multiline = $true
$txtInfos.ReadOnly = $true
$txtInfos.ScrollBars = "Vertical"
$grpInfo.Controls.Add($txtInfos)

$btnManage = New-Object System.Windows.Forms.Button
$btnManage.Text = "Liste Verwalten"
$btnManage.Location = New-Object System.Drawing.Point(320, 420)
$btnManage.Size = New-Object System.Drawing.Size(325, 42)
$form.Controls.Add($btnManage)

# --- Hilfsfunktionen ---
function Update-MainList {
    $listBoxMain.Items.Clear()
    $limit = if ($script:showAll) { $script:waifuList.Count } else { [Math]::Min(10, $script:waifuList.Count) }
    
    for ($i = 0; $i -lt $limit; $i++) {
        $rank = $i + 1
        [void]$listBoxMain.Items.Add("$rank. $($script:waifuList[$i].Name)")
    }

    if ($listBoxMain.Items.Count -gt 0) {
        $listBoxMain.SelectedIndex = 0
    } else {
        Clear-InfoPanel
    }
}

function Clear-InfoPanel {
    $lblName.Text = "Name: -"
    $lblSerie.Text = "Serie: -"
    $txtInfos.Text = ""
    $linkBild.Visible = $false
    $linkBild.Tag = $null
    $lblPicStatus.Visible = $false
    if ($picBox.Image) {
        $picBox.Image.Dispose()
        $picBox.Image = $null
    }
}

function Convert-BytesToImage([byte[]]$bytes) {
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    try {
        return [System.Drawing.Image]::FromStream($ms)
    }
    catch {
        $ms.Position = 0
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
            $ms,
            [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,
            [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        )
        $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
        $encoder.Frames.Add($decoder.Frames[0])
        $pngStream = New-Object System.IO.MemoryStream
        $encoder.Save($pngStream)
        $pngStream.Position = 0
        return [System.Drawing.Image]::FromStream($pngStream)
    }
}

function Set-PreviewImage($rawPath) {
    if ($picBox.Image) {
        $picBox.Image.Dispose()
        $picBox.Image = $null
    }
    $lblPicStatus.Visible = $false

    if ([string]::IsNullOrWhiteSpace($rawPath)) { return }
    $cleanPath = $rawPath.Trim().Trim('"')

    try {
        if (Test-Path -LiteralPath $cleanPath) {
            $bytes = [System.IO.File]::ReadAllBytes($cleanPath)
            $picBox.Image = Convert-BytesToImage $bytes
        }
        elseif ($cleanPath -match "^https?://") {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            $bytes = $wc.DownloadData($cleanPath)
            $picBox.Image = Convert-BytesToImage $bytes
        }
        else {
            $lblPicStatus.Text = "Pfad nicht gefunden."
            $lblPicStatus.Visible = $true
        }
    }
    catch {
        $lblPicStatus.Text = "Bild konnte nicht geladen werden.`n(Kein Direktlink oder Server blockiert)"
        $lblPicStatus.Visible = $true
    }
}

# --- Events ---
$btnTheme.Add_Click({
    $script:isDarkMode = -not $script:isDarkMode
    $btnTheme.Text = if ($script:isDarkMode) { "$script:iconSun Light Mode" } else { "$script:iconMoon Dark Mode" }
    Save-ThemeConfig $script:isDarkMode
    Set-ControlTheme $form
})

$listBoxMain.Add_SelectedIndexChanged({
    $idx = $listBoxMain.SelectedIndex
    if ($idx -lt 0 -or $idx -ge $script:waifuList.Count) { return }

    $entry = $script:waifuList[$idx]
    $lblName.Text = "#$($idx + 1) - $($entry.Name)"
    $lblSerie.Text = "Serie: $($entry.Serie)"
    $txtInfos.Text = $entry.Infos

    if (-not [string]::IsNullOrWhiteSpace($entry.BildLink)) {
        $linkBild.Visible = $true
        $linkBild.Tag = $entry.BildLink.Trim().Trim('"')
    } else {
        $linkBild.Visible = $false
        $linkBild.Tag = $null
    }

    Set-PreviewImage $entry.BildLink
})

$linkBild.Add_LinkClicked({
    if ($linkBild.Tag) {
        Start-Process $linkBild.Tag
    }
})

$btnToggleList.Add_Click({
    $script:showAll = -not $script:showAll
    if ($script:showAll) {
        $lblListHeader.Text = "Komplette Liste ($($script:waifuList.Count))"
        $btnToggleList.Text = "Nur Top 10 anzeigen"
    } else {
        $lblListHeader.Text = "Top 10 Liste"
        $btnToggleList.Text = "Komplette Liste"
    }
    Update-MainList
})

# --- Verwaltungs-Dialog ---
$btnManage.Add_Click({
    $sub = New-Object System.Windows.Forms.Form
    $sub.Text = "Waifu-Liste verwalten"
    $sub.Size = New-Object System.Drawing.Size(600, 430)
    $sub.StartPosition = "CenterParent"
    $sub.FormBorderStyle = "FixedDialog"
    $sub.MaximizeBox = $false
    $sub.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

    $lbSub = New-Object System.Windows.Forms.ListBox
    $lbSub.Location = New-Object System.Drawing.Point(15, 15)
    $lbSub.Size = New-Object System.Drawing.Size(230, 310)
    $sub.Controls.Add($lbSub)

    $btnUp = New-Object System.Windows.Forms.Button
    $btnUp.Text = "$([char]0x25B2) Hoch"
    $btnUp.Location = New-Object System.Drawing.Point(15, 335)
    $btnUp.Size = New-Object System.Drawing.Size(110, 32)
    $sub.Controls.Add($btnUp)

    $btnDown = New-Object System.Windows.Forms.Button
    $btnDown.Text = "$([char]0x25BC) Runter"
    $btnDown.Location = New-Object System.Drawing.Point(135, 335)
    $btnDown.Size = New-Object System.Drawing.Size(110, 32)
    $sub.Controls.Add($btnDown)

    $lblN = New-Object System.Windows.Forms.Label
    $lblN.Text = "Name:"
    $lblN.Location = New-Object System.Drawing.Point(265, 15)
    $lblN.AutoSize = $true

    $txtN = New-Object System.Windows.Forms.TextBox
    $txtN.Location = New-Object System.Drawing.Point(265, 38)
    $txtN.Size = New-Object System.Drawing.Size(300, 25)

    $lblS = New-Object System.Windows.Forms.Label
    $lblS.Text = "Serie / Game:"
    $lblS.Location = New-Object System.Drawing.Point(265, 72)
    $lblS.AutoSize = $true

    $txtS = New-Object System.Windows.Forms.TextBox
    $txtS.Location = New-Object System.Drawing.Point(265, 95)
    $txtS.Size = New-Object System.Drawing.Size(300, 25)

    $lblB = New-Object System.Windows.Forms.Label
    $lblB.Text = "Bild-Link (Direkt-URL oder Datei):"
    $lblB.Location = New-Object System.Drawing.Point(265, 129)
    $lblB.AutoSize = $true

    $txtB = New-Object System.Windows.Forms.TextBox
    $txtB.Location = New-Object System.Drawing.Point(265, 152)
    $txtB.Size = New-Object System.Drawing.Size(260, 25)

    $btnPickImg = New-Object System.Windows.Forms.Button
    $btnPickImg.Text = "..."
    $btnPickImg.Location = New-Object System.Drawing.Point(530, 151)
    $btnPickImg.Size = New-Object System.Drawing.Size(35, 26)

    $lblI = New-Object System.Windows.Forms.Label
    $lblI.Text = "Infos / Notizen:"
    $lblI.Location = New-Object System.Drawing.Point(265, 186)
    $lblI.AutoSize = $true

    $txtI = New-Object System.Windows.Forms.TextBox
    $txtI.Location = New-Object System.Drawing.Point(265, 209)
    $txtI.Size = New-Object System.Drawing.Size(300, 75)
    $txtI.Multiline = $true

    $btnAddNew = New-Object System.Windows.Forms.Button
    $btnAddNew.Text = "Neu hinzuf$([char]0x00FC)gen"
    $btnAddNew.Tag = "Add"
    $btnAddNew.Location = New-Object System.Drawing.Point(265, 298)
    $btnAddNew.Size = New-Object System.Drawing.Size(145, 32)

    $btnUpdate = New-Object System.Windows.Forms.Button
    $btnUpdate.Text = "$([char]0x00C4)nderung speichern"
    $btnUpdate.Location = New-Object System.Drawing.Point(420, 298)
    $btnUpdate.Size = New-Object System.Drawing.Size(145, 32)

    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "Eintrag l$([char]0x00F6)schen"
    $btnDelete.Tag = "Delete"
    $btnDelete.Location = New-Object System.Drawing.Point(265, 338)
    $btnDelete.Size = New-Object System.Drawing.Size(300, 30)

    $sub.Controls.AddRange(@($lblN, $txtN, $lblS, $txtS, $lblB, $txtB, $btnPickImg, $lblI, $txtI, $btnAddNew, $btnUpdate, $btnDelete))
    Set-ControlTheme $sub

    $btnPickImg.Add_Click({
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Filter = "Bilddateien (*.jpg;*.jpeg;*.png;*.webp;*.gif;*.bmp)|*.jpg;*.jpeg;*.png;*.webp;*.gif;*.bmp|Alle Dateien (*.*)|*.*"
        if ($ofd.ShowDialog() -eq "OK") {
            $txtB.Text = $ofd.FileName
        }
    })

    function Sync-SubList($selectIndex = -1) {
        $lbSub.Items.Clear()
        for ($i = 0; $i -lt $script:waifuList.Count; $i++) {
            [void]$lbSub.Items.Add("$($i + 1). $($script:waifuList[$i].Name)")
        }
        if ($selectIndex -ge 0 -and $selectIndex -lt $lbSub.Items.Count) {
            $lbSub.SelectedIndex = $selectIndex
        }
    }
    Sync-SubList 0

    $lbSub.Add_SelectedIndexChanged({
        $idx = $lbSub.SelectedIndex
        if ($idx -ge 0) {
            $item = $script:waifuList[$idx]
            $txtN.Text = $item.Name
            $txtS.Text = $item.Serie
            $txtB.Text = $item.BildLink
            $txtI.Text = $item.Infos
        }
    })

    $btnAddNew.Add_Click({
        if ([string]::IsNullOrWhiteSpace($txtN.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Bitte mindestens einen Namen angeben.", "Hinweis")
            return
        }
        $obj = [PSCustomObject]@{
            Name     = $txtN.Text.Trim()
            Serie    = $txtS.Text.Trim()
            BildLink = $txtB.Text.Trim().Trim('"')
            Infos    = $txtI.Text.Trim()
        }
        [void]$script:waifuList.Add($obj)
        Sync-SubList ($script:waifuList.Count - 1)
    })

    $btnUpdate.Add_Click({
        $idx = $lbSub.SelectedIndex
        if ($idx -lt 0) { return }
        if ([string]::IsNullOrWhiteSpace($txtN.Text)) { return }

        $script:waifuList[$idx] = [PSCustomObject]@{
            Name     = $txtN.Text.Trim()
            Serie    = $txtS.Text.Trim()
            BildLink = $txtB.Text.Trim().Trim('"')
            Infos    = $txtI.Text.Trim()
        }
        Sync-SubList $idx
    })

    $btnDelete.Add_Click({
        $idx = $lbSub.SelectedIndex
        if ($idx -lt 0) { return }
        $script:waifuList.RemoveAt($idx)
        $txtN.Clear()
        $txtS.Clear()
        $txtB.Clear()
        $txtI.Clear()
        Sync-SubList ([Math]::Min($idx, $script:waifuList.Count - 1))
    })

    $btnUp.Add_Click({
        $idx = $lbSub.SelectedIndex
        if ($idx -le 0) { return }
        $temp = $script:waifuList[$idx]
        $script:waifuList[$idx] = $script:waifuList[$idx - 1]
        $script:waifuList[$idx - 1] = $temp
        Sync-SubList ($idx - 1)
    })

    $btnDown.Add_Click({
        $idx = $lbSub.SelectedIndex
        if ($idx -lt 0 -or $idx -ge ($script:waifuList.Count - 1)) { return }
        $temp = $script:waifuList[$idx]
        $script:waifuList[$idx] = $script:waifuList[$idx + 1]
        $script:waifuList[$idx + 1] = $temp
        Sync-SubList ($idx + 1)
    })

    $sub.Add_FormClosing({
        Save-WaifuData $script:waifuList
        if ($script:showAll) { $lblListHeader.Text = "Komplette Liste ($($script:waifuList.Count))" }
        Update-MainList
    })

    [void]$sub.ShowDialog()
})

Set-ControlTheme $form
Update-MainList
[void]$form.ShowDialog()