#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        type = @{ type = "str"; choices = "reservation", "lease"; default = "reservation" }
        scope_id = @{ type = "str" }
        ip = @{ type = "str" }
        mac = @{ type = "str" }
    }
    required_if = @(
        @("type", "reservation", @("mac", "ip"), $true),
        @("type", "lease", @("mac", "ip"), $true),
        @("type", "scope", @("scope_id"))
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$type = $module.Params.type
$ip = $module.Params.ip
$scope_id = $module.Params.scope_id
$mac = $module.Params.mac

Function Get-DhcpScopeReturnObject {
    Param(
        $Object
    )

    $obj = @{
        name            = $Object
        scope_id        = $Object
        subnet_mask     = $Object
        address_state   = $Object
        start_range     = $Object
        end_range       = $Object
        lease_duration = @{
            days = $x
            hours = $y
        }
    }

    return $obj
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

Function Get-AllDhcpLeaseObjects {
    return Get-DhcpServerv4Scope | Get-DhcpServerv4Lease
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
        # Remove Dashes
        $mac = $mac -replace '-'
        return $mac
    }
    else {
        return $false
    }
}

Function Compare-DhcpLease {
    Param(
        [PSObject]$Original,
        [PSObject]$Updated
    )

    # Compare values that we care about
    if (($Original.AddressState -eq $Updated.AddressState) -and ($Original.IPAddress -eq $Updated.IPAddress) -and ($Original.ScopeId -eq $Updated.ScopeId) -and ($Original.Name -eq $Updated.Name) -and ($Original.Description -eq $Updated.Description)) {
        # changed = false
        return $false
    }
    else {
        # changed = true
        return $true
    }
}

Try {
    # Import DHCP Server PS Module
    Import-Module DhcpServer
}
Catch {
    # Couldn't load the DhcpServer Module
    $module.FailJson("The DhcpServer module failed to load properly",$_)
}

# Scope
if ($type -eq "scope") {
    # Single Scope
    if($scope_id) {
        Try {
            $current_scope = Get-DhcpServerv4Scope -ScopeId $scope_id
        }
        Catch {
            $module.FailJson("Unable to retrive data on scope $scope_id",$_)
        }
    }

    # Multi Scope
    if($scope_id -eq "") {
        Try {
            $current_scope = Get-DhcpServerv4Scope
        }
        Catch {
            $module.FailJson("Unable to retrive scopes from DHCP",$_)
        }
    }
}

# Determine if there is an existing lease
if ($ip) {
    $current_lease = Get-DhcpServerv4Scope | Get-DhcpServerv4Lease | Where-Object IPAddress -eq $ip
}

# MacAddress was specified
if ($mac) {
    if ($mac -like "*-*") {
        $mac_original = $mac
        $mac = Convert-MacAddress -mac $mac
    }

    if ($mac -eq $false) {
        $module.FailJson("The MAC Address is not properly formatted")
    }
    else {
        $current_lease = Get-DhcpServerv4Scope | Get-DhcpServerv4Lease | Where-Object ClientId -eq $mac_original
    }
}

# Did we find a lease/reservation
if ($current_lease) {
    $current_lease_exists = $true
    $original_lease = $current_lease
    $module.Diff.before = Convert-ReturnValue -Object $original_lease
}
else {
    $current_lease_exists = $false
}

# If we found a lease, is it a reservation?
if ($current_lease_exists -eq $true -and ($current_lease.AddressState -like "*Reservation*")) {
    $current_lease_reservation = $true
}
else {
    $current_lease_reservation = $false
}

$module.ExitJson()