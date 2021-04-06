# ------------------------------------------------------------------
# List commits
# ------------------------------------------------------------------
function Git-Status {
    git status
}

function Git-Commits {
    Param (
        [Parameter(mandatory=$false)] [String]$filePattern = ""
    )
    # --since=2.weeks
    # --until="2008-01-20"
    # --grep=""     - Search on commit messages.
    # --author=""   - Search on commit authors.
    # -n            - Show last n commits.
    if (![string]::IsNullOrWhiteSpace($filePattern))
    {
        $files = gci -Recurse -File $filePattern
        if ($files.Count -gt 1)
        {
            Write-Host "The pattern is not specific enough."
            $sList = ($files -join "`r`n" | out-string)
            $sList = $sList.Replace($pwd, ".")
            Write-Host $sList
            return
        }
        elseif ($files.Count -gt 0)
        {
            $file = $files[0]
            $path = $file.FullName
            $path = $path.Replace($pwd, ".")
            $path = $path.Replace("\", "/")
            $followArg = " --follow " + $path
        }
        else {
            Write-Host "File not found"
            return
        }
    }
    $cmd = 'git log --pretty=format:"%h - %cd %an: %s" -15 --date=short' + $followArg
    Write-Host $cmd
    iex $cmd
    # %H Commit hash
    # %h Abbreviated commit hash
    # %T Tree hash
    # %t Abbreviated tree hash
    # %P Parent hashes
    # %p Abbreviated parent hashes
    # %an Author name
    # %ae Author email
    # %ad Author date (format respects the --date=option)
    # %ar Author date, relative
    # %cn Committer name
    # %ce Committer email
    # %cd Committer date
    # %cr Committer date, relative
    # %s Subject
}

function Git-ExtensionsInStaging {
    git diff --name-only --cached | foreach { [System.IO.Path]::GetExtension($_) } | select -unique
}

function Git-Previous {
    Param (
        [Parameter(mandatory=$true)] [String]$filePattern,
        [Parameter(mandatory=$false)] [Int]$prevCommitNbr = 1,
        [Parameter(mandatory=$false)] [switch]$openInSubl
    )
    # git show doesn't seem to support wildcards like in `git diff --` and co.
    # Write-Host $pattern
    # $files = gci -Recurse -File $pattern
    # if ($files.Count -gt 1)
    # {
    #     # The pattern is not specific enough.
    #     # Display possibilities.
    #     $sList = ($files -join "`r`n" | out-string)
    #     $sList = $sList.Replace($pwd, ".")
    #     Write-Host $sList
    #     Write-Host ($files.Count)
    # }
    # else 
    
    $file = Resolve-Path $filePattern | gci
    $ext = $file.Extension
    $path = $file.FullName
    $path = $path.Replace($pwd, ".")
    $path = $path.Replace("\", "/")
    
    $commits = iex ('git log --pretty=format:"%h" --follow "' + $path + '"')
    $commit = "";
    if ($commits -is [array]) {
        $commit = $commits[$prevCommitNbr - 1]
    }
    else {
        # Commits wont be an array is only a single commit
        # was returned in the gitlog command.
        $commit = $commits;
    }
    if ($commit -eq $null) {
        Write-Host SelectedCommitIsNull
        return;
    }
    if ($commit -eq "") {
        Write-Host SelectedCommitIsEmpty
        return;
    }
    write-host Commits: $commits
    write-host Selected: $commit

    $tmpPath = [System.IO.Path]::GetTempFileName()
    $tmpPath = $tmpPath.Replace(".tmp", $ext)
    # You can't pipe binary data without corruption it.
    # So this function is useless for blobs.
    $cmd = 'git show ' + $commit + ':' + '"' + $path + '"' + ' > ' + $tmpPath
    write-host Command: $cmd
    iex $cmd
    if ($openInSubl) {
        subl -n $tmpPath
    }
}