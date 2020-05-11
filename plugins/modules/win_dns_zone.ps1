#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str"; required = $true }
        type = @{ type = "str"; choices = "primary", "secondary", "forwarder", "stub"; default = "primary" }
        replication = @{ type = "str"; choices = "forest", "domain", "legacy", "none" }
        dynamic_update = @{ type = "str"; choices = "secure", "none", "nonsecureandsecure"; }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
        forwarder_timeout = @{ type = "int" }
        dns_servers = @{ type = "list" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$name = $module.Params.name
$type = $module.Params.type
$replication = $module.Params.replication
$dynamic_update = $module.Params.dynamic_update
$state = $module.Params.state
$dns_servers = $module.Params.dns_servers
$forwarder_timeout = $module.Params.forwarder_timeout

$parms = @{
    name = $name
}

Function Get-DnsZoneObject {
    Param(
        [PSObject]$Object
    )
    $parms = @{
        name     = $Object.ZoneName.toLower()
        type     = $Object.ZoneType.toLower()
        paused   = $Object.IsPaused
        shutdown = $Object.IsShutdown
    }

    if ($Object.DynamicUpdate) { $parms.dynamic_update = $Object.DynamicUpdate.toLower() }
    if ($Object.IsReverseLookupZone) { $parms.reverse_lookup = $Object.IsReverseLookupZone }
    if ($Object.ZoneType -like 'forwarder' ) { $parms.forwarder_timeout = $Object.ForwarderTimeout }
    if ($Object.MasterServers) { $parms.dns_servers = $Object.MasterServers.IPAddressToString }
    if (-not $Object.IsDsIntegrated) {
        $parms.replication = "none"
        $parms.zone_file = $Object.ZoneFile
    } else {
        $parms.replication = $Object.ReplicationScope.toLower()
    }

    return $parms | Sort-Object
}

Function Compare-DnsZone {
    Param(
        [PSObject]$Original,
        [PSObject]$Updated
    )

    if($Original -eq $false) { return $false }
    $props = @('ZoneType','DynamicUpdate','IsDsIntegrated','MasterServers','ForwarderTimeout','ReplicationScope')
    $x = Compare-Object $Original $Updated -Property $props
    if($x.Count -eq 0) { return $true }
    return $false
}

Function Compare-IpList {
    Param(
        [PSObject]$Current,
        [PSObject]$Desired
    )

    # ensure that all of the desired IP's are in the current list
    $Desired | ForEach-Object { if ($_ -notin $Current) { return $false } }
    return $true
}

# attempt import of module
Try { Import-Module DnsServer }
Catch { $module.FailJson("The DnsServer module failed to load properly: $($_.Exception.Message)", $_) }

# determine current zone state
Try {
    $current_zone = Get-DnsServerZone -name $name
    if ($current_zone.ZoneType -like $type) { $current_zone_type_match = $true }
} Catch {
    $current_zone = $false
}

if ($state -eq "present") {
    if (-not $replication) { $parms.ReplicationScope = $current_zone.ReplicationScope }
    elseif ($replication -eq 'none') { $parms.ZoneFile = "$name.dns" }
    else  { $parms.ReplicationScope = $replication }
    if ($dynamic_update) { $parms.DynamicUpdate = $dynamic_update }
    if ($dns_servers) { $parms.MasterServers = $dns_servers }
    if ($forwarder_timeout -and ($forwarder_timeout -in 0..15)) { $parms.ForwarderTimeout = $forwarder_timeout }
    $module.Result.debug = $parms
    switch ($type) {
        "primary" {
            if (-not $current_zone) {
                # create zone
                Try { Add-DnsServerPrimaryZone @parms -WhatIf:$check_mode }
                Catch { $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_) }
            } else {
                # update zone
                if (-not $current_zone_type_match) {
                    Try { ConvertTo-DnsServerPrimaryZone @parms -Force -WhatIf:$check_mode } 
                    Catch { $module.FailJson("Failed to convert DNS zone $($name): $($_.Exception.Message)", $_) }
                }
                
                Try { Set-DnsServerPrimaryZone @parms -WhatIf:$check_mode } 
                Catch { $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_) }
            }
        }
        "secondary" {
            if (-not $current_zone) {
                # create zone
                Try { Add-DnsServerSecondaryZone @parms -WhatIf:$check_mode }
                Catch { $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_) }
            } else {
                # update zone
                if (-not $current_zone_type_match) {
                    $parms.Remove('ReplicationScope')
                    Try { ConvertTo-DnsServerSecondaryZone @parms -Force -WhatIf:$check_mode } 
                    Catch { $module.FailJson("Failed to convert DNS zone $($name): $($_.Exception.Message)", $_) }
                }
                Try { Set-DnsServerSecondaryZone @parms -WhatIf:$check_mode } 
                Catch { $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_) }
            }
        }
        "stub" {
            if (-not $current_zone) {
                # create zone
                Try { Add-DnsServerStubZone @parms -WhatIf:$check_mode }
                Catch { $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_) }
            } else {
                # update zone
                if (-not $current_zone_type_match) { $module.FailJson("Failed to convert DNS zone $($name) to $type, unsupported conversion") }
                Try {
                    if ($parms.ReplicationScope) { Set-DnsServerStubZone -Name $name -ReplicationScope $parms.ReplicationScope -WhatIf:$check_mode }
                    if ($forwarder_timeout) { Set-DnsServerStubZone -Name $name -ForwarderTimeout $forwarder_timeout -WhatIf:$check_mode }
                    if ($dns_servers) { Set-DnsServerStubZone -Name $name -MasterServers $dns_servers -WhatIf:$check_mode }
                }
                Catch { $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_) }
            }
        }
        "forwarder" {
            if (-not $current_zone) {
                # create zone
                Try { Add-DnsServerConditionalForwarderZone @parms -WhatIf:$check_mode }
                Catch { $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_) }
            } else {
                # update zone
                if (-not $current_zone_type_match) { $module.FailJson("Failed to convert DNS zone $($name) to $type, unsupported conversion") }
                Try {
                    if ($parms.ReplicationScope) { Set-DnsServerConditionalForwarderZone -Name $name -ReplicationScope $parms.ReplicationScope -WhatIf:$check_mode }
                    if ($forwarder_timeout) { Set-DnsServerConditionalForwarderZone -Name $name -ForwarderTimeout $forwarder_timeout -WhatIf:$check_mode }
                    if ($dns_servers) { Set-DnsServerConditionalForwarderZone -Name $name -MasterServers $dns_servers -WhatIf:$check_mode }
                }
                Catch { $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_) }
            }
        }
    }
}

