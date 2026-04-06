# Shared bootstrap helper for znelchar wrapper scripts.
# Dot-source this file from any script in the scripts/ directory to make
# Resolve-ZnelcharModuleManifest available before importing the module.

function Resolve-ZnelcharModuleManifest {
    # Module distribution layout: Znelchar.Tools.psd1 sits one level above scripts/
    $packagedManifest = Join-Path $PSScriptRoot '../Znelchar.Tools.psd1'
    if (Test-Path -LiteralPath $packagedManifest) {
        return (Resolve-Path $packagedManifest).Path
    }

    # Portable distribution and dev layout: manifest lives inside module/Znelchar.Tools/
    $devManifest = Join-Path $PSScriptRoot '../module/Znelchar.Tools/Znelchar.Tools.psd1'
    if (Test-Path -LiteralPath $devManifest) {
        return (Resolve-Path $devManifest).Path
    }

    throw 'Could not locate Znelchar.Tools module manifest.'
}
