# Copyright (c) William Aftring (william.aftring@outlook.com)
# Licensed under the MIT license

# TODO
# -Fix assertion conditons...

Import-Module ".\Get-WERConfig.psm1"

$Script:WERRoot = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps'
function Assert-Condition {
    param(
        $Condition1,
        $Condition2,
        [ValidateSet("EQ", "NEQ")]
        $Comparison,
        $Msg
    )
    if ($Comparison -eq "EQ") {
        if ($Condition1 -ne $Condition2) {
            Write-Host "$Condition1 != $Condition2"
            throw $Msg
        }
    }
    else {
        if ($Condition1 -eq $Condition2) {
            Write-Host "$Condition1 == $Condition2"
            throw $Msg
        }
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
        Assert-Condition $WerObj.DumpType "MiniDump" "DumpType string mismatch" -Comparison EQ
        Assert-Condition $WerObj.DumpTypeValue 1 "DumpType value mismatch"
        Assert-Condition $WerObj.DumpFolder "%LOCALAPPDATA%\CrashDumps" "DumpFolder mismatch"
        Assert-Condition $WerObj.DumpCount 1 "DumpCount mismatch"
        Assert-Condition $WerObj.CustomDumpFlags "" "CustomDumpFlags mismatch"
        Assert-Condition $WerObj.KeyPath $Script:WERRoot "KeyPath mismatch"
        return $true
    }
    catch {
        return $false
    }

}

function Test2 {

    $WerObj = New-WERConfig -AppName "exceptions" -DumpFolder "C:\CrashDumps" -DumpCount 10 -DumpType "FullDump"

    try {
        Assert-Condition $WerObj.DumpType "FullDump" "DumpType string mismatch"
        Assert-Condition $WerObj.DumpFolder "C:\CrashDumps" "DumpFolder mismatch"
        Assert-Condition $WerObj.DumpCount 10 "DumpCount mismatch"
        Assert-Condition $WerObj.DumpTypeValue 2 "DumpTypeValue mismatch"
        Assert-Condition $WerObj.CustomDumpFlags "" "CustomDumpFlags mismatch"
        Assert-Condition $WerObj.KeyPath $($Script:WERRoot + "\exceptions.exe") "KeyPath mismatch"
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
        Assert-Condition $WerObj.DumpType "FullDump" "DumpType string mismatch"
        Assert-Condition $WerObj.DumpFolder "C:\CrashDumps" "DumpFolder mismatch"
        Assert-Condition $WerObj.DumpCount 10 "DumpCount mismatch"
        Assert-Condition $WerObj.DumpTypeValue 2 "DumpTypeValue mismatch"
        Assert-Condition $WerObj.CustomDumpFlags "" "CustomDumpFlags mismatch"
        Assert-Condition $WerObj.KeyPath $($Script:WERRoot + "\exceptions.exe") "KeyPath mismatch"
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
        Assert-Condition $WerObj.DumpType "MiniDump" "DumpType string mismatch"
        Assert-Condition $WerObj.DumpFolder "%LOCALAPPDATA%\CrashDumps" "DumpFolder mismatch"
        Assert-Condition $WerObj.DumpCount 10 "DumpCount mismatch"
        Assert-Condition $WerObj.DumpTypeValue 1 "DumpTypeValue mismatch"
        Assert-Condition $WerObj.CustomDumpFlags "" "CustomDumpFlags mismatch"
        Assert-Condition $WerObj.KeyPath $Script:WERRoot "KeyPath mismatch"
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
        Assert-Condition $WerObj.DumpType "MiniDump" "DumpType string mismatch"
        Assert-Condition $WerObj.DumpFolder "C:\" "DumpFolder mismatch"
        Assert-Condition $WerObj.DumpCount 10 "DumpCount mismatch"
        Assert-Condition $WerObj.DumpTypeValue 1 "DumpTypeValue mismatch"
        Assert-Condition $WerObj.CustomDumpFlags "" "CustomDumpFlags mismatch"
        Assert-Condition $WerObj.KeyPath $($Script:WERRoot + "\exceptions.exe") "KeyPath mismatch"
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
        Assert-Condition $WerObj.DumpType "FullDump" "DumpType string mismatch"
        Assert-Condition $WerObj.DumpFolder "C:\CrashDumps" "DumpFolder mismatch"
        Assert-Condition $WerObj.DumpCount 50 "DumpCount mismatch"
        Assert-Condition $WerObj.DumpTypeValue 2 "DumpTypeValue mismatch"
        Assert-Condition $WerObj.CustomDumpFlags "" "CustomDumpFlags mismatch"
        Assert-Condition $WerObj.KeyPath $Script:WERRoot "KeyPath mismatch"
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
        Assert-Condition $WerObj.DumpType "CustomDump" "DumpType string mismatch"
        Assert-Condition $WerObj.DumpFolder "C:\CrashDumps" "DumpFolder mismatch"
        Assert-Condition $WerObj.DumpCount 3 "DumpCount mismatch"
        Assert-Condition $WerObj.DumpTypeValue 0 "DumpTypeValue mismatch"
        Assert-Condition $WerObj.CustomDumpFlags 0x00000121 "CustomDumpFlags mismatch"
        Assert-Condition $WerObj.KeyPath $($Script:WERRoot + "\exceptions2.exe") "KeyPath mismatch"
        return $true
    }
    catch {
        Write-Host $_
        return $false
    }
}

function Test8 {
    New-WERConfig -AppName "ApplicationA" -DumpType 2
    Get-WERConfig -AppName "exc*" | Remove-WERConfig
    Get-WERConfig -AppName All | ForEach-Object {
        Assert
    }

}

# Start by clearing out all settings
Remove-WERConfig -AppName "GLOBAL" -Force

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

# Clean everything up with pipeline
Write-Host "TEST #8: Remove exc* configurations"
Write-Result -Success $(Test8)

Remove-Module Get-WERConfig