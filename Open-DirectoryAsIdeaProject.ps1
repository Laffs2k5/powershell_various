# 
# .SYNOPSIS
# Script for opening IDEA project from commandline or windows explorer
# 
# .DESCRIPTION
# The script will open the latest IDEA version installed on the system.
# - Given a file the file is opened in IDEA
# - Given a directory the script looks for: .idea subdir or *.ipr or *.pom
#
# Windows explorer integration:
# - Run the script as admin with the -Install switch. You are now able to 
#   right click any directory in explorer and open it in IDEA.
#
# Removing explorer integration:
# - Run the script as admin with the -Uninstall switch.
# 
# .INPUTS
#  FilePath - The path to a file or directory to open in IDEA.

[cmdletbinding()]
param(  
    [Parameter(
            Mandatory=$true,
            ParameterSetName='OpenOperation',
            ValueFromPipeline=$true,
            HelpMessage='Path to file or directory to open in IDEA.'
    )]
    [Alias('FullName')]
    [String]$FilePath,
    [Parameter(ParameterSetName='InstallOperation')]
    [switch]$Install,
    [Parameter(ParameterSetName='UninstallOperation')]
    [switch]$Uninstall
)

Begin {
    # Don't anyoy me when I'm debugging
    If ($PSBoundParameters['Debug']) {
        $DebugPreference = 'Continue'
    }

    # Function: Check for su
    function Test-IsAdmin() {
        return [bool](([Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')
    }
    
    # Check for where the latest version of IDEA is installed
    $IdeaBin = '{0}\{1}' -f (`
        Get-ChildItem -Path "$env:ProgramW6432\JetBrains" -Filter 'IntelliJ IDEA*' | `
        Sort-Object -Descending | `
        Select-Object -First 1 `
    ).FullName, `
    'bin\idea64.exe'
    if(Test-Path -Path $IdeaBin -PathType Leaf) {
        Write-Debug -Message ('IDEA: Latest bin found at "{0}"' -f $IdeaBin)
    }
    else{
        Write-Debug -Message ('IDEA: No file found at "{0}"' -f $IdeaBin)
        $IdeaBin = $null
    }

    # Install/uninstall
    if([bool]$Uninstall -or [bool]$Install) {
        # Require elevation for install/uninstall
        if( -not $(Test-IsAdmin)) {
            throw 'ERROR: Install/uninstall requires elevation'
        }
        if($null -eq $IdeaBin -and [bool]$Install) {
            throw 'ERROR: Unable to install, the IDEA binary was not found'
        }
        
        $null = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
        $RegEntries = @(
            @{
                'Path' = 'HKCR:\Directory\shell\intellijidea'
                'Name' = '(Default)'
                'PropertyType' = [Microsoft.Win32.RegistryValueKind]::String
                'Value' =  'Open Folder as &IDEA Project'
            },
            @{
                'Path' = 'HKCR:\Directory\shell\intellijidea'
                'Name' = 'Icon'
                'PropertyType' = [Microsoft.Win32.RegistryValueKind]::String
                'Value' =  $('{0},0' -f $IdeaBin)
            },
            @{
                'Path' = 'HKCR:\Directory\shell\intellijidea\command'
                'Name' = '(Default)'
                'PropertyType' = [Microsoft.Win32.RegistryValueKind]::String
                'Value' =  $('powershell.exe -ExecutionPolicy bypass -WindowStyle Hidden -NonInteractive -NoLogo -NoProfile -File "{0}" -FilePath "%1"' -f $PSCommandPath)
            },
            @{
                'Path' = 'HKCR:\Directory\Background\shell\intellijidea'
                'Name' = '(Default)'
                'PropertyType' = [Microsoft.Win32.RegistryValueKind]::String
                'Value' =  'Open Folder as &IDEA Project'
            },
            @{
                'Path' = 'HKCR:\Directory\Background\shell\intellijidea'
                'Name' = 'Icon'
                'PropertyType' = [Microsoft.Win32.RegistryValueKind]::String
                'Value' =  $('{0},0' -f $IdeaBin)
            },
            @{
                'Path' = 'HKCR:\Directory\Background\shell\intellijidea\command'
                'Name' = '(Default)'
                'PropertyType' = [Microsoft.Win32.RegistryValueKind]::String
                'Value' =  $('powershell.exe -ExecutionPolicy bypass -WindowStyle Hidden -NonInteractive -NoLogo -NoProfile -File "{0}" -FilePath "%V"' -f $PSCommandPath)
            }
        )

        if([bool]$Uninstall) {
            $RegEntries | ForEach-Object {
                $RegHash = $_
                if(Test-Path -Path $RegHash.Path) {
                    Write-Debug -Message ('REG: Deleting "{0}"' -f $RegHash.Path)
                    $null = Remove-Item -Path $RegHash.Path -Recurse -Force
                }
            }        
            $IdeaBin = $null
        }
        else { # install
            $RegEntries | ForEach-Object {
                $RegHash = $_
                if(-not (Test-Path -Path $RegHash.Path)) {
                    Write-Debug -Message ('REG: Creating "{0}"' -f $RegHash.Path)
                    $null = New-Item -Path $RegHash.Path -Force
                }
                Write-Debug -Message 'REG: Creating reg key:'
                $RegHash | Out-String | Write-Debug
                $null = New-ItemProperty @RegHash -Force
            }
            $IdeaBin = $null
        }
    }
} #end Begin
Process {
    if($IdeaBin) {
        Write-Debug -Message ('INPUT: Processing "{0}"' -f $FilePath)

        # Given an existing file
        if(Test-Path -Path $FilePath -PathType Leaf) {
            Write-Debug -Message 'INPUT: Opening as file'
            Start-Process `
            -FilePath $IdeaBin `
            -WorkingDirectory $([IO.Path]::GetDirectoryName($FilePath)) `
            -ArgumentList $('"{0}"' -f $FilePath)
        }
        else {
            if(Test-Path -Path $('{0}\{1}' -f $FilePath,'.idea') -PathType Container) {
                Write-Debug -Message 'INPUT: Opening via the .idea dir'
                Start-Process `
                -FilePath $IdeaBin `
                -WorkingDirectory $FilePath `
                -ArgumentList $('"{0}"' -f $FilePath)
            }
            elseif(Test-Path -Path $('{0}\{1}' -f $FilePath,'pom.xml') -PathType Leaf) {
                Write-Debug -Message 'INPUT: Importing from pom'
                Start-Process `
                -FilePath $IdeaBin `
                -WorkingDirectory $FilePath `
                -ArgumentList '"pom.xml"'
            }
            elseif($null -ne $(Get-ChildItem -Path $FilePath -Filter '*.ipr' -ErrorAction SilentlyContinue|Select-Object -First 1)) {
                Write-Debug -Message 'Opening via the project file'
                Start-Process `
                -FilePath $IdeaBin `
                -WorkingDirectory $FilePath `
                -ArgumentList $('"{0}"' -f (Get-ChildItem -Path $FilePath -Filter '*.ipr' -ErrorAction SilentlyContinue|Select-Object -First 1))
            }
            else {
                Write-Debug -Message 'Input was garbage, starting IDEA'
                Start-Process -FilePath $IdeaBin
            }
        }   
    }
}
End {}
