# ------------------------
# Profile
# ------------------------
$HOSTFILE = "C:\Windows\system32\drivers\etc\hosts"
$HOMEDIR = $env:USERPROFILE
$env:HOME = $HOMEDIR


# Alias
# ~~~~~~~~~~~~
Set-Alias dumpbin "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\bin\dumpbin.exe"
Set-alias chrome "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
Set-alias merge "C:\Program Files\Sublime Merge\sublime_merge.exe"
Set-alias 7zip "C:\Program Files\7-Zip\7z.exe" 
Set-alias bcomp "C:\Program Files\Beyond Compare 4\BComp.exe" 
# --
# Use dotnet-script instead of csi.
# Set-alias csi "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\MSBuild\15.0\Bin\Roslyn\csi.exe"



# ----------------
# Examples
# ----------------
# Get-WmiObject -ComputerName <hostName> -Class Win32_ComputerSystem | select Username
# Get-WmiObject -ComputerName <hostName> -Class Win32_Service | ft
# Get-WmiObject -ComputerName <hostName> -Class Win32_Process | ft
# Get-WmiObject -ComputerName <hostName> -Class Win32_Printer | ft
# Get-ADComputer -Filter {OperatingSystem -Like "*server*"} -Property * | Format-Table Name,OperatingSystem,OperatingSystemServicePack -Wrap -Auto

function Get-DirListing {
    ls -File `
        | select `
            Name, `
            CreationTime, `
            @{Name="KB";Expression={ "{0:N0}" -f ($_.Length / 1KB) }}, `
            @{Name="MB";Expression={ "{0:N0}" -f ($_.Length / 1MB) }}, `
            @{Name="GB";Expression={ "{0:N0}" -f ($_.Length / 1GB) }} `
        | Format-Table -Property `
            Name, `
            CreationTime, `
            @{Name="KB";Expression={$_.KB};Alignment="right"}, `
            @{Name="MB";Expression={$_.MB};Alignment="right"}, `
            @{Name="GB";Expression={$_.GB};Alignment="right"} `
}


# ------------------------------------------------------------------
# Manage environment variables
# ------------------------------------------------------------------
function Get-Path {
    Param(
        [parameter()]
        [System.EnvironmentVariableTarget] $scope = [System.EnvironmentVariableTarget]::User
    )

    $paths = [Environment]::GetEnvironmentVariable("PATH", $scope)
    $paths = $paths.trim(";")
    $sortedPaths = $paths.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries) | sort
    return $sortedPaths
}
function Get-PathWithIdx {
    Param(
        [parameter()]
        [System.EnvironmentVariableTarget] $scope = [System.EnvironmentVariableTarget]::User
    )

    $paths = Get-Path $scope;
    $i = 1;
    foreach($path in $paths) {
        Write-Host ($i.ToString().PadLeft(2) + " ") -ForegroundColor "Green" -NoNewLine
        Write-Host $path
        $i += 1
    }
}
function Remove-Path {
    Param(
        [parameter(Mandatory=$true)]
        [int] $Index,
        [parameter()]
        [System.EnvironmentVariableTarget] $Scope = [System.EnvironmentVariableTarget]::User
    )

    $Index -= 1
    $path = Get-Path | select -Index $Index
    if ($path.Trim() -ne "" -and $Index -ge 0)
    {
        $paths = [Environment]::GetEnvironmentVariable("PATH", $Scope)
        $paths = $paths.Replace($path + ";", "").Replace($path, "").Trim(";")
        $paths = $paths.Replace(";;", ";")
        [Environment]::SetEnvironmentVariable("PATH", $paths, $Scope)
        Refresh-Path
    }
}
function Add-Path {
    Param(
        [parameter(Mandatory=$true)]
        [string] $Path,
        [parameter(Mandatory=$true)]
        [System.EnvironmentVariableTarget] $Scope
    )
    $Path = Resolve-Path $Path;
    $Path = $Path.Trim(";")
    if ($Path.Trim() -ne "")
    {
        $paths = [Environment]::GetEnvironmentVariable("PATH", $Scope)
        $paths = $paths.Trim(";")
        $paths += ";" + $Path
        [Environment]::SetEnvironmentVariable("PATH", $paths, $Scope)
        Refresh-Path;
    }
}
function Refresh-Path {
    $machinePaths = [Environment]::GetEnvironmentVariables("Machine")["Path"].Trim(";");
    $userPaths = [Environment]::GetEnvironmentVariables("User")["Path"].Trim(";");
    $env:Path = $userPaths + ";" + $machinePaths;
}


# ------------------------------------------------------------------
# Explorer 
# ------------------------------------------------------------------
function Restart-Explorer {
    # Explorer restarts itself automatically if killed this way.
    # taskkill /F /IM explorer.exe
    # & explorer.exe
    Stop-Process -ProcessName explorer
}


# ------------------------------------------------------------------
# Start PowerShell with admin rights
# ------------------------------------------------------------------
function Start-ElevatedPowerShell {
    $command = "-NoExit -Command `"Set-Location " + $pwd + "`"";
    $exe = "C:\Program Files\PowerShell\7\pwsh.exe";
    Start-Process $exe -Verb Runas -ArgumentList $command
}
Set-Alias -Name sudo -Value Start-ElevatedPowerShell | out-null


