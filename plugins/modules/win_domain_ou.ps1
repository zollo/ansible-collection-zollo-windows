#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str" }
        protected = @{ type = "bool";  }
        path = @{ type = "str" }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$name = $module.Params.name
$protected = $module.Params.protected
$path = $module.Params.path
$state = $module.Params.state

$parms = @{}

Function Get-AdOuObject {
    Param(
        [PSObject]$Original
    )

    return @{
        
    }
}

# attempt import of module
Try { Import-Module ActiveDirectory }
Catch { $module.FailJson("The ActiveDirectory module failed to load properly: $($_.Exception.Message)", $_) }

# 
Try { $current_ou = "" }
Catch { $module.FailJson("The ActiveDirectory module failed to load properly: $($_.Exception.Message)", $_) }

# state present
if ($state -eq "present") {

}

# state absent
if ($state -eq "absent") {

}

# Remove-ADOrganizationalUnit -Identity "OU=Accounting,DC=FABRIKAM,DC=COM" -Recursive

$module.ExitJson()