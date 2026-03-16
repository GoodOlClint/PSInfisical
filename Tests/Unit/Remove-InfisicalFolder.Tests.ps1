using module ..\..\PSInfisical.psd1

# Remove-InfisicalFolder.Tests.ps1
# Unit tests for the Remove-InfisicalFolder function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Remove-InfisicalFolder' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Remove by ID' {
        It 'Removes folder successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse
            } -ModuleName PSInfisical

            { Remove-InfisicalFolder -Id 'folder-001' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }
    }

    Context 'Remove by Name' {
        It 'Removes folder by name' {
            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse
            } -ModuleName PSInfisical

            { Remove-InfisicalFolder -Name 'old-folder' -Confirm:$false } | Should -Not -Throw
        }
    }

    Context '-ForceDelete' {
        It 'Passes forceDelete in body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.forceDelete | Should -BeTrue
                return Get-SampleFolderResponse
            } -ModuleName PSInfisical

            { Remove-InfisicalFolder -Id 'folder-001' -ForceDelete -Confirm:$false } | Should -Not -Throw
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse
            } -ModuleName PSInfisical

            Remove-InfisicalFolder -Id 'folder-001' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'Folder not found' {
        It 'Writes non-terminating error if not found' {
            Mock Invoke-RestMethod {
                return $null
            } -ModuleName PSInfisical

            $result = Remove-InfisicalFolder -Id 'nonexistent' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable errVar

            $errVar | Should -Not -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalFolderNotFound'
        }
    }

    Context 'ConfirmImpact' {
        It 'Has ConfirmImpact set to High' {
            $cmd = Get-Command Remove-InfisicalFolder
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }
    }

    Context 'Pipeline input' {
        It 'Accepts pipeline input from Get-InfisicalFolder' {
            Mock Invoke-RestMethod {
                return Get-SampleFoldersListResponse
            } -ModuleName PSInfisical -ParameterFilter { $null -eq $Method -or $Method -eq 'GET' }

            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse
            } -ModuleName PSInfisical -ParameterFilter { $Method -eq 'DELETE' }

            { Get-InfisicalFolder | Remove-InfisicalFolder -Confirm:$false } | Should -Not -Throw
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
