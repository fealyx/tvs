function Get-ZnelcharToolRoot {
    $moduleRoot = $script:ZnelcharModuleRoot

    if (Test-Path -LiteralPath (Join-Path $moduleRoot 'scripts')) {
        return $moduleRoot
    }

    $devRoot = [System.IO.Path]::GetFullPath((Join-Path $moduleRoot '../..'))
    if (Test-Path -LiteralPath (Join-Path $devRoot 'scripts')) {
        return $devRoot
    }

    # Fallback: use schemas/ as an alternative structural marker when scripts/ is absent
    if (Test-Path -LiteralPath (Join-Path $moduleRoot 'schemas')) {
        return $moduleRoot
    }

    if (Test-Path -LiteralPath (Join-Path $devRoot 'schemas')) {
        return $devRoot
    }

    throw 'Could not resolve znelchar tool root.'
}
