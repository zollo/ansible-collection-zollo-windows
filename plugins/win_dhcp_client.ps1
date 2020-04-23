#!powershell

# Ansible Module by Joseph Zollo

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
    } elseif ($mac.Length -eq 17) {
        # Remove Dashes
        $mac = $mac -replace '-'
        return $mac
    } else {
        return $false
    }
}

# Doesn't support check mode for now
$params = Parse-Args -arguments $args -supports_check_mode $false
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$diff_mode = Get-AnsibleParam -obj $params -name "_ansible_diff" -type "bool" -default $false

# Server Config Params
# $server = Get-AnsibleParam -obj $params -name "server" -type "str" -failifempty $true
# $user = Get-AnsibleParam -obj $params -name "user" -type "str" -failifempty $true
# $pass = Get-AnsibleParam -obj $params -name "pass" -type "str" -failifempty $true


# Client Config Params
$type = Get-AnsibleParam -obj $params -name "type" -type "str" -default "reservation" -validateset "reservation","lease"
$ip = Get-AnsibleParam -obj $params -name "ip" -type "str"
$scope_id = Get-AnsibleParam -obj $params -name "scope_id" -type "str"
$mac = Get-AnsibleParam -obj $params -name "macaddress" -type "str"
$duration = Get-AnsibleParam -obj $params -name "duration" -type "int"
$dns_hostname = Get-AnsibleParam -obj $params -name "dns_hostname" -type "str"
$dns_regtype = Get-AnsibleParam -obj $params -name "dns_regtype" -type "str" -default "aptr" -validateset "aptr","a","noreg"
$reservation_name = Get-AnsibleParam -obj $params -name "dns_regtype" -type "str"
$description = Get-AnsibleParam -obj $params -name "description" -type "str"
$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present" -validateset "absent","present"

#$before_value = [Environment]::GetEnvironmentVariable($name, $level)

# Result KVP
$result = @{
    changed = $false
    value = $value
}

<#
# Generate a credential
$server_credential = New-Object System.Management.Automation.PSCredential ($user, $password)

Try {
    # Enter the DHCP Server Remotely
    Enter-PSSession -ComputerName $server -Credential $server_credential 
} Catch { 
    # We couldn't connect to the DHCP server
    Fail-Json -obj $result -message "Could not connect to the DHCP server with the specified credentials"
}
#>

Try {
    # Import DHCP Server PS Module
    Import-Module DhcpServer
} Catch {
    # Couldn't load the DhcpServer Module
    Fail-Json -obj $result -message "The DhcpServer module failed to load properly."
}


<#
# Determine if there is an existing lease
#>

Try {
    # IP Address was specified
    if($ip) {
        $current_lease = Get-DhcpServerv4Scope | Get-DhcpServerv4Lease | Where-Object IPAddress -eq $ip
        $current_lease_exists = $true
    }

    # MacAddress was specified
    if($mac) {
        if(($mac = Convert-MacAddress -mac $mac) -eq $false) {
            Fail-Json -obj $result -message "The MAC Address is improperly formatted"
        } else {
            $current_lease = Get-DhcpServerv4Scope | Get-DhcpServerv4Lease | Where-Object ClientId -eq $mac
            $current_lease_exists = $true
        }
    }
} Catch {
    # Couldn't find a lease
    $current_lease_exists = $false 
}

# Is the existing lease a valid reservation
if($current_lease_exists -eq $true -and ($current_lease.AddressState -contains "Reservation")) {
    $current_lease_reservation = $true
}

# State: Absent - Ensure the DHCP Lease/Reservation is not present
if($state -eq "absent") {

    # If the lease exists, we need to destroy it
    if($current_lease_exists -ne $false) {

        # Try to remove reservation
        Try {
            Remove-DhcpServerv4Reservation -IPAddress $ip -ErrorAction Stop
            $state_absent_removed = $true
        } Catch { 
            $state_absent_removed = $false
        }

        # Try to remove lease
        Try { 
            Remove-DhcpServerv4Lease -IPAddress $ip -ErrorAction Stop
            $state_absent_removed = $true
        } Catch { 
            $state_absent_removed = $false
        }
    }

    # Successful
    if($state_absent_removed) {
        $result.changed = $true
    }
} 

# State: Present - Add/Modify the DHCP Lease, Reservation, or Both
if($state -eq "present") {

    # Convert to Reservation if Desired
    if(($current_lease_reservation -eq $false) -and ($type -eq "reservation")) {
        Try {
            $current_lease | Add-DhcpServerv4Reservation
            $result.changed = $true
        } Catch {
            $result.changed = $false
        }
    }

    # Convert to Lease if Desired
    if(($current_lease_reservation -eq $true) -and ($type -eq "lease")) {
        Try {
            $current_lease | Remove-DhcpServerv4Reservation
            $result.changed = $true
        } Catch {
            $result.changed = $false
        }
    }

    # Lease Exists - Update
    if($current_lease_exists -ne $false) {
        if($type -eq "lease") {
            Fail-Json -obj $result -message "Cannot update the properties of a DHCP lease"
        }

        # Update Reservation
        if($type -eq "reservation") {
            $reservation_params = @{
                IPAddress=$ip
                Confirm = $false
            }

            # MAC Address -> ClientId
            if($mac) {
                $reservation_params.ClientId = $macaddress
            }

            # DNS Hostname -> ComputerName
            if($reservation_name) {
                $reservation_params.Name = $reservation_name
            }

            # Description -> Description
            if($description) {
                $reservation_params.Description = $description
            }

            # Update Reservation Properties
            Try {
                Set-DhcpServerv4Reservation @reservation_params
                $result.changed = $true
            } Catch {
                $result.changed = $false
            }
        }
    }

    # Lease Doesn't Exist - Create
    if($current_lease_exists -eq $false) {

        # Required Parameters
        $lease_params = @{
            ClientId = $macaddress
            IPAddress = $ip
            ScopeId = $scope_id
            Confirm = $false
        }

        if($duration) {
            $lease_params.LeaseExpiryTime = (Get-Date).AddDays($duration)
        }

        if($dns_hostname) {
            $lease_params.HostName = $dns_hostname
        }

        if($dns_regtype) {
            $lease_params.DnsRR = $dns_regtype
        }

        if($reservation_name) {
            $lease_params.Name = $reservation_name
        }

        if($description) {
            $lease_params.Description = $description
        }

        # Create Lease
        $lease = Add-DhcpServerv4Lease @lease_params

        # If desired, convert lease to reservation
        if($type -eq "reservation") {
            $lease | Add-DhcpServerv4Reservation
        }

        $result.changed = $true
    }
}

# Exit, Return Result
Exit-Json -obj $result