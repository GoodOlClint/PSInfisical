# PSInfisical.build.ps1
# InvokeBuild script for the PSInfisical module.
# Tasks: Clean, Build, Test, Analyze, Package, Publish.
# Called by: Invoke-Build (user or CI).
# Dependencies: InvokeBuild, Pester 5.x, PSScriptAnalyzer

param(
    [string] $ModuleName = 'PSInfisical',
    [string] $NuGetApiKey = $env:NUGET_API_KEY
)

# $BuildRoot is set automatically by Invoke-Build. Fall back to $PSScriptRoot
# so the script also works when dot-sourced or run directly for debugging.
if (-not $BuildRoot) {
    $BuildRoot = $PSScriptRoot
}

$OutputDir = Join-Path -Path $BuildRoot -ChildPath 'output'
# The build script lives in the repo root alongside the module source.
$moduleSrcDir = $BuildRoot
$moduleOutDir = Join-Path -Path $OutputDir -ChildPath $ModuleName

# --- Clean: Remove output directory ---
task Clean {
    if (Test-Path -Path $OutputDir) {
        Write-Build Yellow "Removing output directory: $OutputDir"
        Remove-Item -Path $OutputDir -Recurse -Force
    }
    Write-Build Green 'Clean complete.'
}

# --- Build: Copy module files to output ---
task Build {
    Write-Build Yellow "Building module to: $moduleOutDir"

    $null = New-Item -Path $moduleOutDir -ItemType Directory -Force

    # Copy module files preserving directory structure
    $itemsToCopy = @(
        'PSInfisical.psd1'
        'PSInfisical.psm1'
        'Public'
        'Private'
        'Classes'
        'PSInfisical.Extension'
    )

    foreach ($item in $itemsToCopy) {
        $sourcePath = Join-Path -Path $moduleSrcDir -ChildPath $item
        if (Test-Path -Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $moduleOutDir -Recurse -Force
            Write-Build Gray "  Copied: $item"
        }
        else {
            Write-Build Red "  Missing: $item"
        }
    }

    # Copy metadata files for PSGallery publishing
    foreach ($metaFile in @('LICENSE', 'README.md', 'CHANGELOG.md')) {
        $metaSource = Join-Path -Path $moduleSrcDir -ChildPath $metaFile
        if (Test-Path -Path $metaSource) {
            Copy-Item -Path $metaSource -Destination $moduleOutDir -Force
            Write-Build Gray "  Copied: $metaFile"
        }
    }

    Write-Build Green 'Build complete.'
}

# --- Test: Run Pester unit tests ---
task Test Build, {
    Write-Build Yellow 'Running Pester unit tests...'

    $testResultsPath = Join-Path -Path $OutputDir -ChildPath 'TestResults.xml'
    $testsPath = Join-Path -Path $moduleSrcDir -ChildPath 'Tests'

    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = @(
        (Join-Path -Path $testsPath -ChildPath 'PSInfisical.Tests.ps1')
        (Join-Path -Path $testsPath -ChildPath 'Unit')
    )
    $pesterConfig.Run.Exit = $false
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.Output.Verbosity = 'Detailed'
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputPath = $testResultsPath
    $pesterConfig.TestResult.OutputFormat = 'NUnitXml'

    $results = Invoke-Pester -Configuration $pesterConfig

    if ($results.FailedCount -gt 0) {
        Write-Build Red "$($results.FailedCount) test(s) failed."
        throw "$($results.FailedCount) Pester test(s) failed."
    }

    Write-Build Green "All $($results.PassedCount) tests passed."
}

