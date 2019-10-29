<#
Office ProPlus Architecture Detection Script for Intune 
Version 1.0
Last Update - 10/29/2019

PURPOSE
    This script is used to detect the architecture of Office ProPlus
    that is installed on a computer. It will report back to Intune 
    success/failure depending on the architecture searched for.

USE
    Set the desired architecture to search for using the $DesiredArch variable
    and then deploy the script using Intune. Any device with the desired architecture
    will have a Success status. Any other architecture will return a Failed status.

VARIABLES
    $DesiredArch - Sets the Office architecture to search for.
        x86 - 32-bit
        x64 - 64-bit 
#>

#Variables
$DesiredArch = "x86"

If ((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration).Platform -eq $DesiredArch){
    Write-Host "Desired Office ProPlus architecture found - $DesiredArch"
    Exit 0
}
Else{
    Write-Error -Message "Could not find desired architecture - $DesiredArch"
    Exit 1
}