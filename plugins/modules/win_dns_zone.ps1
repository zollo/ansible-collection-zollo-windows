#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options             = @{
        name              = @{ type = "str"; required = $true }
        type              = @{ type = "str"; choices = "primary", "secondary", "forwarder", "stub"; default = "primary" }
        replication       = @{ type = "str"; choices = "forest", "domain", "legacy", "none" }
        dynamic_update    = @{ type = "str"; choices = "secure", "none", "nonsecureandsecure"; }
        state             = @{ type = "str"; choices = "absent", "present"; default = "present" }
        forwarder_timeout = @{ type = "int" }
        dns_servers       = @{ type = "list" }
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

    # Parse Params
    if ($Object.DynamicUpdate) { $parms.DynamicUpdate = $Object.DynamicUpdate.toLower() }
    if ($Object.IsReverseLookupZone) { $parms.reverse_lookup = $Object.IsReverseLookupZone }
    if ($Object.ZoneType -like 'forwarder' ) { $parms.forwarder_timeout = $Object.ForwarderTimeout }
    if ($Object.MasterServers) { $parms.dns_servers = $Object.MasterServers.IPAddressToString }

    # Parse Params: AD Replication/Scope
    if (-not $Object.IsDsIntegrated) {
        $parms.replication = "none"
        $parms.zone_file = $Object.ZoneFile
    }
    else {
        $parms.replication = $Object.ReplicationScope.toLower()
    }

    return $parms | Sort-Object
}

Function Update-DnsReplication {
    Param(
        [PSObject]$Current,
        [PSObject]$ReplicationScope,
        [String]$ZoneType,
        [Boolean]$CheckMode
    )

    if($Current.IsDsIntegrated -and $ReplicationScope -notlike 'none') {
        switch ($ZoneType) {
            "primary" { Set-DnsServerPrimaryZone @parms -WhatIf:$CheckMode }
            "secondary" { Set-DnsServerSecondaryZone @parms -WhatIf:$CheckMode }
            "stub" { Set-DnsServerStubZone @parms -WhatIf:$CheckMode }
            "forwarder" { Set-DnsServerConditionalForwarderZone @parms -WhatIf:$CheckMode }
        }
        return $true
    } else {
        return $false
    }
}

Function Compare-DnsZone {
    Param(
        [PSObject]$Orig,
        [PSObject]$New
    )

    # Compare values that we care about
    -not (
        ($Original.ZoneType -eq $New.ZoneType) -and
        ($Original.IPAddress -eq $New.IPAddress) -and
        ($Original.ScopeId -eq $New.ScopeId) -and
        ($Original.Name -eq $New.Name) -and
        ($Original.Description -eq $New.Description)
    )
}

Function Compare-IpList {
    Param(
        [PSObject]$Current,
        [PSObject]$Desired
    )

    # Ensure that all of the desired IP's are in the current list
    $Desired | ForEach-Object { if ($_ -notin $Current) { return $false } }

    # No conflicts found, return true
    return $true
}

Function Convert-DnsZone {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]$To,
        [String]$ReplicationScope,
        [String]$MasterServers,
        [PSObject]$Original
    )

    $parms = @{ }

    # Converting to primary from secondary
    if ($To -like 'primary') {
        # If AD Integrated, set ReplicationScope instead of zone
        if ($Original.IsDsIntegrated) { $parms.ReplicationScope = $ReplicationScope } else { $parms.ZoneFile = $Original.ZoneFile }
        $Original | ConvertTo-DnsServerPrimaryZone @parms -Force
    }

    # Converting to secondary from primary or stub (AD integrated not supported)
    if ($To -like 'secondary') {
        # Ensure MasterServers and ZoneFile are defined params
        if ($MasterServers) { $parms.MasterServers = $MasterServers }
        if ($Original.ZoneFile) { $parms.ZoneFile = $Original.ZoneFile } 
        $Original | ConvertTo-DnsServerSecondaryZone @parms -Force
    }
}

Try {
    # Import DNS Server PS Module
    Import-Module DnsServer
}
Catch {
    # Couldn't load the DhcpServer Module
    $module.FailJson("The DnsServer module failed to load properly: $($_.Exception.Message)", $_)
}

