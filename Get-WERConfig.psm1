# Copyright (c) William Aftring (william.aftring@outlook.com)
# Licensed under the MIT license

#region GLOBALS

$Script:WERRoot = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps'
$Script:CustomDumpFlagArray = @(
    "MiniDumpNormal!0x00000000",
    "MiniDumpWithDataSegs!0x00000001",
    "MiniDumpWithFullMemory!0x00000002",
    "MiniDumpWithHandleData!0x00000004",
    "MiniDumpFilterMemory!0x00000008",
    "MiniDumpScanMemory!0x00000010",
    "MiniDumpWithUnloadedModules!0x00000020",
    "MiniDumpWithIndirectlyReferencedMemory!0x00000040",
    "MiniDumpFilterModulePaths!0x00000080",
    "MiniDumpWithProcessThreadData!0x00000100",
    "MiniDumpWithPrivateReadWriteMemory!0x00000200",
    "MiniDumpWithoutOptionalData!0x00000400",
    "MiniDumpWithFullMemoryInfo!0x00000800",
    "MiniDumpWithThreadInfo!0x00001000",
    "MiniDumpWithCodeSegs!0x00002000",
    "MiniDumpWithoutAuxiliaryState!0x00004000",
    "MiniDumpWithFullAuxiliaryState!0x00008000",
    "MiniDumpWithPrivateWriteCopyMemory!0x00010000",
    "MiniDumpIgnoreInaccessibleMemory!0x00020000",
    "MiniDumpWithTokenInformation!0x00040000",
    "MiniDumpWithModuleHeaders!0x00080000",
    "MiniDumpFilterTriage!0x00100000",
    "MiniDumpWithAvxXStateContext!0x00200000",
    "MiniDumpWithIptTrace!0x00400000",
    "MiniDumpScanInaccessiblePartialPages!0x00800000",
    "MiniDumpValidTypeFlags!0x01ffffff"
)
$Script:WerPropertyArray = @(
    "DumpType!DWord",
    "DumpFolder!ExpandString",
    "DumpCount!DWord",
    "CustomDumpFlags!DWord"
)

class WERConfig {

    [string]$AppName
    [string]$DumpType
    [string]$DumpFolder
    [uint64]$DumpCount
    [uint64]$CustomDumpFlags
    [uint64]$DumpTypeValue
    [string]$KeyPath

