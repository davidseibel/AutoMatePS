function Get-AMUser {
    <#
        .SYNOPSIS
            Gets AutoMate Enterprise users.

        .DESCRIPTION
            Get-AMUser gets user objects from AutoMate Enterprise.  Get-AMUser can receive items on the pipeline and return related objects.

        .PARAMETER InputObject
            The object(s) to use in search for users.

        .PARAMETER Name
            The name of the user (case sensitive).  Wildcard characters can be escaped using the ` character.  If using escaped wildcards, the string
            must be wrapped in single quotes.  For example: Get-AMUser -Name '`[Test`]'

        .PARAMETER ID
            The ID of the user.

        .PARAMETER FilterSet
            The parameters to filter the search on.  Supply hashtable(s) with the following properties: Property, Operator, Value.
            Valid values for the Operator are: =, !=, <, >, contains (default - no need to supply Operator when using 'contains')

        .PARAMETER FilterSetMode
            If multiple filter sets are provided, FilterSetMode determines if the filter sets should be evaluated with an AND or an OR

        .PARAMETER SortProperty
            The object property to sort results on.  Do not use ConnectionAlias, since it is a custom property added by this module, and not exposed in the API.

        .PARAMETER SortDescending
            If specified, this will sort the output on the specified SortProperty in descending order.  Otherwise, ascending order is assumed.

        .PARAMETER Connection
            The AutoMate Enterprise management server.

        .INPUTS
            Users related to the following objects can be retrieved by this function:
            UserGroup
            Folder

        .OUTPUTS
            User

        .EXAMPLE
            # Get user "MyUsername"
            Get-AMUser "MyUsername"

        .EXAMPLE
            # Get users in user group "group01"
            Get-AMUserGroup "group01" | Get-AMUser

        .EXAMPLE
            # Get users using filter sets
            Get-AMAgent -FilterSet @{ Property = "Enabled"; Operator = "="; Value = "true"}

        .NOTES
            Author(s):     : David Seibel
            Contributor(s) :
            Date Created   : 07/26/2018
            Date Modified  : 11/15/2018

        .LINK
            https://github.com/davidseibel/AutoMatePS
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    [OutputType([System.Object[]])]
    param (
        [Parameter(ValueFromPipeline = $true, ParameterSetName = "ByPipeline")]
        [ValidateNotNullOrEmpty()]
        $InputObject,

        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = "ByID")]
        [ValidateNotNullOrEmpty()]
        [string]$ID,

        [ValidateNotNullOrEmpty()]
        [Hashtable[]]$FilterSet,

        [ValidateSet("And","Or")]
        [string]$FilterSetMode = "And",

        [ValidateNotNullOrEmpty()]
        [string[]]$SortProperty = "Name",

        [ValidateNotNullOrEmpty()]
        [switch]$SortDescending = $false,

        [ValidateNotNullOrEmpty()]
        $Connection
    )

    BEGIN {
        # If the server is specified, or only 1 server is connected, don't show it.  Otherwise, show the server.
        if ($PSCmdlet.ParameterSetName -eq "ByID" -and (-not $PSBoundParameters.ContainsKey("Connection")) -and ((Get-AMConnection).Count -gt 1)) {
            throw "When searching by ID: 1) Connection must be specified, OR 2) only one server can be connected."
        }
        $splat = @{
            RestMethod = "Get"
        }
        if ($PSBoundParameters.ContainsKey("Connection")) {
            $Connection = Get-AMConnection -Connection $Connection
            $splat.Add("Connection",$Connection)
        }
        $result = @()
        $userCache = @{}
        if ($PSBoundParameters.ContainsKey("Name") -and (-not [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name))) {
            $FilterSet += @{Property = "Name"; Operator = "="; Value = [System.Management.Automation.WildcardPattern]::Unescape($Name)}
        } elseif ($PSBoundParameters.ContainsKey("Name") -and [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name)) {
            try   { "" -like $Name | Out-Null } # Test wildcard string
            catch { throw }                     # Throw error if wildcard invalid
            $splat += @{ FilterScript = {$_.Name -like $Name} }
        }
    }

    PROCESS {
        switch($PSCmdlet.ParameterSetName) {
            "All" {
                $splat += @{ Resource = Format-AMUri -Path "users/list" -FilterSet $FilterSet -FilterSetMode $FilterSetMode -SortProperty $SortProperty -SortDescending:$SortDescending.ToBool() }
                $result = Invoke-AMRestMethod @splat
            }
            "ByID" {
                $splat += @{ Resource = "users/$ID/get" }
                $result = Invoke-AMRestMethod @splat
            }
            "ByPipeline" {
                foreach ($obj in $InputObject) {
                    $tempSplat = $splat
                    if (-not $tempSplat.ContainsKey("Connection")) {
                        $tempSplat += @{ Connection = $obj.ConnectionAlias }
                    } else {
                        $tempSplat["Connection"] = $obj.ConnectionAlias
                    }
                    if (-not $userCache.ContainsKey($obj.ConnectionAlias)) {
                        Write-Verbose "Caching user objects for server $($obj.ConnectionAlias) for better performance"
                        $userCache.Add($obj.ConnectionAlias, (Get-AMUser -FilterSet $FilterSet -FilterSetMode $FilterSetMode -SortProperty $SortProperty -SortDescending:$SortDescending.ToBool() -Connection $obj.ConnectionAlias))
                    }
                    Write-Verbose "Processing $($obj.Type) '$($obj.Name)'"
                    switch ($obj.Type) {
                        "UserGroup" {
                            # Get users contained within the provided user group(s)
                            foreach ($userID in $obj.UserIDs) {
                                $result += $userCache[$obj.ConnectionAlias] | Where-Object {$_.ID -eq $userID}
                            }
                        }
                        "Folder" {
                            # Get the user for the specified "user" folder
                            if ($obj.Path -like "\WORKFLOWS*") {
                                Write-Verbose "Getting user whose user folder for workflows is $(Join-Path -Path $obj.Path -ChildPath $obj.Name)..."
                                $result += $userCache[$obj.ConnectionAlias] | Where-Object {$_.WorkflowFolderID -eq $obj.ID}
                            } elseif ($obj.Path -like "\TASKS*") {
                                Write-Verbose "Getting user whose user folder for tasks is $(Join-Path -Path $obj.Path -ChildPath $obj.Name)..."
                                $result += $userCache[$obj.ConnectionAlias] | Where-Object {$_.TaskFolderID -eq $obj.ID}
                            } elseif ($obj.Path -like "\CONDITIONS*") {
                                Write-Verbose "Getting user whose user folder for conditions is $(Join-Path -Path $obj.Path -ChildPath $obj.Name)..."
                                $result += $userCache[$obj.ConnectionAlias] | Where-Object {$_.ConditionFolderID -eq $obj.ID}
                            } elseif ($obj.Path -like "\PROCESSES*") {
                                Write-Verbose "Getting user whose user folder for processes is $(Join-Path -Path $obj.Path -ChildPath $obj.Name)..."
                                $result += $userCache[$obj.ConnectionAlias] | Where-Object {$_.ProcessFolderID -eq $obj.ID}
                            } elseif (($obj.Path -like "\USERS*") -or ($obj.Path -eq "\" -and $obj.Name -eq "USERS")) {
                                # Get users contained within the provided folder(s)
                                Write-Verbose "Getting users contained in folder $(Join-Path -Path $obj.Path -ChildPath $obj.Name)..."
                                $result += $userCache[$obj.ConnectionAlias] | Where-Object {$_.ParentID -eq $obj.ID}
                            } else {
                                Write-Warning "Invalid folder type (Path: $(Join-Path -Path $obj.Path -ChildPath $obj.Name))!"
                            }
                        }
                        "SystemPermission" {
                            $result += Get-AMUser -ID $obj.GroupID
                        }
                        default {
                            $unsupportedType = $obj.GetType().FullName
                            if ($_) {
                                $unsupportedType = $_
                            } elseif (-not [string]::IsNullOrEmpty($obj.Type)) {
                                $unsupportedType = $obj.Type
                            }
                            Write-Error -Message "Unsupported input type '$unsupportedType' encountered!" -TargetObject $obj
                        }
                    }
                }
            }
        }
    }

    END {
        $SortProperty += "ConnectionAlias", "ID"
        return $result | Sort-Object $SortProperty -Unique -Descending:$SortDescending.ToBool()
    }
}
