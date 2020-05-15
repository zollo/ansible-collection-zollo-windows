#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        type = @{ type = "str"; choices = "zone", "record", "all"; default = "all" }
        zone_name = @{ type = "str"; }
        zone_type = @{ type = "str"; choices = "primary", "secondary", "forwarder", "stub"; }
        record_name = @{ type = "str"; }
        record_type = @{ type = "str"; choices = "A", "AAAA", "MX", "CNAME", "PTR", "NS", "TXT"; }
        filter_ad = @{ type = "bool"; default = $true }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$parms = @{}

$type = $module.Params.type
$zone_name = $module.Params.zone_name
$zone_type = $module.Params.zone_type
$record_name = $module.Params.record_name
$record_type = $module.Params.record_type
$filter_ad = $module.Params.filter_ad

Function Get-DnsZoneRecordsObject {
    Param(
        [String]$ZoneName,
        [String]$RRType,
        [Boolean]$FilterAd,
        [String]$RecordName
    )

    $parms = @{ZoneName = $ZoneName }
    if ($RRType) { $parms.RRType = $RRType }
    if ($RecordName) { $parms.Name = $RecordName }
    $records = Get-DnsServerResourceRecord @parms
    if ($FilterAd) { 
        $records = $records | Where-Object {
            ($_.HostName -notlike '_kerberos*') -and 
            ($_.HostName -notlike '_ldap*') -and 
            ($_.HostName -notlike '_kpasswd*') -and 
            ($_.HostName -notlike '_gc*') -and 
            ($_.HostName -notlike '*._msdcs*') -and
            ($_.HostName -notlike 'gc._msdcs') -and
            ($_.HostName -notlike '*_ldap._tcp*') -and
            ($_.HostName -notlike '*forestdnszones*') -and
            ($_.HostName -notlike '*domaindnszones*')
        }
    }

    $record_list = @()
    foreach ($item in $records) {
        $record_list += Get-DnsRecordObject -ZoneName $ZoneName -Object $item
    }

    return $record_list
}

Function Get-DnsRecordObject {
    Param(
        [PSObject]$Object,
        [String]$ZoneName
    )

    $parms = @{
        name = $Object.HostName.toLower()
        fqdn = $Object.HostName.toLower() + '.' + $ZoneName.toLower()
        type = $Object.RecordType.toLower()
        ttl = $Object.TimeToLive.TotalSeconds
    }

    if($Object.RecordType -like 'aaaa') { $parms.data = $Object.RecordData.IPv6Address.IPAddressToString }
    if($Object.RecordType -like 'a') { $parms.data = $Object.RecordData.IPv4Address.IPAddressToString }
    if($Object.RecordType -like 'cname') { $parms.data = $Object.RecordData.HostNameAlias }
    if($Object.RecordType -like 'mx') {
        $parms.data = @{
            mail_exchange = $Object.RecordData.MailExchange
            priority = $Object.RecordData.Priority
        }
    }
    if($Object.RecordType -like 'srv') {
        $parms.data = @{
            domain_name = $Object.RecordData.DomainName
            port = $Object.RecordData.Port
            priority = $Object.RecordData.Priority
            weight = $Object.RecordData.Weight
        }
    }

    return $parms | Sort-Object
}

Function Get-DnsZoneObject {
    Param([PSObject]$Object)
    $parms = @{}
    $parms.name     = $Object.ZoneName.toLower()
    $parms.type     = $Object.ZoneType.toLower()
    $parms.paused   = $Object.IsPaused
    $parms.shutdown = $Object.IsShutdown

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

# attempt import of module
Try { Import-Module DnsServer }
Catch { $module.FailJson("The DnsServer module failed to load properly: $($_.Exception.Message)", $_) }

# determine zone type
if (-not $zone_type) { $zone_type = '*' }
$zones_tmp = @()

# determine data struct
if ($type -eq "record") { $module.Result.records = @() } 
else { $module.Result.zones = @() }

Try {
    # determine current zones
    if ($zone_name) { $zones_tmp += Get-DnsServerZone -Name $zone_name } 
    else { $zones_tmp += Get-DnsServerZone | Where-Object { $_.ZoneType -like $zone_type } }
}
Catch {
    $module.FailJson("Unable to retreive zone(s) from DNS server: $($_.Exception.Message)", $_)
}

Try {
    foreach ($zone in $zones_tmp) {
        $zone_parsed = Get-DnsZoneObject -Object $zone
        if ($type -eq "zone") { $module.Result.zones += $zone_parsed }
        if ($zone.ZoneType -in @('primary', 'secondary')) {
            $dns_tmp = Get-DnsZoneRecordsObject -RecordName $record_name -ZoneName $zone.ZoneName -FilterAd $filter_ad -RRType $record_type
        }
        if ($type -eq "record") { $module.Result.records += $dns_tmp }
        if ($type -eq "all") {
            $zone_parsed.dns_records = $dns_tmp
            $module.Result.zones += $zone_parsed
        }
    }
}
Catch {
    $module.FailJson("Unable to retreive record(s) from DNS server: $($_.Exception.Message)", $_)
}

$module.ExitJson()