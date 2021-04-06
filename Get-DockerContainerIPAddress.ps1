function Get-DockerContainerIPAddress($name) {
    $o = docker inspect $name | `
        ConvertFrom-Json | `
        select -ExpandProperty SyncRoot | `
        select -expand netWorkSettings | `
        select -ExpandProperty Networks | `
        Select -ExpandProperty nat | `
        Select IPAddress `
        ;
    ($o.IPAddress.ToString()) | clip.exe
    return $o;
}