#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str"; }
        type = @{ type = "str"; choices = "primary","secondary","forwarder","stub"; default = "primary" }
        replication = @{ type = "str"; choices = "forest", "domain", "legacy"; default = "forest" }
        dynamic_update = @{ type = "str"; default = "secure", "none", "nonsecureandsecure" }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
        dns_servers = @{ type = "list"; }
    }
    required_if = @(
        @("state", "present", @("mac", "ip"), $true),
        @("state", "absent", @("mac", "ip"), $true)
    )
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

$parms = @{}

$result = @{
    changed = $false
}

Function Compare-DnsZone {
    Param(
        [PSObject]$Original,
        [PSObject]$New
    )

    # Compare values that we care about
    -not (
        ($Original.IsDsIntegrated -eq $New.IsDsIntegrated) -and
        ($Original.IsReverseLookupZone -eq $New.IsReverseLookupZone) -and
        ($Original.ZoneName -eq $New.ZoneName) -and
        ($Original.ZoneType -eq $New.ZoneType) -and
        ($Original.DynamicUpdate -eq $New.DynamicUpdate) -and
        ($Original.ReplicationScope -eq $New.ReplicationScope)
    )
}

Function Get-DnsObject {
    Param(
        [PSObject]$Original
    )

    return @{
        
    }

}

Function Convert-RetrunValue {
    
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
    # Attempt to find the zone
    $current_zone = Get-DnsServerZone -name $name

    # Load a custom object
    $current_zone = Get-DnsObject -Original $current_zone

    # Compare against param values
    if ($current_zone.ZoneType -like $type) {
        $current_zone_type_match = $true
    }
    
    # Compare against param values
    if ($current_zone.ZoneName -like $name) {
        $current_zone_name_match = $true
    }
}
Catch {
    # Couldn't find zone on DNS server
    $current_zone = $false
    $current_zone_err = $_
}

# Ensure the DNS zone is present
if ($state -eq "present") {
    switch ($type) {

        "primary" {
            if ($current_zone -eq $false) {
                # Zone is not present
                Try {
                    # Check for non-AD integrated zone
                    if($replication -eq "none") {
                        Add-DnsServerPrimaryZone -Name $name -ZoneFile "$name.dns" -DynamicUpdate $dynamic_update
                    } else {
                        Add-DnsServerPrimaryZone -Name $name -ReplicationScope $replication -DynamicUpdate $dynamic_update
                    }
                    $result.changed = $true
                }
                Catch {
                    $module.FailJson("Unable to add DNS zone: $($_.Exception.Message)", $_)
                }
            } else {

                # Zone is present, ensure it's consistent with the desired state

                if (-not $current_zone_type_match) {

                    # Zone does not match type - attempt conversion

                    Try {
                        $current_zone = $current_zone | ConvertTo-DnsServerPrimaryZone
                    }
                    Catch {
                        $module.FailJson("Failed to convert DNS zone",$_)
                    }

                } else {

                    # Zone matches type, try to set other properties (Dynamic Update/Rep. Scope)

                    Try {
                        # Check dynamic update
                        if($current_zone.DynamicUpdate -notlike $dynamic_update) {
                            $current_zone = $current_zone | Set-DnsServerPrimaryZone -DynamicUpdate $dynamic_update
                        }
    
                        # Check replication scope
                        if($current_zone.ReplicationScope -notlike $replication) {

                            # Special condition, convert from non replicated to replicated
                            if($current_zone.ReplicationScope -notlike 'none' -and ($replication -like 'none')) {
                                $current_zone = $current_zone | ConvertTo-DnsServerPrimaryZone -ReplicationScope $replication
                            }

                            # Special condition, convert from replicated to non replicated
                            if($current_zone.ReplicationScope -like 'none' -and ($replication -notlike 'none')) {
                                $current_zone = $current_zone | ConvertTo-DnsServerPrimaryZone -ReplicationScope $replication
                            }

                        }
                    }
                    Catch {
                        $module.FailJson("Failed to set property on the zone $zone_name",$_)
                    }

                }
            }
        }

        "secondary" {
            if ($current_zone -eq $false) {
                # Zone is not present
                Try {
                    # Check for non-AD integrated zone
                    if($replication -eq "none") {
                        Add-DnsServerSecondaryZone -Name $name -ZoneFile "$name.dns" -DynamicUpdate $dynamic_update
                    } else {
                        Add-DnsServerSecondaryZone -Name $name -ReplicationScope $replication -DynamicUpdate $dynamic_update
                    }
                    $result.changed = $true
                }
                Catch {
                    $module.FailJson("Unable to add DNS zone: $($_.Exception.Message)", $_)
                }
            }
            else {
                # Zone is present, ensure it's consistent with the desired state
                if (-not $current_zone_type_match) {
                    # Zone type mismatch, cannot change
                    $module.FailJson("Unable to convert DNS zone")
                } else {
                    # Zone type is consistent, check other values
                    # We can change the replication scope and dynamic update setting
                    # Set-DnsServerSecondaryZone
                }
            }
        }

        "stub" {
            if ($current_zone -eq $false) {
                # Zone is not present
                Try {
                    # Check for non-AD integrated zone
                    if($replication -eq "none") {
                        Add-DnsServerStubZone -Name $name -MasterServers $dns_servers -ZoneFile "$name.dns"
                    } else {
                        Add-DnsServerStubZone -Name $name -ReplicationScope $replication -MasterServers $dns_servers
                    }
                    $result.changed = $true
                }
                Catch {
                    $module.FailJson("Unable to add DNS zone: $($_.Exception.Message)", $_)
                }
            }
            else {
                # Zone is present, ensure it's consistent with the desired state
                if (-not $current_zone_type_match) {
                    # Zone type mismatch, cannot change
                    $module.FailJson("Unable to convert DNS zone")
                } else {
                    # Zone type is consistent, check other values
                    # Set-DnsServerStubZone
                }
            }
        }

        "forwarder" {
            if ($current_zone -eq $false) {
                # Zone is not present
                Try {
                    # Check for non-AD integrated zone
                    if($replication -eq "none") {
                        Add-DnsServerConditionalForwarderZone -Name $name -ZoneFile "$name.dns" -MasterServers $dns_servers
                    } else {
                        Add-DnsServerConditionalForwarderZone -Name $name -ReplicationScope $replication -MasterServers $dns_servers
                    }
                    $result.changed = $true
                }
                Catch {
                    $module.FailJson("Unable to add DNS zone: $($_.Exception.Message)", $_)
                }
            }
            else {
                # Zone is present, ensure it's consistent with the desired state
                if (-not $current_zone_type_match) {
                    # Zone type mismatch, cannot change
                    $module.FailJson("Unable to convert DNS zone")
                } else {
                    # Zone type is consistent, check other values
                    # We can change the replication scope and MasterServers
                    Update-DnsZone -Type "fowarder"
                    Try {
                        Set-DnsServerConditionalForwarderZone -MasterServers $dns_servers -ReplicationScope $replication
                    }
                    Catch {
                        $module.FailJson("Unable to update DNS zone: $($_.Exception.Message)", $_)
                    }
                    
                }
            }
        }
    }
}

# Ensure the DNS zone is absent
if ($state -eq "absent") {
    if($current_zone) {
        # Zone is present in DNS server, let's remove it
        Try {
            Remove-DnsServerZone -Name $name -Force
            $result.changed = $true
        }
        Catch {
            $module.FailJson("Could not remove DNS zone: $($_.Exception.Message)", $_)
        }
    }
}

$module.ExitJson()