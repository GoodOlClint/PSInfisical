using module ..\..\PSInfisical.psd1

# Get-InfisicalFolder.Tests.ps1
# Unit tests for the Get-InfisicalFolder function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalFolder' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'List folders by path' {
        It 'Returns array of InfisicalFolder objects' {
            Mock Invoke-RestMethod {
                return Get-SampleFoldersListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalFolder

            $results | Should -HaveCount 2
            $results[0].GetType().Name | Should -Be 'InfisicalFolder'
        }

        It 'Returns folders with correct names' {
            Mock Invoke-RestMethod {
                return Get-SampleFoldersListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalFolder

            $results[0].Name | Should -Be 'database'
            $results[1].Name | Should -Be 'api-keys'
        }

        It 'Emits objects individually (pipeline-friendly)' {
            Mock Invoke-RestMethod {
                return Get-SampleFoldersListResponse
            } -ModuleName PSInfisical

            $count = 0
            Get-InfisicalFolder | ForEach-Object { $count++ }
            $count | Should -Be 2
        }

        It 'Passes -Recursive as query param' {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match 'recursive=true'
                return Get-SampleFoldersListResponse
            } -ModuleName PSInfisical

            Get-InfisicalFolder -Recursive | Out-Null
        }
    }

    Context 'Get folder by ID' {
        It 'Returns a single InfisicalFolder' {
            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse -Name 'my-folder' -Id 'folder-abc-123'
            } -ModuleName PSInfisical

            $result = Get-InfisicalFolder -Id 'folder-abc-123'

            $result.GetType().Name | Should -Be 'InfisicalFolder'
            $result.Name | Should -Be 'my-folder'
            $result.Id | Should -Be 'folder-abc-123'
        }

        It 'Writes non-terminating error if not found' {
            Mock Invoke-RestMethod {
                return $null
            } -ModuleName PSInfisical

            $result = Get-InfisicalFolder -Id 'nonexistent' -ErrorAction SilentlyContinue -ErrorVariable errVar

            $result | Should -BeNullOrEmpty
            $errVar | Should -Not -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalFolderNotFound'
        }
    }

    Context 'Empty results' {
        It 'Returns nothing when no folders exist' {
            Mock Invoke-RestMethod {
                return @{ folders = @() }
            } -ModuleName PSInfisical

            $results = @(Get-InfisicalFolder)
            $results | Should -HaveCount 0
        }
    }

    Context 'Folder properties' {
        It 'Maps Description and GetFullPath correctly' {
            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse -Name 'creds' -Id 'folder-xyz'
            } -ModuleName PSInfisical

            $result = Get-InfisicalFolder -Id 'folder-xyz'

            $result.Description | Should -Be 'Test folder'
            $result.GetFullPath() | Should -Be '/creds'
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
