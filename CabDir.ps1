
function New-CabFromDirectory($dir, $cabName) {
    # FileName is not a path, only a name.
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        $NewLine = [Environment]::NewLine;
        $dir = (Get-Item $dir).FullName
        if ($cabName -eq $null) {
            $cabName = Split-Path -leaf $dir
        }
        $ext = ".cab";
        if (-not $cabName.EndsWith($ext)) {
            $cabName += $ext;
        }
        $ddf = ".OPTION EXPLICIT";
        $ddf += $NewLine + ".Set CabinetNameTemplate=$cabName"
        $ddf += $NewLine + ".Set DiskDirectory1=."
        $ddf += $NewLine + ".Set CompressionType=MSZIP"
        $ddf += $NewLine + ".Set Cabinet=on"
        $ddf += $NewLine + ".Set Compress=on"
        $ddf += $NewLine + ".Set CabinetFileCountThreshold=0"
        $ddf += $NewLine + ".Set FolderFileCountThreshold=0"
        $ddf += $NewLine + ".Set FolderSizeThreshold=0"
        $ddf += $NewLine + ".Set MaxCabinetSize=0"
        $ddf += $NewLine + ".Set MaxDiskFileCount=0"
        $ddf += $NewLine + ".Set MaxDiskSize=0"
        $ddf += $Newline;
        # --
        $ddfpath = ($env:TEMP+"\temp.ddf")
        $ddf += (ls -recurse $dir | where { !$_.PSIsContainer } | select -ExpandProperty FullName | foreach { '"' + $_ + '" "' + ($_ | Split-Path -Leaf) + '"' }) -join "`r`n"
        $ddf
        $ddf | Out-File -Encoding UTF8 $ddfpath
        makecab.exe /F $ddfpath
        rm $ddfpath
        rm setup.inf
        rm setup.rpt
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
}
