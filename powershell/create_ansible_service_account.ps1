# Create dedicated service account for Ansible
New-LocalUser -Name "ansible_service" -Password (ConvertTo-SecureString "SecurePassword123!" -AsPlainText -Force) -Description "Ansible Service Account"
Add-LocalGroupMember -Group "Administrators" -Member "ansible_service"

# Set password to never expire
Set-LocalUser -Name "ansible_service" -PasswordNeverExpires $true