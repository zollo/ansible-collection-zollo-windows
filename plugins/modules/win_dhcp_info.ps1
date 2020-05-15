#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        type = @{ type = "str"; choices = "all", "scope", "reservation", "lease"; default = "all" }
        scope_id = @{ type = "str" }
        ip = @{ type = "str" }
        mac = @{ type = "str" }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$parms = @{}

$type = $module.Params.type
$ip = $module.Params.ip
$scope_id = $module.Params.scope_id
$mac = $module.Params.mac

Function Get-DhcpScopeLeasesObject {
    Param(
        [String]$LeaseName,
        [String]$RecordName
    )

    $parms = @{ZoneName = $ZoneName }

    if ($RRType) { $parms.RRType = $RRType }
    if ($RecordName) { $parms.Name = $RecordName }
    Get-DhcpServerv4Lease @parms
    $leases = Get-DnsServerResourceRecord @parms

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

    $lease_list = @()
    foreach ($item in $records) {
        $record_list += Get-DnsRecordObject -ZoneName $ZoneName -Object $item
    }

    return $record_list
}

Function Get-DhcpScopeObject {
    Param(
        $Object
    )

    return @{
        name = $Object.name
        scope_id = $Object.ScopeId.IPAddressToString
        subnet_mask = $Object.SubnetMask.IPAddressToString
        address_state = $Object.State
        start_range = $Object.StartRange.IPAddressToString
        end_range = $Object.EndRange.IPAddressToString
        lease_duration = @{
            days = $Object.LeaseDuration.Days
            hours = $Object.LeaseDuration.Hours
        }
    }
}

Function Get-DhcpLeaseObject {
    Param(
        $Object
    )

    return @{
        client_id = $Object.ClientId
        address_state = $Object.AddressState
        ip_address = $Object.IPAddress.IPAddressToString
        scope_id = $Object.ScopeId.IPAddressToString
        name = $Object.Name
        description = $Object.Description
    }
}

Function Get-AllDhcpLeaseObjects {
    param(
        [Parameter(Mandatory=$true)]$Type,
        [Parameter(Mandatory=$false)]$ClientId,
        [Parameter(Mandatory=$false)]$Scope
    )

    Switch($Type) {
        "lease" { $query = 'Active' }
        "reservation" { $query = '*Reservation*' }
        "all" { $query = '*' }
    }

    # Limit/Filter to Defined Scope(s)
    if($Scope) {
        $leases = $Scope | Get-DhcpServerv4Lease
    } else {
        $leases = Get-DhcpServerv4Scope | Get-DhcpServerv4Lease
    }

    # Limit/Filter by Defined Type
    $leases = $leases | Where-Object {
        $_.AddressState -like $query
    }

    # Limit/Filter by Defined ClientId
    if($ClientId) {
        $leases = $leases | Where-Object {
            (Convert-MacAddress -mac $_.ClientId) -like $ClientId
        }
    }

    # Return the Filtered List
    return $leases
}

Function Convert-IPAddressToMac {
    param(
        [String]$IPAddress
    )

    Try { $lease = Get-AllDhcpLeaseObjects -Type "all" | Where-Object { $_.IPAddress -like $IPAddress } }
    Catch { return $false }
    return $lease.ClientId
}

Function Convert-MacAddress {
    Param(
        [string]$mac
    )

    # Evaluate Length
    if ($mac.Length -eq 12) {
        return $mac.Insert(2, "-").Insert(5, "-").Insert(8, "-").Insert(11, "-").Insert(14, "-")
    } elseif ($mac.Length -eq 17) {
        if($mac -like "*:*:*:*:*:*") { return ($mac -replace ':') }
        if ($mac -like "*-*-*-*-*-*") { return ($mac -replace '-') }
    } else {
        return $false
    }
}

# attempt import of module
Try { Import-Module DhcpServer }
Catch { $module.FailJson("The DhcpServer module failed to load properly: $($_.Exception.Message)", $_) }

# determine data struct
if ($type -in @('lease','reservation')) { $module.Result.leases = @() } 
else { $module.Result.scopes = @() }
$scopes_tmp = @()

# convert ip to mac address/client id if needed
if ($ip) { $mac = Convert-IPAddressToMac -IPAddress $ip }

Try {
    # determine current scopes
    if ($scope_id) { $scopes_tmp += Get-DhcpServerv4Scope -ScopeId $scope_id }
    else { $scopes_tmp = Get-DhcpServerv4Scope }
}
Catch {
    $module.FailJson("Unable to retrive scope(s) from DHCP server: $($_.Exception.Message)", $_)
}

# determine leases
if ($mac) {
    Try { $current_lease = Get-AllDhcpLeaseObjects -Type $type -ClientId (Convert-MacAddress -mac $mac) }
    Catch { $module.FailJson("Unable to retrive lease/reservation from DHCP server", $_) }
}






Try {
    foreach ($scope in $scopes_tmp) {

        $scope_parsed = Get-DhcpScopeObject -Object $scope

        if ($type -eq "scope") { $module.Result.scopes += $scope_parsed }

        $lease_tmp = Get-DnsScopeLeasesObject -RecordName $record_name -ZoneName $zone.ZoneName -FilterAd $filter_ad -RRType $record_type

        if ($type -eq "record") { $module.Result.records += $dns_tmp }

        if ($type -eq "all") {
            $zone_parsed.dns_records = $dns_tmp
            $module.Result.zones += $zone_parsed
        }
    }
}
Catch {
    $module.FailJson("Unable to retreive lease(s) from DHCP server: $($_.Exception.Message)", $_)
}












# type: scope/all
if (($type -eq "scope") -or ($type -eq "all")) {
    Try { $current_scope | ForEach-Object { $module.Result.scopes += Get-DhcpScopeReturnObject -Object $_ } }
    Catch { $module.FailJson("Unable to retrive scope(s) from DHCP server", $_) }
}

# type: lease/reservation/all
if (($type -ne "scope") -or ($type -eq "all")) {
    Try {
        if ((-not $mac) -and (-not $ip)) {
            (Get-AllDhcpLeaseObjects -Type $type -Scope $current_scope) | ForEach-Object { 
                $module.Result.leases += Get-DhcpLeaseReturnObject -Object $_ 
            }
        } else { 
            $module.Result.leases += (Get-DhcpLeaseReturnObject -Object $current_lease -Scope $current_scope) 
        }
    } Catch { $module.FailJson("Unable to retrive leases/reservations from DHCP server", $_) }
}

$module.ExitJson()