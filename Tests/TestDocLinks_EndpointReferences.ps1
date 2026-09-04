# Checks every SKY API documentation link in the repository against the developer portal's own operation
# list, so a link that no longer resolves is caught here rather than by a reader who clicks it.
#
# Two ways a link dies, both of which have already happened in this repository:
#
#   1. The URL SHAPE was retired. Links of the form
#          developer.sky.blackbaud.com/docs/services/<api>/operations/<operation>
#      now return HTTP 404 for every api and operation. The portal serves the same page as
#          developer.sky.blackbaud.com/api#api=<api>&operation=<operation>
#      Commit 1fd1ec3 converted the function help to the new shape in 2024; the changelog was converted later.
#   2. The API ID was wrong. The portal knows the Constituent (Raiser's Edge NXT) API only by its service id
#      56b76470069a0509c8f1c5b3. The friendly-looking 'constituent' is not an alias and 404s.
#
# Neither failure is visible to a spell check or a Markdown linter, and neither can be caught by fetching the
# URL: the operation id lives in the fragment, which never reaches the server, so every well-formed link
# returns HTTP 200 whether or not the operation exists. The portal's management API is what actually knows.
#
# Casing is NOT checked. The comparison below is PowerShell's -contains, which is case-insensitive, and the
# portal's management API resolves an operation under either casing, so neither side would notice. Most
# operation ids are PascalCase (V1UsersPatch) while exactly seven are lowercase on the portal (v1yearsget,
# v1rolesget, v1termsget, v1levelsget, v1gradelevelsget, v1offeringtypesget, v1usersget). Those seven are
# correct as written and must not be "fixed" to PascalCase, but this script will not stop anyone doing so.
#
# Scans the files Git tracks plus the ones it does not track yet, honoring .gitignore. That keeps ignored
# scratch folders such as '@Local Only' out of the results while still checking a file that has been written
# but not yet committed. Pass -Path to add another checkout, for example the wiki:
#
#     .\TestDocLinks_EndpointReferences.ps1 -Path 'c:\Programming\Wikis\SKYAPI.wiki'
#
# Needs network, but no auth, no tenant and no token file: it reads the public developer portal only.

[CmdletBinding()]
param(
    # Roots to scan. The repository this script lives in is always included; anything passed here is added to
    # it, so the wiki (a separate repository) can be checked in the same run.
    [string[]]$Path = @(),

    # List every link, not just the ones with a problem.
    [switch]$ShowAll
)

$ErrorActionPreference = 'Stop'

# Normalize the '..' away rather than handing it to the provider, which would resolve it against the caller's
# current location instead of against the script.
$RepoRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..'))
$Roots = @($RepoRoot) + $Path
$Roots = $Roots | ForEach-Object { [System.IO.Path]::GetFullPath($_) } | Select-Object -Unique
foreach ($Root in $Roots)
{
    if (-not (Test-Path -LiteralPath $Root)) { throw "path not found: $Root" }
}

if ($PSVersionTable.PSEdition -eq 'Desktop')
{
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

$ApiVersion = '2022-04-01-preview'

# Operations Blackbaud has removed from the portal, which are still named in historical changelog entries.
# A retired operation is reported but does not fail the run: the entry is a record of what happened in that
# release, and the endpoint really is gone, so there is no working link to point it at.
$RetiredOperations = @{
    'V1LegacyListsByList_idGet' = 'legacy Lists endpoint, deprecated and removed by Blackbaud; the 0.2.1 entry announced Get-SchoolList as its replacement'
}

# api id -> operation names, or $null when the api id itself is not known to the portal.
# 'unreachable' is tracked separately so a network outage cannot be reported as a repository full of bad links.
$OpCache = @{}
$Unreachable = @{}

function Get-OperationName
{
    param([string]$Api)

    if ($OpCache.ContainsKey($Api)) { return $OpCache[$Api] }

    $Names = $null
    try
    {
        $Url = "https://developer.sky.blackbaud.com/mapi/apis/$Api/operations?api-version=$ApiVersion&`$top=500"
        $Names = [string[]]((Invoke-RestMethod -Uri $Url -Method Get -ErrorAction Stop).value | ForEach-Object { $_.name })
    }
    catch
    {
        # A 404 is a real answer: the portal does not have that api id. Anything else (DNS, timeout, proxy,
        # a 500) says nothing about the link and must not be reported as one.
        $Status = $null
        if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response)
        {
            $Status = $_.Exception.Response.StatusCode
        }
        if ("$Status" -ne 'NotFound')
        {
            $Unreachable[$Api] = $_.Exception.Message
        }
    }

    $OpCache[$Api] = $Names
    $Names
}

# Tracked files only, so ignored scratch folders stay out. Falls back to a filesystem walk when a root is not
# a Git checkout or Git is unavailable.
function Get-CandidateFile
{
    param([string]$Root)

    $Extensions = @('.md', '.ps1', '.psm1', '.psd1', '.txt')
    $Files = $null

    if (Get-Command git -ErrorAction SilentlyContinue)
    {
        # --cached is the tracked files and --others adds the ones Git does not track yet, so links in a file
        # that has not been committed are still checked. --exclude-standard applies .gitignore, which is what
        # keeps the ignored scratch folder out of the scan.
        $Listed = & git -C $Root ls-files --cached --others --exclude-standard 2>$null
        if ($LASTEXITCODE -eq 0 -and $Listed)
        {
            $Files = $Listed | Select-Object -Unique |
                         ForEach-Object { [System.IO.Path]::Combine($Root, ($_ -replace '/', [System.IO.Path]::DirectorySeparatorChar)) }
        }
    }

    if ($null -eq $Files)
    {
        Write-Warning "not a Git checkout, scanning the filesystem instead: $Root"
        $Files = Get-ChildItem -LiteralPath $Root -Recurse -File |
                     Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
                     ForEach-Object { $_.FullName }
    }

    $Files | Where-Object { $Extensions -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant() } |
             Where-Object { Test-Path -LiteralPath $_ }
}

