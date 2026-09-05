# Offline test for file encoding and line endings across the repository. No API calls, no module import, no
# network: it reads bytes off disk and compares them against the policy in .gitattributes.
#
# A check is needed because Git hides this class of problem: it normalizes line endings before diffing, so a
# file whose endings are wrong shows no diff at all and leaves "git status" clean.
#
# Three rules:
#
#   1. No byte order mark. Every text file here is pure ASCII, so a BOM buys nothing and breaks things
#      quietly: shell tools that do not strip a BOM treat it as content, and it defeats the point of LF
#      files being byte-identical to what Git stores.
#
#   2. LF only, no CR anywhere. .gitattributes pins every text type to eol=lf, which is what Git already
#      stores, so a checked-out file is byte for byte the repository's copy on every platform. Line endings
#      do not affect how PowerShell parses a script; this is about there being no conversion layer to
#      reason about.
#
#   3. Files Git treats as binary are skipped and reported, never rewritten. Git reports such a file as
#      -text, so no line-ending rule applies to it, and a bulk "read text, write text" pass over one would
#      silently re-encode it and can halve its size. A NUL byte is Git's own binary heuristic and is what
#      this test uses, so any such file is skipped automatically rather than being mangled by the next tool
#      that runs over the tree.
#
# Files are enumerated the way Tests/TestDocLinks_EndpointReferences.ps1 does it, with --cached --others
# --exclude-standard, so a file that has been written but not yet committed is checked while .gitignore is
# still honored.

$Stats = @{ Pass = 0; Fail = (New-Object System.Collections.ArrayList) }
function Assert-Equal { param([string]$Name,$Expected,$Actual)
    if ("$Expected" -eq "$Actual") { $Stats.Pass++; "  PASS  $Name" }
    else { [void]$Stats.Fail.Add($Name); "  FAIL  $Name -- expected '$Expected', got '$Actual'" } }

$RepoRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot,'..'))

# Extensions .gitattributes declares as text. LICENSE has no extension and is listed there by name.
$TextExtension = @('.ps1','.psm1','.psd1','.ps1xml','.psrc','.pssc','.md','.txt','.json','.yml','.yaml','.url','.csv')

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
$WithCr      = New-Object System.Collections.ArrayList
$SkippedBinary = New-Object System.Collections.ArrayList
$Checked     = 0

foreach ($Relative in $Listed)
{
    $Extension = [System.IO.Path]::GetExtension($Relative).ToLowerInvariant()
    $Leaf      = [System.IO.Path]::GetFileName($Relative)
    if ($TextExtension -notcontains $Extension -and $Leaf -ne 'LICENSE' -and $Leaf -ne '.gitignore' -and $Leaf -ne '.gitattributes') { continue }

    $Full = [System.IO.Path]::Combine($RepoRoot, ($Relative -replace '/', [System.IO.Path]::DirectorySeparatorChar))
    if (-not (Test-Path -LiteralPath $Full)) { continue }   # listed but deleted in the working tree

    $Bytes = [System.IO.File]::ReadAllBytes($Full)

    # Rule 3 first: a NUL byte means Git treats this as binary, so no text rule applies and nothing may
    # rewrite it. UTF-16 lands here, which is the point.
    if ($Bytes -contains 0)
    {
        [void]$SkippedBinary.Add($Relative)
        continue
    }

    $Checked++

    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF)
    {
        [void]$WithBom.Add($Relative)
    }

    if ($Bytes -contains 13)   # CR
    {
        [void]$WithCr.Add($Relative)
    }
}

"--- no text file carries a byte order mark ($Checked checked)"
Assert-Equal 'no file has a UTF-8 BOM' '' ($WithBom -join ', ')

"--- every text file uses LF, matching the eol=lf pin in .gitattributes"
Assert-Equal 'no text file contains a CR' '' ($WithCr -join ', ')

# A guard that silently checks nothing is worse than no guard, so prove the enumeration found something.
"--- the scan actually reached the repository"
Assert-Equal 'text files were checked' $true ($Checked -gt 100)

if ($SkippedBinary.Count)
{
    "--- skipped as binary (Git reports these as -text; do not run line-ending tools over them)"
    $SkippedBinary | ForEach-Object { "        $_" }
}

$Total = $Stats.Pass + $Stats.Fail.Count

''
if (-not $Total) { 'NO CASES RAN - treating as failure'; exit 1 }
if ($Stats.Fail.Count -eq 0) { "ALL $Total FILE-ENCODING CASES PASSED" }
else
{
    "$($Stats.Fail.Count) of $Total CASES FAILED: $($Stats.Fail -join '; ')"
    ''
    'To convert a text file to LF (never run this over a file listed as skipped-as-binary above):'
    '    $t = [System.IO.File]::ReadAllText($Path)'
    '    [System.IO.File]::WriteAllText($Path, ($t -replace "`r`n","`n"))'
    exit 1
}
