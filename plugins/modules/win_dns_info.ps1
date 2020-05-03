#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        type = @{ type = "str"; choices = "zone", "record", "all"; default = "all" }
        zone_name = @{ type = "str"; }
        zone_type = @{ type = "str"; choices = "primary","secondary","forwarder","stub"; default = "forest" }
        record_type = @{ type = "str"; choices = "A","AAAA","MX","CNAME","PTR","NS","TXT","all"; default = "all" }
        record_name = @{ type = "str"; choices = "absent", "present"; default = "present" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$type = $module.Params.type
$zone_name = $module.Params.zone_name
$zone_type = $module.Params.zone_type
$record_name = $module.Params.record_name
$record_type = $module.Params.record_type

# Result KVP
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
    $current_zone = $false
    $current_zone_err = $_
}

# Ensure the DNS zone is present
if ($state -eq "present") {
    switch ($type) {

        "primary" {
            # Add the primary zone
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
                    # Zone type mismatch, cannot change
                    $module.FailJson("Unable to convert DNS zone")
                } else {
                    # Zone type is consistent, check other values
                    # We can change the replication scope and dynamic update setting
                    
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
    Try {
        Remove-DnsServerZone -Name $name -Force
        $result.changed = $true
    }
    Catch {
        $module.FailJson("Could not remove DNS zone: $($_.Exception.Message)", $_)
    }
}

$module.ExitJson()