param
(
    [Switch]$Finalize
)

function Get-EnvironmentInfo
{
    $Lookup = @{
        378389 = [version]'4.5'
        378675 = [version]'4.5.1'
        378758 = [version]'4.5.1'
        379893 = [version]'4.5.2'
        393295 = [version]'4.6'
        393297 = [version]'4.6'
        394254 = [version]'4.6.1'
        394271 = [version]'4.6.1'
        394802 = [version]'4.6.2'
        394806 = [version]'4.6.2'
        460798 = [version]'4.7'
        460805 = [version]'4.7'
        461308 = [version]'4.7.1'
        461310 = [version]'4.7.1'
        461808 = [version]'4.7.2'
        461814 = [version]'4.7.2'
    }

    # For extra effect we could get the Windows 10 OS version and build release id:
    try
    {
        $WinRelease, $WinVer = Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" ReleaseId, CurrentMajorVersionNumber, CurrentMinorVersionNumber, CurrentBuildNumber, UBR
        $WindowsVersion = "$($WinVer -join '.') ($WinRelease)"
    }
    catch
    {
        $WindowsVersion = [System.Environment]::OSVersion.Version
    }

    Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse |
        Get-ItemProperty -Name Version, Release -ErrorAction SilentlyContinue |
        # For The One True framework (latest .NET 4x), change match to PSChildName -eq "Full":
    Where-Object { $_.PSChildName -eq "Full"} |
        Select-Object @{name = ".NET Framework"; expression = {$_.PSChildName}},
    @{name = "Product"; expression = {$Lookup[$_.Release]}},
    Version, Release,
    # Some OPTIONAL extra output: PSComputerName and WindowsVersion
    # The Computer name, so output from local machines will match remote machines:
    @{ name = "PSComputerName"; expression = {$Env:Computername}},
    # The Windows Version (works on Windows 10, at least):
    @{ name = "WindowsVersion"; expression = { $WindowsVersion }},
    @{ name = "PSVersion"; expression = { $PSVersionTable.PSVersion }}
}

# Initialize
$TestFile = "TestResultsPS{0}.xml" -f $PSVersionTable.PSVersion
#$VerbosePreference = 'Continue'

# Run a test with the current version of PowerShell
if (!$Finalize)
{
    "[Progress] Testing On:"
    ((Get-EnvironmentInfo) | Out-String).Trim()
    . .\Install.ps1
    Invoke-Pester -OutputFile $TestFile
}
else # Finalize
{
    '[Progress] Finalizing'
    $Failure = $false
    # Upload results for test page
    Get-ChildItem -Path '.\TestResultsPS*.xml' | Foreach-Object {
        $Address = 'https://ci.appveyor.com/api/testresults/nunit/{0}' -f $env:APPVEYOR_JOB_ID
        $Source = $_.FullName
        "[Output] Uploading Files: $Address, $Source"
        [System.Net.WebClient]::new().UploadFile($Address, $Source)

        if (([Xml](Get-Content -Path $Source)).'test-results'.failures -ne '0')
        {
            $Failure = $true
        }
    }
    if ($Failure)
    {
        throw 'Tests failed'
    }
}