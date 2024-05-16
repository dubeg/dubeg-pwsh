Get-SmbOpenFile | ? Path -like *.xll | Select ClientUserName, ClientComputerName, Path, FileId | Sort Path | Format-Table
Get-SmbOpenFile | ? Path -like *.xll | Close-SmbOpenFile