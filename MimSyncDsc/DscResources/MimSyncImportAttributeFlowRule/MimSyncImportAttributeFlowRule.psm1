﻿## This assembly is expected to be in the 'DscResources' folder for this module
Add-Type -Path (Join-Path (Split-Path $PSScriptRoot) xmldiffpatch.dll)

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$ManagementAgentName,

		[parameter(Mandatory = $true)]
		[System.String]
		$MVObjectType,

		[parameter(Mandatory = $true)]
		[System.String]
		$MVAttribute,

		[parameter(Mandatory = $true)]
		[System.String]
		$CDObjectType,

        [parameter(Mandatory = $true)]
		[String]
		$Type
	)
    ### Check the schema cache and update if necessary
    Write-MimSyncConfigCache -Verbose

    ### Find an MA XML by Name
    $maDataXml = Select-Xml -Path (Join-Path (Get-MimSyncConfigCache) *.xml)-XPath "//ma-data[name='$ManagementAgentName']" | Select-Object -First 1
    $managementAgentID = $maDataXml.Node.id

    ### Get the XML from the server configuration files
    Write-Verbose "Finding import attribute flow rule [$ManagementAgentName].$CDObjectType.[$($SrcAttribute -Join ',')] --> MV.$MVObjectType.[$MVAttribute] ..."    
    $xPathFilter = "//mv-data/import-attribute-flow/import-flow-set[@mv-object-type='$MVObjectType']/import-flows[@mv-attribute='$MVAttribute']/import-flow[@src-ma='$managementAgentID' and @cd-object-type='$CDObjectType' and $Type]"
    Write-Verbose "  Using XPath: $xPathFilter"
    $fimSyncObject = Select-Xml -Path (Join-Path (Get-MimSyncConfigCache) mv.xml) -XPath $xPathFilter

    if (-not $fimSyncObject)
    {
        ### No matching object so return nothing
        return
    }

    $fimSrcAttributes = @()
    foreach($fimSrcAttribute in Select-Xml -Xml $fimSyncObject.Node -XPath '*/src-attribute')
    {
        $fimSrcAttributes += $fimSrcAttribute
    }

    $outputObject = @{
		ManagementAgentName  = $ManagementAgentName
        CDObjectType         = $CDObjectType
        MVObjectType         = $MVObjectType
        MVAttribute          = $MVAttribute
        Type                 = $Type
        ID                   = $fimSyncObject.Node.ID
    }

    if ($Type -eq 'scripted-mapping')
    {
        $outputObject.Add('ScriptContext',$fimSyncObject.Node.'scripted-mapping'.'script-context')
        $outputObject.Add('SrcAttribute', $fimSrcAttributes)
    }
    if ($Type -eq 'direct-mapping')
    {
        $outputObject.Add('SrcAttribute', $fimSrcAttributes)
    }
    if ($Type -eq 'constant-mapping')
    {
        $outputObject.Add('ConstantValue', $fimSyncObject.Node.'constant-mapping'.'constant-value')
    }
    if ($Type -eq 'dn-part-mapping')
    {
        $outputObject.Add('DNPart', $fimSyncObject.Node.'dn-part-mapping'.'dn-part')
    }

    Write-Output $outputObject
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$ManagementAgentName,

		[parameter(Mandatory = $true)]
		[System.String]
		$MVObjectType,

		[parameter(Mandatory = $true)]
		[System.String]
		$MVAttribute,

		[parameter(Mandatory = $true)]
		[System.String]
		$CDObjectType,

        [parameter(Mandatory = $true)]
		[String]
		$Type,

        [String[]]
        $SrcAttribute,

        [String]
        $ConstantValue,

        [Uint16]
        $DNPart,

        [String]
        $ScriptContext,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)
    Write-Warning "DSC resources for the Synchronization Service are not able to update the Synchronization configuration."
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$ManagementAgentName,

		[parameter(Mandatory = $true)]
		[System.String]
		$MVObjectType,

		[parameter(Mandatory = $true)]
		[System.String]
		$MVAttribute,

		[parameter(Mandatory = $true)]
		[System.String]
		$CDObjectType,

        [parameter(Mandatory = $true)]
		[String]
		$Type,

        [String[]]
        $SrcAttribute,

        [String]
        $ConstantValue,

        [Uint16]
        $DNPart,

        [String]
        $ScriptContext,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)
    ### Check the schema cache and update if necessary
    Write-MimSyncConfigCache -Verbose

    ### Find an MA XML by Name
    $maDataXml = Select-Xml -Path (Join-Path (Get-FimSyncConfigCache) *.xml)-XPath "//ma-data[name='$ManagementAgentName']" | Select-Object -First 1
    $managementAgentID = $maDataXml.Node.id

    ### Get the XML from the server configuration files
    Write-Verbose "Finding import attribute flow rule [$ManagementAgentName].$CDObjectType.[$($SrcAttribute -Join ',')] --> MV.$MVObjectType.[$MVAttribute] ..."    
    $xPathFilter = "//mv-data/import-attribute-flow/import-flow-set[@mv-object-type='$MVObjectType']/import-flows[@mv-attribute='$MVAttribute']/import-flow[@src-ma='$managementAgentID' and @cd-object-type='$CDObjectType' and $Type]"
    Write-Verbose "  Using XPath: $xPathFilter"
    $fimSyncObject = Select-Xml -Path (Join-Path (Get-MimSyncConfigCache) mv.xml) -XPath $xPathFilter

    $objectsAreTheSame = $true

    if ($Ensure -eq 'Present')
    {
        if ($fimSyncObject -eq $null)
        {
            Write-Verbose "Attribute flow rule not found: $Name."
            $objectsAreTheSame = $false
        }
        else
        {
            Write-Verbose "Attribute flow rule found, diffing the properties..."

            #region Compare type
            Write-Verbose "  Comparing property 'type'"
            if ($fimSyncObject.Node.'direct-mapping')
            {
                $fimMappingType = 'direct-mapping'
            }
            elseif ($fimSyncObject.Node.'scripted-mapping')
            {
                $fimMappingType = 'scripted-mapping'
            }
            elseif ($fimSyncObject.Node.'constant-mapping')
            {
                $fimMappingType = 'constant-mapping'
            }
            elseif ($fimSyncObject.Node.'dn-part-mapping')
            {
                $fimMappingType = 'dn-part-mapping'
            }
            elseif ($fimSyncObject.Node.'sync-rule-mapping')
            {
                $fimMappingType = 'sync-rule-mapping'
            }
            else
            {
                Write-Error "Unexpected rule type"
            }

            Write-Verbose "    From DSC: $Type"
            Write-Verbose "    From MIM: $fimMappingType"
            if ($Type -ne $fimMappingType)
            {
                Write-Warning "  'type' property is not the same."
                $objectsAreTheSame = $false
            }
            #endregion

            #region Compare cd-object-type
            Write-Verbose "  Comparing property 'cd-object-type'"
            Write-Verbose "    From DSC: $CDObjectType"
            Write-Verbose "    From MIM: $($fimSyncObject.Node.'cd-object-type')"
            if ($fimSyncObject.Node.'cd-object-type' -ne $CDObjectType)
            {
                Write-Warning "  'cd-object-type' property is not the same."
                $objectsAreTheSame = $false
            }
            #endregion

            #region Compare script-context
            if ($Type -eq 'scripted-mapping')
            {
                Write-Verbose "  Comparing property 'script-context'"
                Write-Verbose "    From DSC: $ScriptContext"
                Write-Verbose "    From MIM: $($fimSyncObject.Node.'scripted-mapping'.'script-context')"
                if ($fimSyncObject.Node.'scripted-mapping'.'script-context' -ne $ScriptContext)
                {
                    Write-Warning "  'script-context' property is not the same."
                    $objectsAreTheSame = $false
                }
            }
            #endregion

            #region Compare src-attribute
            if ($Type -in 'scripted-mapping','direct-mapping')
            {
                $fimSrcAttributes = @()
                foreach($fimSrcAttribute in Select-Xml -Xml $fimSyncObject.Node -XPath '*/src-attribute')
                {
                    $fimSrcAttributes += $fimSrcAttribute
                }
                Write-Verbose "  Comparing property 'src-attribute'"
                Write-Verbose "    From DSC: $($SrcAttribute -join ',')"
                Write-Verbose "    From MIM: $($fimSrcAttributes -join ',')"
                if (Compare-Object -ReferenceObject $SrcAttribute -DifferenceObject $fimSrcAttributes )
                {
                    Write-Warning "  'src-attribute' property is not the same."
                    $objectsAreTheSame = $false
                }
            }
            #endregion

            #region Compare constant-value
            if ($Type -eq 'constant-mapping')
            {
                Write-Verbose "  Comparing property 'constant-mapping'"
                Write-Verbose "    From DSC: $ConstantValue"
                Write-Verbose "    From MIM: $($fimSyncObject.Node.'constant-mapping'.'constant-value')"
                if ($fimSyncObject.Node.'constant-mapping'.'constant-value' -ne $ConstantValue)
                {
                    Write-Warning "  'constant-value' property is not the same."
                    $objectsAreTheSame = $false
                }
            }
            #endregion

            #region Compare dn-part
            if ($Type -eq 'dn-part-mapping')
            {
                Write-Verbose "  Comparing property 'dn-part'"
                Write-Verbose "    From DSC: $DNPart"
                Write-Verbose "    From MIM: $($fimSyncObject.Node.'dn-part-mapping'.'dn-part')"
                if ($fimSyncObject.Node.'dn-part-mapping'.'dn-part' -ne $DNPart)
                {
                    Write-Warning "  'dn-part' property is not the same."
                    $objectsAreTheSame = $false
                }
            }
            #endregion

            $objectsAreTheSame = $objectsAreTheSame
        }
    }
    elseif($Ensure -eq 'Absent')
    {
        if ($fimSyncObject -ne $null)
        {
            Write-Warning "Attribute flow rule found ($Name) but is supposed to be Absent. DESTROY!!!"
            $objectsAreTheSame = $false
        }
        else
        {
            $objectsAreTheSame = $true
        }
    }
    else
    {
        Write-Error "Expected the 'Ensure' parameter to be 'Present' or 'Absent'"
    }

    if ($objectsAreTheSame -eq $false)
    {
        $currentObject = Get-TargetResource -ManagementAgentName $ManagementAgentName -MVObjectType $MVObjectType -MVAttribute $MVAttribute -CDObjectType $CDObjectType -Type $Type
        Write-MimSyncDscAuditObject -FimXpathFilter $xPathFilter -ObjectTestResult $objectsAreTheSame -DscBoundParameters $PSBoundParameters -CurrentObject $currentObject
    }

    Write-Verbose "Returning: $objectsAreTheSame"
    return $objectsAreTheSame
}

Export-ModuleMember -Function *-TargetResource