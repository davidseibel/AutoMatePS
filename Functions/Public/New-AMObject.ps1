function New-AMObject {
    <#
        .SYNOPSIS
            Creates an Automate object.

        .DESCRIPTION
            New-AMObject receives new Automate object(s) on the pipeline, or via the parameter $InputObject, and creates the objects.

        .PARAMETER InputObject
            The object(s) to be created.

        .PARAMETER Connection
            The server to create the object on.

        .INPUTS
            The following objects can be created by this function:
            Workflow
            Task
            Process
            TaskAgent
            ProcessAgent
            AgentGroup
            User
            UserGroup

        .LINK
            https://github.com/AutomatePS/AutomatePS/blob/master/Docs/New-AMObject.md
    #>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter([AMConnectionCompleter])]
        $Connection
    )

    BEGIN {
        $Connection = Get-AMConnection -Connection $Connection
    }

    PROCESS {
        foreach ($obj in $InputObject) {
            $type = [AMConstructType]$obj.Type
            $splat = @{
                Resource = "$(([AMTypeDictionary]::($type)).RestResource)/create"
                RestMethod = "Post"
                Body = $obj.ToJson()
                Connection = $Connection
            }
            if ($PSCmdlet.ShouldProcess($Connection.Name, "Creating $($type): $(Join-Path -Path $obj.Path -ChildPath $obj.Name)")) {
                Invoke-AMRestMethod @splat | Out-Null
                Write-Verbose "Created $($type): $(Join-Path -Path $obj.Path -ChildPath $obj.Name) on server $($Connection.Name) ($($Connection.Alias))."
                Get-AMObject -ID $obj.ID -Types $type -Connection $Connection
            }
        }
    }
}