# --- Analyze: Run PSScriptAnalyzer ---
task Analyze Build, {
    Write-Build Yellow 'Running PSScriptAnalyzer...'

    # Analyze only production code — tests intentionally use patterns like
    # ConvertTo-SecureString with plaintext that are not appropriate in production.
    $productionPaths = @('Classes', 'Private', 'Public', 'PSInfisical.Extension', 'PSInfisical.psm1', 'PSInfisical.psd1') |
        ForEach-Object { Join-Path -Path $moduleSrcDir -ChildPath $_ } |
        Where-Object { Test-Path $_ }

    $analysisResults = $productionPaths | ForEach-Object {
        Invoke-ScriptAnalyzer -Path $_ -Recurse -Settings @{
            Rules = @{
                PSAvoidUsingWriteHost                         = @{ Enable = $true }
                PSAvoidUsingPlainTextForPassword               = @{ Enable = $true }
                PSUseShouldProcessForStateChangingFunctions    = @{ Enable = $true }
                PSAvoidUsingConvertToSecureStringWithPlainText = @{ Enable = $true }
            }
        }
    }

    $errors = $analysisResults | Where-Object { $_.Severity -eq 'Error' }
    $warnings = $analysisResults | Where-Object { $_.Severity -eq 'Warning' }

    if ($warnings) {
        Write-Build Yellow "PSScriptAnalyzer warnings: $($warnings.Count)"
        $warnings | ForEach-Object {
            Write-Build Yellow "  [$($_.Severity)] $($_.ScriptName):$($_.Line) - $($_.RuleName): $($_.Message)"
        }
    }

    if ($errors) {
        Write-Build Red "PSScriptAnalyzer errors: $($errors.Count)"
        $errors | ForEach-Object {
            Write-Build Red "  [$($_.Severity)] $($_.ScriptName):$($_.Line) - $($_.RuleName): $($_.Message)"
        }
        throw "$($errors.Count) PSScriptAnalyzer error(s) found."
    }

    Write-Build Green 'PSScriptAnalyzer analysis complete — no errors.'
}

# --- Package: Create distribution zip ---
task Package Build, {
    Write-Build Yellow 'Creating distribution package...'

    $zipPath = Join-Path -Path $OutputDir -ChildPath "$ModuleName.zip"

    if (Test-Path -Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }

    Compress-Archive -Path $moduleOutDir -DestinationPath $zipPath -Force

    Write-Build Green "Package created: $zipPath"
}

# --- Test-Integration: Run integration tests against a live Infisical instance ---
# NOT part of the default build — invoke explicitly: Invoke-Build Test-Integration
task Test-Integration Build, {
    Write-Build Yellow 'Starting integration test environment...'

    $integrationDir = Join-Path -Path $moduleSrcDir -ChildPath 'Tests/Integration'
    $startScript = Join-Path -Path $integrationDir -ChildPath 'Start-IntegrationEnvironment.ps1'
    $stopScript = Join-Path -Path $integrationDir -ChildPath 'Stop-IntegrationEnvironment.ps1'
    $testResultsPath = Join-Path -Path $OutputDir -ChildPath 'TestResults-Integration.xml'

    try {
        # Start the Docker Compose environment and bootstrap Infisical
        & $startScript

        Write-Build Yellow 'Running Pester integration tests...'

        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $integrationDir
        $pesterConfig.Run.Exit = $false
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Filter.Tag = 'Integration'
        $pesterConfig.Output.Verbosity = 'Detailed'
        $pesterConfig.TestResult.Enabled = $true
        $pesterConfig.TestResult.OutputPath = $testResultsPath
        $pesterConfig.TestResult.OutputFormat = 'NUnitXml'

        $results = Invoke-Pester -Configuration $pesterConfig

        if ($results.FailedCount -gt 0) {
            Write-Build Red "$($results.FailedCount) integration test(s) failed."
            throw "$($results.FailedCount) Pester integration test(s) failed."
        }

        Write-Build Green "All $($results.PassedCount) integration tests passed."
    }
    finally {
        Write-Build Yellow 'Tearing down integration test environment...'
        & $stopScript
    }
}

# --- Publish: Publish module to PSGallery ---
task Publish Build, Test, Analyze, {
    if (-not $NuGetApiKey) {
        throw 'NuGetApiKey is required. Pass -NuGetApiKey or set $env:NUGET_API_KEY.'
    }

    Write-Build Yellow "Publishing $ModuleName to PSGallery..."
    Publish-Module -Path $moduleOutDir -NuGetApiKey $NuGetApiKey -Verbose
    Write-Build Green "Published $ModuleName to PSGallery."
}

# --- Default: Full pipeline ---
task . Clean, Build, Test, Analyze
