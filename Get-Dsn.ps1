Param(
    # [Parameter(Mandatory=$true)]
    [string] $computerName = $env:ComputerName
)

function GetOdbcReg
{
    Param(
        [Microsoft.Win32.RegistryHive] $scope,
        [string] $odbcKeyName,
        [string] $computerName
    )

    $odbcReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($scope, $computerName).OpenSubkey($odbcKeyName);
    if ($null -eq $odbcReg) 
    {
        return $null;
    }
    else
    {
        return $odbcReg;
    }
}

function GetDsnValues 
{
    Param(
        $odbcReg,
        $dsnName
    )

    $subReg = $odbcReg.OpenSubkey($dsnName);
    if ($null -eq $subReg) {return $null;}

    $dsn = @{};
    $dsn.Name = $dsnName;
    $dsn.LastUser = $subReg.GetValue("LastUser");
    $dsn.IsTrustedConnection = $subReg.GetValue("Trusted_Connection");
    $dsn.Server = $subReg.GetValue("Server");
    $dsn.Database = $subReg.GetValue("Database");
    return $dsn;
}

function DisplayDsnValues
{
    Param(
        $dsn
    )    
    if ($null -eq $dsn) {return;}
    
    Write-Output ($dsn.Name);
    Write-Output ("LastUser: " + $dsn.LastUser);
    Write-Output ("IsTrustedConnection: " + $dsn.IsTrustedConnection);
    Write-Output ("Server: " + $dsn.Server);
    Write-Output ("Database: " + $dsn.Database);
}

# $computerName = "LTI1601";
# $computerName = "LSAC1503"; # Sylvain Morency
# $computerName = "LFIN1701";
$odbcKeyName = "Software\ODBC\ODBC.INI";

$profiles = Get-WmiObject win32_userprofile -ComputerName $computerName | select sid, localpath;

$machineScope = [Microsoft.Win32.RegistryHive]::LocalMachine;
$userScope = [Microsoft.Win32.RegistryHive]::CurrentUser;
$usersScope = [Microsoft.Win32.RegistryHive]::Users;

$svc = Get-Service -ComputerName $computerName -Name RemoteRegistry;
$initialStatus = $svc.Status;
if ($computerName -ne $env:ComputerName -and $initialStatus -eq "Stopped")
{
    Start-Service $svc;
}
# --------------------------
# System DSN
# --------------------------
Write-Host "==================================="
Write-Output "Machine DSNs";
Write-Host "==================================="
try
{
    $odbcReg = GetOdbcReg $machineScope $odbcKeyName $computerName;
    $odbcReg.GetSubKeyNames() | Write-Host;
    
    Write-Host "";
    $dsn = GetDsnValues $odbcReg "DW_PLB";
    DisplayDsnValues $dsn;
}
catch
{
    $_.Exception.Message;
}

# --------------------------
# User DSN
# --------------------------
Write-Host "==================================="
Write-Output "User DSNs";
Write-Host "==================================="
$count = 0;
foreach ($profile in $profiles)
{
    if ($profile.sid.length -le 8) {continue;}
    try 
    {
        $secId = New-Object System.Security.Principal.SecurityIdentifier($profile.sid);
        $ntAccount = $secId.Translate([System.Security.Principal.NTAccount]);
        $username = $ntAccount.Value;
        if (!$username.Contains("PLB")) {continue;}
        
        $userOdbcKey = join-path $profile.sid $odbcKeyName;
        $userOdbcReg = GetOdbcReg $usersScope $userOdbcKey $computerName;
        if ($userOdbcReg -eq $null) {continue;}

        $subKeys = $userOdbcReg.GetSubKeyNames();
        if ($subKeys.length -lt 1) {continue;}

        Write-Output "~~~~~~~~~~~~~~~~~~";
        Write-Output ($ntAccount.Value);
        Write-Output "";
        $subKeys | Write-Host;
        Write-Output "";
        $dsn = GetDsnValues $userOdbcReg "DW_PLB";
        DisplayDsnValues $dsn;
        Write-Output "";
        $count += 1;
    }
    catch 
    {
        $_.Exception.Message;
    }
}
if ($count -gt 0)
{Write-Output "~~~~~~~~~~~~~~~~~~";}

if ($initialStatus -eq "Stopped" -and $svc.Status -ne "Stopped")
{
    Stop-Service $svc
}