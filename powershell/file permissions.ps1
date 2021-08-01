
#Get all children of the SQL path
$files = Get-ChildItem -Path 'C:\Program Files\Microsoft SQL Server' -Recurse
$Account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList 'BUILTIN\Administrators';

# take ownership of everything (10k+ files so takes a bit)
foreach ($File in $files) {
    takeown /F $file.FullName
}

# At this point I used the GUI to flip the "replace child properties with parent" to do a hard reset on security
# Next I ran the new SQL file permission script developed with Joanne

# Finally I ran this snippet to make sure everything is owned by admins and not me
foreach ($File in $files) {

    $acl = get-acl $file.FullName
    $acl.SetOwner($Account)
    set-acl $file.FullName $acl
}