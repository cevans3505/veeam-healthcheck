Clear-Host
# *************** SETTINGS *************** #
$global:DEBUG = $true
$global:SKIP_COLLECT = $false
$global:EXPORT_JSON = $false
$global:EXPORT_XML = $false
$global:OUTPUT_PATH = "C:\temp\vHC\VB365"
$global:REPORTING_INTERVAL_DAYS = 7
$global:VBO_SERVER_FQDN_OR_IP = "drt-vbo-1.drt.davidtosoff.com."
# *************** END SETTINGS *************** #

<#
function Function-Template {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]$Object,
        [string]$Prop
        )
    begin { }
    process {
        
    }
    end { }
}
#>

function Write-LogFile {
    [CmdletBinding()]
    param (
        [string]$Message,
        [ValidateSet("Main","Errors")][string]$LogName="Main"
        )
    begin { }
    process {
        (get-date).ToString("yyyy-MM-dd hh:mm:ss") + "`t-`t" + $Message | Out-File -FilePath ($global:OUTPUT_PATH.Trim('\') + "\Collector" + $LogName + ".log") -Append
    }
    end { }
}


function Write-MemoryUsageToLog {
    [CmdletBinding()]
    param (
        [string]$Message,
        [ValidateSet("Main","Errors")][string]$LogName="Main"
        )
    begin { }
    process {
        $memUsageAfter = (Get-Process -id $pid).WS

        Write-LogFile -Message ("New memory allocated since last message ($message): " + (($MemUsageAfter-$global:MemUsageBefore)/1MB).ToString("0.00 MB")) -LogName $LogName

        $global:MemUsageBefore = $memUsageAfter
    }
    end { }
}

function Lap {
    [CmdletBinding()]
    param (
        [string]$Note
        )
    begin { }
    process {

        $message = "$($Note): $($stopwatch.Elapsed.TotalSeconds)"
        
        if ($global:DEBUG) {
            Write-Host -ForegroundColor Yellow $message
        }

        Write-LogFile -Message $message
        $stopwatch.Reset()
        $stopwatch.Start()
    }
    end { }
}

function Join([string[]]$array, $Delimiter=", ") {
    #$output = ""
    #foreach ($item in $array) {
    #    $output += $item + ", "
    #}
    #return $output
    return $array -join $Delimiter
}


function Expand-Expression {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]$BaseObject,
        [string[]]$Expressions
        )
    begin { }
    process {
        $results = @()

        foreach ($Expression in $Expressions) {
            $expandedExpression = $Expression
            $result = [pscustomobject]@{ColumnName="";Value=""}
            
            if ($Expression.Contains("=>")) {
                $split = $Expression.Split(@("=>"), [StringSplitOptions]::RemoveEmptyEntries)
                $result.ColumnName = $split[0]
                $expandedExpression = $split[1].Replace('$.','$BaseObject.')
            } else {
                $result.ColumnName = $Expression.Replace('$.','')

                #$expandedExpression = '$.'+$Expression
            }

            if ($expandedExpression.Replace(" ","").Contains('+"')) {
                $regSplit = [regex]::Split($expandedExpression,'\+\s?".+"\s?\+')

                foreach ($propName in $regSplit) {
                    if ($propName.StartsWith('$.')) {
                        $expandedExpression.Replace('$.','$BaseObject.')
                    } elseif ($propName.Contains('$') -or $propName.Contains('(')) {
                        # do nothing
                    } else {
                        $expandedExpression = $expandedExpression.Replace($propName,'$BaseObject.'+$propName)
                    }
                }
            } else {
                if ($Expression.Contains('$') -or $Expression.Contains('(')) {
                    #complex expression
                    #do nothing.
                } else {
                    #single property
                    $expandedExpression = '$.'+$expandedExpression
                }
            }

            $expandedExpression = $expandedExpression.Replace('$.','$BaseObject.').Replace('$BaseObject. ','$BaseObject ')

            try {
                $result.Value = Invoke-Expression $expandedExpression

                if ($null -eq $result.value -and $null -ne $BaseObject) {
                    
                    $message = "$expression produced no result."
                    if ($global:DEBUG) { 
                        Write-Warning $message
                    }

                    Write-LogFile -Message $message
                    Write-LogFile -Message $message -LogName Errors
                    Write-LogFile -Message "`tExpanded Expression: $expandedExpression" -LogName Errors
                }
            } catch {

                $message = "$expression not valid."
                if ($global:DEBUG) { 
                    Write-Warning "$expression not valid."
                    ($Error | Select-Object -Last 1).ToString()
                }

                Write-LogFile -Message $message
                Write-LogFile -Message $message -LogName Errors
                Write-LogFile -Message "`tExpanded Expression: $expandedExpression" -LogName Errors
                Write-LogFile -Message ($Error | Select-Object -Last 1).ToString() -LogName Errors

                $result.Value = $null;

            }

            $results += $result
        }

        return $results
    }
    end { }
}

function New-DataTableEntry {
    [CmdletBinding()]
    param (
        [string[]]$PropertyNames,
        [Parameter(ValueFromPipeline)]$Object
        )
    begin { }
    process {
        $OutputObject = New-Object -TypeName pscustomobject

        $parsedResults = Expand-Expression -BaseObject $Object -Expressions $PropertyNames

        foreach ($result in $parsedResults) {
            
            $OutputObject | Add-Member -MemberType NoteProperty -Name $result.ColumnName -Value $result.Value

        }

        return $OutputObject
    }
    end { }
}