# ------------------------------------------------------------------
# Reset colors 
# After an unbehaved program messed them up.
# ------------------------------------------------------------------
$OrigBgColor = $host.ui.rawui.BackgroundColor
$OrigFgColor = $host.ui.rawui.ForegroundColor
function Reset-Colors {
    $host.ui.rawui.BackgroundColor = $OrigBgColor
    $host.ui.rawui.ForegroundColor = $OrigFgColor
}


# ------------------------------------------------------------------
# Get shortened working directory
# 
# Working directory is shortened to a specified nbr of dirs
# with every dir name shortened to a specified nbr of chars.
# ------------------------------------------------------------------
function ShortenLocation($maxDirsInPath, $desiredDirLength, $minHiddenCharsInDir) {
    $shortPath = ''
    $path = (Get-Location);
    $dirs = $path.Path.Split('\');

    # 1. Shorten path
    for($i = 1; $i -le $dirs.Length -and $i -le $maxDirsInPath; $i++)
    {
        $dir = $dirs[$dirs.Length - $i];
        # 1.1 Shorten dir.
        $dir = ShortenName $dir  $desiredDirLength $minHiddenCharsInDir
        # 1.2 Set short dir to shortpath.
        $shortPath = $dir + '\' + $shortPath; 
    }

    #2. Add hint when path is longer than desired.
    if($dirs.Length -gt $maxDirsInPath){
        $shortPath = "...\" + $shortPath
    }
    return $shortPath
}


# ------------------------------------------------------------------
# Get shortened dirname
# 
# Params
#   MinHiddenCharsInDir: 
#   Specify the amount of missing chars a dirName can have.
#   This was added because a name with only 1-2 chars replaced
#   with a '~' looked silly.
# ------------------------------------------------------------------
function ShortenName($fn, $desiredLength, $minHiddenChars) {
    if (($fn.Length - $desiredLength) -gt $minHiddenChars)
    {
        $endStart =  $fn.Length - [int]($desiredLength / 2)
        $fn = $fn.substring(0, [int]($desiredLength / 2) + $desiredLength % 2).TrimEnd() `
            + "~" `
            + $fn.substring($endStart, $desiredLength / 2).TrimStart()
    }
    return $fn
}

# ------------------------------------------------------------------
# Check current user has admin rights
# ------------------------------------------------------------------
function Test-Admin {
    (
        [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}



# ------------------------------------------------------------------
# Prompt
# Returns string prompting for user input.
# ------------------------------------------------------------------
function prompt {
    $maxDirsInPath = 3;
    $desiredDirLength = 12;
    $minHiddenCharsInDir = 4
    $adminHint = "adm|"
    $windowTitle = ""
    $path = ShortenLocation $maxDirsInPath $desiredDirLength $minHiddenCharsInDir
    $cuser = [ConsoleColor]::DarkCyan
    $chost = [ConsoleColor]::DarkCyan
    $cDelim = [ConsoleColor]::Cyan
    $cloc = [ConsoleColor]::DarkGray
    $clc = [ConsoleColor]::Green
    if (Test-Admin) {
        write-host $adminHint -n -f Red
        $windowTitle += $adminHint
    }
    Write-Host ("$(Get-Date -format HH:mm)") -n -f DarkGray 
    Write-Host ("#") -n -f $cDelim 
    Write-Host ($path) -n -f $cloc 
    # -----------------------------------
    # Posh-Git
    # -----------------------------------
    # $PrevExitCode = $LASTEXITCODE
    # Write-VcsStatus
    # $global:LASTEXITCODE = $PrevExitCode
    # -----------------------------------
    Write-Host ("$") -NoNewLine -ForegroundColor $clc 
    return " "
}

# -------------------------------
# Run Only Once
# -------------------------------
if ($ProfileLoaded -eq $null) {
    if (!(Get-Location).Drive.Name.StartsWith("C")) {
        Set-Location $HOMEDIR
    }
    $ProfileLoaded = $true
}