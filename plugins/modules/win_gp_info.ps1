#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.CamelConversion

# used by Convert-DictToSnakeCase to convert a string in camelCase
# format to snake_case
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


$spec = @{
    options = @{
        guid = @{ type = "str"; }
        name = @{ type = "str"; }
        domain = @{ type = "str"; }
        server = @{ type = "str"; }
    }
    supports_check_mode = $false
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode
$parms = @{}

$guid = $module.Params.guid
$name = $module.Params.name
$domain = $module.Params.domain
$server = $module.Params.server

# attempt import of module
Try { Import-Module GroupPolicy }
Catch { $module.FailJson("The GroupPolicy module failed to load properly: $($_.Exception.Message)", $_) }

Function Get-GpObject {
    Param([PSObject]$Object)
    $parms = @{}

}

if ($domain) { $parms.Domain = $domain }
if ($server) { $parms.Server = $server }

Try {
    # single object - retreive via guid or name
    if ($guid) { $gpo = Get-GPO @parms -Guid $guid }
    if ((-not $guid) -and $name) { $gpo = Get-GPO @parms -Name $name }
} Catch {
    $module.FailJson("Unable to retreive group policy objects: $($_.Exception.Message)", $_)
}

Try {
    # multi-object - retreive via 'all' param
    $gpo = Get-GPO @parms -All
}

$module.Result.gpo = Get-GpObject $gpo