    WERConfig([string]$KeyPath) {
        $this.KeyPath = $KeyPath
        $Name = $KeyPath.Substring($KeyPath.LastIndexOf("\") + 1)
        $this.AppName = if ( $Name -eq "LocalDumps") { "GLOBAL" } else { $Name }
    }

    SetDumpType([string]$DumpType) {
        $DumpInt = -1
        switch ($DumpType) {
            "CustomDump" { $DumpInt = 0 }
            "MiniDump" { $DumpInt = 1 }
            "FullDump" { $DumpInt = 2 }
            default { $DumpInt = -1 }
        }

        $this.DumpTypeValue = $DumpInt
        $this.DumpType = $DumpType
    }

    WriteToRegistry() {
        # Confirming all of the properties exist
        Write-Verbose "Writing WER config to registry"
        foreach ($KeyPropString in $Script:WerPropertyArray) {
            $KeyPropSplit = $KeyPropString.Split("!")
            $KeyPropName = $KeyPropSplit[0]
            $KeyPropType = $KeyPropSplit[1]

            if (Get-ItemProperty -Path $this.KeyPath -Name $KeyPropName -ErrorAction SilentlyContinue) {
                Write-Verbose "Setting property $KeyPropName"
                switch ($KeyPropName) {
                    "DumpType" {
                        Set-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.DumpTypeValue -ErrorAction Stop
                    }
                    "DumpFolder" {
                        Set-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.DumpFolder -ErrorAction Stop
                    }
                    "DumpCount" {
                        Set-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.DumpCount -ErrorAction Stop
                    }
                    "CustomDumpFlags" {
                        Set-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.CustomDumpFlags -ErrorAction Stop
                    }
                }
            }
            else {
                Write-Verbose "Creating property $KeyPropName"
                switch ($KeyPropName) {
                    "DumpType" {
                        New-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.DumpTypeValue -PropertyType $KeyPropType
                    }
                    "DumpFolder" {
                        New-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.DumpFolder -PropertyType $KeyPropType
                    }
                    "DumpCount" {
                        New-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.DumpCount -PropertyType $KeyPropType
                    }
                    "CustomDumpFlags" {
                        New-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.CustomDumpFlags -PropertyType $KeyPropType
                    }
                }
            }
        }
    }
}
#endregion

#region PRIVATE

function Read-WERKey {
    [CmdletBinding()]
    param(
        [string]$AppName,
        [string]$KeyPath
    )
    Write-Verbose "Processing WER Key for $AppName"
    $DumpsKey = Get-ItemProperty $KeyPath

    $Config = [WERConfig]::new($KeyPath)

    $DumpType = ""
    switch ($DumpsKey.DumpType) {
        0 { $DumpType = "CustomDump" }
        1 { $DumpType = "MiniDump" }
        2 { $DumpType = "FullDump" }
        default { $DumpType = "MiniDump" }
    }

    $Config.DumpType = $DumpType
    $Config.DumpTypeValue = if ($null -ne $DumpsKey.DumpType) { $DumpsKey.DumpType } else { 1 }
    $Config.DumpFolder = if ($DumpsKey.DumpFolder) { $DumpsKey.DumpFolder } else { "%LOCALAPPDATA%\CrashDumps" }
    $Config.DumpCount = if ($DumpsKey.DumpCount) { $DumpsKey.DumpCount } else { 10 }
    $Config.CustomDumpFlags = $DumpsKey.CustomDumpFlags

    return $Config
}

#endregion


#region PUBLIC

function Get-WERConfig {
    [CmdletBinding()]
    param(
        $AppName = "GLOBAL"
    )

    if ($AppName -eq "All") {
        Write-Verbose "Processing Global Key $Script:WERRoot"
        if (Test-Path $Script:WERRoot) {
            Read-WERKey -KeyPath $Script:WERRoot -AppName "GLOBAL"
        }
        Write-Verbose "Checking for specific app config"
        (Get-ChildItem $Script:WERRoot -ErrorAction SilentlyContinue) | ForEach-Object {
            $KeyPath = $_.Name
            Write-Verbose "Processing $KeyPath"
            Read-WERKey -KeyPath "Registry::$KeyPath" -AppName $KeyPath.Substring($KeyPath.LastIndexOf("\") + 1)
        }
    }
    elseif ($AppName -eq "GLOBAL") {
        Write-Verbose "Processing Global Key $Script:WERRoot"
        if (Test-Path $Script:WERRoot) {
            Read-WERKey -KeyPath $Script:WERRoot -AppName "GLOBAL"
        }
    }
    if ($AppName.Contains("*")) {
        $KeyPath = $Script:WERRoot + "\$AppName"
        Get-ChildItem -Path $KeyPath | ForEach-Object {
            $AppKey = $_.Name
            Write-Verbose "Processing $AppKey"
            Read-WERKey -KeyPath "Registry::$AppKey" -AppName $AppKey.Substring($AppKey.LastIndexOf("\") + 1)
        }
    }
    else {
        $KeyPath = $Script:WERRoot + "\$AppName"
        if (!$KeyPath.EndsWith(".exe")) { $KeyPath += ".exe" }
        if (Test-Path $KeyPath) {
            Read-WERKey -KeyPath $KeyPath -AppName $AppName
        }
    }


}
#endregion

function Set-WERConfig {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [string]$AppName = "GLOBAL",
        [ValidateSet("CustomDump", "MiniDump", "FullDump")]
        [string]$DumpType,
        [string]$DumpFolder,
        [uint64]$DumpCount,
        [uint64]$CustomDumpFlags = $null
    )

    Write-Verbose "AppName $AppName"
    $KeyPath = $Script:WERRoot
    $WERConfig = ""

    if ($DumpType -eq "CustomDump" -and $null -eq $CustomDumpFlags) {
        Write-Error "Missing parameter CustomDumpFlags" -ErrorAction Stop
    }

    if ($AppName -eq "GLOBAL") {
        if (!(Test-Path $KeyPath)) {
            Write-Error "$KeyPath not found" -ErrorAction Stop
        }
        $WERConfig = Read-WERKey -AppName $AppName -KeyPath $KeyPath
    }
    elseif ($AppName) {
        # Normalizing the AppName
        if (!$AppName.EndsWith(".exe")) { $AppName += ".exe" }
        $KeyPath += "\$AppName"
        if (!(Test-Path $KeyPath)) {
            Write-Error "$KeyPath not found" -ErrorAction Stop
        }
        $WERConfig = Read-WERKey -AppName $AppName -KeyPath $KeyPath
    }

    if ($DumpType) { $WERConfig.SetDumpType($DumpType) }
    if ($DumpCount) { $WERConfig.DumpCount = $DumpCount }
    if ($DumpFolder) { $WERConfig.DumpFolder = $DumpFolder }
    if ($CustomDumpFlags) { $WERConfig.CustomDumpFlags = $CustomDumpFlags }

    try {
        if ($PSCmdlet.ShouldProcess($WERConfig.KeyPath, "Update WER configuration")) {
            $WERConfig.WriteToRegistry()
            $WERConfig
        }
    }
    catch { Write-Error $_ -ErrorAction Stop }

}

function New-WERConfig {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [string]$AppName = "GLOBAL",
        [ValidateSet("CustomDump", "MiniDump", "FullDump")]
        [string]$DumpType = $null,
        [string]$DumpFolder = $null,
        [uint64]$DumpCount = $null,
        [uint64]$CustomDumpFlags = 0
    )

    Write-Verbose "AppName $AppName"
    $KeyPath = $Script:WERRoot
    if ($AppName -ne "GLOBAL") {
        Write-Verbose "Appending AppName"
        if (!$AppName.EndsWith(".exe")) { $AppName += ".exe" }
        $KeyPath += "\$AppName"
    }

    Write-Verbose "Checking if $KeyPath exists"
    if (Test-Path $KeyPath) { throw "$KeyPath already exists" }
    New-Item $KeyPath -Force | Out-Null

    #FIXME(will): These outputs end up being wrong because of the defaults
    $WERConfig = [WERConfig]::new($KeyPath)
    if ($DumpType) { $WERConfig.SetDumpType($DumpType) }
    if ($DumpFolder) { $WERConfig.DumpFolder = $DumpFolder }
    if ($DumpCount) { $WERConfig.DumpCount = $DumpCount }
    if ($CustomDumpFlags) { $WERConfig.CustomDumpFlags = $CustomDumpFlags }

    try {
        if ($PSCmdlet.ShouldProcess($WERConfig.KeyPath, "Write config to registry")) {
            $WERConfig.WriteToRegistry()
            $WERConfig = Read-WERKey -KeyPath $KeyPath -AppName $AppName
        }
        $WERConfig
    }
    catch { Write-Error $_ -ErrorAction Stop }
}

function Remove-WERConfig {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$AppName,
        [switch]$Force
    )

    Begin {
        $OldSetting = $ConfirmPreference
        if ($Force) {
            $ConfirmPreference = "None"
        }
    }

    Process {
        foreach ($_AppName in $AppName) {
            Write-Verbose "AppName $_AppName"
            $KeyPath = $Script:WERRoot
            if ($_AppName -eq "GLOBAL") {
                if (!($Force)) {
                    Write-Warning "Removing the global WER settings will remove all application specific settings"
                }
                if (!$PSCmdlet.ShouldProcess("Global WER Configuration")) {
                    return
                }
            }
            else {
                if (!$_AppName.EndsWith(".exe")) { $_AppName += ".exe" }
                $KeyPath += "\$_AppName"
            }

            Remove-Item $KeyPath -Recurse
        }
    }
    End {
        $ConfirmPreference = $OldSetting
    }
}

function Get-WERInfo {
    Get-WERConfig -AppName "All" | Format-Table
    Get-WinEvent -FilterHashTable @{LogName = "Application"; Id = 1001 } -MaxEvents 5
}