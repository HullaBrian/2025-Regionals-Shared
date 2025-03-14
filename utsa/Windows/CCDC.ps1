Function Get-LocalGroupMembers {
    param (
        [string]$GroupName
    )

    $groupInfo = net localgroup "$GroupName" | Select-Object -Skip 6 | Where-Object {$_ -match '\S'}  

    if ($groupInfo) {
        Write-Host "`n$GroupName" -ForegroundColor Cyan
        Write-Host "------------------------"

        if ($groupInfo.Count - 1 -le 0) {
            Write-Host "Group '$GroupName' not found or has no members." -ForegroundColor Red
        }

        for ($i = 0; $i -lt $groupInfo.Count - 1; $i++) {
            Write-Host "  - $($groupInfo[$i])"
        }
    } else {
        Write-Host "Group '$GroupName' not found or has no members." -ForegroundColor Red
    }
}

Function Get-RegistryKeys {
    param (
        [string]$RegKey
    )
    Write-Host "$RegKey" -ForegroundColor Cyan
    $runKey = Get-Item -Path "$RegKey"
    $runKey.GetValueNames() | ForEach-Object { [PSCustomObject]@{ Name = $_; Value = $runKey.GetValue($_) } } | Out-Host
}

function Get-Tools {
    New-Item -Path C:\ -Name "Tools" -ItemType Directory -Force > $null
    Write-Host "[+] Created tools directory!"

    Write-Host "[+] Collecting tools..."
    Write-Host "[+] Downloading SystemInformer"
    Invoke-WebRequest https://phoenixnap.dl.sourceforge.net/project/systeminformer/systeminformer-3.2.25011-release-setup.exe?viasf=1 -OutFile "C:\Tools\SystemInformer.exe"
    Write-Host "[+] Downloading Cable"
    Invoke-WebRequest https://github.com/logangoins/Cable/releases/download/1.0/Cable.exe -OutFile "C:\Tools\Cable.exe"
    Write-Host "[+] Downloading Autoruns"
    Invoke-WebRequest https://download.sysinternals.com/files/Autoruns.zip -OutFile "C:\Tools\Autoruns.zip"
    Write-Host "[+] Downloading Sysmon"
    Invoke-WebRequest https://download.sysinternals.com/files/Sysmon.zip -OutFile "C:\Tools\Sysmon.zip"
    Write-Host "[+] Downloading Firefox"
    Invoke-WebRequest "https://download.mozilla.org/?product=firefox-stub&os=win&lang=en-US" -OutFile "C:\Tools\FirefoxInstaller.exe"
    Write-Host "[+] Downloading LDAP Firewall"
    Invoke-WebRequest https://github.com/zeronetworks/ldapfw/releases/download/v1.0.0/ldapfw_v1.0.0-x64.zip -OutFile "C:\Tools\ldapfw.zip"
    Write-Host "[+] Downloading Account Lockout Tools"
    Invoke-WebRequest "https://download.microsoft.com/download/1/f/0/1f0e9569-3350-4329-b443-822976f29284/ALTools.exe" -OutFile "C:\Tools\ALTools.exe"
    Write-Host "[+] Finished downloading tools!" -ForegroundColor Green

    Write-Host "[+] Expanding archives"
    Expand-Archive -Path "C:\Tools\Autoruns.zip" -DestinationPath "C:\Tools\Autoruns" -Force
    Expand-Archive -Path "C:\Tools\Sysmon.zip" -DestinationPath "C:\Tools\Sysmon" -Force
    Expand-Archive -Path "C:\Tools\ldapfw.zip" -DestinationPath "C:\Tools\ldapfw" -Force
    Write-Host "[+] Expanded Archives"
    Remove-Item "C:\Tools\Autoruns.zip"
    Remove-Item "C:\Tools\Sysmon.zip"
    Remove-Item "C:\Tools\ldapfw.zip"
    Write-Host "[+] Removed zip files"

    Rename-Item -Path "C:\Tools\Sysmon\Sysmon.exe" -NewName "StorageSyncSvc.exe" > $null
    C:\Tools\Sysmon\StorageSyncSvc.exe -i -accepteula -d storagesync > $null
    Write-Host "[+] Installed Sysmon"
    $acl = Get-ACL "C:\Windows\StorageSyncSvc.exe"
    $acl.SetAccessRuleProtection($True, $False)
    Set-ACL "C:\Windows\StorageSyncSvc.exe" $acl | Out-Null
    $sddl = "O:BAG:DUD:PAI(A;;0x1200a9;;;SY)(A;;FA;;;BA)"
    $FileSecurity = New-Object System.Security.AccessControl.FileSecurity
    $FileSecurity.SetSecurityDescriptorSddlForm($SDDL)
    Set-ACL -Path "C:\Windows\StorageSyncSvc.exe" -ACLObject $FileSecurity
    Write-Host "[+] Hardened Sysmon service configuration"

    Invoke-WebRequest https://raw.githubusercontent.com/zeronetworks/ldapfw/refs/heads/master/example_configs/DACLPrevention_config.json -OutFile "C:\Tools\ldapfw\DACLPrevention_config.json"
    Move-Item "C:\Tools\ldapfw\DACLPrevention_config.json" "C:\Tools\ldapfw\config.json" -Force
    Write-Host "[+] Downloaded LDAP Firewall configuration"

    Write-Host "[+] Done!" -ForegroundColor Green
}

