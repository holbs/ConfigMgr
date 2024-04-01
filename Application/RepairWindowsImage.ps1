#Region: Detection
If ((Repair-WindowsImage -Online -CheckHealth).ImageHealthState -eq "Healthy") {
    Return $true
}
#EndRegion
#Region: Installation
$CheckHealth = Repair-WindowsImage -Online -CheckHealth
$ScanHealth = Repair-WindowsImage -Online -ScanHealth
$RestoreHealth = Repair-WindowsImage -Online -RestoreHealth
# Create registry settings for a custom URI so PowerShell can exectue scripts from a notification
New-Item "HKLM:\SOFTWARE\Classes\toastnotification" -Force
New-Item "HKLM:\SOFTWARE\Classes\toastnotification\DefaultIcon" -Force
New-Item "HKLM:\SOFTWARE\Classes\toastnotification\shell" -Force
New-Item "HKLM:\SOFTWARE\Classes\toastnotification\shell\open" -Force
New-Item "HKLM:\SOFTWARE\Classes\toastnotification\shell\open\command" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Classes\toastnotification" -Name "(default)" -Value "URL:PowerShell Toast Notification Protocol" -Type String -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Classes\toastnotification" -Name "URL Protocol" -Value "" -Type String -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Classes\toastnotification\DefaultIcon" -Name "(default)" -Value "%windir%\System32\WindowsPowerShell\v1.0\powershell.exe,1" -Type String -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Classes\toastnotification\shell" -Name "(default)" -Value "open" -Type String -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Classes\toastnotification\shell\open\command" -Name "(default)" -Value "`"$env:ProgramData\ToastNotification\RestartComputer.cmd`" %1" -Type String -Force
# Copy restart script to %ProgramData% so it can be called through the notification
New-Item -Path "$env:ProgramData\ToastNotification" -ItemType Directory -Force
Copy-Item -Path "$PSScriptHost\RestartComputer.cmd" -Destination "$env:ProgramData\ToastNotification\RestartComputer.cmd" -Force -Confirm:$false # RestartComputer.cmd is in the application content, and triggers the PowerShell script
Copy-Item -Path "$PSScriptHost\RestartComputer.ps1" -Destination "$env:ProgramData\ToastNotification\RestartComputer.ps1" -Force -Confirm:$false # RestartComputer.ps1 is in the application content, and runs Restart-Computer
# If the Repair-WindowsImage commands did not require a restart then run sfc /scannow
If ($CheckHealth.RestartNeeded -ne $true -and $ScanHealth.RestartNeeded -ne $true -and $RestoreHealth.RestartNeeded -ne $true) {
    # Trigger SFC /scannow
    Start-Process -WindowStyle hidden -FilePath "$env:WINDIR\System32\sfc.exe" -ArgumentList "/scannow"
    Wait-Process -Name "sfc" -ErrorAction SilentlyContinue
}
#  Prompt the user to restart via a toast notification
$ToastXml = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Restart Notification</text>
            <text>A system scan has found Windows image corruption. Please restart your computer to complete repairs.</text>
            <image placement="appLogoOverride" src="$PSScriptHost\Restart.png"/>
        </binding>
    </visual>
    <actions>
        <action content="Snooze" activationType="protocol" arguments="" />
        <action content="Restart" activationType="protocol" arguments="toastnotification://trigger" />
    </actions>
</toast>
"@
$XmlDocument = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]::New()
$XmlDocument.LoadXml($ToastXml)
$AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::CreateToastNotifier($AppId).Show($XmlDocument)
#EndRegion