function Import-VMCFile {
    [CmdletBinding()]
    param ()
    begin {
        $LogPath = Get-Item -Path ($env:ProgramData+'\Veeam\Backup365\Logs')
    }
    process {
        $VmcFiles = $LogPath.GetFiles('*VB*_VMC*')
        $LatestVmcFile = $VmcFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $VmcContents = (Get-Content $LatestVmcFile.FullName -Raw)

        $StartIndex = $VmcContents.LastIndexOf("Product: [Veeam") 
        $LatestDetailsTxt = $VmcContents.Substring($StartIndex,$VmcContents.Length-$StartIndex) -replace '\[\d+\.\d+\.\d+\s\d+\:\d+\:\d+\]\s\<\d+\>\s\w+\s{1,5}(=+[\w\s]+=+)?',''   
        $LatestDetails = $LatestDetailsTxt.Split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries)

        function Convert-VMCLineToObject($VMCLine) {
            if (!$VMCLine.Trim().StartsWith('{')) {
                $VMCLine = "{ " + $VMCLine + " }"
            }
            return ($VMCLine -replace '([\da-zA-Z]{8}-([\da-zA-Z]{4}-){3}[\da-zA-Z]{12})','"$1"' -replace "(?<!:\s{\s)(:\s)(\[)?(\w)",'$1$2"$3' -replace '(?<![}\]\"])(,\s[A-Z]|\s}|\])','"$0') | ConvertFrom-Json
        }

        $result = [ordered]@{}
        $result.ProductDetails = @()
        $result.LicenseDetails = @()
        $result.HostDetails = @()
        $result.SettingsDetails = @()
        $result.InfraCounts = @()
        $result.ProductDetails = @()
        $result.OrgDetails = @()
        $result.ProxyDetails = @()
        $result.RepoDetails = @()
        $result.ObjectDetails = @()
        $result.JobDetails = @()
        

        foreach ($line in $LatestDetails) {
            switch ($line.Substring(0,$line.IndexOf(':'))) {
                "Product" {$result.ProductDetails += Convert-VMCLineToObject -VMCLine $line; break}
                "License" {$result.LicenseDetails += Convert-VMCLineToObject -VMCLine $line; break}
                "HostID" {
                    $result.HostDetails += Convert-VMCLineToObject -VMCLine $line; break}
                "UpdatesAutoCheckEnabled" {$result.SettingsDetails += Convert-VMCLineToObject -VMCLine $line; break}
                "Backup Infrastructure counts" {$result.InfraCounts += Convert-VMCLineToObject -VMCLine ($line.Replace("Backup Infrastructure counts: ","")); break}
                "OrganizationID" {$result.OrgDetails += Convert-VMCLineToObject -VMCLine $line; break}
                "ProxyID" {
                    $result.ProxyDetails += Convert-VMCLineToObject -VMCLine $line; break}
                "RepositoryID" {$result.RepoDetails += Convert-VMCLineToObject -VMCLine $line; break}
                "ObjStgID" {$result.ObjectDetails += Convert-VMCLineToObject -VMCLine $line; break}
                "JobID" {$result.JobDetails += Convert-VMCLineToObject -VMCLine $line; break}
                Default {Write-Host "uncaptured: $Line"}
            }
        }

        return $result
        
    }
    end {
        
    }
}

function Import-PermissionsFromLogs {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)][Veeam.Archiver.PowerShell.Model.VBOJob[]]$Jobs
        )
    begin {
        $LogPath = Get-Item -Path ($env:ProgramData+'\Veeam\Backup365\Logs')
        $Permissions = [ordered]@{}

        function Add-PermissionsFromLog ([string[]]$LogPaths,[ValidateSet("Backup","Restore")]$Prefix) {
            foreach ($logFilePath in $logPaths) {
                $content = Get-Content -Path  $logFilePath -TotalCount 1000
                $hasDoneAtLeastOneOperation = ($content | Select-String "Token found").Count -gt 0

                $orgNames = (($content | Select-String "(.+Counting items in: |.+Tenant: )(.+)(\s\(.+\)\s\(.+\).+|, Auth.+)") -replace "(.+Counting items in: |.+Tenant: )(.+)(\s\(.+\)\s\(.+\).+|, Auth.+)",'$2' | Group-Object).Name

                foreach ($orgName in $orgNames) {
                    $permName = $Prefix + " - " + $orgName + ": No operations run"
                    if (!$hasDoneAtLeastOneOperation -and ($Permissions.Keys -match ($Prefix + " - " + $orgName)).Count -eq 0) {
                        $Permissions.$permName = [PSCustomObject]@{Type=$Prefix; Organization=$orgName; API=""; Permission="No backup/restore operations found"}
                    } else {
                        $permissionStrs = (($content | Select-String "Token found with the following permissions") -replace ".+Token found with the following permissions\: (.+)",': $1' -replace "(.+), Microsoft API: (.+)",'$2$1')
                        $impersonationCheck = $null -ne ($content | Select-String "The account does not have permission to impersonate the requested user")

                        if ($null -ne $Permissions.$permName -and $permissionStrs.Count -gt 0) {
                            $Permissions.Remove($permName)
                        }

                        if ($impersonationCheck -eq $true) {
                            $permName = $Prefix + " - " + $orgName + ": ApplicationImpersonation"
                            $Permissions.$permName = [PSCustomObject]@{Type="Restore"; Organization=$orgName; API="Exchange"; Permission="ApplicationImpersonation"}
                        }

                        foreach ($permStr in $permissionStrs) {
                            $API = $permStr.Split(':')[0].Trim()

                            $perms = $permStr.Split(':')[1].Split(",").Trim()

                            foreach ($perm in $perms) {
                                $permName = $Prefix + " - " + $orgName + ": " + $perm
                                $permValue = [PSCustomObject]@{Type=$Prefix; Organization=$orgName; API=$API; Permission=$perm}
                                if ($null -eq $Permissions.$permName) {
                                    $Permissions.$permName = $permValue
                                } else {
                                    $Permissions.$permName.Type = $Prefix
                                    $Permissions.$permName.Organization = $orgName
                                    $Permissions.$permName.API = if ($API -ne "" -and $null -ne $API) { $API } else { $Permissions.$permName.API }
                                    $Permissions.$permName.Permission = $perm
                                }
                            }
                        }
                    }
                }
            }

            $content = ""
            [GC]::Collect()
        }
    }
    process {
        $latestLogs = @{}
        $VEXLogPath = Get-Item ($LogPath.FullName+"\..\..\Backup\ExchangeExplorer\Logs")
        $VESPLogPath = Get-Item ($LogPath.FullName+"\..\..\Backup\SharePointExplorer\Logs")
        $VEODLogPath = Get-Item ($LogPath.FullName+"\..\..\Backup\OneDriveExplorer\Logs")
        $VETLogPath = Get-Item ($LogPath.FullName+"\..\..\Backup\TeamsExplorer\Logs")
        $latestLogs.VEX = Get-ChildItem -Path $VEXLogPath -Recurse -File -Filter "Veeam.Exchange.Explorer_*.log" | Select-Object Name, LastWriteTime,FullName | Sort-Object LastWriteTime -Descending | Select-Object -First 5
        $latestLogs.VESP = Get-ChildItem -Path $VESPLogPath -Recurse -File -Filter "Veeam.SharePoint.Explorer_*.log" | Select-Object Name, LastWriteTime,FullName | Sort-Object LastWriteTime -Descending | Select-Object -First 5
        $latestLogs.VEOD = Get-ChildItem -Path $VEODLogPath -Recurse -File -Filter "Veeam.OneDrive.Explorer_*.log" | Select-Object Name, LastWriteTime,FullName | Sort-Object LastWriteTime -Descending | Select-Object -First 5
        $latestLogs.VET = Get-ChildItem -Path $VETLogPath -Recurse -File -Filter "Veeam.Teams.Explorer_*.log" | Select-Object Name, LastWriteTime,FullName | Sort-Object LastWriteTime -Descending | Select-Object -First 5

        Add-PermissionsFromLog -LogPath $latestLogs.VEX.FullName -Prefix Restore
        Add-PermissionsFromLog -LogPath $latestLogs.VESP.FullName -Prefix Restore
        Add-PermissionsFromLog -LogPath $latestLogs.VEOD.FullName -Prefix Restore
        Add-PermissionsFromLog -LogPath $latestLogs.VET.FullName -Prefix Restore

        foreach ($job in $Jobs) {
            $JobLogPaths = Get-Item ($LogPath.FullName+"\"+$job.Organization.name+"\"+$job.Name),($LogPath.FullName+"\"+$job.Organization.OfficeName+"\"+$job.Name) -ErrorAction SilentlyContinue

            
            $latestBackupLog = Get-ChildItem -Path $JobLogPaths -Recurse -File -Filter "Job.$($job.Name)_*.log" | Select-Object Name, LastWriteTime,FullName | Sort-Object LastWriteTime -Descending | Select-Object -First 1

            Add-PermissionsFromLog -LogPath $latestBackupLog.FullName -Prefix Backup
        }
    }
    end {
        return $Permissions
    }
}