function Enumerate {
    param (
        [string]$AdminPass
    )
    Write-Host "[+] Start Windows Updates and Defender Protection Updates!!" -ForegroundColor Blue
    Write-Output "=========START SYSTEM INFO========="
    $hostinfo = Get-ComputerInfo
    Write-Host "[+] Retrieved host info!" -ForegroundColor Green
    $netinfo = Get-NetIPConfiguration -Detailed
    Write-Host "[+] Retrieved network configuration!" -ForegroundColor Green
    
    Write-Output "Hostname: $($hostinfo.CsDomain)\$($hostinfo.CsName)`n"
    Write-Output "OS: $($hostinfo.WindowsProductName) - $($hostinfo.OSVersion) - $($hostinfo.OsBuildNumber)"
    
    foreach( $interface in $netinfo ) {
        Write-Output "- $($interface.InterfaceAlias)"
        Write-Output "    - IPv4: $($interface.IPv4Address.IPv4Address)"
        Write-Output "    - IPv6: $($interface.IPv6Address.IPv6Address)"
        Write-Output "    - Default gateway: $($interface.IPv4DefaultGateway.NextHop)"
        Write-Output "    - DNS: $($interface.DNSServer.ServerAddresses)"
    }
    Write-Output ""
    
    Write-Output "Domain Joined: $($hostinfo.CsPartOfDomain)"
    Write-Output "Domain Role: $($hostinfo.CsDomainRole)"

    Write-Output "=========END SYSTEM INFO========="

    Write-Output "=========START USER INFO========="
    Get-LocalUser | Out-Host
    
    Write-Host "Local Groups:"
    net localgroup

    Get-LocalGroupMembers -GroupName "Administrators"
    Get-LocalGroupMembers -GroupName "Remote Management Users"
    Get-LocalGroupMembers -GroupName "Remote Desktop Users"
    Get-LocalGroupMembers -GroupName "Backup Operators"
    Get-LocalGroupMembers -GroupName "Network Configuration Operators"
    Get-LocalGroupMembers -GroupName "Server Operators"
    Get-LocalGroupMembers -GroupName "Account Operators"
    
    Write-Output ""
    if ($AdminPass) {
        Enable-LocalUser Administrator
        Write-Host "[+] Enabled local administrator" -ForegroundColor Green
        Set-LocalUser -Name Administrator -Password (ConvertTo-SecureString $AdminPass -AsPlainText -Force)
        Write-Host "[+] Changed Administrator password!" -ForegroundColor Green
    } else {
        Write-Host "[-] Nothing was given for new Administrator password - skipping" -ForegroundColor Yellow
    }
    Write-Output "=========END USER INFO========="
    
    Write-Output "=========START LISTENING PORTS========="
    $procs = Get-Process
    $ports = netstat -ano
    $ports[4..$ports.length] |
        ConvertFrom-String -PropertyNames ProcessName,Proto,Local,Remote,State,PID  | 
        where  State -eq 'LISTENING' | 
        foreach {
            $_.ProcessName = ($procs | where ID -eq $_.PID).ProcessName
            $_
        } | 
        Format-Table
    Write-Output "=========END LISTENING PORTS========="
    
    Write-Output "=========START PROCESSES========="
    $sessions = @(query session | ForEach-Object {
        if ($_ -match "(\S+)\s+(\d+)\s") {
            [PSCustomObject]@{
                SessionName = $matches[1]
                SessionId   = [int]$matches[2]
            }
        }
    })

    Get-CimInstance Win32_Process | ForEach-Object {
        $proc = $_
        $owner = $proc | Invoke-CimMethod -MethodName GetOwner
        $commandLine = $proc.CommandLine
        $sessionId = $proc.SessionId

        $sessionName = ($sessions | Where-Object { $_.SessionId -eq $sessionId }).SessionName
        if (-not $sessionName) { $sessionName = "Unknown" }

        [PSCustomObject]@{
            UserName    = "$($owner.Domain)\$($owner.User)"
            ProcessID   = $proc.ProcessId
            CommandLine = $commandLine
            SessionName = $sessionName
            SessionId   = $sessionId
        }
    } | Format-Table -AutoSize
    Write-Output "==========END PROCESSES=========="

    Write-Output "==========START SERVICES=========="
    $svc = Get-WmiObject Win32_Service | Select-Object Name, PathName
    Write-Output $svc
    Write-Output "==========END SERVICES=========="

    Write-Output "==========START Installed Applications=========="
    $a1 = gci HKLM:\SOFTWARE
    $a2 = gci "C:\Program Files" -Force
    $a3 = gci "C:\Program Files (x86)" -Force
    $a4 = gci "C:\Windows\Temp" -Force
    Write-Output "HKLM:\SOFTWARE`n--------------"
    Write-Output $a1
    Write-Output "`nC:\Program Files\`n-----------------"
    Write-Output $a2
    Write-Output "`nC:\Program Files (x86)\`n-----------------------"
    Write-Output $a3
    Write-Output "`nC:\Windows\Temp\`n-----------------------"
    Write-Output $a4
    Write-Output "==========END Installed Applications=========="

    Write-Output "==========START Scheduled Tasks=========="
    $tasks = Get-ScheduledTask | ForEach-Object {
        $taskName = $_.TaskName
        $taskPath = $_.TaskPath
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName -TaskPath $taskPath
        $execPath = ($_ | Select-Object -ExpandProperty Actions).Execute

        [PSCustomObject]@{
            TaskPath  = $taskPath
            TaskName  = $taskName
            ExecPath  = $execPath
        }
    }
    $tasks | Format-Table -AutoSize
    Write-Output "==========END Scheduled Tasks=========="

    Write-Output "==========START Registry Keys=========="
    Get-RegistryKeys -RegKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    Get-RegistryKeys -RegKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    Get-RegistryKeys -RegKey "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    Get-RegistryKeys -RegKey "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
    Write-Output "==========END Registry Keys=========="

    Write-Output "==========START Startup Folder==========" 
    gci "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" -Force | Out-Host
    Write-Output "==========END Startup Folder=========="
    Write-Output "`n"

    Get-SmbShare | ForEach-Object {
    $share = $_
    $access = Get-SmbShareAccess -Name $share.Name
    $access | Select-Object @{Name="ShareName";Expression={$share.Name}}, 
                            @{Name="SharePath";Expression={$share.Path}},
                            @{Name="AccessRight";Expression={$_.AccessRight}},
                            @{Name="AccountName";Expression={$_.AccountName}}
    } | Out-Host
    Read-Host -Prompt "Press enter to remove and limit unnecessary shares!"
    net share C$ /delete
    net share ADMIN$ /delete
    Read-Host -Prompt "Stop HERE! Change permissions on shares to readonly in the gui! If done, press enter!"

    Clear-History
    try {
        rm $(Get-PSReadLineOption).HistorySavePath -ErrorAction Stop
        Write-Host "[+] Cleared powershell history!" -ForegroundColor Green
    } catch {
        Write-Host "[-] No powershell history file found!" -ForegroundColor Yellow
    }
    
    Write-Host "[+] Finished machine enumeration!`n" -ForegroundColor Green
    Write-Host "Things to do:`n* Delete unnecessary local administrators!" -ForegroundColor Yellow
}

