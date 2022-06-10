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
    "DumpFolder!String",
    "DumpCount!DWord",
    "CustomDumpFlags!DWord"
)

class WERConfig {

    [string]$AppName
    [string]$DumpType
    [string]$DumpFolder
    [uint]$DumpCount
    [string]$CustomDumpFlags
    [uint]$_DumpType
    [uint]$_CustomDumpFlags
    [string]$_KeyPath

    WERConfig([string]$KeyPath) {
        $this._KeyPath = $KeyPath
        $Name = $KeyPath.Substring($KeyPath.LastIndexOf("\") + 1)
        $this.AppName = if ( $Name -eq "LocalDumps") { "GLOBAL" } else { $Name }
    }

    [bool]SetDumpType([string]$DumpType) {
        $DumpInt = -1
        switch ($DumpType) {
            "CustomDump" { $DumpInt = 0 }
            "MiniDump" { $DumpInt = 1 }
            "FullDump" { $DumpInt = 2 }
            default { $DumpInt = -1 }
        }

        $this._DumpType = $DumpInt
        $this.DumpType = $DumpType
        return ($DumpInt -ne -1)
    }

    WriteToRegistry() {
        # Confirming all of the properties exist
        foreach ($KeyPropString in $Script:WerPropertyArray) {
            $KeyPropSplit = $KeyPropString.Split("!")
            $KeyPropName = $KeyPropSplit[0]
            $KeyPropType = $KeyPropSplit[1]

            if (Get-ItemProperty -Path $this._KeyPath -Name $KeyPropName -ErrorAction SilentlyContinue) {
                switch ($KeyPropName) {
                    "DumpType" {
                        Set-ItemProperty -Path $this._KeyPath -Name $KeyPropName -Value $this._DumpType -Type $KeyPropType
                    }
                    "DumpFolder" {
                        Set-ItemProperty -Path $this._KeyPath -Name $KeyPropName -Value $this.DumpFolder -Type $KeyPropType
                    }
                    "DumpCount" {
                        Set-ItemProperty -Path $this._KeyPath -Name $KeyPropName -Value $this.DumpCount -Type $KeyPropType
                    }
                    "CustomDumpFlags" {
                        Set-ItemProperty -Path $this._KeyPath -Name $KeyPropName -Value $this._CustomDumpFlags -Type $KeyPropType
                    }
                }
            }
            else {
                switch ($KeyPropName) {
                    "DumpType" {
                        New-ItemProperty -Path $this._KeyPath -Name $KeyPropName -Value $this._DumpType -PropertyType $KeyPropType
                    }
                    "DumpFolder" {
                        New-ItemProperty -Path $this._KeyPath -Name $KeyPropName -Value $this.DumpFolder -PropertyType $KeyPropType
                    }
                    "DumpCount" {
                        New-ItemProperty -Path $this._KeyPath -Name $KeyPropName -Value $this.DumpCount -PropertyType $KeyPropType
                    }
                    "CustomDumpFlags" {
                        New-ItemProperty -Path $this._KeyPath -Name $KeyPropName -Value $this._CustomDumpFlags -PropertyType $KeyPropType
                    }
                }
            }
        }
    }
}
#endregion

#region PRIVATE

function Process-WERKey {
    [CmdletBinding()]
    param(
        [string]$AppName,
        [string]$KeyPath
    )

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
    if ($DumpsKey.DumpType) { $Config._DumpType = $DumpsKey.DumpType }
    $Config.DumpFolder = if ($DumpsKey.DumpFolder) { $DumpsKey.DumpFolder } else { "%LOCALAPPDATA%\CrashDumps" }
    $Config.DumpCount = if ($DumpsKey.DumpCount) { $DumpsKey.DumpCount } else { 10 }

    if ($Config.DumpType -eq "CustomDump" -and $DumpsKey.CustomDumpFlags) {
        $ParsedFlags = ""
        foreach ($FlagString in $Script:CustomDumpFlagArray) {
            $FlagSplit = $FlagString.Split("!")
            $FlagName = $FlagSplit[0]
            $FlagValue = $FlagSplit[1]
            if ($DumpsKey.CustomDumpFlags -band $FlagValue) {
                $ParsedFlags += "$FlagName|"
            }
        }
        if ($ParsedFlags[-1] -eq '|') { $ParsedFlags = $ParsedFlags.Substring(0, $ParsedFlags.Length - 1) }
        $Config.CustomDumpFlags = $ParsedFlags
        $Config._CustomDumpFlags = $DumpsKey.CustomDumpFlags
    }
    else {
        $Config.CustomDumpFlags = "NONE"
    }

    return $Config
}

#endregion


#region PUBLIC

function Get-WERConfig {
    [CmdletBinding()]
    param(
        $AppName
    )
    Write-Verbose "Processing Global Key $Script:WERRoot"
    Process-WERKey -KeyPath $Script:WERRoot -AppName "GLOBAL"
    Write-Verbose "Checking for specific app config"
    (Get-ChildItem $Script:WERRoot).Name | ForEach-Object {
        $KeyPath = $_
        Write-Verbose "Processing $KeyPath"
        Process-WERKey -KeyPath "Registry::$KeyPath" -AppName $KeyPath.Substring($KeyPath.LastIndexOf("\") + 1)
    }
}
#endregion

function Set-WERConfig {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = "Named")]
        [string]$AppName = "",
        [Parameter(ParameterSetName = "Pipeline",
            ValueFromPipeLine = $true)]
        [WERConfig]$InputObject,
        [Parameter(ParameterSetName = "Named")]
        [ValidateSet("CustomDump", "MiniDump", "FullDump")]
        [string]$DumpType,
        [Parameter(ParameterSetName = "Named")]
        [string]$DumpFolder,
        [Parameter(ParameterSetName = "Named")]
        [uint]$DumpCount,
        [Parameter(ParameterSetName = "Named")]
        [uint]$CustomDumpFlags
    )
    Write-Verbose "AppName $AppName"
    $KeyPath = $Script:WERRoot
    $WERConfig
    if ($AppName -eq "") {
        $WERConfig = Process-WERKey -AppName "GLOBAL" -KeyPath $KeyPath
    }
    elseif ($AppName) {
        # Normalizing the AppName
        if (!$AppName.EndsWith(".exe")) { $AppName += ".exe" }
        $KeyPath += "\$AppName"
        if (!Test-Path $KeyPath) {
            throw "$KeyPath not found"
        }
        $WERConfig = Process-WERKey -AppName $AppName -KeyPath $KeyPath
    }

    $WERConfig.SetDumpType($DumpType)
    $WERConfig.DumpCount = $DumpCount
    $WERConfig.DumpFolder = $DumpFolder

    if ($DumpType -eq "CustomDump") {
        # TODO(wiaftrin): Add flag validation
        $WERConfig._CustomDumpFlags = $_CustomDumpFlags
    }

    # TODO(wiaftrin): Fix this
    try {
        $WERConfig.WriteToRegistry()
    }
    catch {
        Write-Error
    }

}

function Get-WERInfo {
    Get-WERConfig | Format-Table
    Get-WinEvent -FilterHashTable @{LogName = "Application"; Id = 1001 } -MaxEvents 3
}