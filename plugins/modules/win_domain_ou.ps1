#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str" }
        protected = @{ type = "bool"; }
        path = @{ type = "str" }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
        properties = @{
            type = "dict"
            required = $false
            options = @{
                display_name = @{ type = "str"; required = $false }
                description = @{ type = "str"; required = $false }
                city = @{ type = "str"; required = $false }
                street_address = @{ type = "str"; required = $false }
                postal_code = @{ type = "str"; required = $false }
                country = @{ type = "str"; required = $false }
                managed_by = @{ type = "str"; required = $false }
            }
        }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$name = $module.Params.name
$protected = $module.Params.protected
$path = $module.Params.path
$state = $module.Params.state
$recursive = $module.Params.recursive
$properties = $module.Params.properties

$parms = @{}

Function Get-OUObject {
    Param([PSObject]$Object)
    $parms = @{
        name = $Object.Name
        guid = $Object.ObjectGUID.toString()
    }

    if($Object.ManagedBy) { $parms.managed_by = $Object.ManagedBy }
    if($Object.City) { $parms.city = $Object.City }
    if($Object.Country) { $parms.country = $Object.Country }
    if($Object.DistinguishedName) { $parms.distinguished_name = $Object.Country }
    if($Object.Name) { $parms.name = $Object.Name }
    if($Object.PostalCode) { $parms.postal_code = $Object.PostalCode }
    if($Object.State) { $parms.state = $Object.State }
    if($Object.StreetAddress) { $parms.street_address = $Object.StreetAddress }
    return $parms | Sort-Object
}

# attempt import of module
Try { Import-Module ActiveDirectory }
Catch { $module.FailJson("The ActiveDirectory module failed to load properly: $($_.Exception.Message)", $_) }
 
# find current ou
Try {
    $current_ou = Get-ADOrganizationalUnit -Identity "OU=$name,$path"
    $module.Diff.before = Get-OUObject -Object $current_ou
} Catch {
    $module.Diff.before = ""
    $current_ou = $false
}




if ($state -eq "present") {
    # ou doesn't exist already
    if(-not $current_ou) {
        New-ADOrganizationalUnit -Name "$name" -Path "OU=$name,$path" -ProtectedFromAccidentalDeletion $protected
    }

    # ou exists, update props
    if($current_ou) {

    }

}



if ($state -eq "absent") {
    # ou exists
    if ($current_ou -and -not $check_mode) {
        Try {
            Remove-ADOrganizationalUnit -Name $name -Force -Recursive -WhatIf:$check_mode
            $module.Result.changed = $true
            $module.Diff.after = ""
        } Catch {
            $module.FailJson("Failed to remove OU: $($_.Exception.Message)", $_)
        }
    }
    $module.ExitJson()
}

# determine if a change was made
Try {
    $new_zone = Get-DnsServerZone -Name $name
    if (-not (Compare-DnsZone -Original $current_zone -Updated $new_zone)) {
        $module.Result.changed = $true
        $module.Result.zone = Get-OUObject -Object $new_zone
        $module.Diff.after = Get-OUObject -Object $new_zone
    }

    # simulate changes if check mode
    if ($check_mode) {
        $new_zone = @{}
        $current_zone.PSObject.Properties | ForEach-Object {
            if($parms[$_.Name]) {
                $new_zone[$_.Name] = $parms[$_.Name]
            } else {
                $new_zone[$_.Name] = $_.Value
            }
        }
        $module.Diff.after = Get-OUObject -Object $new_zone
    }
} Catch {
    $module.FailJson("Failed to lookup new OU $($name): $($_.Exception.Message)", $_)
}

$module.ExitJson()