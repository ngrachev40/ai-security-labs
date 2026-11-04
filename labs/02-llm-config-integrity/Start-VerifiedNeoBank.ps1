param(
    [string]$ModelFile = "$PSScriptRoot\neobank-baseline.Modelfile"
)

$ErrorActionPreference = 'Stop'
$expectedHash = '66EC48B1E589ABD150F61EEAEE7D47DE1D22FDA0F53963AEC81E56AF9A298CF9'
$modelName = 'neobank-verified'

try {
    $snapshot = [System.IO.Path]::GetTempFileName()
    Copy-Item -LiteralPath $ModelFile -Destination $snapshot

    $actualHash = (Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash

    if ($actualHash -ne $expectedHash) {
        throw 'SHA256 mismatch. Model creation and launch blocked.'
    }

    Write-Host 'Integrity check passed.' -ForegroundColor Green

    ollama create $modelName -f $snapshot
    if ($LASTEXITCODE -ne 0) {
        throw 'Model creation failed. Launch blocked.'
    }
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
finally {
    if ($snapshot -and (Test-Path -LiteralPath $snapshot)) {
        Remove-Item -LiteralPath $snapshot
    }
}

ollama run $modelName
exit $LASTEXITCODE
