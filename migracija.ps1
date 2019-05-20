$DNS = Read-Host "Iveskite DNS adresa"
$DNS2 = Read-Host "Iveskite atsargini DNS adresa"
$Domain = Read-Host "Iveskite domain varda"


# SID gavimas #
function Get-SID([string]$User){
$userobject = New-Object System.Security.Principal.NTAccount($User)
$SID = $userobject.Translate([System.Security.Principal.SecurityIdentifier])
$SID.Value
}
# DNS nustatymas #
$Netinfo=Get-WmiObject Win32_NetworkAdapterConfiguration -filter "ipenabled=true" 
 
$Netinfo | foreach { 
If(!$_.DNSServerSearchOrder) 
    { 
    Write-Host -Fore Yellow "DNS adresas yra tuscias siame $($_.Description) adapteryje." 
    $Correct_DNS_Settings = Read-Host "Ar norite nustatyti DNS adresa siam adapteriui (y/n)?" 
    while($Correct_DNS_Settings -ne 'y' -AND $Correct_DNS_Settings -ne 'n') 
        { 
        Write-Host "Iveskite 'y' arba 'n'." 
        $Correct_DNS_Settings = Read-Host "Ar norite nustatyti DNS adresa siam adapteriui(y/n)?" 
        } 
    If ($Correct_DNS_Settings -eq 'y') 
        { 
        $DNS_Change_Result = $_.SetDNSServerSearchOrder($(If($DNS -AND $DNS2){$DNS,$DNS2} elseif($DNS){$DNS} else{$DNS2})) 
        If (!$DNS_Change_Result.ReturnValue) 
        { 
        Write-Host -Fore Cyan "DNS adresas adapteryje $($_.Description) buvo pakeistas i $DNS $(if($DNS2){"ir $DNS2"})" 
        } 
        else 
        { 
        Write-Host -Fore Red "Neiseina pakeisti DNS adreso siam adapteriui $($_.Description). Isitikinkite, kad Powershell yra paleistas su administratoriaus teisemis" 
        Exit; 
        } 
        } 
    } 
elseif( $Dns1 -contains $_.DNSServerSearchOrder[0] -AND $DNS2 -contains $_.DNSServerSearchOrder[1]  ) 
    { 
    Write-Host "DNS adresas siam adapteriui $($_.Description) yra teisingas." 
    } 
else 
    { 
    Write-Host -Fore Red "DNS adresas siam adapteriui $($_.Description) yra neteisingas." 
    $Correct_DNS_Settings = Read-Host "Ar norite nustatyti DNS adresa siam adapteriui (y/n)?" 
        while($Correct_DNS_Settings -ne 'y' -AND $Correct_DNS_Settings -ne 'n') 
        { 
        Write-Host "Iveskite 'y' arba 'n'." 
        $Correct_DNS_Settings = Read-Host "Ar norite nustatyti DNS adresa siam adapteriui (y/n)?" 
        } 
    If ($Correct_DNS_Settings -eq 'y') 
        { 
        $DNS_Change_Result = $_.SetDNSServerSearchOrder($($DNS,$DNS2)) 
        If (!$DNS_Change_Result.ReturnValue) 
        { 
        Write-Host -Fore Cyan "DNS adresas adapteryje $($_.Description) buvo pakeistas $DNS $(if($DNS2){"ir $DNS2"})" 
        } 
        else 
        { 
        Write-Host -Fore Red "Neiseina pakeisti adreso siam adapteriui $($_.Description). Isitikinkite, kad Powershell yra paleistas su administratoriaus teisemis" 
        Exit; 
        } 
        } 
    } 
} 
# Klausia ar tikrai norite prisijungti i domena #
$Domainjoin = Read-Host "Ar norite testi prisijungima i domena (y/n)?"
while ($Domainjoin -ne 'y' -and $Domainjoin -ne 'n')
{
Write-Host "Iveskite 'y' arba 'n' "
$Domainjoin = Read-Host "Ar norite testi prisijungima i domena (y/n)?"
}
# Jei pasirenkame jungtis i domena #
if ($Domainjoin -eq 'y'){
$username = Read-Host "Iveskite domeno vartotojo varda"
$password = Read-Host -AsSecureString "Iveskite domeno vartotojo slaptazodi"
$credential = New-Object System.Management.Automation.PSCredential($username,$password)
# Jei slaptazodi nera tuscias, vykdyti toliau #
if ($credential.GetNetworkCredential().Password){
$newuser = $credential.GetNetworkCredential().UserName
$newSPN_Name = $newuser+'@'+$Domain
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $newSPN_Name, $credential.Password
Write-Host -ForegroundColor Cyan "Jungiamasi i domena. Prasome palaukti..."
# Jungiames i domena #
Try 
    { 
    $DomainJoinResult=Add-Computer -DomainName $Domain -Credential $Cred -PassThru -EA Stop -WarningAction SilentlyContinue 
    Start-Sleep 1;              
    } 
catch 
    { 
    Write-Host -Fore Red "Neiseina prisijungti i domena. Tai gali buti del:" 
    Write-Host -Fore Red "1) Blogas vartotojo vardas arba slaptazodis." 
    Write-Host -Fore Red "2) Powershell console yra paleista be administratoriaus teisiu." 
    } 
} 
else 
{ 
Write-Host -Fore Red "Jus neivedete slaptazodzio." 
} 
# Jei pavyko prisijungti i domena, testi toliau #
If ($DomainJoinResult.HasSucceeded) 
{ 
Write-Host -Fore Green "Kompiuteris sekmingai prijungtas i domena." 
# dabartinio bei naujo vartotojo SID gavimas #
$CurrentUser = [Environment]::UserName 
$CurrentUserSID= Get-SID $CurrentUser 
$NewUserSID= Get-SID $newSPN_Name 
 
# Paklausti ar vartotojas tikrai nori migruoti savo lokaju vartotoj #
$Migrate_Profile = Read-Host "`nAr tikrai norite migruoti vartotojo $CurrentUser`'s profili i naujaji `'$NewSPN_Name`' vartotoja.(y/n)?" 
while($Migrate_Profile -ne 'y' -AND $Migrate_Profile -ne 'n') 
{ 
Write-Host "Iveskite 'y' arba 'n'." 
$Migrate_Profile = Read-Host "Ar tikrai norite migruoti vartotojo $CurrentUser`'s profili i naujaji $NewSPN_Name vartotoja.(y/n)?" 
} 
 
If ($Migrate_Profile -eq 'y') 
{ 
##################### Assign full permission of Current User's home directory to new user ################ 
$Acl = (Get-Item $home).GetAccessControl('Access') 
$Ar = New-Object system.security.accesscontrol.filesystemaccessrule($newSPN_Name,"FullControl","ContainerInherit,ObjectInherit","None","Allow") 
$Acl.SetAccessRule($Ar) 
$Acl | Set-Acl -Path $home 
 
###################### Backup current user's SID to file in home directory(comment below 2 lines if not needed)################# 
Write-Host "$CurrentUser`'s SID $CurrentUserSID buvo issaugotas $home\UserSID.txt." 
Set-Content $home\UserSID.txt "SID of $CurrentUser `r`n$CurrentUserSID`r`n`r`nSID of $newSPN_Name SID `r`n$NewUserSID" 
 
####################### If AD Join is OK, then change registry of current user SID to new user SID ############## 
Rename-Item "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\$CurrentUserSID" -NewName $NewUserSID 
 
####################### Change Security Permission of Current User's SID Profile and Profile's SID_Classes key registry ############### 
$Acl = Get-Acl "Registry::HKU\$CurrentUserSID" 
$rule = New-Object System.Security.AccessControl.RegistryAccessRule ($newSPN_Name,"FullControl","ContainerInherit,ObjectInherit","None","Allow") 
$Acl.SetAccessRule($rule) 
$Acl |Set-Acl -Path "Registry::HKU\$CurrentUserSID" 
 
$Acl = Get-Acl "Registry::HKU\$($CurrentUserSID)_Classes" 
$rule = New-Object System.Security.AccessControl.RegistryAccessRule ($newSPN_Name,"FullControl","ContainerInherit,ObjectInherit","None","Allow") 
$Acl.SetAccessRule($rule) 
$Acl |Set-Acl -Path "Registry::HKU\$($CurrentUserSID)_Classes" 
Write-Host -Fore Green "Dabartinio vartotojo $CurrentUser`'s buvo migruotas i nauja profili $newSPN_Name." 
} 
####################### Prompt the user to restart the computer ############################ 
$Restart=Read-Host "`nAr norite perkrauti kompiuteri ir prisijungti i naujaji vartotoja ($newSPN_Name)? (y/n)" 
If ($Restart -eq 'y') 
{ Restart-Computer -Force } 
} 
} 

