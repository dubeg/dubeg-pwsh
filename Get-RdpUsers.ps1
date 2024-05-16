function Get-RdpUsers {
	$users = quser | % {$_ -replace '\s{2,}', ','} | ConvertFrom-CSV
	foreach($user in $users) {
		if ($user.USERNAME.StartsWith(">")) {
			$user.USERNAME = $user.USERNAME.TrimStart(">");
			break;
		}
	}
    return $users;
    # ID
    # IDLE
    # LOGON
    # SESSIONNAME
    # STATE
    # USERNAME
}


function Connect-RdpShadow {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        [switch]$Control
    )
    $isAdmin = (
        [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
    if ($isAdmin -eq $false) {
        Write-Host "You must run this cmdlet in an elevated prompt.";
        return;
    }
    $sessionId = Get-RdpUsers | ? Username -eq $username | Select -ExpandProperty ID;
    if ($sessionId -eq $null) {
        Write-Host "User not found: '$Username'";
        return;
    }
    $ctrlArg = '';
    if ($control) {
        $ctrlArg = "/control";
    }
    $cmd = "mstsc /shadow:$sessionId ${ctrlArg} /noConsentPrompt";
    Write-Host $cmd;
    Invoke-Expression $cmd;
}
