function Convert-NameToSID {
    Param(
        [string]$name,
        [string]$domain
    )
    if ($domain -eq $null) {
        $domain = (Get-WmiObject Win32_ComputerSystem).Domain
    }
    $Account = New-Object System.Security.Principal.NTAccount($domain, $name)
    $Identifier = $Account.Translate([System.Security.Principal.SecurityIdentifier])
    $Identifier.Value
}

function Convert-SIDToName {
    Param(
        [string]$sid
    )

    $Identifier = New-Object System.Security.Principal.SecurityIdentifier($sid) 
    $Account = $Identifier.Translate( [System.Security.Principal.NTAccount]) 
    $Account.Value
}