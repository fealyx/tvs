function Write-ZnelcharFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$CharacterCompactJson,
        [Parameter(Mandatory = $true)][System.Collections.IEnumerable]$TextureDescriptors,
        [Parameter(Mandatory = $true)][string]$TexturesRoot
    )

    $encoding = [System.Text.UTF8Encoding]::new($false)
    $jsonStringOptions = [System.Text.Json.JsonSerializerOptions]::new()
    $jsonStringOptions.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
    $fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $writer = [System.IO.StreamWriter]::new($fileStream, $encoding)
    $overallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $totalTextureBytesRead = 0L
    $textureCount = 0
    try {
        $writer.Write('{')
        $writer.Write('"_characterData":')
        $writer.Write([System.Text.Json.JsonSerializer]::Serialize($CharacterCompactJson, $jsonStringOptions))
        $writer.Write(',"_textureDatas":[')

        $first = $true
        $textureIndex = 0
        foreach ($descriptor in $TextureDescriptors) {
            $textureIndex++
            $textureCount++
            $textureFilePath = Join-Path $TexturesRoot $descriptor.fileName
            if (-not (Test-Path -LiteralPath $textureFilePath)) {
                throw "Texture file from descriptor was not found: $textureFilePath"
            }

            Write-Host "[pack] Texture $($textureIndex): $($descriptor.textureName)"
            Write-Verbose "Encoding texture '$($descriptor.textureName)' from $textureFilePath"
            $textureStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            if (-not $first) {
                $writer.Write(',')
            }

            $writer.Write('{')
            $writer.Write('"_textureName":')
            $writer.Write([System.Text.Json.JsonSerializer]::Serialize([string]$descriptor.textureName, $jsonStringOptions))
            $writer.Write(',"_textureData":')
            $bytesRead = Write-Base64JsonStringStreamed -Path $textureFilePath -Writer $writer
            $writer.Write('}')

            $textureStopwatch.Stop()
            $totalTextureBytesRead += $bytesRead
            $rate = Format-BytesPerSecond -Bytes $bytesRead -Seconds $textureStopwatch.Elapsed.TotalSeconds
            Write-Host ('[pack] Texture {0} complete in {1:N2}s ({2:N2} MB, {3})' -f $textureIndex, $textureStopwatch.Elapsed.TotalSeconds, ($bytesRead / 1MB), $rate)
            $first = $false
        }

        $writer.Write(']}')

        $overallStopwatch.Stop()
        return [ordered]@{
            textureCount = $textureCount
            totalTextureBytesRead = $totalTextureBytesRead
            elapsedSeconds = [double]$overallStopwatch.Elapsed.TotalSeconds
            averageRate = (Format-BytesPerSecond -Bytes $totalTextureBytesRead -Seconds $overallStopwatch.Elapsed.TotalSeconds)
        }
    }
    finally {
        $writer.Dispose()
        $fileStream.Dispose()
    }
}
