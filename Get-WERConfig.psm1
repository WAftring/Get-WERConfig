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
    [uint]$DumpCount
    [string]$CustomDumpFlags
    [uint]$DumpTypeValue
    [uint]$CustomDumpFlagsValue
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
                        # NOTE(wiaftrin): reg add doesn't see to run into permissions issues...
                        Set-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.DumpTypeValue -ErrorAction Stop
                    }
                    "DumpFolder" {
                        Set-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.DumpFolder -ErrorAction Stop
                    }
                    "DumpCount" {
                        Set-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.DumpCount -ErrorAction Stop
                    }
                    "CustomDumpFlags" {
                        Set-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this._CustomDumpFlag -ErrorAction Stop
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
                        New-ItemProperty -Path $this.KeyPath -Name $KeyPropName -Value $this.CustomDumpFlagsValue -PropertyType $KeyPropType
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
    $Config.DumpTypeValue = if ($DumpsKey.DumpType) { $DumpsKey.DumpType } else { 1 }
    $Config.DumpFolder = if ($DumpsKey.DumpFolder) { $DumpsKey.DumpFolder } else { "%LOCALAPPDATA%\CrashDumps" }
    $Config.DumpCount = if ($DumpsKey.DumpCount) { $DumpsKey.DumpCount } else { 10 }

    Write-Verbose "Checking custom dump flags"
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
        $Config.CustomDumpFlagsValue = $DumpsKey.CustomDumpFlags
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
    if (Test-Path $Script:WERRoot) {
        Process-WERKey -KeyPath $Script:WERRoot -AppName "GLOBAL"
    }
    Write-Verbose "Checking for specific app config"
    (Get-ChildItem $Script:WERRoot -ErrorAction SilentlyContinue).Name | ForEach-Object {
        $KeyPath = $_
        Write-Verbose "Processing $KeyPath"
        Process-WERKey -KeyPath "Registry::$KeyPath" -AppName $KeyPath.Substring($KeyPath.LastIndexOf("\") + 1)
    }
}
#endregion

function Set-WERConfig {
    [CmdletBinding()]
    param(
        [string]$AppName = "GLOBAL",
        [ValidateSet("CustomDump", "MiniDump", "FullDump")]
        [string]$DumpType,
        [string]$DumpFolder,
        [uint]$DumpCount,
        [uint]$CustomDumpFlags
    )

    Write-Verbose "AppName $AppName"
    $KeyPath = $Script:WERRoot
    $WERConfig = ""
    if ($AppName -eq "GLOBAL") {
        if (!(Test-Path $KeyPath)) {
            Write-Error "$KeyPath not found" -ErrorAction Stop
        }
        $WERConfig = Process-WERKey -AppName $AppName -KeyPath $KeyPath
    }
    elseif ($AppName) {
        # Normalizing the AppName
        if (!$AppName.EndsWith(".exe")) { $AppName += ".exe" }
        $KeyPath += "\$AppName"
        if (!(Test-Path $KeyPath)) {
            Write-Error "$KeyPath not found" -ErrorAction Stop
        }
        $WERConfig = Process-WERKey -AppName $AppName -KeyPath $KeyPath
    }

    if ($DumpType) { $WERConfig.SetDumpType($DumpType) }
    if ($DumpCount) { $WERConfig.DumpCount = $DumpCount }
    if ($DumpFolder) { $WERConfig.DumpFolder = $DumpFolder }

    if ($DumpType -eq "CustomDump") {
        # TODO(wiaftrin): Add flag validation
        $WERConfig.CustomDumpFlagsValue = $CustomDumpFlagsValue
    }

    try { $WERConfig.WriteToRegistry() }
    catch { Write-Error $_ -ErrorAction Stop }

}

function New-WERConfig {
    [CmdletBinding()]
    param(
        [string]$AppName = "GLOBAL",
        [ValidateSet("CustomDump", "MiniDump", "FullDump")]
        [string]$DumpType,
        [string]$DumpFolder,
        [uint]$DumpCount,
        [uint]$CustomDumpFlags
    )

    Write-Verbose "AppName $AppName"
    $KeyPath = $Script:WERRoot
    if ($AppName -ne "GLOBAL") {
        if (!$AppName.EndsWith(".exe")) { $AppName += ".exe" }
        $KeyPath += "\$AppName"
    }

    Write-Verbose "Checking if $KeyPath exists"
    if (Test-Path $KeyPath) { Write-Error "$KeyPath already exists" -ErrorAction Stop }
    New-Item $KeyPath -Force | Out-Null

    $WERConfig = [WERConfig]::new($KeyPath)
    $WERConfig.SetDumpType($DumpType)
    $WERConfig.DumpFolder = $DumpFolder
    $WERConfig.DumpCount = $DumpCount
    if ($DumpType -eq "CustomDumpType") {
        $WERConfig.CustomDumpFlagsValue = $CustomDumpFlags
    }

    try { $WERConfig.WriteToRegistry() }
    catch { Write-Error $_ -ErrorAction Stop }
}

function Remove-WERConfig {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High", DefaultParameterSetName = "Individual")]
    param(
        [Parameter(ParameterSetName = "Individual")]
        [string]$AppName = "GLOBAL",
        [Parameter(ParameterSetName = "Pipeline")]
        [WERConfig]$InputObject = $null,
        [switch]$Force
    )

    $OldSetting = $ConfirmPreference

    if ($Force) {
        $ConfirmPreference = "None"
    }

    if ($null -ne $InputObject) {
        $AppName = $InputObject.AppName
    }

    Write-Verbose "AppName $AppName"
    $KeyPath = $Script:WERRoot
    if ($AppName -eq "GLOBAL") {
        Write-Warning "Removing the global WER settings will remove all application specific settings"
        if (!$PSCmdlet.ShouldProcess("Global WER Configuration")) {
            return
        }
    }
    else {
        if (!$AppName.EndsWith(".exe")) { $AppName += ".exe" }
        $KeyPath += "\$AppName"
    }

    Remove-Item $KeyPath
    $ConfirmPreference = $OldSetting
}

function Get-WERInfo {
    Get-WERConfig | Format-Table
    Get-WinEvent -FilterHashTable @{LogName = "Application"; Id = 1001 } -MaxEvents 3
}