if ($state -eq "absent") {
    if ($current_zone) {
        Try {
            Remove-DnsServerZone -Name $name -Force -WhatIf:$check_mode
            $module.Result.changed = $true
        } Catch { 
            $module.FailJson("Failed to remove DNS zone: $($_.Exception.Message)", $_) 
        }
    }
    $module.ExitJson()
}

# determine if a change was made
Try {
    $new_zone = Get-DnsServerZone -Name $name
    $module.Result.debug.zones_are_equal = (Compare-DnsZone -Original $current_zone -Updated $new_zone)
    $module.Result.debug.zone_found = ($current_zone -ne $false)
    if($current_zone -ne $false) {
        $module.Result.debug.current_zone = Get-DnsZoneObject -Object $current_zone
    }

    if(-not (Compare-DnsZone -Original $current_zone -Updated $new_zone)) {
        $module.Result.changed = $true
        $module.Result.zone = Get-DnsZoneObject -Object $new_zone
        $module.Diff.after = Get-DnsZoneObject -Object $new_zone
        if($current_zone) { $module.Diff.before = Get-DnsZoneObject -Object $current_zone }
    }
} Catch { 
    $module.FailJson("Failed to lookup new zone $($name): $($_.Exception.Message)", $_) 
}

$module.ExitJson()