$Password = (ConvertTo-SecureString -String "" -AsPlainText -Force)
$DomainNameDNS = ""
$DomainNameNetbios = ""
$DomainMode = "WinThreshold"
$ForestConfiguration = @{
  '-DatabasePath'= 'C:\Windows\NTDS';
  '-DomainMode' = $DomainMode;
  '-DomainName' = $DomainNameDNS;
  '-DomainNetbiosName' = $DomainNameNetbios;
  '-ForestMode' = $DomainMode;
  '-InstallDns' = $true;
  '-LogPath' = 'C:\Windows\NTDS';
  '-NoRebootOnCompletion' = $false;
  '-SysvolPath' = 'C:\Windows\SYSVOL';
  '-Force' = $true;
  '-SafeModeAdministratorPassword' = $Password;
  '-CreateDnsDelegation' = $false }

Set-LocalUser -Name "Administrator" -Password $Password | Enable-LocalUser

Import-Module RemoteDesktop
Add-WindowsFeature -Name RSAT-AD-Tools -IncludeManagementTools -IncludeAllSubFeature
Add-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -IncludeAllSubFeature
Add-WindowsFeature -Name DNS -IncludeManagementTools -IncludeAllSubFeature
Add-WindowsFeature -Name NFS-Client

# Promote AD
Import-Module ADDSDeployment
Install-ADDSForest @ForestConfiguration
