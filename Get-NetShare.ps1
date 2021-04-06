function Get-NetShare {
    param(
      [String] $ComputerName = "."
    )
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        using System.Text;
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct SHARE_INFO_1 {
          [MarshalAs(UnmanagedType.LPWStr)]
          public string Name;
          public uint Type;
          [MarshalAs(UnmanagedType.LPWStr)]
          public string Remark;
        }
        public static class NetApi32 {
          [DllImport("netapi32.dll", SetLastError = true)]
          public static extern int NetApiBufferFree(IntPtr Buffer);
          [DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
          public static extern int NetShareEnum(
            StringBuilder servername,
            int level,
            ref IntPtr bufptr,
            uint prefmaxlen,
            ref int entriesread,
            ref int totalentries,
            ref int resume_handle);
        }
"@;

    $pBuffer = [IntPtr]::Zero
    $entriesRead = $totalEntries = $resumeHandle = 0
    $result = [NetApi32]::NetShareEnum(
      $ComputerName,        # servername
      1,                    # level
      [Ref] $pBuffer,       # bufptr
      [UInt32]::MaxValue,   # prefmaxlen
      [Ref] $entriesRead,   # entriesread
      [Ref] $totalEntries,  # totalentries
      [Ref] $resumeHandle   # resumehandle
    )
    if ( ($result -eq 0) -and ($pBuffer -ne [IntPtr]::Zero) -and ($entriesRead -eq $totalEntries) ) {
      $offset = $pBuffer.ToInt64()
      for ( $i = 0; $i -lt $totalEntries; $i++ ) {
        $pEntry = New-Object IntPtr($offset)
        $shareInfo = [Runtime.InteropServices.Marshal]::PtrToStructure($pEntry, [Type] [SHARE_INFO_1])
        $shareInfo
        $offset += [Runtime.InteropServices.Marshal]::SizeOf($shareInfo)
      }
      [Void] [NetApi32]::NetApiBufferFree($pBuffer)
    }
    if ( $result -ne 0 ) {
      Write-Error -Exception (New-Object ComponentModel.Win32Exception($result))
    }
}