#!powershell

# Copyright: (c) 2021 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        site = @{ type = "str" }
        discover = @{ type = "bool"; default=$true }
        filter = @{ type = "str" }
        identity = @{ type = "str" }
        service = @{ type = "list"; }
        domain_name = @{type = "str" }
        domain_username = @{ type = "str" }
        domain_password = @{ type = "str" }
        domain_server = @{ type = "str" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$site = $module.Params.site
$discover = $module.Params.discover
$filter = $module.Params.filter
$identity = $module.Params.identity
$domain_username = $module.Params.domain_username
$domain_password = $module.Params.domain_password
$domain_server  = $module.Params.domain_server

# create blank parm map
$parms = @{
    Discover = $discover
}

$valid_services = @('PrimaryDC',"GlobalCatalog","KDC","TimeService","ReliableTimeService","ADWS")

# attempt import of module
Try { Import-Module ActiveDirectory }
Catch { $module.FailJson("The ActiveDirectory module failed to load properly: $($_.Exception.Message)", $_) }

# generate credential
if ($null -ne $domain_username) {
    $domain_password = ConvertTo-SecureString $domain_password -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $domain_username, $domain_password
    $parms.Credential = $credential
}

if ($null -ne $domain_server) { $parms.Server = $domain_server }
if ($null -ne $site) { $parms.SiteName = $site }
if ($null -ne $identity) { $parms.Identity = $identity }
if ($null -ne $filter) { $parms.Filter = $filter }
if ($null -ne $service) { $parms.Service = $($service -join ',') }

$current_domain_info = Get-ADDomainController @parms

$module.ExitJson()