function Guest-Service {
    $domain = $env:USERDOMAIN
    $username = "$domain\Guest"
    $password = Read-Host -AsSecureString "Enter the password for the $username account"
    $passwordPlainText = [System.Net.NetworkCredential]::new('', $password).Password
    $serviceName = Read-Host "Enter the service name to manage"
    $service = Get-WmiObject -Class Win32_Service -Filter "Name = '$serviceName'"

    if ($service) {
        $service.change($null, $null, $null, $null, $null, $null, $username, $passwordPlainText) > $null
        Restart-Service -Name $serviceName -Force

        Set-Service -Name $serviceName -StartupType Disabled
        Stop-Service -Name $serviceName -Force

        Write-Host "$serviceName has been restarted and disabled using the Guest account."
    } else {
        Write-Host "Service $serviceName not found."
    }
}

function Phase2 {
    Write-Output "Starting Phase 2!"
    Read-Host -Prompt "Stopping services: WebClient, Spooler, WinRM"
    Get-Service "WebClient" | Stop-Service
    Get-Service "Spooler" | Stop-Service
    Get-Service "WinRM" | Stop-Service
    Read-Host -Prompt "Press enter to start Defender services"
    Get-Service "WinDefend" | Start-Service
    Get-Service "WdNisSvc" | Start-Service
    Get-Service "MdCoreSvc" | Start-Service
    Get-Service "SecurityHealthService" | Start-Service
    Get-Service "Sense" | Start-Service
    Write-Output "Current Exclusions: (Path = Folder & File, Extension = File type, Process = Process Binary"
    Get-MpPreference | Select-Object -ExpandProperty ExclusionPath,ExclusionProcess,ExclusionExtension
    $answer = Read-Host -Prompt "Do you want to remove exclusions? yes/no"
    if ($answer -eq "yes")
    {
        foreach ($i in (Get-MpPreference).ExclusionPath) {
            Remove-MpPreference -ExclusionPath $i
            Write-Host($i)
        }
        foreach ($i in (Get-MpPreference).ExclusionProcess) {
            Remove-MpPreference -ExclusionProcess $i
            Write-Host($i)
        }
        foreach ($i in (Get-MpPreference).ExclusionExtension) {
            Remove-MpPreference -ExclusionExtension $i
            Write-Host($i)
        }
    }
    
    Read-Host -Prompt "Press enter to harden Defender (SampleSubmission, Enable protections, run Defender protection threats update)"
    Set-MpPreference -SubmitSamplesConsent SendAllSamples
    Set-MpPreference -MAPSReporting Advanced
    Set-MpPreference -DisableIOAVProtection 0
    Set-MpPreference -DisableRealtimeMonitoring 0
    Set-MpPreference -DisableBehaviorMonitoring 0
    Set-MpPreference -DisableScriptScanning 0
    Set-MpPreference -DisableArchiveScanning 0
    Set-MpPreference -PUAProtection 1
    Set-MpPreference -EnableControlledFolderAccess Enabled
    Add-MpPreference -ControlledFolderAccessProtectedFolders "C:\inetpub"
    Add-MpPreference -ControlledFolderAccessProtectedFolders "C:\Users\Public\"
    Add-MpPreference -ControlledFolderAccessProtectedFolders "C:\Windows\System32\CodeIntegrity\"

    Read-Host -Prompt "Press enter to add ASR rules & restart Defender"
    Add-MpPreference -AttackSurfaceReductionRules_Ids 56a863a9-875e-4185-98a7-b882c64b5ce5 -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids 7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids D4F940AB-401B-4EfC-AADCAD5F3C50688A -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids 9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2 -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550 -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids 01443614-CD74-433A-B99E2ECDC07BFC25 -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids 5BEB7EFE-FD9A-4556801D275E5FFC04CC -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids D3E037E1-3EB8-44C8-A917-57927947596D -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids 3B576869-A4EC-4529-8536-B80A7769E899 -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids 75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84 -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids 26190899-1602-49e8-8b27-eb1d0a1ce869 -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids e6db77e5-3df2-4cf1-b95a-636979351e5b -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids D1E49AAC-8F56-4280-B9BA993A6D77406C -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids 33ddedf1-c6e0-47cb-833e-de6133960387 -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids B2B3F03D-6A65-4F7B-A9C7-1C7EF74A9BA4 -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids c0033c00-d16d-4114-a5a0-dc9b3a7d2ceb -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids a8f5898e-1dc8-49a9-9878-85004b8a61e6 -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids 92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B -AttackSurfaceReductionRules_Actions Enabled
    Add-MpPreference -AttackSurfaceReductionRules_Ids C1DB55AB-C21A-4637-BB3FA12568109D35 -AttackSurfaceReductionRules_Actions Enabled
    Update-MpSignature -AsJob

    Read-Host -Prompt "Press enter to enable LSA protections"
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPLBoot" -Value 1

    Write-Host "[!] Finished Phase2!!`n" -ForegroundColor Green
    Write-Host "Things to do:`n* Run 'svcstuff'`n* Begin firewall rules!" -ForegroundColor Yellow
}

