<#
.Synopsis
 Backs up registry key for the user's profile and renames the profile folder so that the corrupt
 profile can be recreated
.Example
 . recreate-profile.ps1
.Notes
 This script is intended to be run by double-clicking on recreate-profile.bat. the script will
 prompt for the domain name and user name of the target profile. Make sure that the user has not
 logged in since the machine was last booted, and run using an administrator account.
 AUTHOR: O'Ryan Hedrick
 LASTEDIT: 8/6/2015, more comments added 9/13/2018
 VERSION: 1
 KEYWORDS: Windows 7, corrupt profile
#>
[CmdletBinding()]
param()
Set-Variable -Name domain -Description "Domain the user account resides in" -value "5s38ct1"
set-variable -name username -Description "Username of the profile to be recreated" -value "administrator"
set-variable -Name sid -Description "User's SID"
Set-Variable -Name sidkey -Description "User's registry key"
Set-Variable -Name profilepath -Description "User's profile directory"
Set-Variable -Name i -Description "Incrementor" -Value 1
Set-Variable -Name oldpath -Description "Path used for the original profile folder"
function get-sidfromuser
{
<#
.Synopsis
 Finds a SID for a username
.Example
 get-sidfromuser -user bq6767 -domain DUPONTNET
.Notes
 NAME:
 AUTHOR: O'Ryan Hedrick
 LASTEDIT: 7/28/2015
 VERSION: 1
 KEYWORDS: SID, user account, profile
 LINK:
#>
[cmdletbinding()]
param(
    [string]
    $domain,
    [string]
    $user,
    [string]
    $sid
    ) #end param
$ntaccount = New-Object System.Security.Principal.NTAccount($domain,$user)
$ntaccount = $ntaccount.Translate([System.Security.Principal.SecurityIdentifier])
($local:ntaccount).value
} # end get-sidfromuser

#collect information from operator
$domain = Read-Host "Enter domain of user"
$username = Read-Host "Enter username"
write-verbose "USER: $domain\$username"

#find the SID of the targeted user account
$sid = get-sidfromuser -domain $domain -user $username
write-debug "SID: $sid"
#store location of profile key in $sidkey variable
$sidkey = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
write-debug "PROFILE REGISTRY KEY: $sidkey"
#pull user's profile directory from the registry key
$profilepath = (get-itemproperty -Path registry::$sidkey -name profileimagepath).profileimagepath
write-debug "PROFILE PATH: $profilepath"


#backup user profile key
if (test-path registry::$sidkey){
    $exportfile = "c:\users\$username" + ".reg"
    regedit /e $exportfile $sidkey
    write-verbose "$sidkey exported to $exportfile"
    } # end if

#set what the profile directory will be renamed to
$oldpath = $profilepath + ".old"
write-debug "OLDPATH: $oldpath"

#If the profile directory specified by the registry key exists, and there isn't
#already a backup folder, rename the folder to create the backup.
#If there is any issue, error out so the technician can examine the issue. I
#recommend starting with a reboot.
if ((test-path $profilepath) -and (!(test-path $oldpath))){
    try
    {
        rename-item -path $profilepath -NewName $oldpath -ErrorAction Stop
        write-verbose "$profilepath renamed to $oldpath"
    }
    catch {
        Write-host "Error: $_"
        if ($_.tostring() -eq "The process cannot access the file because it is being used by another process.")
            {Write-host "Try restarting the computer, making sure to not log in as the target account."}
        break
    }
    } # end if
#If the registry key backup exists, remove the user's profile key from the registry
if (test-path $exportfile) {Remove-Item registry::$sidkey;Write-Verbose "Removed $sidkey from registry"}
