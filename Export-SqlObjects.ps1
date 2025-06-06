[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$true)]
    [string]$DatabaseName,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,
    
    [Parameter(Mandatory=$false)]
    [SqlObjectTypes]$ObjectTypes = [SqlObjectTypes]::All
)

$ErrorActionPreference = "Stop";

# --------------------------------------------
# Run this manually before calling this script:
# --------------------------------------------
# Add-Type -TypeDefinition @"
#     [System.Flags]
#     public enum SqlObjectTypes {
#         All = 0,
#         Tables = 1,
#         Procedures = 2,
#         Functions = 4,
#         Views = 8,
#         DatabaseTriggers = 16,
#         TableTriggers = 32
#     }
# "@

# Check for SqlServer module and load it
function EnsureSqlServerModule {
    if (-not (Get-Module -Name SqlServer -ListAvailable)) {
        Write-Host "SqlServer module not found. Attempting to install..."
        try {
            Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to install SqlServer module: $_"
            Write-Host "Please run 'Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber' manually."
            exit 1
        }
    }
    
    if (-not (Get-Module -Name SqlServer)) {
        Write-Host "Loading SqlServer module..."
        Import-Module -Name SqlServer -ErrorAction Stop
    }
}

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
    
    # Ensure the SqlServer module is loaded
    EnsureSqlServerModule
    
    # Load SMO assemblies if needed
    if (-not ([System.Management.Automation.PSTypeName]'Microsoft.SqlServer.Management.Smo.Server').Type) {
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
    }
    
    # Prompt for credentials
    $credential = Get-Credential -Message "Enter SQL Server credentials for $ServerName"
    $Username = $credential.UserName
    $Password = $credential.GetNetworkCredential().Password
    
    $conn = New-Object "Microsoft.SqlServer.Management.Common.ServerConnection" $ServerName,$Username,$Password
    $conn.Connect();
    if ($conn.IsOpen) {
        Write-Host "Connection successful"
    } else {
        Write-Host "Connection failed"
    }
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $conn

    # $svr.GetDefaultInitFields(typeof(StoredProcedure)); 
    # $svr.SetDefaultInitFields(typeof(StoredProcedure), "IsSystemObject");
    # $svr.SetDefaultInitFields(typeof(Table), "IsSystemObject");
    # $svr.SetDefaultInitFields(typeof(Views), "IsSystemObject");
    # $svr.SetDefaultInitFields(typeof(UserDefinedFunctions), "IsSystemObject");

    $db = $srv.Databases[$DatabaseName]

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

function GenerateScripts($items, $path, $createPath = $True, $includeSystemObjects = $true) {
    if ($createPath) {
        New-Item -Type Directory $path -Force | Out-Null
    }
    $count = 0;
    $systemCount = 0;
    $i = 0;
    Write-Host "Total: $($items.Count)";
    foreach ($item in $items) {
        $i += 1;
        if ($item.IsSystemObject -and (-not $includeSystemObjects)) {
            $systemCount += 1;
            continue;
        }
        
        $filename = $item.Name + ".sql"
        if (-not [string]::IsNullOrEmpty($item.Schema)) {
            $filename = $item.Schema + "." + $filename
        }

        $options.FileName = Join-Path $path (Remove-InvalidFileNameChars $filename)

        try {
            $count += 1;
            $item.Script($options)
            Write-Host -NoNewLine "`r$i processed; $count exported; $systemCount skipped (system)";
        }
        catch [Exception] {
            Write-Host "Uh oh";
            echo $_.Exception | format-list -force
            throw $_.Exception
        }
    } 
    Write-Host -NoNewLine "`r$i processed; $count exported; $systemCount skipped (system)";
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


# Execute the function with the provided parameters
Export-SqlObjects -ServerName $ServerName -DatabaseName $DatabaseName -OutputDir $OutputDir -ObjectTypes $ObjectTypes