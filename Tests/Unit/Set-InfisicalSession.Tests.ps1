using module ..\..\PSInfisical.psd1

# Set-InfisicalSession.Tests.ps1
# Unit tests for the Set-InfisicalSession function.

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Set-InfisicalSession' {

    BeforeEach {
        $mockSession = New-MockSession -ProjectId '' -Environment 'prod'
        Mock Get-InfisicalSession { return $mockSession } -ModuleName PSInfisical
    }

    Context 'Set OrganizationId' {
        It 'Updates session OrganizationId' {
            Set-InfisicalSession -OrganizationId 'org-123'
            $mockSession.OrganizationId | Should -Be 'org-123'
        }

        It 'Returns session with -PassThru' {
            $result = Set-InfisicalSession -OrganizationId 'org-456' -PassThru
            $result | Should -Not -BeNullOrEmpty
            $result.OrganizationId | Should -Be 'org-456'
        }
    }

    Context 'Set ProjectId' {
        It 'Updates session ProjectId' {
            Set-InfisicalSession -ProjectId 'new-project-id'
            $mockSession.ProjectId | Should -Be 'new-project-id'
        }

        It 'Returns session with -PassThru' {
            $result = Set-InfisicalSession -ProjectId 'proj-456' -PassThru
            $result | Should -Not -BeNullOrEmpty
            $result.ProjectId | Should -Be 'proj-456'
        }
    }

    Context 'Set Environment' {
        It 'Updates session DefaultEnvironment' {
            Set-InfisicalSession -Environment 'staging'
            $mockSession.DefaultEnvironment | Should -Be 'staging'
        }
    }

    Context 'Set both' {
        It 'Updates both ProjectId and Environment' {
            Set-InfisicalSession -ProjectId 'proj-789' -Environment 'dev'
            $mockSession.ProjectId | Should -Be 'proj-789'
            $mockSession.DefaultEnvironment | Should -Be 'dev'
        }
    }

    Context 'No parameters' {
        It 'Warns when no parameters specified' {
            Set-InfisicalSession 3>&1 | Should -BeLike '*No parameters*'
        }
    }

    Context 'Validation' {
        It 'Rejects empty OrganizationId' {
            { Set-InfisicalSession -OrganizationId '' } | Should -Throw
        }

        It 'Rejects empty ProjectId' {
            { Set-InfisicalSession -ProjectId '' } | Should -Throw
        }

        It 'Rejects invalid Environment slug' {
            { Set-InfisicalSession -Environment 'has spaces' } | Should -Throw
        }
    }

    Context 'Requires active session' {
        It 'Throws when not connected' {
            Mock Get-InfisicalSession {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.InvalidOperationException]::new('Not connected to Infisical. Run Connect-Infisical first.'),
                    'InfisicalNotConnected',
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    $null
                )
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            } -ModuleName PSInfisical

            { Set-InfisicalSession -ProjectId 'proj-123' } | Should -Throw '*Not connected*'
        }
    }
}
