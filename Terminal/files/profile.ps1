# PowerShell profile - loads the Nightdrive theme.
# Remove or comment the line below to go back to the stock prompt.

$NightdrivePath = Join-Path $PSScriptRoot 'nightdrive.ps1'
if (Test-Path $NightdrivePath) { . $NightdrivePath }
