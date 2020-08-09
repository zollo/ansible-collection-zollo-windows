#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        state = @{ type = "str"; choices = @("absent", "present"); default = "present" }
        name = @{ type = "str"; required = $true }
        protected = @{ type = "bool"; }
        path = @{ type = "str"; required = $true }
        recursive = @{ type = "bool"; default = $false }
        properties = @{
            type = "dict";
            options = @{
                managed_by = @{ type = "str"; }
                display_name = @{ type = "str"; }
                description = @{ type = "str"; }
                state = @{ type = "str"; }
                city = @{ type = "str"; }
                street_address = @{ type = "str"; }
                postal_code = @{ type = "int"; }
                country = @{ type = "str"; }
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

Function Compare-OuObject {
    Param(
        [PSObject]$Original,
        [PSObject]$Updated
    )

    if ($Original -eq $false) { return $false }
    $props = @('Name', 'ObjectGUID', 'ProtectedFromAccidentalDeletion',
                'DistinguishedName', 'ManagedBy', 'City', 'Country',
                'Name', 'State', 'PostalCode', 'StreetAddress')
    $x = Compare-Object $Original $Updated -Property $props
    $x.Count -eq 0
}

Function Get-OuObject {
    Param([PSObject]$Object)
    $parms = @{
        distinguished_name = $Object.DistinguishedName.toString()
        protected = $Object.ProtectedFromAccidentalDeletion
    }

    $parms.properties = @{}
    if ($Object.Created) { $parms.created = $Object.Created.toString() }
    if ($Object.ObjectGUID) { $parms.guid = $Object.ObjectGUID.toString() }
    if ($Object.Name) { $parms.name = $Object.Name }
    if ($Object.Modified) { $parms.modified = $Object.Modified.toString() }
    if ($Object.ManagedBy) { $parms.properties.managed_by = $Object.ManagedBy }
    if ($Object.City) { $parms.properties.city = $Object.City }
    if ($Object.Country) { $parms.properties.country = $Object.Country }
    if ($Object.Name) { $parms.properties.name = $Object.Name }
    if ($Object.PostalCode) { $parms.properties.postal_code = $Object.PostalCode }
    if ($Object.State) { $parms.properties.state = $Object.State }
    if ($Object.StreetAddress) { $parms.properties.street_address = $Object.StreetAddress }
    return $parms | Sort-Object
}

# attempt import of module
Try { Import-Module ActiveDirectory }
Catch { $module.FailJson("The ActiveDirectory module failed to load properly: $($_.Exception.Message)", $_) }

# determine current object state
Try {
    $current_ou = Get-ADOrganizationalUnit -Filter * -Properties * | Where-Object { 
        $_.DistinguishedName -eq "OU=$name,$path"
    }
    $module.Diff.before = Get-OuObject -Object $current_ou
    $module.Result.ou = $module.Diff.before
} Catch {
    $module.Diff.before = ""
    $current_ou = $false
}

if ($state -eq "present") {
    # parse inputs
    if ($protected) { $parms.ProtectedFromAccidentalDeletion = $protected }
    if ($properties.city) { $parms.City = $properties.city }
    if ($properties.description) { $parms.Description = $properties.description }
    if ($properties.display_name) { $parms.DisplayName = $properties.display_name }
    if ($properties.country) { $parms.Country = $properties.country }
    if ($properties.managed_by) { $parms.ManagedBy = $properties.managed_by }
    if ($properties.street_address) { $parms.StreetAddress = $properties.street_address }
    if ($properties.state) { $parms.State = $properties.state }

    # ou does not exist, create object
    if(-not $current_ou) {
        $parms.Name = $name
        $parms.Path = $path
        Try { New-ADOrganizationalUnit @parms -WhatIf:$check_mode }
        Catch { $module.FailJson("Failed to create organizational unit: $($_.Exception.Message)") }
    }

    # ou exists, update object
    if ($current_ou) {
        Try { Set-ADOrganizationalUnit -Identity "OU=$name,$path" @parms -WhatIf:$check_mode }
        Catch {
            $module.Result.debug = $parms
            $module.FailJson("Failed to update organizational unit: $($_.Exception.Message)") }
    }
}

if ($state -eq "absent") {
    # ou exists, delete object
    if ($current_ou -and -not $check_mode) {
        Try {
            # override protected from accidental deletion
            Set-ADOrganizationalUnit -Identity "OU=$name,$path" -ProtectedFromAccidentalDeletion $false -Confirm:$False -WhatIf:$check_mode
            # check recursive deletion
            if ($recursive) { Remove-ADOrganizationalUnit -Identity "OU=$name,$path" -Confirm:$False -WhatIf:$check_mode -Recursive }
            else { Remove-ADOrganizationalUnit -Identity "OU=$name,$path" -Confirm:$False -WhatIf:$check_mode }
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
    $new_ou = Get-ADOrganizationalUnit -Filter * -Properties * | Where-Object { 
        $_.DistinguishedName -eq "OU=$name,$path"
    }
    $new_ou_obj = Get-OuObject $new_ou
    # compare the two objects
    Try {
        if (-not (Compare-OuObject -Original $current_ou -Updated $new_ou)) {
            $module.Result.changed = $true
            $module.Result.zone = Get-OuObject -Object $new_ou
            $module.Diff.after = Get-OuObject -Object $new_ou
        }
    } Catch {
        $module.FailJson("Failed to compare objects: $($_.Exception.Message)", $_)
    }

    # simulate changes if check mode
    if ($check_mode) {
        $new_ou = @{}
        $current_ou.PSObject.Properties | ForEach-Object {
            if($parms[$_.Name]) {
                $new_ou[$_.Name] = $parms[$_.Name]
            } else {
                $new_ou[$_.Name] = $_.Value
            }
        }
        $module.Diff.after = Get-OuObject -Object $new_ou
    }
} Catch {
    $module.FailJson("Failed to lookup new OU: $($_.Exception.Message)", $_)
}

$module.ExitJson()