function Generate-WDAC {
    param([switch] $Refresh)

    $PolicyPath=$env:userprofile+"\Desktop\"
    $PolicyName="Policy"
    $Policy=$PolicyPath+$PolicyName+".xml"
    $DriversPolicy=$PolicyPath+"drivers.xml"
    $IISPolicy=$PolicyPath+"inetsrv.xml"
    $pf64Policy=$PolicyPath+"pf64.xml"
    $pf32Policy=$PolicyPath+"pf32.xml"
    $pdPolicy=$PolicyPath+"pd.xml"
    $toolsPolicy=$PolicyPath+"tools.xml"
    $DefaultWindowsPolicy=$env:windir+"\schemas\CodeIntegrity\ExamplePolicies\DefaultWindows_Audit.xml"
    New-Item $Policy -Force > $null

    if (Test-Path "C:\Program Files\Microsoft\Exchange Server\") {
        Write-Host "[!] Detected an Exchange server! Policy creation for this type of server will result in issues" -ForegroundColor Red
        return
    }

    Write-Host "[+] Generating policy..."
    $pf64 = Start-Job -ScriptBlock { param($pf64Policy) New-CIPolicy -FilePath $pf64Policy -Level FilePublisher -Fallback Hash,FileName -ScanPath "C:\Program Files\" -UserPEs -OmitPaths "C:\Program Files\WindowsApps\" } -ArgumentList $pf64Policy
    $pf32 = Start-Job -ScriptBlock { param($pf32Policy) New-CIPolicy -FilePath $pf32Policy -Level FilePublisher -Fallback Hash,FileName -ScanPath "C:\Program Files(x86)\" -UserPEs } -ArgumentList $pf32Policy
    $pd = Start-Job -ScriptBlock { param($pdPolicy) New-CIPolicy -FilePath $pdPolicy -Level FilePublisher -Fallback Hash,FileName -ScanPath "C:\ProgramData\" -UserPEs } -ArgumentList $pdPolicy
    $tools = Start-Job -ScriptBlock { param($toolsPolicy) New-CIPolicy -FilePath $toolsPolicy -Level FilePublisher -Fallback Hash -ScanPath "C:\Tools\" -UserPEs } -ArgumentList $toolsPolicy

    if ((Get-WindowsFeature Web-Server).InstallState -eq "Installed") {
        Write-Host "[!] Detected an IIS Server! Adjusting WDAC policy creation..." -ForegroundColor Yellow
        $iis = Start-Job -ScriptBlock { param($IISPolicy) New-CIPolicy -FilePath $IISPolicy -Level FilePublisher -Fallback Hash,Filename -ScanPath "C:\Windows\System32\inetsrv\" } -ArgumentList $IISPolicy
    }
    $drivers = Start-Job -ScriptBlock { param($DriversPolicy) New-CIPolicy -FilePath $DriversPolicy -Level SignedVersion -Fallback FilePublisher,Hash -ScanPath "C:\Windows\System32\drivers\" } -ArgumentList $DriversPolicy
    
    Wait-Job $pf64,$pf32,$pd,$drivers,$tools
    if ($iis) { Wait-Job $iis ; Remove-Job $iis }
    Remove-Job $pf64,$pf32,$pd,$drivers,$tools
    $additional_blocks = New-CIPolicyRule -Level Hash -Fallback FileName -DriverFilePath C:\Windows\System32\vssadmin.exe -Deny
    $additional_blocks += New-CIPolicyRule -Level Hash -Fallback FileName -DriverFilePath C:\Windows\System32\vssuirun.exe -Deny
    $additional_blocks += New-CIPolicyRule -Level Hash -Fallback FileName -DriverFilePath C:\Windows\System32\ntdsutil.exe -Deny
    $additional_blocks += New-CIPolicyRule -Level Hash -Fallback FileName -DriverFilePath C:\Windows\System32\reg.exe -Deny
    Write-Host "[+] Generated policies!" -ForegroundColor Green
    
    Write-Host "[+] Merging policies..."
    Merge-CIPolicy -OutputFilePath $Policy -PolicyPaths $DefaultWindowsPolicy,$pf32Policy,$pf64Policy,$pdPolicy,$DriversPolicy,$toolsPolicy > $null
    Merge-CIPolicy -OutputFilePath $Policy -PolicyPaths $Policy -Rules $additional_blocks > $null
    if ($iis) { Merge-CIPolicy -OutputFilePath $Policy -PolicyPaths $Policy,$IISPolicy > $null }
    Write-Host "[+] Merged policies"
    
    Set-CIPolicyIdInfo -FilePath $Policy -PolicyName $PolicyName
    Set-CIPolicyVersion -FilePath $Policy -Version "1.0.0.0"
    Set-RuleOption -FilePath $Policy -Option 3 -Delete
    Set-RuleOption -FilePath $Policy -Option 6
    Set-RuleOption -FilePath $Policy -Option 9
    Set-RuleOption -FilePath $Policy -Option 10
    Set-RuleOption -FilePath $Policy -Option 11
    Set-RuleOption -FilePath $Policy -Option 12
    Set-RuleOption -FilePath $Policy -Option 14
    Set-RuleOption -FilePath $Policy -Option 16
    Set-RuleOption -FilePath $Policy -Option 19
    Write-Host "[+] Added configuration rules to policy!"

    $PolicyBin = $PolicyPath+"SiPolicy.p7b"
    ConvertFrom-CIPolicy -XmlFilePath $Policy -BinaryFilePath $PolicyBin > $null
    Write-Host "[+] Generated policy at $PolicyBin"

    if ($Refresh) {
        Write-Host "[+] Refreshing policy..."
        try {
            copy $PolicyBin "C:\Windows\System32\CodeIntegrity\"
            Write-Host "[+] Moved policy!"
            Invoke-CimMethod -Namespace root\Microsoft\Windows\CI -ClassName PS_UpdateAndCompareCIPolicy -MethodName Update -Arguments @{FilePath = "C:\Windows\System32\CodeIntegrity\SiPolicy.p7b"} > $null
            Write-Host "[+] Refreshed policy!" -ForegroundColor Green
        } catch {
            Write-Host "[!] Failed to copy policy! Is controlled folder access on?" -ForegroundColor Red
        }
    }
    Write-Host "[+] Exiting..."
}

function Refresh-WDAC {
    Invoke-CimMethod -Namespace root\Microsoft\Windows\CI -ClassName PS_UpdateAndCompareCIPolicy -MethodName Update -Arguments @{FilePath = "C:\Windows\System32\CodeIntegrity\SiPolicy.p7b"}
}

function Get-GroupMembersRecursive {
    param (
        [string]$GroupName
    )

    $GroupMembers = Get-ADGroupMember -Identity $GroupName -Recursive | Where-Object { $_.objectClass -eq "user" }
    return $GroupMembers
}

Function Add-UsersToGroup {
    param (
        [string]$Source,
        [string]$Destination
    )
    $Users = Get-GroupMembersRecursive -GroupName $Source
    foreach ($User in $Users) {
        try {
            Add-ADGroupMember -Identity $Destination -Members $User
            Write-Host "[+] Added user $User to $Destination" -ForegroundColor Green
        } catch {
            Write-Host "[-] Skill issue for user $User" -ForegroundColor Red
        }
        
    }
}

Function Group-Passwords {
    param(
        $Group,
        $PasswordFile,
        $OutputCSV
    )
    $GroupUsers = Get-GroupMembersRecursive -GroupName $Group | Where-Object { $_.SamAccountName -ne $ExcludeUser }
    $Passwords = Get-Content -Path $PasswordFile

    if ($Passwords.Count -lt $GroupUsers.Count) {
        Write-Host "Error: Not enough passwords in the file!" -ForegroundColor Red
        exit
    }

    $Results = @()

    for ($i = 0; $i -lt $GroupUsers.Count; $i++) {
        $User = $GroupUsers[$i]
        $NewPassword = ConvertTo-SecureString -String $Passwords[$i] -AsPlainText -Force

        try {
            Set-ADAccountPassword -Identity $User.SamAccountName -NewPassword $NewPassword -Reset
            $Results += [PSCustomObject]@{
                Username = $User.SamAccountName
                NewPassword = $Passwords[$i]
            }
            Write-Host "Password changed for: $($User.SamAccountName)" -ForegroundColor Green
        } catch {
            Write-Host "Failed to change password for: $($User.SamAccountName) - $_" -ForegroundColor Red
        }
    }

    $Results | Export-Csv -Path $OutputCSV -NoTypeInformation
    Write-Host "Password changes completed. Output saved to $OutputCSV" -ForegroundColor Cyan
}