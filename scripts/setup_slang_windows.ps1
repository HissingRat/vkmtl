$ErrorActionPreference = 'Stop'

$root = $args[0]
$archiveDir = $args[1]
$archive = $args[2]
$stamp = $args[3]
$slangc = $args[4]
$url = $args[5]
$expectedSha = $args[6]
$tag = $args[7]
$packageId = $args[8]

if ((Test-Path -LiteralPath $slangc -PathType Leaf) -and (Test-Path -LiteralPath $stamp -PathType Leaf)) {
    exit 0
}

if (Test-Path -LiteralPath $slangc -PathType Leaf) {
    Write-Host "using existing Slang $tag for $packageId"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $stamp) | Out-Null
    New-Item -ItemType File -Force -Path $stamp | Out-Null
    exit 0
}

New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
$tmp = "$archive.tmp"
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
Write-Host "fetching Slang $tag for $packageId"
Invoke-WebRequest -Uri $url -OutFile $tmp -TimeoutSec 300

$actualSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $tmp).Hash.ToLowerInvariant()
if ($actualSha -ne $expectedSha) {
    Write-Error "vkmtl Slang archive hash mismatch for $url`nexpected: $expectedSha`nactual:   $actualSha"
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    exit 1
}

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $root | Out-Null
Move-Item -LiteralPath $tmp -Destination $archive -Force
Expand-Archive -LiteralPath $archive -DestinationPath $root -Force

if (!(Test-Path -LiteralPath $slangc -PathType Leaf)) {
    Write-Error "vkmtl could not find slangc at $slangc after extracting $archive"
    Get-ChildItem -Path $root -Recurse -Filter 'slangc*.exe' -File -ErrorAction SilentlyContinue | ForEach-Object { Write-Error $_.FullName }
    exit 1
}

New-Item -ItemType File -Force -Path $stamp | Out-Null
