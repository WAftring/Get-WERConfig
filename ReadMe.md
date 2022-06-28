# Overview

This module acts as a wrapper around the registry settings for Windows Error Reporting (WER).

The module supports global WER configurations as well as specific application configurations.

# Install

The module can be installed from the PowerShell Gallery using the following command in PowerShell:

```powershell
Install-Module -Name Get-WERConfig
```

# Usage

## Get-WERConfig

Get the current WER configuration. `-AppName` supports wildcards. Use `-AppName All` to display all configurations.

## Set-WERConfig

*Requires run as administrator*

Update an existing WER configuration. This function supports the PowerShell pipeline.

## New-WERConfig

*Requires run as administrator*

Creates a new WER configuration.

## Remove-WERConfig

*Requires run as administrator*

Removes an existing WER configuration. If the global configuration is removed all app specific configurations will also be removed.

## Get-WERInfo

Displays all WER configurations and displays the last 5 application crashes from the Windows Application EventLog.

```powershell
$ Get-WERInfo

AppName DumpType DumpFolder                DumpCount CustomDumpFlags DumpTypeValue KeyPath
------- -------- ----------                --------- --------------- ------------- -------
GLOBAL  MiniDump %LOCALAPPDATA%\CrashDumps        10               0             1 Registry::HKEY_LOCAL_MACHINE\SOFTWA…


   ProviderName: Windows Error Reporting

TimeCreated          Id LevelDisplayName Message
-----------          -- ---------------- -------
6/26/2022 22:43:00 1001 Information      Fault bucket 2020166421524484167, type 4…
6/23/2022 10:47:19 1001 Information      Fault bucket 1466619447997080460, type 4…
6/22/2022 15:33:53 1001 Information      Fault bucket 125730739576, type 5…
6/22/2022 08:18:50 1001 Information      Fault bucket 1718606572004173045, type 5…
6/22/2022 08:18:50 1001 Information      Fault bucket 1316385779437571683, type 5…
```