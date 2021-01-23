#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.CamelConversion

$spec = @{
  options = @{}
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

Try {
  $info = Get-ComputerInfo
  $info = Convert-DictToSnakeCase($info)
  $module.Result.info = @{}
} Catch {
  $module.FailJson("Failed to query computer information $($_.Exception.Message)", $_)
}

$module.ExitJson()