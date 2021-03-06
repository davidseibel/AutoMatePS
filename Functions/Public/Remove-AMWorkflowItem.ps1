function Remove-AMWorkflowItem {
    <#
        .SYNOPSIS
            Removes an item from an Automate workflow

        .DESCRIPTION
            Remove-AMWorkflowItem can remove items from a workflow object.

        .PARAMETER InputObject
            The item object to remove.

        .PARAMETER ID
            The ID of the item to remove (if passing in a workflow).

        .INPUTS
            The following Automate object types can be modified by this function:
            Workflow
            WorkflowItem
            WorkflowTrigger

        .OUTPUTS
            None

        .EXAMPLE
            # Remove all triggers from workflow "Some Workflow"
            (Get-AMWorkflow "Some Workflow").Triggers | Remove-AMWorkflowItem

        .LINK
            https://github.com/AutomatePS/AutomatePS/blob/master/Docs/Remove-AMWorkflowItem.md
    #>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Medium")]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $InputObject,

        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ID
    )

    PROCESS {
        :objectloop foreach ($obj in $InputObject) {
            $shouldUpdate = $false
            switch ($obj.Type) {
                "Workflow" {
                    $updateObject = Get-AMWorkflow -ID $obj.ID -Connection $obj.ConnectionAlias
                    if (($updateObject | Measure-Object).Count -eq 1) {
                        $updateObject.Items = @($updateObject.Items | Where-Object {$_.ID -ne $ID})
                        $updateObject.Triggers = @($updateObject.Triggers | Where-Object {$_.ID -ne $ID})
                        $updateObject.Links = @($updateObject.Links | Where-Object {$_.SourceID -ne $ID -and $_.DestinationID -ne $ID})
                        $shouldUpdate = $true
                    } else {
                        Write-Warning "Multiple workflows found for ID $($obj.ID)! No action will be taken."
                        continue objectloop
                    }
                }
                {$_ -in "WorkflowCondition","WorkflowItem","WorkflowTrigger"} {
                    $updateObject = Get-AMObject -ID $obj.WorkflowID -Types Workflow
                    if (($updateObject | Measure-Object).Count -eq 1) {
                        $updateObject.Items = @($updateObject.Items | Where-Object {$_.ID -ne $obj.ID})
                        $updateObject.Triggers = @($updateObject.Triggers | Where-Object {$_.ID -ne $obj.ID})
                        $updateObject.Links = @($updateObject.Links | Where-Object {$_.SourceID -ne $obj.ID -and $_.DestinationID -ne $obj.ID})
                        $shouldUpdate = $true
                    } else {
                        Write-Warning "Multiple workflows found for ID $($obj.WorkflowID)! No action will be taken."
                        continue objectloop
                    }
                }
                default {
                    Write-Error -Message "Unsupported input type '$($obj.Type)' encountered!" -TargetObject $obj
                }
            }
            if ($shouldUpdate) {
                $updateObject | Set-AMObject
            } else {
                Write-Verbose "$($updateObject.Type) '$($updateObject.Name)' does not contain a link with ID $($obj.ID)."
            }
        }
    }
}