function Add-NetworkShortcut {
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $TargetPath
    )
    $shell = New-Object -comObject WScript.Shell;
    $networkShortcutsPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::NetworkShortcuts);
    $linkExt = ".lnk";
    if (!($Name.EndsWith($linkExt))) {
        $Name += $linkExt;
    }
    $linkPath = Join-Path $networkShortcutsPath $Name;
    $link = $shell.CreateShortcut($linkPath);
    $link.TargetPath = $TargetPath;
    $link.IconLocation = "%SystemRoot%\system32\imageres.dll,137";
    $link.Save();
}

function Remove-NetworkShortcut {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $Name
    )
    $shell = New-Object -comObject WScript.Shell;
    $networkShortcutsPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::NetworkShortcuts);
    $linkExt = ".lnk";
    if (!($Name.EndsWith($linkExt))) {
        $Name += $linkExt;
    }
    $linkPath = Join-Path $networkShortcutsPath $Name;
    Remove-Item $linkPath;
}