# Collect one large object w/ all stats
function Get-VBOEnvironment {
    [CmdletBinding()]
    param (
        )
    begin { }
    process {
        $e = [ordered]@{}

        $progress=0
        $progressSplat = @{Id=1; Activity="Collecting VBO Environment`'s stats..."}
        

        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Starting...";

        #Org settings:
        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Collecting organization..."
        $e.VBOOrganization = Get-VBOOrganization
            # we can optionally collect user, site, group,team org info. excluded for now: https://helpcenter.veeam.com/docs/vbo365/powershell/organization_items.html?ver=60
        $e.VBOApplication = $e.VBOOrganization | Get-VBOApplication
        $e.VBOBackupApplication = $e.VBOOrganization `
            | Where-Object {$_.Office365ExchangeConnectionSettings.AuthenticationType -ne [Veeam.Archiver.PowerShell.Model.Enums.VBOOffice365AuthenticationType]::Basic} `
            | Get-VBOBackupApplication
        Write-MemoryUsageToLog -Message "Org collected"

        #infra settings:
        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Collecting backup infrastructure..."
        $e.VBOServerComponents = Get-VBOServerComponents
        $e.VBORepository = Get-VBORepository
        $e.VBOObjectStorageRepository = Get-VBOObjectStorageRepository
        $e.VBOProxy = Get-VBOProxy
        $e.AzureInstance = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01"
        Write-MemoryUsageToLog -Message "Infra collected"

        #Archiver applainces
        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Collecting object storage & cloud settings..."
        #$e.VBOAmazonInstanceType = Get-VBOAmazonInstanceType # these archiver settings need more work to collect https://helpcenter.veeam.com/docs/vbo365/powershell/get-vboamazoninstancetype.html?ver=60
        #$e.VBOAmazonSecurityGroup = Get-VBOAmazonSecurityGroup
        #$e.VBOAmazonSubnet = Get-VBOAmazonSubnet
        #$e.VBOAmazonVPC = Get-VBOAmazonVPC
        #$e.VBOAzureLocation = Get-VBOAzureLocation
        #$e.VBOAzureResourceGroup = Get-VBOAzureResourceGroup
        #$e.VBOAzureSubNet = Get-VBOAzureSubNet
        #$e.VBOAzureVirtualMachineSize = Get-VBOAzureVirtualMachineSize
        #$e.VBOAzureVirtualNetwork = Get-VBOAzureVirtualNetwork
        #Object details
        $e.VBOAzureBlobAccount = Get-VBOAzureBlobAccount
        $e.VBOAzureServiceAccount = Get-VBOAzureServiceAccount
        #$e.VBOAzureSubscription = Get-VBOAzureSubscription
        #$e.VBOAzureBlobFolder = Get-VBOAzureBlobFolder
        $e.VBOAmazonS3Account = Get-VBOAmazonS3Account
        $e.VBOAmazonS3CompatibleAccount = Get-VBOAmazonS3CompatibleAccount
        #$e.VBOAmazonS3Bucket = Get-VBOAmazonS3Bucket
        #$e.VBOAmazonS3Folder = Get-VBOAmazonS3Folder
        $e.VBOEncryptionKey = Get-VBOEncryptionKey
        Write-MemoryUsageToLog -Message "Object & cloud collected"

        #jobs
        Lap "Collection: Job settings..."
        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Collecting Job settings..."
        $e.VBOJob = Get-VBOJob
        $e.VBOBackupItem = $e.VBOJob | ForEach-Object { Get-VBOBackupItem -Job $_ | Select-Object @{n="Job";e={$_.Name}},*}
        $e.VBOBackupItem = $e.VBOJob | ForEach-Object { Get-VBOExcludedBackupItem -Job $_ | Select-Object @{n="Job";e={$_.Name}},*}
        $e.VBOOrganizationRetentionExclusion = $e.VBOOrganization | ForEach-Object { Get-VBOOrganizationRetentionExclusion -Organization $_ | Select-Object @{n="Job";e={$_}},*}
        $e.VBOCopyJob = Get-VBOCopyJob
        Write-MemoryUsageToLog -Message "Jobs collected"

        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Collecting entity details..."
        #$e.VBOEntityData = [Veeam.Archiver.PowerShell.Cmdlets.DataManagement.VBOEntityDataType].GetEnumNames() `
        #    | ForEach-Object { $e.VBORepository | Get-VBOEntityData -Type $_ -WarningAction SilentlyContinue} | select *,@{n="Repository",} #slow/long-running
        $e.VBOEntityData = $(
            foreach ($repo in $e.VBORepository) {
                foreach ($entityType in @('Mailbox','OneDrive','Group','Site','Team')) { #[Veeam.Archiver.PowerShell.Cmdlets.DataManagement.VBOEntityDataType].GetEnumNames()
                    $repo | Get-VBOEntityData -Type $entityType -WarningAction SilentlyContinue | Select-Object *,@{n="Repository";e={@{Id=$repo.Id;Name=$repo.Name}}},@{n="Proxy";e={$proxy=($e.VBOProxy | Where-Object { $_.id -eq $repo.ProxyId}); @{Id=$proxy.Id;Name=$proxy.Hostname}}} #slow/long-running
                }
            }
        )
        Write-MemoryUsageToLog -Message "Entities collected"

        #backups
        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Collecting restore points..."
        $e.VBORestorePoint = Get-VBORestorePoint
        Write-MemoryUsageToLog -Message "RPs collected"
        #Global
        Lap "Collection: Global settings..."
        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Collecting global settings..."
        $e.VBOLicense = Get-VBOLicense
        $e.VBOLicensedUser = Get-VBOLicensedUser
        $e.VBOFolderExclusions = Get-VBOFolderExclusions
        $e.VBOGlobalRetentionExclusion = Get-VBOGlobalRetentionExclusion
        $e.VBOEmailSettings = Get-VBOEmailSettings
        $e.VBOHistorySettings = Get-VBOHistorySettings
        $e.VBOInternetProxySettings = Get-VBOInternetProxySettings
        Write-MemoryUsageToLog -Message "Global collected"
        #security
        Lap "Collection: Security settings..."
        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Collecting security settings..."
        $e.VBOTenantAuthenticationSettings = Get-VBOTenantAuthenticationSettings
        $e.VBORestorePortalSettings = Get-VBORestorePortalSettings
        $e.VBOOperatorAuthenticationSettings = Get-VBOOperatorAuthenticationSettings
        $e.VBORbacRole = Get-VBORbacRole
        $e.VBORestAPISettings = Get-VBORestAPISettings
        $e.VBOSecuritySettings = Get-VBOSecuritySettings
        Write-MemoryUsageToLog -Message "Security collected"
        
        #stats
        Lap "Collection: Job & session stats..."
        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Collecting sessions & statistics..."
        $e.VBOJobSession = Get-VBOJobSession
        $e.VBORestoreSession = Get-VBORestoreSession
        $e.VBOUsageData = $e.VBORepository | ForEach-Object { Get-VBOUsageData -Repository $_ }
        $e.VBODataRetrievalSession = Get-VBODataRetrievalSession
        Write-MemoryUsageToLog -Message "Sessions & stats collected"

        #reports
        Lap "Collection: Generating Reports..."
        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Generating reports..."
        Get-ChildItem -Path ($global:OUTPUT_PATH + "\Veeam_*Report*.csv") | Remove-Item -Force
        $e.VBOOrganization | ForEach-Object { Get-VBOMailboxProtectionReport -Organization $_ -Path $global:OUTPUT_PATH -Format CSV }
        $e.VBOOrganization | ForEach-Object { Get-VBOStorageConsumptionReport -StartTime (Get-Date).AddDays(-$global:REPORTING_INTERVAL_DAYS) -EndTime (Get-Date) -Path $global:OUTPUT_PATH -Format CSV }
        $e.VBOOrganization | ForEach-Object { Get-VBOLicenseOverviewReport -StartTime (Get-Date).AddDays(-$global:REPORTING_INTERVAL_DAYS) -EndTime (Get-Date) -Path $global:OUTPUT_PATH -Format CSV }
        Write-MemoryUsageToLog -Message "Reports generated"

        Lap "Collection: Parse VMC Log..."
        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Parsing VMC Log..."
        $e.VMCLog = Import-VMCFile
        Write-MemoryUsageToLog -Message "VMC Log Parsed"
        Lap "Collection: Parse Job Logs..."
        Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Parsing Job Log..."
        $e.PermissionsCheck = Import-PermissionsFromLogs -Jobs $e.VBOJob
        Write-MemoryUsageToLog -Message "VMC Job Parsed"

        Write-Progress @progressSplat -PercentComplete 100 -CurrentOperation "Done"
        Start-Sleep -Seconds 1
        Write-Progress @progressSplat -PercentComplete 100 -CurrentOperation "Done" -Completed

        return $e
    }
    end { }
}

