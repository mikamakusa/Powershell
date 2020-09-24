$Domain = ''
$Password = ''
$Login = ''
$UserName = ($Domain.split(".")[0])+"\"+$Login
$ADServerIP = ''
$filestore_ip = ''
$CollectionName = ''

if (!(Test-Path Z:)) {
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default" -Name "AnonymousUid" -Value "0" -PropertyType DWORD
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default" -Name "AnonymousGid" -Value "0" -PropertyType DWORD
    nfsadmin client stop
    nfsadmin client start
    cmd.exe /c "mount "+$filestore_ip+":/mnt z:"
}

if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain == false) {
    $joinCred = New-Object pscredential -ArgumentList ([pscustomobject]@{
        UserName = $UserName
        Password = (ConvertTo-SecureString -String $Password -AsPlainText -Force)[0]
    })
    Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses $ADServerIP
    Add-Computer -Domain $Domain -Credential $joinCred -Restart -Force -EA Stop
} 

if ($env:computername -match "rd-worker") {
    if (!(Get-WindowsFeature "RDS-RD-Server").installed) {
        Import-Module RemoteDesktop
        Install-WindowsFeature RDS-RD-SERVER
    } else {
        New-Item -Name "$env:computername.txt" -Path Z:\Hostlist\ -ItemType "file"
    }
} else {
    if (!(Get-WindowsFeature "RDS-Connection-Broker").installed) {
        Import-Module RemoteDesktop
        Install-WindowsFeature RDS-RD-Server, RDS-Connection-Broker, RDS-Gateway, RDS-Web-Access 
    } else {
        New-RDSessionDeployment -ConnectionBroker $env:computername.$Domain -SessionHost $env:computername.$Domain -WebAccessServer $env:computername.$Domain
        New-RDSessionCollection -CollectionName $CollectionName -ConnectionBroker $env:computername -SessionHost $env:computername
        Set-RDSessionCollectionConfiguration -CollectionName $CollectionName -TemporaryFoldersPerSession $false -TemporaryFoldersDeletedOnExit $false -DisconnectedSessionLimitMin 360 -IdleSessionLimitMin 120
        foreach ($item in (Get-ChildItem -Path Z:\Hostlist\)) {
            Add-RDSessionHost -SessionHost $item.$Domain -ConnectionBroker $env:computername.$Domain
        }
        $hosts = Get-ChildItem -Path Z:\Hostlist
        $LoadBalanceObjectsArray = New-Object System.Collections.Generic.List[Microsoft.RemoteDesktopServices.Management.RDSessionHostCollectionLoadBalancingInstance]
        for ($i = 0; $i -lt $hosts.Count; $i++) {
            $LoadBalanceSessionHost[$i] = New-Object Microsoft.RemoteDesktopServices.Management.RDSessionHostCollectionLoadBalancingInstance( $CollectionName, 50, 200, $hosts[$i] )
            $LoadBalanceObjectsArray.Add($LoadBalanceSessionHost[$i])
        }
        Set-RDSessionCollectionConfiguration -CollectionName $CollectionName -LoadBalancing $LoadBalanceObjectsArray -ConnectionBroker $env:computername
    }
}