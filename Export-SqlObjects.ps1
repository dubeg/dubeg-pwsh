$ErrorActionPreference = "Stop";
Add-Type -TypeDefinition @"
    [System.Flags]
    public enum SqlObjectTypes {
        All = 0,
        Tables = 1,
        Procedures = 2,
        Functions = 4,
        Views = 8,
        DatabaseTriggers = 16,
        TableTriggers = 32
    }
"@

function Export-SqlObjects
{
    Param(
        [Parameter(Mandatory=$true)]
        [string]$ServerName,
        [Parameter(Mandatory=$true)]
        [string]$DatabaseName,
        [Parameter(Mandatory=$true)]
        [string]$OutputDir,
        [Parameter(Mandatory=$true)]
        [SqlObjectTypes]$ObjectTypes = [SqlObjectTypes]::All
    )
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
    $srv = new-object "Microsoft.SqlServer.Management.SMO.Server" $serverName
    
    $db = New-Object "Microsoft.SqlServer.Management.SMO.Database"
    $db = $srv.Databases[$databaseName]

    $scr = New-Object "Microsoft.SqlServer.Management.Smo.Scripter"
    $scr.Server = $srv

    $options = New-Object "Microsoft.SqlServer.Management.SMO.ScriptingOptions"
    $options.AllowSystemObjects = $false
    $options.IncludeHeaders = $false
    $options.ToFileOnly = $true
    $options.AppendToFile = $false
    $options.DriAllConstraints = $true
    $scr.Options = $options

    # -------------------------
    # Create output Directory
    # -------------------------
    $outputDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputDir);
    # $outputDir = Join-Path $outputDir $db.Name
    
    Write-Host ("OutputDir: {0}" -f $outputDir)
    New-Item -Type Directory $outputDir -Force | Out-Null

    Write-Host "Exporting:"
    $ExportAll = $ObjectTypes -eq [SqlObjectTypes]::All;

    if ($ExportAll -or ($ObjectTypes -band [SqlObjectTypes]::Tables) -ne 0) {
        $path = (Join-Path $outputDir "Tables")
        Remove-Item -Force -Recurse $path -ErrorAction SilentlyContinue
        Write-Host ($db.Name + "/Tables ({0})" -f $db.Tables.Count)
        GenerateScripts $db.Tables $path
    }   

    if ($ExportAll -or ($ObjectTypes -band [SqlObjectTypes]::Views) -ne 0) {
        $path = (Join-Path $outputDir "Views")
        Remove-Item -Force -Recurse $path -ErrorAction SilentlyContinue
        Write-Host ($db.Name + "/Views ({0})" -f $db.Views.Count)
        GenerateScripts $db.Views $path
    }

    if ($ExportAll -or ($ObjectTypes -band [SqlObjectTypes]::Procedures) -ne 0) {
        $path = (Join-Path $outputDir "Procedures")
        Remove-Item -Force -Recurse $path -ErrorAction SilentlyContinue
        Write-Host ($db.Name + "/Procedures ({0})" -f $db.StoredProcedures.Count)
        GenerateScripts $db.StoredProcedures $path
    }   

    if ($ExportAll -or ($ObjectTypes -band [SqlObjectTypes]::Functions) -ne 0) {
        $path = (Join-Path $outputDir "Functions")
        Remove-Item -Force -Recurse $path -ErrorAction SilentlyContinue
        Write-Host ($db.Name + "/Functions ({0})" -f $db.UserDefinedFunctions.Count)
        GenerateScripts $db.UserDefinedFunctions $path
    }

    if ($ExportAll -or ($ObjectTypes -band [SqlObjectTypes]::DatabaseTriggers) -ne 0) {
        $path = (Join-Path $outputDir "DBTriggers")
        Remove-Item -Force -Recurse $path -ErrorAction SilentlyContinue
        Write-Host ($db.Name + "/Database Triggers ({0})" -f $db.Triggers.Count)
        GenerateScripts $db.Triggers $path
    }

    if ($ExportAll -or ($ObjectTypes -band [SqlObjectTypes]::TableTriggers) -ne 0) {
        $path = (Join-Path $outputDir "TBTriggers")
        Remove-Item -Force -Recurse $path -ErrorAction SilentlyContinue
        Write-Host ($db.Name + "/Table Triggers")
        foreach ($table in $db.Tables) {
            if ($table.Triggers.Count -lt 1) {continue;}
            Write-Host ("  " + $table.Name + ", ({0})" -f $table.Triggers.Count)
            GenerateScripts $table.Triggers $path
        }
    }

    Get-ChildItem $outputDir -Recurse | `
        where {$_.PSIsContainer -and @(Get-ChildItem -LiteralPath:$_.fullname).Count -eq 0} | `
        Remove-Item
}

function GenerateScripts($items, $path, $createPath = $True)
{
    if ($createPath) {
        New-Item -Type Directory $path -Force | Out-Null
    }
    $count = 0;
    foreach ($item in $items)
    {
        if ($item.IsSystemObject) {continue;}
        
        $filename = $item.Name + ".sql"
        if (-not [string]::IsNullOrEmpty($item.Schema)) {
            $filename = $item.Schema + "." + $filename
        }

        $options.FileName = Join-Path $path (Remove-InvalidFileNameChars $filename)

        try
        {
            $count += 1;
            $item.Script($options)
            Write-Host -NoNewLine ("`r{0} exported." -f $count);
        }
        catch [Exception]
        {
            echo $_.Exception | format-list -force
            throw $_.Exception
        }
    } 
    if ($count -gt 0) { Write-Host ""; }
}

function Remove-InvalidFileNameChars {
  param(
    [Parameter(Mandatory=$true,
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)]
    [String]$Name
  )

  $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
  $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
  return ($Name -replace $re)
}