############## START OF MAIN EXECUTION  ################
Clear-Host
Disconnect-VBOServer # remove before publishing

# Initial setup
Set-Alias -Name MDE -Value New-DataTableEntry -Force -Option Private -ErrorAction SilentlyContinue
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$Error.Clear()
$global:MemUsageBefore = (Get-Process -id $pid).WS
Write-LogFile ""
Write-LogFile "Starting new VB365 data collection session."
Write-LogFile ""

# Import modules & connect to server
Import-Module -Name Veeam.Archiver.PowerShell,Veeam.Exchange.PowerShell,Veeam.SharePoint.PowerShell,Veeam.Teams.PowerShell
if ($global:VBO_SERVER_FQDN_OR_IP -ne "localhost") {
    if ($null -eq $global:VBO_SERVER_CREDS) {
        $global:VBO_SERVER_CREDS = Get-Credential -Message "Enter authorized VBO Server credentials"
    }
    Connect-VBOServer -Server $global:VBO_SERVER_FQDN_OR_IP -Credential $global:VBO_SERVER_CREDS -ErrorAction Stop;
} else {
    Connect-VBOServer -Server localhost -ErrorAction Stop;
}

#check if path exists
if (!(Test-Path $global:OUTPUT_PATH)) {
    New-Item -ItemType Directory -Path $global:OUTPUT_PATH
}

Lap "Ready to collect"
Write-MemoryUsageToLog -Message "Start"

