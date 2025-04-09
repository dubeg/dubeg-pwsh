function Add-ContextMenuItem {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ExePath,

        [string]$IconPath = $null,

        [switch]$AddToFolderBackground,

        [switch]$AddToFolder,
        
        [ValidateScript({
            $_ | ForEach-Object {
                if ($_ -eq $true -or $_ -eq $false) {
                    throw "Extensions must be strings, not boolean values"
                }
                return $true
            }
            return $true
        })]
        [Parameter(Mandatory = $false)]
        [string[]]$AddToExtensions = @()
    )
    function Add-Menu {
        param (
            [string]$RegistryPath,
            [string]$ExePath,
            [string]$Name,
            [string]$IconPath,
            [switch]$UseV
        )

        try {
            New-Item -Path $RegistryPath -Force | Out-Null
            if ($IconPath) {
                Set-ItemProperty -Path $RegistryPath -Name "Icon" -Value $IconPath
            }

            $commandPath = Join-Path $RegistryPath "command"
            New-Item -Path $commandPath -Force | Out-Null
            $arg = "%1"
            if ($UseV) {
                $arg = "%V"
            }
            Set-ItemProperty -Path $commandPath -Name "(default)" -Value "$ExePath `"$arg`""
            Write-Host "Added context menu item to $RegistryPath"
        } catch {
            Write-Warning "Failed to add context menu item to $RegistryPath : $_"
        }
    }

    $baseKey = "HKCU:\Software\Classes"

    if ($AddToFolderBackground) {
        $regPath = "$baseKey\Directory\Background\shell\$Name"
        Add-Menu -RegistryPath $regPath -ExePath $ExePath -Name $Name -IconPath $IconPath -UseV;
    }

    if ($AddToFolder) {
        $regPath = "$baseKey\Directory\shell\$Name"
        Add-Menu -RegistryPath $regPath -ExePath $ExePath -Name $Name -IconPath $IconPath;
    }

    if ($AddToExtensions.Count -gt 0) {
        foreach ($ext in $AddToExtensions) {
            if ($ext -notmatch '^\.') { $ext = ".$ext" }

            # Attempt to resolve the file type (like .txt -> txtfile), fallback to extension
            $typeKey = Get-ItemProperty -Path "$baseKey\$ext" -ErrorAction SilentlyContinue
            $type = if ($typeKey.'(default)') { $typeKey.'(default)' } else { $ext }

            $regPath = "$baseKey\$type\shell\$Name"
            Add-Menu -RegistryPath $regPath -ExePath $ExePath -Name $Name -IconPath $IconPath
        }
    }
}