# Check the current state
Try {
    $current_zone = Get-DnsServerZone -name $name
    if ($current_zone.ZoneType -like $type) { $current_zone_type_match = $true }
}
Catch {
    $current_zone = $false
}

if ($state -eq "present") {
    if(-not $current_zone) { # build parms for new zone creation
        if ($replication -eq 'none') { $parms.ReplicationScope = $parms.ZoneFile = "$name.dns" }
        if ($replication) { $parms.ReplicationScope = $replication }
        if ($dynamic_update) { $parms.ReplicationScope = $dynamic_update }
        if ($dns_servers) { $parms.MasterServers = $dns_servers }
    } else { # build parms for zone update
        if ($replication) { $parms.ReplicationScope = $replication }
        if ($dynamic_update) { $parms.DynamicUpdate = $dynamic_update }
        if ($dns_servers) { $parms.MasterServers = $dns_servers }
        #$current_zone.IsDsIntegrated -and ($current_zone.DynamicUpdate -notlike $dynamic_update)) { $parms.DynamicUpdate = $dynamic_update }
    }

    switch ($type) {
        "primary" {
            if (-not $current_zone) {
                Try { Add-DnsServerPrimaryZone @parms -WhatIf:$check_mode }
                Catch { $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_) }
                $module.Result.changed = $true
            } else {
                if (-not $current_zone_type_match) {
                    Try { Convert-DnsZone -Original $current_zone -To $type } 
                    Catch { $module.FailJson("Failed to convert DNS zone $($name): $($_.Exception.Message)", $_) }
                }

                Try {
                    # check parms

                    # check replication
                    
                    # set properties
                    Set-DnsServerPrimaryZone @parms -WhatIf:$CheckMode
                    $module.Result.changed = $true
                } Catch {
                    $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_)
                }
            }
        }
        "secondary" {
            if (-not $current_zone) {
                Try {
                    # build params
                    
                    else { $module.FailJson("The dns_servers param is required when creating a new secondary zone") }
                    # create zone
                    Add-DnsServerSecondaryZone @parms -WhatIf:$check_mode
                    $module.Result.changed = $true
                } Catch {
                    $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_)
                }
            }
            else {
                if (-not $current_zone_type_match) {
                    Try {
                        # check for stub (AD) to secondary conversion
                        if ($current_zone.ZoneType -like 'stub' -and $current_zone.IsDsIntegrated) {
                            $module.FailJson("Converting Active Directory integrated stub zone to secondary zone is unsupported")
                        }

                        # conversion path: primary/stub to secondary
                        if (($current_zone.ZoneType -like 'primary') -or ($current_zone.ZoneType -like 'stub')) {
                            Convert-DnsZone -Original $current_zone -To $type -ReplicationScope $replication -MasterServers $dns_servers
                            $module.Result.changed = $true
                        } else {
                            $module.FailJson("Converting $($current_zone.ZoneType) to secondary zone is unsupported")
                        }
                    } Catch {
                        $module.FailJson("Failed to convert DNS zone: $($_.Exception.Message)", $_)
                    }
                }

                Try {
                    # check dns_servers
                    if ($dns_servers -and (-not (Compare-IpList -Desired $dns_servers -Current $current_zone.MasterServers.IPAddressToString))) {
                        $parms.MasterServers = $dns_servers
                    }
                    # set properties
                    Set-DnsServerSecondaryZone @parms -WhatIf:$check_mode
                    $module.Result.changed = $true
                } Catch {
                    $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_)
                }
            }
        }
        "stub" {
            if ($current_zone -eq $false) {
                Try {
                    # build params
                    if (-not $replication) { $parms.ReplicationScope = 'forest' }
                    elseif ($replication -like 'none') { $parms.ZoneFile = "$name.dns" }
                    else { $parms.ReplicationScope = $replication }
                    if ($dns_servers) { $parms.MasterServers = $dns_servers }
                    else { $module.FailJson("The dns_servers param is required when creating a new stub zone", $_) }
                    # create zone
                    Add-DnsServerStubZone @parms -WhatIf:$check_mode
                    $module.Result.changed = $true
                }
                Catch {
                    $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_)
                }
            }
            else {
                if (-not $current_zone_type_match) {
                    # fail: bad conversion path
                    $module.FailJson("Converting from a $($current_zone.ZoneType) zone to a stub zone is unsupported", $_)
                }

                Try {
                    # check dns_servers
                    if ($dns_servers -and (-not (Compare-IpList -Desired $dns_servers -Current $current_zone.MasterServers.IPAddressToString))) {
                        $parms.MasterServers = $dns_servers
                    }

                    # check replication
                    if ($replication -and ($current_zone.ReplicationScope -notlike $replication)) {
                        if ((($current_zone.ReplicationScope -notlike 'none') -and ($replication -notlike 'none')) -or (($current_zone.ReplicationScope -like 'none') -and ($replication -like 'none'))) {
                            $parms.ReplicationScope = $replication
                        } else {
                            $module.FailJson("Converting between a file backed DNS zone and an Active Directory integrated zone is unsupported")
                        }
                    }

                    Set-DnsServerStubZone @parms -WhatIf:$check_mode
                    $module.Result.changed = $true
                }
                Catch {
                    $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_)
                }
            }
        }
        "forwarder" {
            if ($current_zone -eq $false) {
                Try {
                    # build params
                    if (-not $replication) { $parms.ReplicationScope = 'forest' }
                    elseif ($replication -like 'none') { $parms.ZoneFile = "$name.dns" }
                    else { $parms.ReplicationScope = $replication }
                    if ($dns_servers) { $parms.MasterServers = $dns_servers }
                    else { $module.FailJson("The dns_servers param is required when creating a new stub zone", $_) }

                    # validate: forwarder_input
                    if ($forwarder_timeout -and ($forwarder_timeout -le 15) -and ($forwarder_timeout -ge 0)) {$parms.ForwarderTimeout = $forwarder_timeout }
                    if ($forwarder_timeout -and (($forwarder_timeout -gt 15) -or ($forwarder_timeout -lt 0))) { $module.Warn("The forwarder_timeout param must be between 0 and 15") }
                    
                    # create record
                    Add-DnsServerConditionalForwarderZone @parms -WhatIf:$check_mode
                    $module.Result.changed = $true
                }
                Catch {
                    $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_)
                }
            }
            else {
                if (-not $current_zone_type_match) {
                    # fail: bad conversion path
                    $module.FailJson("Converting from a $($current_zone.ZoneType) zone to a condititonal forwarder is unsupported", $_)
                }

                Try {
                    # check dns_servers
                    if ($dns_servers) { $parms.MasterServers = $dns_servers }

                    # check forwarder_timeout
                    if ($forwarder_timeout) { $parms.ForwarderTimeout = $forwarder_timeout }

                    # check replication
                    if ($replication -and ($current_zone.ReplicationScope -notlike $replication)) {
                        if ((($current_zone.ReplicationScope -notlike 'none') -and ($replication -notlike 'none')) -or (($current_zone.ReplicationScope -like 'none') -and ($replication -like 'none'))) {
                            $parms.ReplicationScope = $replication
                        } else {
                            $module.FailJson("Converting between a file backed DNS zone and an Active Directory integrated zone is unsupported")
                        }
                    }
                    # set params
                    Set-DnsServerConditionalForwarderZone @parms -WhatIf:$check_mode
                    $module.Result.changed = $true
                }
                Catch {
                    $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_)
                }

            }
        }
    }
}

# Ensure the DNS zone is absent
if ($state -eq "absent") {
    if ($current_zone) {
        # Zone is present in DNS server, let's remove it
        Try {
            Remove-DnsServerZone -Name $name -Force -WhatIf:$check_mode
            $module.Result.changed = $true
        }
        Catch {
            $module.FailJson("Could not remove DNS zone: $($_.Exception.Message)", $_)
        }
    }
}

# Parse the results
if (($module.Result.changed -eq $true) -and ($state -eq 'present')) {
    $obj = (Get-DnsServerZone -name $name)
    $module.Result.zone = Get-DnsZoneObject -Object $obj
}

$module.ExitJson()