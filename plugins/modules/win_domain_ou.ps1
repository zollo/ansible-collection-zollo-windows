#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        state = @{ type = "str"; choices = @("absent", "present"); default = "present" }
        name = @{ type = "str"; required = $true }
        protected = @{ type = "bool"; default = $false }
        path = @{ type = "str" }
        domain_username = @{ type = "str" }
        domain_password = @{ type = "str" }
        domain_server = @{ type = "str" }
        managed_by = @{ type = "str"; }
        display_name = @{ type = "str"; }
        description = @{ type = "str"; }
        location = @{ 
            type = "dict"
            options = @{
                state = @{ type = "str" }
                city = @{ type = "str" }
                street_address = @{ type = "str" }
                postal_code = @{ type = "int" }
                country = @{ type = "str" }
            }
        }
        other_attributes = @{ type = "dict" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$state = $module.Params.state
$name = $module.Params.name
$protected = $module.Params.protected
$path = $module.Params.path
$domain_username = $module.Params.domain_username
$domain_password = $module.Params.domain_password
$domain_server  = $module.Params.domain_server
$managed_by = $module.Params.managed_by
$display_name = $module.Params.display_name
$description = $module.Params.description
$location = $module.Params.location
$other_attributes = $module.Params.other_attributes

$primary_props = @('Name', 'ObjectGUID', 'ProtectedFromAccidentalDeletion',
                    'DistinguishedName', 'ManagedBy', 'City', 'Country',
                    'Name', 'State', 'PostalCode', 'StreetAddress')

# map of props used for object comparison
$pmap = @{
    Created = 'created'; ObjectGUID = 'guid'; Name = 'name';
    Modified = 'modified'; ProtectedFromAccidentalDeletion = 'protected';
    DistinguishedName = 'distinguished_name'; ManagedBy = 'managed_by';
    StreetAddress = "location.street_address"; City = 'location.city';
    Country = 'location.country'; State = 'location.state';
    PostalCode = 'location.postal_code'
}

$x = @('Name', 'ObjectGUID', 'ProtectedFromAccidentalDeletion',
        'DistinguishedName', 'ManagedBy', 'City', 'Country',
        'Name', 'State', 'PostalCode', 'StreetAddress')

$parms = @{}

if($null -eq $path) {
    $path = (Get-ADDomain).DistinguishedName
}

if ($null -ne $domain_username) {
    $domain_password = ConvertTo-SecureString $domain_password -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $domain_username, $domain_password
    $parms.Credential = $credential
}

if ($null -ne $domain_server) {
    $parms.Server = $domain_server
}

Function Compare-OuObject {
    Param(
        [PSObject]$Original,
        [PSObject]$Updated
    )

    # loop over original
    $obj1.PSObject.Properties | foreach-object { if($obj1[$_.Name] -ne $obj2[$_.Name]){write-host "diff" }  }



    $Original.PSObject.Properties | ForEach-Object {
        if($_.Name)
    }

    if ($Original -eq $false) { return $false }

    $x = Compare-Object $Original $Updated
    $x.Count -eq 0
}

Function Get-ParsedAttributes {
    Param(
        [PSObject]$Original,
        [PSObject]$Updated
    )
}

Function Get-SimulatedOu {
    # generate a simulated OU based on the input object
    Param($Object)

    $parms = @{
        Name = $Object.name
        DistinguishedName = "OU=$($Object.name)," + $Object.path
        ProtectedFromAccidentalDeletion = $Object.protected
    }


    if ($Object.description) { $parms.Description = $Object.properties.description }
    if ($Object.location) {
        if ($Object.location.city) { $parms.City = $Object.location.city }
        if ($Object.location.state) { $parms.State = $Object.location.city }
        if ($Object.location.street_address) { $parms.StreetAddress = $Object.location.city }
        if ($Object.location.postal_code) { $parms.PostalCode = $Object.location.city }
        if ($Object.location.country) { $parms.Country = $Object.location.country }
    }
    if ($Object.properties.managed_by) { $parms.ManagedBy = $Object.properties.managed_by }

    # convert to psobject & return
    [PSCustomObject]$parms
}


Function Convert-StringToSnakeCase($string) {
    # cope with pluralized abbreaviations such as TargetGroupARNs
    if ($string -cmatch "[A-Z]{3,}s") {
        $replacement_string = $string -creplace $matches[0], "_$($matches[0].ToLower())"

        # handle when there was nothing before the plural pattern
        if ($replacement_string.StartsWith("_") -and -not $string.StartsWith("_")) {
            $replacement_string = $replacement_string.Substring(1)
        }
        $string = $replacement_string
    }
    $string = $string -creplace "(.)([A-Z][a-z]+)", '$1_$2'
    $string = $string -creplace "([a-z0-9])([A-Z])", '$1_$2'
    $string = $string.ToLower()

    return $string
}

# used by Convert-DictToSnakeCase to covert list entries from camelCase
# to snake_case
Function Convert-ListToSnakeCase($list) {
    $snake_list = [System.Collections.ArrayList]@()
    foreach ($value in $list) {
        if ($value -is [Hashtable]) {
            $new_value = Convert-DictToSnakeCase -dict $value
        } elseif ($value -is [Array] -or $value -is [System.Collections.ArrayList]) {
            $new_value = Convert-ListToSnakeCase -list $value
        } else {
            $new_value = $value
        }
        [void]$snake_list.Add($new_value)
    }

    return ,$snake_list
}

# converts a dict/hashtable keys from camelCase to snake_case
# this is to keep the return values consistent with the Ansible
# way of working.
Function Convert-DictToSnakeCase($dict) {
    $snake_dict = @{}
    foreach ($dict_entry in $dict.GetEnumerator()) {
        $key = $dict_entry.Key
        $snake_key = Convert-StringToSnakeCase -string $key

        $value = $dict_entry.Value
        if ($value -is [Hashtable]) {
            $snake_dict.$snake_key = Convert-DictToSnakeCase -dict $value
        } elseif ($value -is [Array] -or $value -is [System.Collections.ArrayList]) {
            $snake_dict.$snake_key = Convert-ListToSnakeCase -list $value
        } else {
            $snake_dict.$snake_key = $value
        }
    }

    return ,$snake_dict
}

Function Get-OuObject {
    Param([PSObject]$Object)
    $parms = @{}

    foreach ($i in $pmap.Keys) {
        if ($($Object.$i)) {
            $parms.$($pmap.Item($i)) = $($Object.$i)
        }
    }

    # populate ldap attributes

    $parms.location = @{}
    if ($Object.Created) { $parms.created = $Object.Created.toString() }
    if ($Object.ObjectGUID) { $parms.guid = $Object.ObjectGUID.toString() }
    if ($Object.Name) { $parms.name = $Object.Name }
    if ($Object.Modified) { $parms.modified = $Object.Modified.toString() }
    if ($Object.ManagedBy) { $parms.managed_by = $Object.ManagedBy }

    if ($Object.City) { $parms.location.city = $Object.City }
    if ($Object.Country) { $parms.location.country = $Object.Country }
    if ($Object.PostalCode) { $parms.location.postal_code = $Object.PostalCode }
    if ($Object.State) { $parms.location.state = $Object.State }
    if ($Object.StreetAddress) { $parms.location.street_address = $Object.StreetAddress }

    return $parms | Sort-Object
}

Function Get-OuAttributes {
    Param([PSObject]$original,[Hashtable]$attributes)
    $parms = @{}
    # loop over attributes in spec and compare to equivalent in the orig. object
    $attributes.Keys | foreach-object {
        # convert attributes to a string for comparison
        if(($original[$_] -join ' ') -ne ($attributes[$_] -join ' ')) {
            # attributes are not equal
            $parms[$_] = $attributes[$_]
        }

        if(($original[$_] -join ' ') -ne ($attributes[$_] -join ' ')) {
            # attributes are not equal
            $parms[$_] = $attributes[$_]
        }
    }

    # update attributes
    $original | Set-ADOrganizationalUnit -Add
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
    if ($description) { $parms.Description = $description }
    if ($display_name) { $parms.DisplayName = $display_name }
    if ($managed_by) { $parms.ManagedBy = $managed_by }
    if ($other_attributes) { $parms.OtherAttributes = $other_attributes }
    if ($location) {
        if ($location.postal_code) { $parms.PostalCode = $location.postal_code }
        if ($location.street_address) { $parms.StreetAddress = $properties.street_address }
        if ($location.state) { $parms.State = $location.state }
        if ($location.country) { $parms.Country = $properties.country }
        if ($location.city) { $parms.City = $properties.city }
    }

    if(-not $current_ou) { # ou does not exist, create object
        $parms.Name = $name
        $parms.Path = $path
        Try { New-ADOrganizationalUnit @parms -ProtectedFromAccidentalDeletion $protected -WhatIf:$check_mode }
        Catch { $module.FailJson("Failed to create organizational unit: $($_.Exception.Message)") }
    }

    if ($current_ou) { # ou exists, update object
        # compare object
        
        Try { Set-ADOrganizationalUnit -Identity "OU=$name,$path" @parms -WhatIf:$check_mode }
        Catch {
            $module.Result.debug = $parms
            $module.FailJson("Failed to update organizational unit: $($_.Exception.Message)",$_) }
    }
}

if ($state -eq "absent") {
    # ou exists, delete object
    if ($current_ou -and -not $check_mode) {
        Try {
            # override protected from accidental deletion
            Set-ADOrganizationalUnit -Identity "OU=$name,$path" -ProtectedFromAccidentalDeletion $false -Confirm:$False -WhatIf:$check_mode
            Remove-ADOrganizationalUnit -Identity "OU=$name,$path" -Confirm:$False -WhatIf:$check_mode -Recursive
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
    if (-not $check_mode) {
        $new_ou = Get-ADOrganizationalUnit -Filter * -Properties * | Where-Object {
            $_.DistinguishedName -eq "OU=$name,$path"
        }
        # compare old/new objects
        if (-not (Compare-OuObject -Original $current_ou -Updated $new_ou)) {
            $module.Result.changed = $true
            $module.Result.ou = Get-OuObject -Object $new_ou
            $module.Diff.after = Get-OuObject -Object $new_ou
        }
    }

    # simulate changes
    if ($check_mode -and $current_ou) {
        $new_ou = @{}
        $current_ou.PSObject.Properties | ForEach-Object {
            if ($parms[$_.Name]) { $new_ou[$_.Name] = $parms[$_.Name] }
            else { $new_ou[$_.Name] = $_.Value }
        }
        $module.Diff.after = Get-OuObject -Object $new_ou
    }

    # simulate new ou created
    if ($check_mode -and -not $current_ou) {
        $simulated_ou = Get-SimulatedOu -Object $parms
        $module.Diff.after = Get-OuObject -Object $simulated_ou
    }
} Catch {
    $module.FailJson("Failed to lookup new organizational unit: $($_.Exception.Message)", $_)
}

$module.ExitJson()