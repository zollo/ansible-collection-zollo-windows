#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        state = @{ type = "str"; choices = "all", "scope", "reservation", "lease"; default = "present" }
        name = @{ type = "str" }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$parms = @{}

$state = $module.Params.state
$name = $module.Params.name

# ensure winget binary is installed
Try { $w = winget -info }
Catch { $module.FailJson("The winget binary is not installed: $($_.Exception.Message)", $_) }

# state: present/latest
if($state -eq 'present' -or $state -eq 'latest') {

}

# state: absent
if($state -eq 'absent') {

}

Start-Process -FilePath "winget install $x" -Verb RunAs

$module.ExitJson()