if (!$global:SKIP_COLLECT) { 
    $WarningPreference = "SilentlyContinue"
    # Start the data collection
    Write-Host "Collecting VBO Environment`'s stats..."
    Write-LogFile "Collecting VBO Environment`'s stats..."

    $Global:VBOEnvironment = Get-VBOEnvironment 
    if ($global:DEBUG) { $v = $Global:VBOEnvironment; $v.Keys; }

    Write-MemoryUsageToLog -Message "Done collecting"
    if ($global:EXPORT_JSON) {
        $VBOEnvironment | ConvertTo-Json -Depth 100 | Out-File ($global:OUTPUT_PATH.Trim('\')+"\VBOEnvironment.json") -Force
        [GC]::Collect()
        Write-MemoryUsageToLog -Message "JSON Exported"
    }
    if ($global:EXPORT_XML) {
        $VBOEnvironment | Export-Clixml -Depth 100 -Path ($global:OUTPUT_PATH.Trim('\')+"\VBOEnvironment.xml") -Force
        [GC]::Collect()
        Write-MemoryUsageToLog -Message "XML Exported"
    }

    $WarningPreference = "continue"
 }

Write-Host "VB365 Environment stats collected."
Write-LogFile "VB365 Environment stats collected."
Lap "Time"


####### FUNCTIONS THAT SUPPORT MAPPING PROCESS ######
#Start processing the data into columns
function Test-CertPKExportable([string]$thumbprint) {
    $isCertDriveExists = Get-PSDrive -Name Cert
    if ($null -ne $isCertDriveExists) {
        $certEntries = Get-ChildItem -Recurse cert:\* | Where-Object {$_.Thumbprint -eq $thumbprint }

        if ($null -ne $certEntries) {
            foreach ($certEntry in $certEntries) {
                if ($certEntries.PrivateKey.CspKeyContainerInfo.Exportable -eq $true) {
                    return $true
                }
            }

            return $false; #if no other return true first, then result to false
        } else {
            return "Failed to find cert."
        }
    }
}
function ConvertData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object[]]$Items,
        [ValidateSet("TB","GB","MB","KB","B","Tb","Gb","Mb","Kb","b")][string]$To,
        [string]$Format="0.0"
    )
    begin { 
        $results = @()
    }
    process {
        foreach ($item in $Items) {
            $result = $item.Replace(" ","")

            $multiplier = if ($Item.IndexOf("B",[StringComparison]::Ordinal) -ge 0 -and $To.IndexOf("b",[StringComparison]::Ordinal) -ge 0) { 1/8 } elseif ($Item.IndexOf("b",[StringComparison]::Ordinal) -ge 0 -and $To.IndexOf("B",[StringComparison]::Ordinal) -ge 0) { 8 } else { 1 }

            $outFormat = $Format
            if ($Format -eq "0.0") {
                $outFormat += " " + $To
                if ($item.Contains("/s")) {
                    $outFormat += "/s"   
                }
            }

            if ([regex]::IsMatch($result,"\d+[Bb](?:/s)?$")) { #is in Bytes/bits
                $result = ($result.Replace("B","").Replace("b","").Replace("/s","")/"$multiplier$to")
            } else {
                $result = ($result.Replace("/s","")/"$multiplier$to")
            }

            if ($resul -eq 0) {
                $results += $null
            } else {
                $results += $result.ToString($outFormat)
            }
        }
    }
    end {
        return $results
    }
}


################################ HERE IS WHERE THE PROPERTY MAPPING STARTS ################################

#USAGE examples:
# 'Name'                                                            :: will populate the column name as "Name", and the value from the passed in object (BaseObject)
# 'Name=>Hostname'                                                  :: will populate the column name as "Name", and the value from "Hostname" property of the passed in object (BaseObject)
# 'Name=>$.Hostname'                                                :: use of "$." is the shorthand for the base object
# 'Listener=>Host + ":" + Port'                                     :: use of an expression that includes '+"' or "+ "' is a simple way to concatenate two or more of the same BaseObject's properties together with a string.
# 'Name=>if (x) { $.Hostname } else { $othervariable.othername }'   :: advanced expression will be evaluated/invoked from the string to a command. You must use the "$." short hand for the BaseObject's properties.
    # This example would set the Name column to either the baseobject's "Hostname" property or to the $othervariable's "othername" property depending on whether X is true.
    # These expressions can be as advanced as you like, as long as they evaluate back to a single result

Write-MemoryUsageToLog -Message "Start Mapping"
$progress=0
$progressSplat = @{Id=2; Activity="Building maps..."}
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Starting...";

$map = [ordered]@{}
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Management Server...";
$map.Controller = $Global:VBOEnvironment.VMCLog.HostDetails | mde @(
    'VB365 Version=>$Global:VBOEnvironment.VMCLog.ProductDetails.Version'
    'OS Version=>OSVersion'
    'RAM=>($.RAMTotalSize/1GB).ToString("0.0 GB")'
    'CPUs=>CPUCount'
    'Proxies Managed=>$VBOEnvironment.VMCLog.InfraCounts.BackupProxiesCount'
    'Repos Managed=>[int]$VBOEnvironment.VMCLog.InfraCounts.BackupRepositoriesCount + [int]$VBOEnvironment.VMCLog.InfraCounts.ObjStgCount'
    'Orgs Managed=>$VBOEnvironment.VMCLog.InfraCounts.OrganizationsCount'
    'Jobs Managed=>$VBOEnvironment.VMCLog.InfraCounts.BackupJobsCount'
    'PowerShell Installed?=>IsPowerShellServiceInstalled'
    'Proxy Installed?=>if ($.IsProxyServiceInstalled -or $.Type -eq "Proxy") { $true } else { $false }'
    'REST Installed?=>IsRestServiceInstalled'
    'Console Installed?=>IsShellServiceInstalled'
    'VM Name=>$Global:VBOEnvironment.AzureInstance.compute.name'
    'VM Location=>if ($null -ne $Global:VBOEnvironment.AzureInstance.compute.location) { $Global:VBOEnvironment.AzureInstance.compute.location + " (Zone " + $Global:VBOEnvironment.AzureInstance.compute.zone + ")" }'
    'VM SKU=>$Global:VBOEnvironment.AzureInstance.compute.sku'
    'VM Size=>$Global:VBOEnvironment.AzureInstance.compute.vmSize'
)
$map.ControllerDrives = Get-PhysicalDisk | mde @(
    'Friendly Name=>FriendlyName'
    'DeviceId'
    'Bus Type=>BusType'
    'Media Type=>MediaType'
    'Manufacturer'
    'Model'
    'Size'
    'Allocated Size=>AllocatedSize'
    'Operational Status=>OperationalStatus'
    'Health Status=>HealthStatus'
    'Boot Drive=>(get-disk | ? { $_.Number -eq $.DeviceId }).IsBoot'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Global...";
$map.Global = $Global:VBOEnvironment.VBOLicense | mde @(
    'License Status=>Status'
    'License Expiry=>ExpirationDate'
    'License Type=>Type'
    'Licensed To=>LicensedTo'
    'License Contact=>ContactPerson'
    'Licensed For=>TotalNumber'
    'Licenses Used=>UsedNumber'
    'Support Expiry=>SupportExpirationDate'
    'Global Folder Exclusions=>Join(($Global:VBOEnvironment.VBOFolderExclusions.psobject.Properties | ? { $_.Value -eq $true}).Name)'
    'Global Ret. Exclusions=>Join(($Global:VBOEnvironment.VBOGlobalRetentionExclusion.psobject.Properties | ? { $_.Value -eq $true}).Name)'
    'Log Retention=>if($Global:VBOEnvironment.VBOHistorySettings.KeepAllSessions) { "Keep All" } else {$Global:VBOEnvironment.VBOHistorySettings.KeepOnlyLastXWeeks }'
    'Notification Enabled=>$Global:VBOEnvironment.VBOEmailSettings.EnableNotification'
    'Notifify On=>Join((($Global:VBOEnvironment.VBOEmailSettings | select NotifyOn*).psobject.Properties | ? { $_.Value -eq $false}).Name)'
    'Automatic Updates?=>$Global:VBOEnvironment.VMCLog.SettingsDetails.UpdatesAutoCheckEnabled'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Security...";
$map.Security = $null | mde @(
    'Win. Firewall Enabled?=>$v = ((Get-NetConnectionProfile).NetworkCategory -replace "Authenticated","" | % {Get-NetFirewallProfile -Name $_}); Join( $v | % { $_.Name +": " + $_.Enabled } )'
    'Internet proxy?=>$v=$Global:VBOEnvironment.VBOInternetProxySettings; if($v.UseInternetProxy) { $v.Host+":"+$v.Port } else { $false}'
    'Server Cert=>$Global:VBOEnvironment.VBOSecuritySettings.CertificateFriendlyName'
    'Server Cert PK Exportable?=>Test-CertPKExportable($Global:VBOEnvironment.VBOSecuritySettings.CertificateThumbprint)'
    'Server Cert Expires=>$Global:VBOEnvironment.VBOSecuritySettings.CertificateExpirationDate'
    'Server Cert Self-Signed?=>$Global:VBOEnvironment.VBOSecuritySettings.CertificateIssuedTo -eq $Global:VBOEnvironment.VBOSecuritySettings.CertificateIssuedBy'
    'API Enabled?=>$Global:VBOEnvironment.VBORestAPISettings.IsServiceEnabled'
    'API Port=>$Global:VBOEnvironment.VBORestAPISettings.HTTPSPort'
    'API Cert=>$Global:VBOEnvironment.VBORestAPISettings.CertificateFriendlyName'
    'API Cert PK Exportable?=>Test-CertPKExportable($Global:VBOEnvironment.VBORestAPISettings.CertificateThumbprint)'
    'API Cert Expires=>$Global:VBOEnvironment.VBORestAPISettings.CertificateExpirationDate'
    'API Cert Self-Signed?=>$Global:VBOEnvironment.VBORestAPISettings.CertificateIssuedTo -eq $global:VBOEnvironment.VBORestAPISettings.CertificateIssuedBy'
    'Tenant Auth Enabled?=>$Global:VBOEnvironment.VBOTenantAuthenticationSettings.AuthenticationEnabled'
    'Tenant Auth Cert=>$Global:VBOEnvironment.VBOTenantAuthenticationSettings.CertificateFriendlyName'
    'Tenant Auth PK Exportable?=>Test-CertPKExportable($Global:VBOEnvironment.VBOTenantAuthenticationSettings.CertificateThumbprint)'
    'Tenant Auth Cert Expires=>$Global:VBOEnvironment.VBOTenantAuthenticationSettings.CertificateExpirationDate'
    'Tenant Auth Cert Self-Signed?=>$Global:VBOEnvironment.VBOTenantAuthenticationSettings.CertificateIssuedTo -eq $global:VBOEnvironment.VBOTenantAuthenticationSettings.CertificateIssuedBy'
    'Restore Portal Enabled?=>$Global:VBOEnvironment.VBORestorePortalSettings.IsServiceEnabled'
    'Restore Portal Cert=>$Global:VBOEnvironment.VBORestorePortalSettings.CertificateFriendlyName'
    'Restore Portal Cert PK Exportable?=>Test-CertPKExportable($Global:VBOEnvironment.VBORestorePortalSettings.CertificateThumbprint)'
    'Restore Portal Cert Expires=>$Global:VBOEnvironment.VBORestorePortalSettings.CertificateExpirationDate'
    'Restore Portal Cert Self-Signed?=>$Global:VBOEnvironment.VBORestorePortalSettings.CertificateIssuedTo -eq $global:VBOEnvironment.VBORestorePortalSettings.CertificateIssuedBy'
    'Operator Auth Enabled?=>$Global:VBOEnvironment.VBOOperatorAuthenticationSettings.AuthenticationEnabled'
    'Operator Auth Cert=>$Global:VBOEnvironment.VBOOperatorAuthenticationSettings.CertificateFriendlyName'
    'Operator Auth Cert PK Exportable?=>Test-CertPKExportable($Global:VBOEnvironment.VBOOperatorAuthenticationSettings.CertificateThumbprint)'
    'Operator Auth Cert Expires=>$Global:VBOEnvironment.VBOOperatorAuthenticationSettings.CertificateExpirationDate'
    'Operator Auth Cert Self-Signed?=>$Global:VBOEnvironment.VBOOperatorAuthenticationSettings.CertificateIssuedTo -eq $global:VBOEnvironment.VBOOperatorAuthenticationSettings.CertificateIssuedBy'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "RBACRoles...";
$map.RBACRoles = $Global:VBOEnvironment.VBORbacRole | mde @(
    'Name'
    'Description'
    'Role Type=>RoleType'
    'Operators=>Join($.Operators.DisplayName)'
    'Selected Items=>Join($.SelectedItems.DisplayName)'
    'Excluded Items=>Join($.ExcludedItems.DisplayName)'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Permissions Check...";
$map.Permissions = $Global:VBOEnvironment.PermissionsCheck.Values | mde @(
    'Type'
    'Organization'
    'API'
    'Permission'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Proxies...";
$map.Proxies = $Global:VBOEnvironment.VBOProxy | mde @(
    'Name=>Hostname'
    'Description'
    'Threads=>ThreadsNumber'
    'Throttling?=>if($.ThrottlingValue -gt 0) { $.ThrottlingValue.ToString() + " " + $.ThrottlingUnit } else { "disabled" }'
    'State'
    'Type'
    'Outdated?=>IsOutdated'
    'Internet Proxy=>InternetProxy.UseInternetProxy'
    'Objects Managed=>($Global:VBOEnvironment.VBOEntityData | ? { $.Id -eq $_.Proxy.Id } | group Proxy,Type | measure-object -Sum Count).Sum'
    'OS Version=>($Global:VBOEnvironment.VMCLog.ProxyDetails | ? { $.Id -eq $_.ProxyID }).OSVersion'
    'RAM=>(($Global:VBOEnvironment.VMCLog.ProxyDetails | ? { $.Id -eq $_.ProxyID }).RAMTotalSize/1GB).ToString("0.0 GB")'
    'CPUs=>($Global:VBOEnvironment.VMCLog.ProxyDetails | ? { $.Id -eq $_.ProxyID }).CPUCount'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Repositories...";
$map.Repositories = $Global:VBOEnvironment.VBORepository | mde @(
    'Bound Proxy=>($Global:VBOEnvironment.VBOProxy | ? { $_.id -eq $.ProxyId }).Hostname'
    'Name'
    'Description'
    'Type=>if($.IsLongTerm) {"Archive"} else {"Primary"}'
    'Path'
    'Object Repo=>ObjectStorageRepository'
    'Encryption?=>EnableObjectStorageEncryption'
    'Out of Sync?=>IsOutOfSync'
    'Outdated?=>IsOutdated'
    'Capacity=>($.Capacity/1TB).ToString("0.00") + " TB"'
    'Local Space Used=>((($Global:VBOEnvironment.VBOUsageData | ? { $_.RepositoryId -eq $.Id}).UsedSpace | measure -Sum).Sum/1GB).ToString("0.00 GB")'
    'Cache Space Used=>((($Global:VBOEnvironment.VBOUsageData | ? { $_.RepositoryId -eq $.Id}).LocalCacheUsedSpace | measure -Sum).Sum/1GB).ToString("0.00 GB")'
    'Object Space Used=>((($Global:VBOEnvironment.VBOUsageData | ? { $_.RepositoryId -eq $.Id}).ObjectStorageUsedSpace | measure -Sum).Sum/1GB).ToString("0.00 GB")'
    'Free=>($.FreeSpace/1TB).ToString("0.00") + " TB"'
    'Retention=>($.RetentionPeriod.ToString() -replace "(Years?)(.+)","`$2 `$1" )+", "+$.RetentionType+", Applied "+$.RetentionFrequencyType'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "ObjectRepositories...";
$map.ObjectRepositories = $Global:VBOEnvironment.VBOObjectStorageRepository | mde @(
    'Name'
    'Description'
    'Cloud=>Type'
    'Type=>if($.IsLongTerm) {"Archive"} else {"Primary"}'
    'Bucket/Container=>if($null -ne $.Folder.Container) { $.Folder.Container } else { $.Folder.Bucket }'
    'Path=>$.Folder.Path'
    'Size Limit=>if($.EnableSizeLimit) { ($.SizeLimit/1024).ToString() + " TB" } else { "Unlimited" }'
    'Used Space=>($.UsedSpace/1TB).ToString("0.00") + " TB"'
    'Free Space=>($.FreeSpace/1TB).ToString("0.00") + " TB"'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Organizations...";
$map.Organizations = $Global:VBOEnvironment.VBOOrganization | mde @(
    'Friendly Name=>Name'
    'Real Name=>OfficeName'
    'Type'
    'Protected Apps=>Join($.BackupParts -replace "Office365","")'
    'EXO Settings=>$.Office365ExchangeConnectionSettings.AuthenticationType.ToString() + " (App: " + ($VBOEnvironment.VBOApplication | ? { $.Office365ExchangeConnectionSettings.ApplicationId -eq $_.Id}).DisplayName + " / User: " + $.Office365ExchangeConnectionSettings.ImpersonationAccountName +")"'
    'EXO App Cert=>$v = Get-ChildItem -Recurse cert:\* | Where-Object {$_.Thumbprint -eq $.Office365ExchangeConnectionSettings.ApplicationCertificateThumbprint}; $v.FriendlyName + " (Self-signed?: " + ($v.Subject -eq $v.Issuer) + ")"'
    'SPO Settings=>$.Office365SharePointConnectionSettings.AuthenticationType.ToString() + " (App: " + ($VBOEnvironment.VBOApplication | ? { $.Office365SharePointConnectionSettings.ApplicationId -eq $_.Id}).DisplayName + " / User: " + $.Office365SharePointConnectionSettings.ImpersonationAccountName +")"'
    'SPO App Cert=>$v = Get-ChildItem -Recurse cert:\* | Where-Object {$_.Thumbprint -eq $.Office365SharePointConnectionSettings.ApplicationCertificateThumbprint}; $v.FriendlyName + " (Self-signed?: " + ($v.Subject -eq $v.Issuer) + ")"'
    'On-Prem Exch Settings=>("Server: " + $.OnPremExchangeConnectionSettings.ServerName + " (" + $.OnPremExchangeConnectionSettings.UserName + ")")'
    'On-Prem SP Settings=>("Server: " + $.OnPremSharePointConnectionSettings.ServerName + " (" + $.OnPremSharePointConnectionSettings.UserName + ")")'
    'Licensed Users=>$.LicensingOptions.LicensedUsersCount'
    'Grant SC Admin=>GrantAccessToSiteCollections'
    'Aux Accounts/Apps=>[math]::Max($.BackupAccounts.Count,$.BackupApplications.Count)'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Jobs...";
$map.Jobs = $Global:VBOEnvironment.VBOJob + $Global:VBOEnvironment.VBOCopyJob | mde @(
    'Organization=>if($null -ne $.Organization) { $.Organization } else { $.BackupJob.Organization }'
    'Name'
    'Description'
    'Job Type=>if ($null -eq $.BackupJob) { "Backup" } else { "Backup Copy" }'
    'Scope Type=>JobBackupType'
    'Selected Items=>$.SelectedItems.Count'
    'Excluded Items=>$.ExcludedItems.Count'
    'Repository'
    'Bound Proxy=>($Global:VBOEnvironment.VBOProxy | ? { $_.id -eq $.Repository.ProxyId }).Hostname'
    'Enabled?=>IsEnabled'
    'Schedule=>if ($.SchedulePolicy.EnableSchedule -or $.SchedulePolicy.Type.ToString() -eq "Immediate") {
        if ($.SchedulePolicy.Type.ToString() -eq "Immediate") {
            "Immediate"
        } elseif ($.SchedulePolicy.Type.ToString() -eq "Daily") {
            $.SchedulePolicy.DailyType.ToString() + " @ " + $.SchedulePolicy.DailyTime.ToString()
        } else {
            $.SchedulePolicy.Type.ToString() + " every " + ($.SchedulePolicy.PeriodicallyEvery.ToString() -replace "(\w+?)(\d+)","`$2 `$1") + " (Window?: " + (($.SchedulePolicy.PeriodicallyWindowSettings.BackupWindow -eq $false).Count -gt 0) + ")"
        }
    } else { "Not scheduled" }'
    'Related Job=>if ($null -eq  $.BackupJob) { $Global:VBOEnvironment.VBOCopyJob.Name | ? { $.Name -in $Global:VBOEnvironment.VBOCopyJob.BackupJob.Name} } else { $.BackupJob.Name }'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "JobStats...";
$map.JobStats = $Global:VBOEnvironment.VBOJobSession | Where-Object { $_.JobName -in $Global:VBOEnvironment.VBOJob.Name} | Group-Object JobName | mde @(
    'Name'
    'Average Duration (min)=>($.Group | select *,@{n="Duration";e={($_.EndTime-$_.CreationTime).TotalMinutes}} | ? { $_.Duration -gt 0 } | measure Duration -Average).Average.ToString("0.00")'
    'Max Duration (min)=>($.Group | select *,@{n="Duration";e={($_.EndTime-$_.CreationTime).TotalMinutes}} | ? { $_.Duration -gt 0 } | measure Duration -Maximum).Maximum.ToString("0.00")'
    'Average Data Transferred=>(($.Group.Statistics.TransferredData | ConvertData -To "GB" -Format "0.0000" | measure -Average).Average.ToString("0.00 GB"))'
    'Max Data Transferred=>(($.Group.Statistics.TransferredData | ConvertData -To "GB" -Format "0.0000" | measure -Maximum).Maximum.ToString("0.00 GB") )'
    'Average Objects (#)=>($.Group.Statistics | measure ProcessedObjects -Average).Average.ToString("0")'
    'Max Objects (#)=>($.Group.Statistics | measure ProcessedObjects -Maximum).Maximum.ToString("0")'
    'Average Processing Rate=>(($.Group.Statistics.ProcessingRate -replace "(\d+.+)\s\((.+)\)","`$1" | ConvertData -To "MB" -Format "0.0000" | measure -Average).Average.ToString("0.00 MB/s"))'
    'Max Processing Rate=>(($.Group.Statistics.ProcessingRate -replace "(\d+.+)\s\((.+)\)","`$1" | ConvertData -To "MB" -Format "0.0000" | measure -Maximum).Maximum.ToString("0.00 MB/s") )'
    'Average Item Proc Rate=>(($.Group.Statistics.ProcessingRate -replace "(\d+.+)\s\((.+)items/s\)","`$2" | measure -Average).Average.ToString("0.0 items/s"))'
    'Max Item Proc Rate=>(($.Group.Statistics.ProcessingRate -replace "(\d+.+)\s\((.+)items/s\)","`$2" | measure -Maximum).Maximum.ToString("0.0 items/s") )'
    'Average Read Rate=>(($.Group.Statistics.ReadRate | ConvertData -To "MB" -Format "0.0000" | measure -Average).Average.ToString("0.00 MB/s"))'
    'Max Read Rate=>(($.Group.Statistics.ReadRate | ConvertData -To "MB" -Format "0.0000" | measure -Maximum).Maximum.ToString("0.00 MB/s") )'
    'Average Write Rate=>(($.Group.Statistics.WriteRate | ConvertData -To "MB" -Format "0.0000" | measure -Average).Average.ToString("0.00 MB/s"))'
    'Max Write Rate=>(($.Group.Statistics.WriteRate | ConvertData -To "MB" -Format "0.0000" | measure -Maximum).Maximum.ToString("0.00 MB/s") )'
    'Typical Bottleneck=>($.Group.Statistics.Bottleneck | ? { $_ -ne "NA" } | group | sort Count -Descending | select -first 1).Name'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "JobSessions...";
$map.JobSessions = $Global:VBOEnvironment.VBOJobSession | Where-Object { $_.JobName -in $Global:VBOEnvironment.VBOJob.Name -and $_.CreationTime -gt (Get-Date).AddDays(-$global:REPORTING_INTERVAL_DAYS)} | Sort-Object @{Expression={$_.JobName}; Descending=$false },@{Expression={$_.CreationTime}; Descending=$true } | mde @(
    'Name=>JobName'
    'Status'
    'Start Time=>$.CreationTime.ToString("yyyy/MM/dd HH:mm:ss")'
    'End Time=>$.EndTime.ToString("yyyy/MM/dd HH:mm:ss")'
    'Duration=>( $. | select *,@{n="Duration";e={($_.EndTime-$_.CreationTime).TotalMinutes}}).Duration.ToString("0.0 min")'
    'Log=>Join -Array $($.Log.Title | ? { !$_.Contains("[Success]") }) -Delimiter "`r`n"'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Protection Status...";
$map.ProtectionStatus = Import-Csv -Path ($global:OUTPUT_PATH + "\Veeam_MailboxProtectionReport*.csv") | Where-Object { $_."Protection Status" -eq "Unprotected"} | Sort-Object "Protection Status",User -Descending | mde @(
    'User=>Mailbox'
    'E-mail=>$."E-mail"'
    'Organization'
    'Protection Status=>$."Protection Status"'
    'Last Backup Date=>$."Last Backup Date"'
)
Write-Progress @progressSplat -PercentComplete ($progress++) -CurrentOperation "Done." -Completed

#VMC log, server components, Cloud accounts and archivers (renebale)
#pull unprotected from report
#strike: encryptionkey


######### END MAPS ############


Lap "Ready to map"

# Build the objects & sections
$Global:HealthCheckResult = MDE $map.Keys

foreach ($sectionName in $map.Keys) {
#foreach ($section in $Global:HealthCheckResult.PSObject.Properties) {
    #$map = Get-Variable -Name ("map_"+$section.Name) -ErrorAction SilentlyContinue -ValueOnly

    $section = $map.$sectionName

    if ($null -eq $section) {
        throw "No map found for: "+$section+". Please define."
        return
    } else {
        if ($section.GetType().Name -eq "PSCustomObject" -or $section.GetType().Name -eq "Object[]") {
            $Global:HealthCheckResult.$sectionName = $section
        } else {
            $Global:HealthCheckResult.$sectionName = MDE $section
        }

        if ($global:DEBUG) {
            Write-Host -ForegroundColor Green "SECTION: $($sectionName.ToUpper())"
            $Global:HealthCheckResult.$sectionName | Format-Table *
        }
    }
}


Lap "Done mapping"
Write-MemoryUsageToLog -Message "Done mapping"


Lap "Ready to Export"

$Global:HealthCheckResult.psobject.Properties.Name | ForEach-Object { $Global:HealthCheckResult.$_ | ConvertTo-Csv -NoTypeInformation | Out-File $($global:OUTPUT_PATH.Trim('\') + "\" +$_+".csv") -Force }

Lap "All done"
Write-MemoryUsageToLog -Message "Done export"

Write-LogFile -Message "All Errors:" -LogName Errors
$Error | ForEach-Object {Write-LogFile -Message ($_.ToString() + "`r`n" + $_.InvocationInfo.Line.ToString() + "`r`n" + $_.ScriptStackTrace.ToString()+ "`r`n" +$_.Exception.StackTrace.ToString()) -LogName Errors }

Write-MemoryUsageToLog -Message "All done"
Write-LogFile -Message $($proc = (get-process -Id $PID); "CPU (s): " + $proc.CPU.ToString() + " / Private Mem (MB): " +$proc.PM/1MB + " / Working Set (MB): " + $proc.WorkingSet/1MB);

$stopwatch.Stop()

[GC]::Collect()

#Extended logging may affect...