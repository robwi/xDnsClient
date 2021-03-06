$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\xDnsClientHelper.psm1 -Verbose:$false -ErrorAction Stop


function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [ValidateSet("A","AAAA")]
        [System.String]
        $Type,

        [parameter(Mandatory = $true)]
        [System.String[]]
        $Value,

        [System.Boolean]
        $Register,

        [Uint64]
        $RetryIntervalSec = 1, 

        [Uint32]
        $RetryCount = 0
    )

    $returnValue = @{
        Name = $Name
        Type = $Type
        Value = $Value
    }

    $returnValue
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [ValidateSet("A","AAAA")]
        [System.String]
        $Type,

        [parameter(Mandatory = $true)]
        [System.String[]]
        $Value,

        [System.Boolean]
        $Register,

        [Uint64]
        $RetryIntervalSec = 1, 

        [Uint32]
        $RetryCount = 0
    )

    for($count = 0; $count -lt $RetryCount; $count++)
    {
        if($Register)
        {
            Write-Verbose -Message 'Executing Register-DnsClient'
            Register-DnsClient
        }
        if(Test-TargetResource @PSBoundParameters)
        {
            break
        }
        else
        {
            if(($count + 1) -lt $RetryCount)
            {
                Write-Verbose -Message "$Name not correct in DNS. Will retry again after $RetryIntervalSec sec"
                Start-Sleep -Seconds $RetryIntervalSec
            }
        }
    }

    if(!(Test-TargetResource @PSBoundParameters))
    {
        throw New-TerminatingError -ErrorType ResourceNotInDesiredStateAfterWait -ErrorCategory InvalidResult
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [ValidateSet("A","AAAA")]
        [System.String]
        $Type,

        [parameter(Mandatory = $true)]
        [System.String[]]
        $Value,

        [System.Boolean]
        $Register,

        [Uint64]
        $RetryIntervalSec = 1, 

        [Uint32]
        $RetryCount = 0
    )

    $Domain = (Get-CimInstance -ClassName Win32_ComputerSystem -Verbose:$false).Domain
    $DnsResponse = Resolve-DnsName -Name "$Name.$Domain" -Type $Type -DnsOnly -Verbose:$false -ErrorAction SilentlyContinue

    if($DnsResponse)
    {
        # Additional types may be added later which have a different response property
        switch($Type)
        {
            'A'
            {
                $DnsValue = $DnsResponse.IPAddress
            }
            'AAAA'
            {
                $DnsValue = $DnsResponse.IPAddress
            }
        }
        $result = $true
        foreach($TestValue in $Value)
        {
            if($DnsValue -notcontains $TestValue)
            {
                Write-Verbose "$Name in DNS does not include $TestValue"
                $result = $false
            }
        }
    }
    else
    {
        Write-Verbose "$Name is not registered in DNS"
        $result = $false
    }
    
    $result
}


Export-ModuleMember -Function *-TargetResource