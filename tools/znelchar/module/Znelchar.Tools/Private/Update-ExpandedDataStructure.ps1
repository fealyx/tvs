<#
.SYNOPSIS
Migrates expanded character data structure between schema versions.

.DESCRIPTION
Handles schema version mismatches by migrating the expanded data folder structure
from one version to another. When Compress-ZnelcharData detects a version mismatch,
it throws an error instructing the user to run this function manually before retrying.

Currently, only v1 is implemented. Migration infrastructure is in place for future versions.

.PARAMETER InputPath
The folder containing the expanded data structure.

.PARAMETER FromVersion
The current schema version of the expanded data.

.PARAMETER ToVersion
The target schema version (default: latest).

.PARAMETER OutputPath
Optional output folder for migrated structure. If not specified, migrates in-place (with backup).

.PARAMETER Force
Overwrite existing output if it exists.

.EXAMPLE
# Migrate from v1 to v2
Update-ExpandedDataStructure -InputPath character-expanded -FromVersion 1 -ToVersion 2

.NOTES
Internal use within Znelchar.Tools module.
Migration is performed in-place with automatic backup by default.
#>

function Update-ExpandedDataStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,

        [Parameter(Mandatory = $true)]
        [int]$FromVersion,

        [int]$ToVersion = 1,  # Latest version

        [string]$OutputPath,

        [switch]$Force
    )

    process {
        if (-not (Test-Path -LiteralPath $InputPath -PathType Container)) {
            throw "Input path not found or is not a directory: $InputPath"
        }

        # If no output path specified, create backup and migrate in-place
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $backupPath = "$InputPath.backup.$timestamp"
            Write-Verbose "Creating backup at: $backupPath"
            Copy-Item -Path $InputPath -Destination $backupPath -Recurse
            $OutputPath = $InputPath
        } elseif ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
            throw "Output path already exists: $OutputPath. Use -Force to overwrite."
        }

        # Validate versions
        if ($FromVersion -eq $ToVersion) {
            Write-Verbose "Source and target versions are the same. No migration needed."
            return @{ 
                SourceVersion = $FromVersion
                TargetVersion = $ToVersion
                MigratedPath = $OutputPath
                ChangesApplied = @()
            }
        }

        $changes = @()

        # Apply migration chain from FromVersion to ToVersion
        $currentVersion = $FromVersion
        while ($currentVersion -lt $ToVersion) {
            $nextVersion = $currentVersion + 1
            Write-Verbose "Migrating from v$currentVersion to v$nextVersion..."

            $result = InvokeSchemaMigration -InputPath $InputPath -FromVersion $currentVersion -ToVersion $nextVersion
            $changes += $result.Changes
            
            $currentVersion = $nextVersion
        }

        # Update metadata with new version
        $metadataPath = Join-Path -Path $InputPath -ChildPath '_metadata.yaml'
        if (Test-Path -LiteralPath $metadataPath) {
            $metadata = Read-DataFile -Path $metadataPath
            $metadata.schemaVersion = $ToVersion
            Write-DataFile -InputObject $metadata -OutputPath $metadataPath -Force
            $changes += "Updated _metadata.yaml schemaVersion to $ToVersion"
        }

        return @{
            SourceVersion = $FromVersion
            TargetVersion = $ToVersion
            MigratedPath = $OutputPath
            ChangesApplied = $changes
        }
    }
}

function InvokeSchemaMigration {
    [CmdletBinding()]
    param(
        [string]$InputPath,
        [int]$FromVersion,
        [int]$ToVersion
    )

    $changes = @()

    # Define migration logic for each version transition
    switch ("$FromVersion-$ToVersion") {
        "1-2" {
            # Example: v1->v2 migration logic would go here
            # For now, no changes needed (future-proofing)
            Write-Verbose "No changes defined for v1->v2 migration yet."
            break
        }
        default {
            throw "No migration path defined from v$FromVersion to v$ToVersion"
        }
    }

    return @{ Changes = $changes }
}