# Operation ids are alphanumeric plus underscore, which keeps a Markdown link's trailing ')' out of the match.
$Patterns = @(
    [pscustomobject]@{ Shape = 'current'; Regex = 'developer\.sky\.blackbaud\.com/api#api=(?<api>[^&\s)]+)&operation=(?<op>[A-Za-z0-9_]+)' }
    [pscustomobject]@{ Shape = 'legacy';  Regex = 'developer\.sky\.blackbaud\.com/docs/services/(?<api>[^/\s)]+)/operations/(?<op>[A-Za-z0-9_]+)' }
)

$Links = @()
foreach ($Root in $Roots)
{
    foreach ($File in (Get-CandidateFile -Root $Root))
    {
        $LineNumber = 0
        foreach ($Line in [System.IO.File]::ReadAllLines($File))
        {
            $LineNumber++
            foreach ($Pattern in $Patterns)
            {
                foreach ($Match in [regex]::Matches($Line, $Pattern.Regex))
                {
                    $Links += [pscustomobject]@{
                        File  = $File.Substring($Root.Length).TrimStart('\', '/')
                        Line  = $LineNumber
                        Shape = $Pattern.Shape
                        Api   = $Match.Groups['api'].Value
                        Op    = $Match.Groups['op'].Value
                    }
                }
            }
        }
    }
}

if (-not $Links) { 'No SKY API documentation links found. Nothing to check.'; exit 0 }

# One request per distinct api id, before classifying anything.
foreach ($Api in ($Links.Api | Select-Object -Unique)) { $null = Get-OperationName -Api $Api }

$Rows = foreach ($Link in $Links)
{
    $Names = $OpCache[$Link.Api]

    $Status = 'ok'
    $Detail = ''
    if ($Unreachable.ContainsKey($Link.Api))
    {
        $Status = 'UNCHECKED'
        $Detail = "could not reach the portal: $($Unreachable[$Link.Api])"
    }
    elseif ($null -eq $Names)
    {
        $Status = 'UNKNOWN API'
        $Detail = "the portal has no api id '$($Link.Api)'"
    }
    elseif ($Names -ccontains $Link.Op)
    {
        if ($Link.Shape -eq 'legacy')
        {
            $Status = 'LEGACY SHAPE'
            $Detail = "rewrite as api#api=$($Link.Api)&operation=$($Link.Op)"
        }
    }
    elseif ($Names -contains $Link.Op)
    {
        $Actual = $Names | Where-Object { $_ -eq $Link.Op } | Select-Object -First 1
        $Status = 'CASE'
        $Detail = "the portal spells it '$Actual'"
    }
    elseif ($RetiredOperations.ContainsKey($Link.Op))
    {
        $Status = 'RETIRED'
        $Detail = $RetiredOperations[$Link.Op]
    }
    else
    {
        $Status = 'UNKNOWN OPERATION'
        $Detail = "api '$($Link.Api)' has no operation '$($Link.Op)'"
    }

    [pscustomobject]@{
        File   = $Link.File
        Line   = $Link.Line
        Api    = $Link.Api
        Op     = $Link.Op
        Status = $Status
        Detail = $Detail
    }
}

$Rows = @($Rows)
$Failures  = @($Rows | Where-Object { $_.Status -notin 'ok', 'RETIRED', 'UNCHECKED' })
$Retired   = @($Rows | Where-Object { $_.Status -eq 'RETIRED' })
$Unchecked = @($Rows | Where-Object { $_.Status -eq 'UNCHECKED' })

'================ RESULTS ================'
''
foreach ($Row in $Rows)
{
    if ($Row.Status -eq 'ok')
    {
        if ($ShowAll) { '  PASS  {0}:{1}  {2}' -f $Row.File, $Row.Line, $Row.Op }
        continue
    }
    $Label = if ($Row.Status -eq 'RETIRED' -or $Row.Status -eq 'UNCHECKED') { 'NOTE' } else { 'FAIL' }
    '  {0}  {1}:{2}' -f $Label, $Row.File, $Row.Line
    '        {0}: {1}' -f $Row.Status, $Row.Detail
}
if (-not $ShowAll -and -not $Failures -and -not $Retired -and -not $Unchecked) { '  (no problems found)' }

''
'================ SUMMARY ================'
'  links checked           : {0}' -f $Rows.Count
'  distinct api ids        : {0}' -f @($Links.Api | Select-Object -Unique).Count
'  resolve correctly       : {0}' -f @($Rows | Where-Object { $_.Status -eq 'ok' }).Count
'  retired operations      : {0}   (reported, not a failure)' -f $Retired.Count
'  unchecked               : {0}' -f $Unchecked.Count
'  failures                : {0}' -f $Failures.Count

''
if ($Unchecked)
{
    'PORTAL UNREACHABLE for {0} link(s); those were not checked and this run proves nothing about them.' -f $Unchecked.Count
    exit 1
}
if ($Failures)
{
    'FAIL: {0} documentation link(s) will not resolve.' -f $Failures.Count
    exit 1
}
'PASS: every documentation link resolves to a real operation on the portal.'
