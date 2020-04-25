#!powershell

# Copyright: (c) 2019 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.CamelConversion
#Requires -Module Ansible.ModuleUtils.FileUtil
#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

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

Function Convert-ReturnValue {
    Param(
        $Object
    )

    return @{
        address_state = $Object.AddressState
        client_id     = $Object.ClientId
        ip_address    = $Object.IPAddress.IPAddressToString
        scope_id      = $Object.ScopeId.IPAddressToString
        name          = $Object.Name
        description   = $Object.Description
    }
}

$spec = @{
    options = @{
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
        active = @{ type = "bool" }
        name = @{ type = "str"; required = $true }
        pool_start = @{ type = "str" }
        pool_end = @{ type = "str" }
        subnet_mask = @{ type = "int" }
        subnet_length = @{ type = "int" }
        subnet_delay = @{ type = "str" }
        exclusion_list = @{ type = "list" }
        lease_duration = @{ type = "str" }
        description = @{ type = "str" }
        scope_options = @{ type = "list" }
        value = @{ type = "list"; elements = "str"; default = @() ; aliases=@( 'values' )}
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$state = $module.Params.state
$active = $module.Params.active
$name = $module.Params.name
$pool_start = $module.Params.pool_start
$pool_end = $module.Params.pool_end
$subnet_mask = $module.Params.subnet_mask
$subnet_length = $module.Params.subnet_length
$subnet_delay = $module.Params.subnet_delay
$exclusion_list = $module.Params.exclusion_list
$lease_duration = $module.Params.lease_duration
$description = $module.Params.description
$scope_options = $module.Params.scope_options

<#

# option ID special values DnsServer, DnsDomain, Router, Wpad
6 = DNS Servers
1 = Subnet Mask
3 = Router
252 = Web Proxy Auto Discover 

#>

<#

Set-DhcpServerv4OptionValue -OptionId 6 -Value "192.168.1.1"

Set-DhcpServerv4OptionValue -DnsServer 192.168.1.2 -WinsServer 192.168.1.3 -DnsDomain "contoso.com" -Router 192.168.1.1 -Wpad "http://proxy.contoso.com/wpad.dat"

Set-DhcpServerv4OptionValue -ScopeId 10.10.10.0 -DnsServer 192.168.1.2 -WinsServer 192.168.1.3 -DnsDomain "contoso.com" -Router 192.168.1.1 -Wpad "http://proxy.contoso.com/wpad.dat"
Set-DhcpServerv4OptionValue -ReservedIP 10.10.10.5 -DnsServer 192.168.1.2 -WinsServer 192.168.1.3 -DnsDomain "contoso.com" -Router 192.168.1.1 -Wpad "http://proxy.contoso.com/wpad.dat"
Set-DhcpServerv4OptionValue -ReservedIP 10.10.10.5 -DnsServer 192.168.1.2 -WinsServer 192.168.1.3 -DnsDomain "contoso.com" -Router 192.168.1.1 -Wpad "http://proxy.contoso.com/wpad.dat"
Set-DhcpServerv4OptionValue -ScopeId 10.10.10.0 -PolicyName "LabComputers" -DnsServer 192.168.1.2 -WinsServer 192.168.1.3 -DnsDomain "contoso.com" -Router 192.168.1.1 -Wpad "http://proxy.contoso.com/wpad.dat"

Add-DhcpServerv4OptionDefinition -Name "UCIdentifier" -OptionId 1 -Type "BinaryData" -VendorClass "MS-UC-Client" -Description "UC Identifier"

#>




# Parse Regtype
if ($dns_regtype) {
    Switch ($dns_regtype) {
        "aptr" { $dns_regtype = "AandPTR"; break }
        "a" { $dns_regtype = "A"; break }
        "noreg" { $dns_regtype = "NoRegistration"; break }
        default { $dns_regtype = "NoRegistration"; break }
    }
}

Try {
    # Import DHCP Server PS Module
    Import-Module DhcpServer
}
Catch {
    # Couldn't load the DhcpServer Module
    $module.FailJson("The DhcpServer module failed to load properly")
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

# State: Absent
# Ensure the DHCP Lease/Reservation is not present
if ($state -eq "absent") {

    # Required: MAC or IP address
    if ((-not $mac) -and (-not $ip)) {
        $module.Result.changed = $false
        $module.FailJson("The ip or mac parameter is required for state=absent")
    }

    # If the lease exists, we need to destroy it
    if ($current_lease_reservation -eq $true) {
        # Try to remove reservation
        Try {
            $current_lease | Remove-DhcpServerv4Reservation -WhatIf:$check_mode
            $state_absent_removed = $true
        }
        Catch {
            $state_absent_removed = $false
        }
    }
    else {
        # Try to remove lease
        Try {
            $current_lease | Remove-DhcpServerv4Lease -WhatIf:$check_mode
            $state_absent_removed = $true
        }
        Catch {
            $state_absent_removed = $false
        }
    }

    # If the lease doesn't exist, our work here is done
    if ($current_lease_exists -eq $false) {
        $module.Result.skipped = $true
        $module.Result.msg = "The lease or reservation doesn't exist."
        $module.ExitJson()
    }

    # See if we removed the lease/reservation
    if ($state_absent_removed) {
        $module.Result.changed = $true
        $module.ExitJson()
    }
    else {
        $module.Result.lease = Convert-ReturnValue -Object $current_lease
        $module.FailJson("Unable to remove lease/reservation")
    }
}

# State: Present
# Ensure the DHCP Lease/Reservation is present, and consistent
if ($state -eq "present") {

    # Current lease exists, and is not a reservation
    if (($current_lease_reservation -eq $false) -and ($current_lease_exists -eq $true)) {
        if ($type -eq "reservation") {
            Try {
                # Update parameters
                $params = @{ }
                if ($mac) {
                    $params.ClientId = $mac
                }
                else {
                    $params.ClientId = $current_lease.ClientId
                }

                if ($description) {
                    $params.Description = $description
                }
                else {
                    $params.Description = $current_lease.Description
                }

                if ($reservation_name) {
                    $params.Name = $reservation_name
                }
                else {
                    $params.Name = "reservation-" + $params.ClientId
                }

                # Desired type is reservation
                $current_lease | Add-DhcpServerv4Reservation -WhatIf:$check_mode
                $current_reservation = Get-DhcpServerv4Lease -ClientId $params.ClientId -ScopeId $current_lease.ScopeId

                # Update the reservation with new values
                $current_reservation | Set-DhcpServerv4Reservation @params -WhatIf:$check_mode
                $updated_reservation = Get-DhcpServerv4Lease -ClientId $params.ClientId -ScopeId $current_reservation.ScopeId

                # Successful, compare values
                $module.Result.changed = Compare-DhcpLease -Original $original_lease -Updated $reservation

                # Return values
                $module.Result.lease = Convert-ReturnValue -Object $updated_reservation
                $module.ExitJson()
            }
            Catch {
                $module.Result.changed = $false
                $module.FailJson("Could not convert lease to a reservation")
            }
        }

        # Nothing needs to be done, already in the desired state
        if ($type -eq "lease") {
            $module.Result.skipped = $true
            $module.msg = "The lease is already in it's desired state"
            $module.ExitJson()
        }
    }

    # Current lease exists, and is a reservation
    if (($current_lease_reservation -eq $true) -and ($current_lease_exists -eq $true)) {
        if ($type -eq "lease") {
            Try {
                # Desired type is a lease, remove the reservation
                $current_lease | Remove-DhcpServerv4Reservation -WhatIf:$check_mode

                # Build a new lease object with remnants of the reservation
                $lease_params = @{
                    ClientId = $original_lease.ClientId
                    IPAddress = $original_lease.IPAddress.IPAddressToString
                    ScopeId = $original_lease.ScopeId.IPAddressToString
                    HostName = $original_lease.HostName
                    AddressState = 'Active'
                }

                # Create new lease
                Try {
                    Add-DhcpServerv4Lease @lease_params -WhatIf:$check_mode
                }
                Catch {
                    $module.Result.changed = $false
                    $module.Result.params = $lease_params
                    $module.FailJson("Unable to convert the reservation to a lease")
                }

                # Get the lease we just created
                Try {
                    $new_lease = Get-DhcpServerv4Lease -ClientId $lease_params.ClientId -ScopeId $lease_params.ScopeId
                }
                Catch {
                    $module.Result.changed = $false
                    $module.FailJson("Unable to retreive the newly created lease")
                }

                # Successful
                $module.Result.changed = $true
                $module.Diff.after = Convert-ReturnValue -Object $new_lease
                $module.Result.lease = Convert-ReturnValue -Object $new_lease
                $module.ExitJson()
            }
            Catch {
                $module.Result.changed = $false
                $module.FailJson("Could not convert reservation to lease")
            }
        }

        # Already in the desired state
        if ($type -eq "reservation") {

            # Update parameters
            $params = @{ }
            if ($mac) {
                $params.ClientId = $mac
            }
            else {
                $params.ClientId = $current_lease.ClientId
            }

            if ($description) {
                $params.Description = $description
            }
            else {
                $params.Description = $current_lease.Description
            }

            if ($reservation_name) {
                $params.Name = $reservation_name
            }
            else {
                if ($null -eq $original_lease.Name) {
                    $params.Name = "reservation-" + $original_lease.ClientId
                }
                else {
                    $params.Name = $original_lease.Name
                }
            }

            # Update the reservation with new values
            $current_lease | Set-DhcpServerv4Reservation @params -WhatIf:$check_mode
            $reservation = Get-DhcpServerv4Lease -ClientId $current_lease.ClientId -ScopeId $current_lease.ScopeId

            # Successful
            $module.Result.changed = Compare-DhcpLease -Original $original_lease -Updated $reservation

            # Return values
            $module.Result.lease = Convert-ReturnValue -Object $reservation
            $module.ExitJson()
        }
    }

    # Lease Doesn't Exist - Create
    if ($current_lease_exists -eq $false) {

        # Required: MAC and IP address
        if ((-not $mac) -or (-not $ip)) {
            $module.Result.changed = $false
            $module.FailJson("The ip and mac parameters are required for state=present")
        }

        # Required: Scope ID
        if (-not $scope_id) {
            $module.Result.changed = $false
            $module.FailJson("The scope_id parameter is required for state=present")
        }

        # Required Parameters
        $lease_params = @{
            ClientId     = $mac
            IPAddress    = $ip
            ScopeId      = $scope_id
            AddressState = 'Active'
            Confirm      = $false
        }

        if ($duration) {
            $lease_params.LeaseExpiryTime = (Get-Date).AddDays($duration)
        }

        if ($dns_hostname) {
            $lease_params.HostName = $dns_hostname
        }

        if ($dns_regtype) {
            $lease_params.DnsRR = $dns_regtype
        }

        if ($description) {
            $lease_params.Description = $description
        }

        # Create Lease
        Try {
            # Create lease based on parameters
            Add-DhcpServerv4Lease @lease_params -WhatIf:$check_mode

            # Retreive the lease
            $new_lease = Get-DhcpServerv4Lease -ClientId $mac -ScopeId $scope_id

            # If lease is the desired type
            if ($type -eq "lease") {
                $module.Result.changed = $true
                $module.Diff.after = Convert-ReturnValue -Object $new_lease
                $module.Result.lease = Convert-ReturnValue -Object $new_lease
                $module.ExitJson()
            }
        }
        Catch {
            # Failed to create lease
            $module.Result.changed = $false
            $module.FailJson("Could not create DHCP lease")
        }

        # Create Reservation
        Try {
            # If reservation is the desired type
            if ($type -eq "reservation") {
                if ($reservation_name) {
                    $lease_params.Name = $reservation_name
                }
                else {
                    $lease_params.Name = "reservation-" + $mac
                }

                # Convert to Reservation
                $lease | Add-DhcpServerv4Reservation -WhatIf:$check_mode
                # Get DHCP reservation object
                $new_lease = Get-DhcpServerv4Reservation -ClientId $mac -ScopeId $scope_id
                $module.Result.changed = $true
                $module.Diff.after = Convert-ReturnValue -Object $new_lease
                $module.Result.lease = Convert-ReturnValue -Object $new_lease
                $module.ExitJson()
            }
        }
        Catch {
            # Failed to create reservation
            $module.Result.changed = $false
            $module.FailJson("Could not create DHCP reservation")
        }
    }
}

$module.ExitJson()






















#!powershell

# Copyright © 2019 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# Ansible Module by Joseph Zollo (jzollo@vmware.com)

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.CamelConversion
#Requires -Module Ansible.ModuleUtils.FileUtil
#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

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

Function Convert-ReturnValues {
    Param(
        $Object
    )

    $data = @{
        AddressState = $Object.AddressState
        ClientId     = $Object.ClientId
        IPAddress    = $Object.IPAddress.IPAddressToString
        ScopeId      = $Object.ScopeId.IPAddressToString
        Name         = $Object.Name
        Description  = $Object.Description
    }

    return $data
}

# option ID special values DnsServer, DnsDomain, Router, Wpad

<#

6 = DNS Servers
1 = Subnet Mask
3 = Router
252 = Web Proxy Auto Discover 

#>


Function Convert-SpecialType {
    Param(
        [string]$id
    )

    Switch ($id) {
        "dnsserver" { $return_id = 6; break }
        "dnsdomain" { $return_id = 1; break }
        "router" { $return_id = 3; break }
        "subnetmask" { $return_id = 1; break }
        "wpad" { $return_id = 252; break } 
    }

    return $return_id
}

Function Get-DhcpOption {
    Param(
        [string]$id,
        [string]$name,
        [string]$state,
        [string]$data
    )

    Switch ($state) {

        "present" { 
            $options = Get-DhcpServerv4OptionValue
            break 
        }
    
        "server" { 
            $options = Get-DhcpServerv4OptionValue
            break
        }

        "scope" { 
            $options = Get-DhcpServerv4OptionValue -ScopeId $data
            break
        }

        "reservation" { 
            $options = Get-DhcpServerv4OptionValue -ReservedIP $data
            break
        }
    }

    Get-DhcpServerv4OptionValue -ScopeId

}

# Doesn't Support Check or Diff Mode
$params = Parse-Args -arguments $args -supports_check_mode $false
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$diff_mode = Get-AnsibleParam -obj $params -name "_ansible_diff" -type "bool" -default $false

# Client Config Params
$id = Get-AnsibleParam -obj $params -name "id" -type "str"




$type = Get-AnsibleParam -obj $params -name "type" -type "str"
$name = Get-AnsibleParam -obj $params -name "name" -type "str"
$default_value = Get-AnsibleParam -obj $params -name "default_value" -type "str"
$description = Get-AnsibleParam -obj $params -name "description" -type "str"
$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present" -validateset ("absent", "present", "server", "scope", "reservation")
$value = Get-AnsibleParam -obj $params -name "value" -type "str"

# State = Scope
$scope_id = Get-AnsibleParam -obj $params -name "scope_id" -type "str"

# State = Reservation
$reservation_ip = Get-AnsibleParam -obj $params -name "reservation_ip" -type "str"

$dns_domain = Get-AnsibleParam -obj $params -name "dns_domain" -type "str"
$dns_server = Get-AnsibleParam -obj $params -name "dns_server" -type "str"



# Result KVP
$result = @{
    changed = $false
}

# Import DHCP Server PS Module
Try {
    Import-Module DhcpServer
}
Catch {
    # Couldn't load the DhcpServer Module
    Fail-Json -obj $result -message "The DhcpServer module failed to load properly."
}



<#

// Server wide
Set-DhcpServerv4OptionValue -OptionId 6 -Value "192.168.1.1"

// 
Set-DhcpServerv4OptionValue -DnsServer 192.168.1.2 -WinsServer 192.168.1.3 -DnsDomain "contoso.com" -Router 192.168.1.1 -Wpad "http://proxy.contoso.com/wpad.dat"

Set-DhcpServerv4OptionValue -ScopeId 10.10.10.0 -DnsServer 192.168.1.2 -WinsServer 192.168.1.3 -DnsDomain "contoso.com" -Router 192.168.1.1 -Wpad "http://proxy.contoso.com/wpad.dat"
Set-DhcpServerv4OptionValue -ReservedIP 10.10.10.5 -DnsServer 192.168.1.2 -WinsServer 192.168.1.3 -DnsDomain "contoso.com" -Router 192.168.1.1 -Wpad "http://proxy.contoso.com/wpad.dat"
Set-DhcpServerv4OptionValue -ReservedIP 10.10.10.5 -DnsServer 192.168.1.2 -WinsServer 192.168.1.3 -DnsDomain "contoso.com" -Router 192.168.1.1 -Wpad "http://proxy.contoso.com/wpad.dat"
Set-DhcpServerv4OptionValue -ScopeId 10.10.10.0 -PolicyName "LabComputers" -DnsServer 192.168.1.2 -WinsServer 192.168.1.3 -DnsDomain "contoso.com" -Router 192.168.1.1 -Wpad "http://proxy.contoso.com/wpad.dat"

Add-DhcpServerv4OptionDefinition -Name "UCIdentifier" -OptionId 1 -Type "BinaryData" -VendorClass "MS-UC-Client" -Description "UC Identifier"

#>



# Determine if the option is present

Switch ($state) {


    "absent" { 
        Get-DhcpOption
        break 
    }


    "present" { 

        break 
    }


    "server" { 

        break 
    }


    "scope" { 

        break 
    }


    "reservation" { 

        break 
    }


}







# Did we find a lease/reservation
if ($current_lease) {
    $current_lease_exists = $true
}
else {
    $current_lease_exists = $false
}

# If we found a lease, is it a reservation
if ($current_lease_exists -eq $true -and ($current_lease.AddressState -like "*Reservation*")) {
    $current_lease_reservation = $true
}
else {
    $current_lease_reservation = $false
}

# State: Absent
# Ensure the DHCP Lease/Reservation is not present
if ($state -eq "absent") {

    # Required: MAC or IP address
    if ((-not $mac) -and (-not $ip)) {
        $result.changed = $false
        Fail-Json -obj $result -message "The ip or mac parameter is required for state=absent"
    }

    # If the lease exists, we need to destroy it
    if ($current_lease_reservation -eq $true) {
        # Try to remove reservation
        Try {
            $current_lease | Remove-DhcpServerv4Reservation 
            $state_absent_removed = $true
        }
        Catch {
            $state_absent_removed = $false
        }
    }
    else {
        # Try to remove lease
        Try {
            $current_lease | Remove-DhcpServerv4Lease 
            $state_absent_removed = $true
        }
        Catch { 
            $state_absent_removed = $false
        }
    }

    # If the lease doesn't exist, our work here is done
    if ($current_lease_exists -eq $false) {
        $result.changed = $false
        Exit-Json -obj $result
    }

    # See if we removed the lease/reservation
    if ($state_absent_removed) {
        $result.changed = $true
        Exit-Json -obj $result
    }
    else {
        $result.lease = Convert-ReturnValues -Object $current_lease
        Fail-Json -obj $result -message "Could not remove lease/reservation"
    }
} 

# State: Present
# Ensure the DHCP Lease/Reservation is present, and consistent
if ($state -eq "present") {

    # Current lease exists, and is not a reservation
    if (($current_lease_reservation -eq $false) -and ($current_lease_exists -eq $true)) {
        if ($type -eq "reservation") {
            Try {
                # Update parameters
                $params = @{ }
                if ($mac) {
                    $params.ClientId = $mac
                }
                else {
                    $params.ClientId = $current_lease.ClientId
                }

                if ($description) {
                    $params.Description = $description
                }
                else {
                    $params.Description = $current_lease.Description
                }

                if ($reservation_name) {
                    $params.Name = $reservation_name
                }
                else {
                    $params.Name = $current_lease.ClientId + "-" + "res"
                }
    
                # Desired type is reservation
                $current_lease | Add-DhcpServerv4Reservation
                $current_reservation = Get-DhcpServerv4Reservation -ClientId $current_lease.ClientId -ScopeId $current_lease.ScopeId
                # Update the reservation with new values
                $current_reservation | Set-DhcpServerv4Reservation @params
                $reservation = Get-DhcpServerv4Reservation -ClientId $current_reservation.ClientId -ScopeId $current_reservation.ScopeId
                # Successful
                $result.changed = $true
                $result.lease = Convert-ReturnValues -Object $reservation
                Exit-Json -obj $result
            }
            Catch {
                $result.changed = $false
                Fail-Json -obj $result -message "Could not convert lease to a reservation"
            }
        }

        # Nothing needs to be done, already in the desired state
        if ($type -eq "lease") {
            $result.changed = $false
            $result.lease = Convert-ReturnValues -Object $current_lease
            Exit-Json -obj $result
        }
    }

    # Current lease exists, and is a reservation
    if (($current_lease_reservation -eq $true) -and ($current_lease_exists -eq $true)) {
        if ($type -eq "lease") {
            Try {
                # Save Lease Data
                $lease = $current_lease
                # Desired type is a lease, remove & recreate
                $current_lease | Remove-DhcpServerv4Reservation
                # Create new lease
                Add-DhcpServerv4Lease -Name $lease.Name -IPAddress $lease.IPAddress -ClientId $lease.ClientId -Description $lease.Description -ScopeId $lease.ScopeId
                # Get the lease we just created
                $new_lease = Get-DhcpServerv4Lease -ClientId $lease.ClientId -ScopeId $lease.ScopeId
                # Successful
                $result.changed = $true
                $result.lease = Convert-ReturnValues -Object $new_lease
                Exit-Json -obj $result
            }
            Catch {
                $result.changed = $false
                Fail-Json -obj $result -message "Could not convert reservation to lease"
            }
        }

        # Already in the desired state
        if ($type -eq "reservation") {

            # Update parameters
            $params = @{ }
            if ($mac) {
                $params.ClientId = $mac
            }
            else {
                $params.ClientId = $current_lease.ClientId
            }

            if ($description) {
                $params.Description = $description
            }
            else {
                $params.Description = $current_lease.Description
            }

            if ($reservation_name) {
                $params.Name = $reservation_name
            }

            # Update the reservation with new values
            $current_lease | Set-DhcpServerv4Reservation @params
            $reservation = Get-DhcpServerv4Reservation -ClientId $current_lease.ClientId -ScopeId $current_lease.ScopeId
            # Successful
            $result.changed = $true
            $result.lease = Convert-ReturnValues -Object $reservation
            Exit-Json -obj $result
        }
    }

    # Lease Doesn't Exist - Create
    if ($current_lease_exists -eq $false) {

        # Required: MAC and IP address
        if ((-not $mac) -or (-not $ip)) {
            $result.changed = $false
            Fail-Json -obj $result -message "The ip and mac parameters are required for state=present"
        }

        # Required: Scope ID
        if (-not $scope_id) {
            $result.changed = $false
            Fail-Json -obj $result -message "The scope_id parameter is required for state=present"
        }

        # Required Parameters
        $lease_params = @{
            ClientId     = $mac
            IPAddress    = $ip
            ScopeId      = $scope_id
            AddressState = 'Active'
            Confirm      = $false
        }

        if ($duration) {
            $lease_params.LeaseExpiryTime = (Get-Date).AddDays($duration)
        }

        if ($dns_hostname) {
            $lease_params.HostName = $dns_hostname
        }

        if ($dns_regtype) {
            $lease_params.DnsRR = $dns_regtype
        }

        if ($description) {
            $lease_params.Description = $description
        }

        # Create Lease
        Try {
            # Create lease based on parameters
            Add-DhcpServerv4Lease @lease_params
            # Retreive the lease
            $lease = Get-DhcpServerv4Lease -ClientId $mac -ScopeId $scope_id

            # If lease is the desired type
            if ($type -eq "lease") {
                $result.changed = $true
                $result.lease = Convert-ReturnValues -Object $lease
                Exit-Json -obj $result
            }
        }
        Catch {
            # Failed to create lease
            $result.changed = $false
            Fail-Json -obj $result -message "Could not create DHCP lease"
        }

        # Create Reservation
        Try {
            # If reservation is the desired type
            if ($type -eq "reservation") {
                if ($reservation_name) {
                    $lease_params.Name = $reservation_name
                }
                else {
                    $lease_params.Name = $mac + "_" + "pc"
                }

                # Convert to Reservation
                $lease | Add-DhcpServerv4Reservation
                # Get DHCP reservation object
                $reservation = Get-DhcpServerv4Reservation -ClientId $mac -ScopeId $scope_id
                $result.changed = $true
                $result.lease = Convert-ReturnValues -Object $reservation
                Exit-Json -obj $result
            }
        }
        Catch {
            # Failed to create reservation
            $result.changed = $false
            Fail-Json -obj $result -message "Could not create DHCP reservation"
        }
    }
}

# Exit, Return Result
Exit-Json -obj $result