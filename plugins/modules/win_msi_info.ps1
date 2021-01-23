#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        path = @{ type = "str"; required = $true }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$parms = @{}

$path = $module.Params.path
$module.Result.properties = {}

$win_installer_obj = New-Object -com WindowsInstaller.Installer

Try {
    [IO.FileInfo[]]$path_object = $path
    $msi_db = $win_installer_obj.GetType().InvokeMember("OpenDatabase","InvokeMethod",$Null,$win_installer_obj,@($path_object.FullName, 0))
    $open_view = $msi_db.GetType().InvokeMember("OpenView","InvokeMethod",$Null,$msi_db,("SELECT * FROM Property"))
    $open_view.GetType().InvokeMember("Execute","InvokeMethod",$Null,$open_view,$Null)
    $fetch_record = $open_view.GetType().InvokeMember("Fetch","InvokeMethod",$Null,$open_view,$Null)

    while ($fetch_record -ne $null) {
        # generate key value from property value
        $k = $fetch_record.GetType().InvokeMember("StringData", "GetProperty", $Null, $fetch_record, 1)
        # populate value and append to hash table
        $module.Result.properties[$k] = $fetch_record.GetType().InvokeMember("StringData", "GetProperty", $Null, $fetch_record, 2)
        $fetch_record = $open_view.GetType().InvokeMember("Fetch","InvokeMethod",$Null,$open_view,$Null)
    }
}
Catch {
    $module.FailJson("Unable to query MSI database: $($_.Exception.Message)", $_)
}

$module.ExitJson()