# Offline test for file encoding and line endings across the repository. No API calls, no module import, no
# network: it reads bytes off disk and compares them against the policy in .gitattributes.
#
# This exists because the policy kept being re-derived. .gitattributes has pinned PowerShell sources to CRLF
# since it was written, but nothing checked it, so a file created with LF (which is what most editors and
# tools produce) stayed wrong until somebody happened to run "git ls-files --eol". Git itself will not tell
# you: it normalizes line endings before diffing, so a whole-file ending flip shows up as no diff at all.
#
# Two rules, both from .gitattributes:
#
#   1. No byte order mark on any text file. Every file in this repo is pure ASCII, so a BOM buys nothing and
#      breaks things quietly: Windows PowerShell 5.1 reads a BOM-less file as the system ANSI codepage, and
#      shell tools that do not strip a BOM treat it as content.
#
#   2. PowerShell sources are CRLF (*.ps1, *.psm1, *.psd1, *.ps1xml, *.psrc, *.pssc carry "text eol=crlf").
#      Everything else is plain "text": Git stores LF and the checkout decides, so BOTH endings are correct
#      in the working tree and this test must not have an opinion about them.
#
# Files are enumerated the way Tests/TestDocLinks_EndpointReferences.ps1 does it, with --cached --others
# --exclude-standard, so a file that has been written but not yet committed is checked while .gitignore is
# still honored.

$Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }
function Assert-Equal { param([string]$Name,$Expected,$Actual)
    if ("$Expected" -eq "$Actual") { $Stats.Pass++; "  PASS  $Name" }
    else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- expected '$Expected', got '$Actual'" } }

$RepoRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot,'..'))

# Extensions Git treats as text. Kept in step with .gitattributes; anything else is binary or unmanaged.
$CrlfPinned = @('.ps1','.psm1','.psd1','.ps1xml','.psrc','.pssc')
$TextOnly   = @('.md','.txt','.json','.yml','.yaml','.url','.csv')

if (-not (Get-Command git -ErrorAction SilentlyContinue))
{
    'git is not available; cannot enumerate repository files'
    exit 1
}

Push-Location $RepoRoot
try   { $Listed = & git ls-files --cached --others --exclude-standard 2>$null; $GitExit = $LASTEXITCODE }
finally { Pop-Location }

if ($GitExit -ne 0 -or -not $Listed)
{
    'git ls-files returned nothing; not a checkout?'
    exit 1
}

$WithBom     = New-Object System.Collections.ArrayList
$PsWithLf    = New-Object System.Collections.ArrayList
$CheckedBom  = 0
$CheckedCrlf = 0

foreach ($Relative in $Listed)
{
    $Extension = [System.IO.Path]::GetExtension($Relative).ToLowerInvariant()
    if ($CrlfPinned -notcontains $Extension -and $TextOnly -notcontains $Extension) { continue }

    $Full = [System.IO.Path]::Combine($RepoRoot, ($Relative -replace '/', [System.IO.Path]::DirectorySeparatorChar))
    if (-not (Test-Path -LiteralPath $Full)) { continue }   # listed but deleted in the working tree

    $Bytes = [System.IO.File]::ReadAllBytes($Full)
    $CheckedBom++

    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF)
    {
        [void]$WithBom.Add($Relative)
    }

    if ($CrlfPinned -contains $Extension)
    {
        $CheckedCrlf++
        # A bare LF is one not preceded by CR. Reading as UTF-8 is safe here: the check is for the byte
        # pattern, and a mis-decoded high byte cannot look like a newline.
        if ([System.Text.Encoding]::UTF8.GetString($Bytes) -match "(?<!`r)`n")
        {
            [void]$PsWithLf.Add($Relative)
        }
    }
}

"--- no text file carries a byte order mark ($CheckedBom checked)"
Assert-Equal 'no file has a UTF-8 BOM' '' ($WithBom -join ', ')

"--- PowerShell sources use CRLF, matching the eol=crlf pin in .gitattributes ($CheckedCrlf checked)"
Assert-Equal 'no PowerShell file contains a bare LF' '' ($PsWithLf -join ', ')

# A guard that silently checks nothing is worse than no guard, so prove the enumeration found something.
"--- the scan actually reached the repository"
Assert-Equal 'text files were checked'       $true ($CheckedBom  -gt 50)
Assert-Equal 'PowerShell files were checked' $true ($CheckedCrlf -gt 50)

$Total = $Stats.Pass + $Stats.Fail.Count

''
if (-not $Total) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Stats.Fail.Count -eq 0) { "ALL $Total FILE-ENCODING CASES PASSED" }
else
{
    "$($Stats.Fail.Count) of $Total CASES FAILED: $($Stats.Fail -join '; ')"
    ''
    'To fix a PowerShell file written with LF:'
    '    $t = [System.IO.File]::ReadAllText($Path)'
    '    [System.IO.File]::WriteAllText($Path, (($t -replace "`r`n","`n") -replace "`n","`r`n"))'
    exit 1
}
