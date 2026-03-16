using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalTag' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'List all tags' {
        It 'Returns array of InfisicalTag objects' {
            Mock Invoke-RestMethod {
                return Get-SampleTagsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalTag
            $results | Should -HaveCount 2
            $results[0].GetType().Name | Should -Be 'InfisicalTag'
        }

        It 'Returns tags with correct slugs' {
            Mock Invoke-RestMethod {
                return Get-SampleTagsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalTag
            $results[0].Slug | Should -Be 'production'
            $results[1].Slug | Should -Be 'database'
        }
    }

    Context 'Get tag by ID' {
        It 'Returns a single tag' {
            Mock Invoke-RestMethod {
                return Get-SampleTagResponse -Slug 'prod' -Id 'tag-001'
            } -ModuleName PSInfisical

            $result = Get-InfisicalTag -Id 'tag-001'
            $result.GetType().Name | Should -Be 'InfisicalTag'
            $result.Id | Should -Be 'tag-001'
        }

        It 'Writes non-terminating error if not found' {
            Mock Invoke-RestMethod { return $null } -ModuleName PSInfisical

            $result = Get-InfisicalTag -Id 'nonexistent' -ErrorAction SilentlyContinue -ErrorVariable errVar
            $result | Should -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalTagNotFound'
        }
    }

    Context 'Get tag by slug' {
        It 'Returns a single tag by slug' {
            Mock Invoke-RestMethod {
                return Get-SampleTagResponse -Slug 'production'
            } -ModuleName PSInfisical

            $result = Get-InfisicalTag -Slug 'production'
            $result.Slug | Should -Be 'production'
        }
    }

    Context 'Empty results' {
        It 'Returns nothing when no tags exist' {
            Mock Invoke-RestMethod { return @{ tags = @() } } -ModuleName PSInfisical
            $results = @(Get-InfisicalTag)
            $results | Should -HaveCount 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
