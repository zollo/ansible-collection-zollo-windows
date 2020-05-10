#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        type = @{ type = "str"; choices = "zone", "record", "all"; default = "all" }
        zone_name = @{ type = "str"; }
        zone_type = @{ type = "str"; choices = "primary","secondary","forwarder","stub"; }
        record_name = @{ type = "str"; }
        record_type = @{ type = "str"; choices = "A","AAAA","MX","CNAME","PTR","NS","TXT"; }
        filter_ad = @{ type = "bool"; default = $false }
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
$filter_ad = $module.Params.filter_ad

$module.Result.zones = @()
$module.Result.records = @()
$parms = @{}

Function Get-DnsRecordFilter {
    Param(
        [PSObject]$Original
    )

    return $Original | Where-Object {
        ($_.HostName -notlike '_kerberos*') -or 
        ($_.HostName -notlike '_ldap*') -or 
        ($_.HostName -notlike '_kpasswd*') -or 
        ($_.HostName -notlike '_gc*') -or 
        ($_.HostName -notlike 'gc._msdcs')
    }
}

Function Get-DnsZoneRecordsObject {
    Param(
        [String]$ZoneName,
        [String]$RRType,
        [Boolean]$FilterAd
    )

    $parms = @{
        ZoneName = $ZoneName
    }

    if($RRType) {
        $parms.RRType = $RRType
    }

    $records = Get-DnsServerResourceRecord @parms

    # Check for FilterAd flag
    if($FilterAd) {
        $records = Get-DnsRecordFilter -Original $records
    }

    $record_list = @()
    foreach($item in $records) {
        $record_list += Get-DnsRecordObject -ZoneName $ZoneName -Original $item
    }

    return $record_list
}

Function Get-DnsRecordObject {
    Param(
        [PSObject]$Original,
        [String]$ZoneName
    )

    return @{
        name    = $Object.HostName
        fqdn    = $Object.HostName + '.' + $ZoneName
        type    = $Object.RecordType
        data    = $Object.ScopeId.IPAddressToString
        ttl     = $Object.TimeToLive.TotalSeconds
    }
}

Function Get-DnsZoneObject {
    Param(
        [PSObject]$Object
    )
    $parms = @{
        name            = $Object.ZoneName.toLower()
        type            = $Object.ZoneType.toLower()
        paused          = $Object.IsPaused
        shutdown        = $Object.IsShutdown
    }

    # Parse Params
    if($Object.DynamicUpdate) { $parms.DynamicUpdate = $Object.DynamicUpdate.toLower() }
    if($Object.IsReverseLookupZone) { $parms.reverse_lookup = $Object.IsReverseLookupZone }

    # Parse Master Servers for forwarder zone
    if($Object.ZoneType -like 'forwarder') {
        $parms.dns_servers = $Object.MasterServers.IPAddressToString
        $parms.forwarder_timeout = $Object.ForwarderTimeout
    }

    # Parse AD Replication/Scope
    if(-not $Object.IsDsIntegrated) {
        $parms.replication = "none"
        $parms.zone_file = $Object.ZoneFile
    } else {
        $parms.replication = $Object.ReplicationScope.toLower()
    }

    return $parms
}


Try {
    # Import DNS Server PS Module
    Import-Module DnsServer
}
Catch {
    # Couldn't load the DhcpServer Module
    $module.FailJson("The DnsServer module failed to load properly: $($_.Exception.Message)", $_)
}

# Evaluate Zone Type
if(-not $zone_type) {
    # Zone type not defined, set flag to wildcard
    $zone_type = '*'
}

# Retreive Zone(s)
Try {
    if($zone_name) {
        # Get the zone we requested, we don't care about type
        $zones_tmp = Get-DnsServerZone -Name $zone_name
    } else {
        # Get all the zones
        $zones_tmp = Get-DnsServerZone | Where-Object {
            $_.ZoneType -like $zone_type
        }
    }
}
Catch {
    $module.FailJson("Unable to retreive zone(s) from DNS server: $($_.Exception.Message)", $_)
}

# Retreive Record(s)
Try {
    if($record_name) {
        # Evaluate the number of zones retreived
        if($zones_tmp.count) {
            # We're requesting multiple zones and requesting a record - invalid
            $module.FailJson("Cannot specify record_name when requesting more than one zone")
        }
        # Get the record we requested filter by record_type
        $record_tmp = Get-DnsServerResourceRecord -ZoneName $zone_name
        # Filter by record type
        if($record_type) {
            $records_tmp = $records_tmp | Where-Object {
                ($_.RecordType -like $record_type)
            }
        }
    } else {
        # Looking for all records
        # Get all records for all zones, filter by record type


        # Loop Over Zones
        foreach($z in $zones_tmp) {
            # Get a Parsed Object
            $z_obj = Get-DnsZoneObject -Original $z
            # Get a list of DNS Records in the Zone (Already Filtered by Record Type)
            $z_obj.dns_records = Get-DnsZoneRecordsObject -ZoneName $z.ZoneName -FilterAd $filter_ad
            $module.Result.zones += Get-DnsZoneObject -Original $z
            # Loop Over Records
        }

        $record_tmp = Get-DnsServerResourceRecord -ZoneName $zone_name
        # Filter by record type
        if($record_type) {
            $records_tmp = $records_tmp | Where-Object {
                ($_.RecordType -like $record_type)
            }
        } 
    }
}
Catch {
    $module.FailJson("Unable to retreive record(s) from DNS server: $($_.Exception.Message)", $_)
}

# if type record is specified, we need the zone name, we need the record name OR type (finds all A records)

# if type zone is specified, record_x is ignored, zone_type/name is optional

# if type all is specified, we need nothing, if a zone name is specified we will filter by it,


$module.ExitJson()