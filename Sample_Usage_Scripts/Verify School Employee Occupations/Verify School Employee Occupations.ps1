# Verify School Employee Occupations
# TODO: Finish sample script

$staffrole = get-schoolrole | Where-Object name -eq "Staff"
$facultyrole = get-schoolrole | Where-Object name -eq "Faculty"

[string]$stafffaculttyidsasstring = $([string]$staffrole.id) + $(',') + $([string]$facultyrole.id)

$employees = Get-SchoolUserByRole -roles $stafffaculttyidsasstring

foreach ($employee in $employees)
{
    [array]$employment = Get-SchoolUserOccupation -User_ID $employee.id | Where-Object { $_.current -eq $true }
    Write-Host "Employee: $($employee.first_name) $($employee.last_name) - $($employee.id)"
    if ($employment.Count -ne 1)
    {
        Write-host -ForegroundColor Yellow -Message "WARNING: Job count not equal to 1. Count is: $($employment.Count)"
    }
    Write-host -ForegroundColor Green -Message "Business: $($employment.business_name)"
    Write-host -ForegroundColor Blue -Message "Job Title: $($employment.title)`n"
}