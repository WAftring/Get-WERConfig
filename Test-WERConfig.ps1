Import-Module ".\Get-WERConfig.psm1"

Set-WERConfig -AppName "exception.exe" -DumpType FullDump -DumpCount 2 -DumpFolder C:\CrashDumps -Verbose