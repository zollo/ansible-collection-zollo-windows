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
    supports_check_mode = $false
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$type = $module.Params.type
$ip = $module.Params.ip
$scope_id = $module.Params.scope_id
$mac = $module.Params.mac

$module.Result.scopes = @()
$module.Result.leases = @()

Function Get-DhcpScopeReturnObject {
    Param(
        $Object
    )

    return @{
        name            = $Object.name
        scope_id        = $Object.ScopeId.IPAddressToString
        subnet_mask     = $Object.SubnetMask.IPAddressToString
        address_state   = $Object.State
        start_range     = $Object.StartRange.IPAddressToString
        end_range       = $Object.EndRange.IPAddressToString
        lease_duration = @{
            days = $Object.LeaseDuration.Days
            hours = $Object.LeaseDuration.Hours
        }
    }
}

Function Get-DhcpLeaseReturnObject {
    Param(
        $Object
    )

    return @{
        client_id       = $Object.ClientId
        address_state   = $Object.AddressState
        ip_address      = $Object.IPAddress.IPAddressToString
        scope_id        = $Object.ScopeId.IPAddressToString
        name            = $Object.Name
        description     = $Object.Description
    }
}

Function Get-DhcpObject {
    param(
        [Parameter(Mandatory=$false)]$Type,
        [Parameter(Mandatory=$false)]$ClientId
    )


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
    $leases
}

Function Convert-IPAddressToMac {
    param(
        [Parameter(Mandatory=$true)]$IPAddress
    )

    $lease = Get-AllDhcpLeaseObjects -Type "all" | Where-Object {
        $_.IPAddress -like $IPAddress
    }

    return $lease.ClientId
}

Function Convert-MacAddress {
    Param(
        [string]$mac
    )

    # Evaluate Length
    if ($mac.Length -eq 12) {
        # Insert Dashes
        $mac = $mac.Insert(2, "-").Insert(5, "-").Insert(8, "-").Insert(11, "-").Insert(14, "-")
        return $mac
    }
    elseif ($mac.Length -eq 17) {
        # Remove Colons
        if($mac -like "*:*:*:*:*:*") {
            return ($mac -replace ':')
        }
        # Remove Dashes
        if ($mac -like "*-*-*-*-*-*") {
            return ($mac -replace '-')
        }
    }
    else {
        return $false
    }
}

Try {
    # Import DHCP Server PS Module
    #Import-Module DhcpServer
}
Catch {
    # Couldn't load the DhcpServer Module
    $module.FailJson("The DhcpServer module failed to load properly: $($_.Exception.Message)", $_)
}

# Convert IP to MAC Address/Client ID if Needed
if($ip) {
    $mac = Convert-IPAddressToMac -IPAddress $ip
}

# Retreive Scope
if($scope_id) {
    $current_scope = Get-DhcpServerv4Scope -ScopeId $scope_id
}

# Retreive All Scopes
if(-not $scope_id) {
    $current_scope = Get-DhcpServerv4Scope
}

# Retreive Lease
if ($mac) {
    Try {
        $current_lease = Get-AllDhcpLeaseObjects -Type $type -ClientId (Convert-MacAddress -mac $mac)
    }
    Catch {
        $module.FailJson("Unable to retrive lease/reservation from DHCP server", $_)
    }
}

# Type: Scope/All
if (($type -eq "scope") -or ($type -eq "all")) {
    Try {
        $current_scope | ForEach-Object {
            $module.Result.scopes += Get-DhcpScopeReturnObject -Object $_
        }
    }
    Catch {
        $module.FailJson("Unable to retrive scope(s) from DHCP server", $_)
    }
}

# Type: Lease/Reservation/All
if (($type -ne "scope") -or ($type -eq "all")) {
    Try {
        if ((-not $mac) -and (-not $ip)) {
            # No MAC/IP is specified, return all objects
            (Get-AllDhcpLeaseObjects -Type $type -Scope $current_scope) | ForEach-Object {
                $module.Result.leases += Get-DhcpLeaseReturnObject -Object $
            }
        }
        else {
            # MAC/IP is specified, return a single object
            $module.Result.leases += Get-DhcpLeaseReturnObject -Object $current_lease -Scope $current_scope
        }
    }
    Catch {
        $module.FailJson("Unable to retrive leases/reservations from DHCP server", $_)
    }
}

$module.ExitJson()