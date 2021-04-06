function Get-AdUser2 {
    Param(
        [Parameter(mandatory=$true)] [string]$Name,
        [Parameter(mandatory=$false)] [string]$Server
    );
    $properties = @(
        "DisplayName", `
        "CanonicalName", `
        "SamAccountName", `
        "Title", `
        "Department", `
        "mail", `
        "Created", `
        "LastLogon", `
        "logonCount", `
        "OfficePhone", `
        "LockedOut", `
        "Enabled", `
        "MemberOf"
    );
    $adUsers = Get-ADUser `
        -Filter {Name -like $name -or SamAccountName -like $name} `
        -Properties $properties `
        -Server $Server;
    $users = $adUsers | select `
        "DisplayName", `
        "CanonicalName", `
        "SamAccountName", `
        "Title", `
        "Department", `
        "mail", `
        "Created", `
        "LastLogon", `
        "logonCount", `
        "OfficePhone", `
        "LockedOut", `
        "Enabled", `
        "MemberOf"
        ;
    foreach($user in $users) {
        $lastLogon = [DateTime]::FromFileTime($user.LastLogon);
        $lastLogonStr = $lastLogon.ToString("yyyy-MM-dd HH:mm:ss");
        $user.LastLogon = $lastLogonStr;
        $memberOf = $user.MemberOf;
        Add-Member -InputObject $user -MemberType NoteProperty -Name MemberOf -Value @() -Force;
        foreach($group in $memberOf) {
            $user.MemberOf += $group.Split(",")[0].Substring(3);
        }
    }
    return $users;
}