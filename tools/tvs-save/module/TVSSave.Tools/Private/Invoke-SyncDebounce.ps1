function Invoke-SyncDebounce {
<#
.SYNOPSIS
Debounce helper for Watch-TVSCharacterSync.

.DESCRIPTION
Waits for a configurable debounce period, collecting all FSW events
that arrive during that window. Returns the deduplicated set of
changed paths.

.PARAMETER Queue
The ConcurrentQueue to drain.

.PARAMETER DebounceMs
Debounce window in milliseconds. Default: 750.

.PARAMETER Token
CancellationToken to abort the wait.
#>
    [CmdletBinding()]
    param(
        [System.Collections.Concurrent.ConcurrentQueue[object]]$Queue,
        [int]$DebounceMs = 750,
        [System.Threading.CancellationToken]$Token = [System.Threading.CancellationToken]::None
    )

    $changedPaths = [System.Collections.Generic.HashSet[string]]::new()

    # Initial drain
    $item = $null
    while ($Queue.TryDequeue([ref]$item)) {
        [void]$changedPaths.Add($item)
    }

    # Wait for debounce period, collecting any new events
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $DebounceMs) {
        if ($Token.IsCancellationRequested) { break }

        $remaining = $DebounceMs - $sw.ElapsedMilliseconds
        if ($remaining -gt 0) {
            Start-Sleep -Milliseconds ([Math]::Min(100, $remaining))
        }

        while ($Queue.TryDequeue([ref]$item)) {
            [void]$changedPaths.Add($item)
        }
    }

    # Final drain
    while ($Queue.TryDequeue([ref]$item)) {
        [void]$changedPaths.Add($item)
    }

    return $changedPaths
}
