# File encoding and line endings

How PowerShell writes text, how Git stores it, and the places where the two disagree quietly. This is
PowerShell and Git behavior rather than SKY API behavior, recorded here because getting it wrong cost real
time and, once, corrupted a file.

Measured on **2026-09-04** on Windows 11, against Windows PowerShell **5.1.26100.9168** and PowerShell
**7.6.5**. No tenant was involved and nothing here describes the API.

**Claims are labelled with their evidence.**

- **Measured** means bytes were written and read back and the first bytes inspected, on the date above.
- **From source** means read out of `.gitattributes` or a function file.

> **The one-line summary:** on Windows PowerShell 5.1, `Out-File` writes UTF-16 unless told otherwise, and
> Git will not show you a line-ending mistake because it normalizes before diffing. Those two facts together
> explain almost everything in this file.

## 1. Measured: what each write method produces

Same nine-character payload, so the byte counts are comparable. `Out-File` adds a trailing newline, which is
the 2-byte difference against the .NET call.

| Write method | Windows PowerShell 5.1 | PowerShell 7 |
| --- | --- | --- |
| `Out-File` with no `-Encoding` | **UTF-16 LE + BOM**, 24 B | UTF-8 no BOM, 11 B |
| `Out-File -Encoding utf8` | UTF-8 **with BOM**, 14 B | UTF-8 no BOM, 11 B |
| `[System.IO.File]::WriteAllText` with `UTF8Encoding($false)` | UTF-8 no BOM, 9 B | UTF-8 no BOM, 9 B |

Three things follow:

- A bare `Out-File` is the usual reason a Windows-authored JSON or config file turns out to be UTF-16.
- `-Encoding utf8` does **not** make the editions agree. 5.1 has no `utf8NoBOM`; that value arrived in
  PowerShell 6. It does eliminate UTF-16, which is normally the actual complaint.
- Only the .NET call is byte-identical across editions. It costs the path handling in section 4.

`Set-Content` is not a way out: 5.1 defaults it to the ANSI code page, which is worse than either.

## 2. Measured: reading is far more forgiving than writing

`Get-Content` detects a BOM and honors it, and a specified `-Encoding` does not override a BOM that is
actually present. Every combination below round-tripped the content correctly:

| File on disk | 5.1 plain | 5.1 `-Encoding UTF8` | 7 plain | 7 `-Encoding UTF8` |
| --- | --- | --- | --- | --- |
| UTF-16 LE + BOM | OK | OK | OK | OK |
| UTF-8 + BOM | OK | OK | OK | OK |
| UTF-8 no BOM | OK | OK | OK | OK |

This is why changing how a file is written needs no migration: files written by an older version keep
reading. Note the caveat, which this test does not cover because the payload was ASCII: a UTF-8 file with
**no BOM** and **non-ASCII content** read by 5.1's plain `Get-Content` is decoded as the ANSI code page and
will corrupt. Specify `-Encoding UTF8` on reads if content may be non-ASCII.

## 3. Measured: a BOM clears itself on the next write

`Out-File -Force` truncates before writing, so a BOM is not sticky. A config written by 5.1
(`UTF-8 (BOM)`, 314 B) and then rewritten by PowerShell 7 came back `UTF-8 (no BOM)`, 307 B, with all field
values intact. Anyone working only in PowerShell 7 therefore ends up with no BOMs regardless of what wrote
the file previously.

## 4. Measured: `.NET` and `Out-File` disagree about relative paths

This is the trap that makes "just use `WriteAllText`" more than a swap.

- `Out-File -FilePath` resolves through PowerShell's provider, so it honors the **PowerShell location**.
- `[System.IO.File]::WriteAllText` resolves against **`[Environment]::CurrentDirectory`**, the process
  working directory, which PowerShell does not keep in step with `Set-Location`.

A relative path such as the documented `Set-SKYAPIConfig -ConfigPath '.\Config\sky_api_config.json'` will
land somewhere unexpected if the write is swapped naively. Resolve first:

```powershell
$FullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
```

Unresolved, because the file need not exist yet. `-Force` also differs: `Out-File -Force` overwrites a
read-only file, while `WriteAllText` throws on one.

## 5. Measured: Git hides line-ending mistakes

Git normalizes line endings before comparing, so **a file with the wrong endings produces no diff and leaves
`git status` clean**. Nothing surfaces the problem on its own; it has to be asked for:

```powershell
git ls-files --eol -- '*.ps1' '*.psm1' '*.psd1' '*.md'
```

`i/` is the index copy, `w/` is the working tree. `attr/` shows the rule from `.gitattributes`. A row reading
`i/lf w/crlf attr/text eol=lf` is a working file that disagrees with the pin.

Two consequences measured here:

- **Switching the pin costs nothing.** Git already stores LF, so changing `eol=crlf` to `eol=lf` and
  converting 122 working files produced **zero** content diff; only `.gitattributes` itself changed.
- **Enumerate with `--cached --others --exclude-standard`.** That covers files written but not yet
  committed while still honoring `.gitignore`, which plain `git ls-files` does not.

`Tests/TestRepoHygiene_FileEncoding.ps1` runs these checks as part of the offline suite.

## 6. Measured: Git treats UTF-16 as binary, and bulk text tools destroy it

A UTF-16 file contains NUL bytes, so Git classifies it `-text`. That means no line-ending rule applies to
it, and Git shows `Bin 784 -> 383 bytes` instead of a diff, so a change to it cannot be reviewed normally.

More dangerous: a bulk "read text, write text" pass silently re-encodes it. Running `ReadAllText` (which
detects the UTF-16 BOM) followed by `WriteAllText` (which defaults to UTF-8) over
`Sample_Usage_Scripts/@SKYAPI Module/Config/sky_api_config.json` cut it from 784 bytes to 383 with no error
and no warning. **Before any bulk pass over text files, skip anything containing a NUL byte**, which is
Git's own binary heuristic.

That file had been UTF-16 since its first commit in 2023 and was converted to UTF-8 in 0.5.1, along with the
four `Out-File` calls that produced files like it. Its three sibling config templates were always UTF-8,
which is the sort of inconsistency worth checking for.

## 7. From source: what this repository pins

`.gitattributes` pins every text type to `eol=lf`, which is what Git stores anyway, so a checked-out file is
byte for byte the repository's copy on any platform and under any `core.autocrlf`. No text file is BOM-free
by accident; all of them are pure ASCII. Binaries under `SKYAPI/Dependencies` are marked `binary` so no
conversion can touch them.

## 8. Unverified

- Whether any consumer outside PowerShell reads the configuration or tokens files, which is what would make
  the BOM that 5.1 writes actually matter rather than merely being untidy.
- Whether a UTF-8 file with no BOM and non-ASCII content is corrupted by 5.1's plain `Get-Content` in
  practice here. It follows from the documented default, but every payload measured above was ASCII.
