# Copyright (c) William Aftring (william.aftring@outlook.com)
# Licensed under the MIT license

# TODO
# -Fix assertion conditons...

Import-Module ".\Get-WERConfig.psm1"

$Script:WERRoot = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps'
function Assert-Condition {
    param(
        [bool]$Result,
        $Msg
    )
    if (!$Result) {
        throw $Msg
    }
}

function Write-Result {
    param(
        [bool]$Success
    )
    if ($Success) { Write-Host "RESULT: SUCCESS" -ForegroundColor Green }
    else { Write-Host "RESULT: FAILED" -ForegroundColor Yellow }
}

function Test1 {

    $WerObj = New-WERConfig -DumpType MiniDump -DumpFolder "%LOCALAPPDATA%\CrashDumps" -DumpCount 1

    try {
        Assert-Condition $($WerObj.DumpType -eq "MiniDump") "DumpType string mismatch"
        Assert-Condition $($WerObj.DumpTypeValue -eq 1) "DumpType value mismatch"
        Assert-Condition $($WerObj.DumpFolder -eq "%LOCALAPPDATA%\CrashDumps") "DumpFolder mismatch"
        Assert-Condition $($WerObj.DumpCount -eq 1) "DumpCount mismatch"
        Assert-Condition $($WerObj.CustomDumpFlags -eq "") "CustomDumpFlags mismatch"
        Assert-Condition $($WerObj.KeyPath -eq $Script:WERRoot) "KeyPath mismatch"
        return $true
    }
    catch {
        Write-Host $_
        return $false
    }

}

function Test2 {

    $WerObj = New-WERConfig -AppName "exceptions" -DumpFolder "C:\CrashDumps" -DumpCount 10 -DumpType "FullDump"

    try {
        Assert-Condition $($WerObj.DumpType -eq "FullDump") "DumpType string mismatch"
        Assert-Condition $($WerObj.DumpFolder -eq "C:\CrashDumps" ) "DumpFolder mismatch"
        Assert-Condition $($WerObj.DumpCount -eq 10 )  "DumpCount mismatch"
        Assert-Condition $($WerObj.DumpTypeValue -eq 2 ) "DumpTypeValue mismatch"
        Assert-Condition $($WerObj.CustomDumpFlags -eq "" ) "CustomDumpFlags mismatch"
        Assert-Condition $($WerObj.KeyPath -eq ($Script:WERRoot + "\exceptions.exe")) "KeyPath mismatch"
        return $true
    }
    catch {
        Write-Host $_
        return $false
    }
}

function Test3 {

    $WerObj = Get-WERConfig -AppName "exceptions.exe"

    try {
        Assert-Condition $($WerObj.DumpType -eq "FullDump") "DumpType string mismatch"
        Assert-Condition $($WerObj.DumpFolder -eq "C:\CrashDumps") "DumpFolder mismatch"
        Assert-Condition $($WerObj.DumpCount -eq 10 ) "DumpCount mismatch"
        Assert-Condition $($WerObj.DumpTypeValue -eq 2 ) "DumpTypeValue mismatch"
        Assert-Condition $($WerObj.CustomDumpFlags -eq "" ) "CustomDumpFlags mismatch"
        Assert-Condition $($WerObj.KeyPath -eq ($Script:WERRoot + "\exceptions.exe"))"KeyPath mismatch"
        return $true
    }
    catch {
        Write-Host $_
        return $false
    }
}

function Test4 {
    $WerObj = Get-WERConfig
    try {
        Assert-Condition $($WerObj.DumpType -eq "MiniDump") "DumpType string mismatch"
        Assert-Condition $($WerObj.DumpFolder -eq "%LOCALAPPDATA%\CrashDumps") "DumpFolder mismatch"
        Assert-Condition $($WerObj.DumpCount -eq 10 ) "DumpCount mismatch"
        Assert-Condition $($WerObj.DumpTypeValue -eq 1 ) "DumpTypeValue mismatch"
        Assert-Condition $($WerObj.CustomDumpFlags -eq "" ) "CustomDumpFlags mismatch"
        Assert-Condition $($WerObj.KeyPath -eq $Script:WERRoot) "KeyPath mismatch"
        return $true
    }
    catch {
        Write-Host $_
        return $false
    }
}

