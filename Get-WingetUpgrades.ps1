class Software {
    [string]$Name
    [string]$Id
    [string]$Version
    [string]$AvailableVersion
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$upgradeResult = winget upgrade | Out-String

$lines = $upgradeResult.Split([Environment]::NewLine)

# Find the line that starts with Name, it contains the header
$fl = 0
while (-not $lines[$fl].StartsWith("Name")) {
    $fl++
}

# Line $i has the header, we can find char where we find ID and Version
$idStart = $lines[$fl].IndexOf("Id")
$versionStart = $lines[$fl].IndexOf("Version")
$availableStart = $lines[$fl].IndexOf("Available")
$sourceStart = $lines[$fl].IndexOf("Source")

# Now cycle in real package and split accordingly
$upgradeList = @()
foreach ($line in $lines) {
    if ($line.Length -gt ($availableStart + 1) -and -not $line.StartsWith('-')) {
        $name = $line.Substring(0, $idStart).TrimEnd()
        $id = $line.Substring($idStart, $versionStart - $idStart).TrimEnd()
        $version = $line.Substring($versionStart, $availableStart - $versionStart).TrimEnd()
        $available = $line.Substring($availableStart, $sourceStart - $availableStart).TrimEnd()
        $software = [Software]::new()
        $software.Name = $name;
        $software.Id = $id;
        $software.Version = $version
        $software.AvailableVersion = $available;
        $upgradeList += $software
    }
}
$upgradeList | Get-Member
$upgradeList | Format-Table