function Test5 {
    Set-WERConfig -AppName "exceptions" -DumpType MiniDump -DumpFolder "C:\"
    $WerObj = Get-WERConfig -AppName "exceptions"

    try {
        Assert-Condition $($WerObj.DumpType -eq "MiniDump") "DumpType string mismatch"
        Assert-Condition $($WerObj.DumpFolder -eq "C:\") "DumpFolder mismatch"
        Assert-Condition $($WerObj.DumpCount -eq 10 ) "DumpCount mismatch"
        Assert-Condition $($WerObj.DumpTypeValue -eq 1 ) "DumpTypeValue mismatch"
        Assert-Condition $($WerObj.CustomDumpFlags -eq "" ) "CustomDumpFlags mismatch"
        Assert-Condition $($WerObj.KeyPath -eq ($Script:WERRoot + "\exceptions.exe")) "KeyPath mismatch"
        return $true
    }
    catch {
        Write-Host $_
        return $false
    }
}

function Test6 {
    Set-WERConfig -DumpType "FullDump" -DumpCount 50 -DumpFolder "C:\CrashDumps"
    $WerObj = Get-WERConfig

    try {
        Assert-Condition $($WerObj.DumpType -eq "FullDump") "DumpType string mismatch"
        Assert-Condition $($WerObj.DumpFolder -eq "C:\CrashDumps" ) "DumpFolder mismatch"
        Assert-Condition $($WerObj.DumpCount -eq 50 ) "DumpCount mismatch"
        Assert-Condition $($WerObj.DumpTypeValue -eq 2 ) "DumpTypeValue mismatch"
        Assert-Condition $($WerObj.CustomDumpFlags -eq "" )"CustomDumpFlags mismatch"
        Assert-Condition $($WerObj.KeyPath -eq $Script:WERRoot) "KeyPath mismatch"
        return $true
    }
    catch {
        Write-Host $_
        return $false
    }
}

function Test7 {
    $WerObj = New-WERConfig -AppName "exceptions2.exe" -DumpType "CustomDump" -CustomDumpFlags 0x00000121 -DumpCount 3 -DumpFolder "C:\CrashDumps"

    try {
        Assert-Condition $($WerObj.DumpType -eq "CustomDump") "DumpType string mismatch"
        Assert-Condition $($WerObj.DumpFolder -eq "C:\CrashDumps" ) "DumpFolder mismatch"
        Assert-Condition $($WerObj.DumpCount -eq 3 ) "DumpCount mismatch"
        Assert-Condition $($WerObj.DumpTypeValue -eq 0 ) "DumpTypeValue mismatch"
        Assert-Condition $($WerObj.CustomDumpFlags -eq 0x00000121 ) "CustomDumpFlags mismatch"
        Assert-Condition $($WerObj.KeyPath -eq ($Script:WERRoot + "\exceptions2.exe")) "KeyPath mismatch"
        return $true
    }
    catch {
        Write-Host $_
        return $false
    }
}

function Test8 {
    New-WERConfig -AppName "ApplicationA" -DumpType "FullDump" | Out-Null
    Get-WERConfig -AppName "exc*" | Remove-WERConfig | Out-Null
    $Result = Get-WERConfig -AppName All
    try {
        Assert-Condition $($Result.Count -eq 2) "Items not removed"
        return $true
    }
    catch {
        Write-Host $_
        return $false
    }
}

function Test9 {
    try {
        New-WERConfig -AppName "ApplicationA" -DumpType "FullDump"
        Write-Host "Didn't catch duplicate"
        return $false
    }
    catch {
        return $true
    }
}

# Start by clearing out all settings
Write-Host "Clearing out key for tests"
Remove-WERConfig -AppName "GLOBAL" -Force -ErrorAction SilentlyContinue

# Create base container
Write-Host "TEST #1: Creating a new WER global key"
Write-Result -Success $(Test1)
Remove-WERConfig -AppName "GLOBAL" -Force

# Creating a subkey
Write-Host "TEST #2: Create a sub config only"
Write-Result -Success $(Test2)

# Get specific app object
Write-Host "TEST #3: Get single app specific config"
Write-Result -Success $(Test3)

# Get global app object
Write-Host "TEST #: Get global configuration"
Write-Result -Success $(Test4)

# Updating specific instance
Write-Host "TEST #5: Setting single app config"
Write-Result -Success $(Test5)

# Updating the global settings
Write-Host "TEST #6: Setting the global config"
Write-Result -Success $(Test6)

# Creating a new app instance with custom dump flags
Write-Host "TEST #7: Creating a new app config with custom dump settings"
Write-Result -Success $(Test7)

# Clean specific app with pipeline
Write-Host "TEST #8: Remove exc* configurations"
Write-Result -Success $(Test8)

# Duplicate testing
Write-Host "TEST #9: Attempt to add duplicate"
Write-Result -Success $(Test9)

# Remove everything
Write-Host "Cleaning up..."
Remove-WERConfig -AppName "GLOBAL" -Force

Remove-Module Get-WERConfig