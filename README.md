# Ansible Windows Automation

This repository contains the necessary files to automate the initial bootstrapping and ongoing management of Windows servers using Ansible. The workflow is designed for security and scalability, starting with a temporary bootstrap account and immediately transitioning to a dedicated, managed service account.

The primary goals of this project are:

* **Idempotent Provisioning:** Safely run tasks multiple times without causing unintended side effects.

* **Centralized Configuration:** Manage server configurations from a central location.

* **Secure Secrets Management:** Use Ansible Vault to encrypt sensitive data like passwords.

* **Dynamic Inventory:** Separate host-specific data from playbooks for reusability.

## Project Structure

The directory structure is organized to promote best practices and modularity:

.
├── ansible.cfg                          # Global Ansible configuration settings
├── bootstrap                            # Scripts to prepare a clean server for Ansible
│   ├── powershell
│   │   └── bootstrap-winrm.ps1          # PowerShell script to enable WinRM and create the initial bootstrap user
│   └── shell
│       └── ansible_bootstrap.sh         # Wrapper script to run the PowerShell bootstrap (optional)
├── collections                          # Ansible collections and roles dependencies
│   └── requirements.yml
├── inventory                            # Inventory files organized by environment and purpose
│   ├── bootstrap                        # Temporary inventory for initial server provisioning
│   │   ├── common
│   │   └── windows_servers
│   ├── development
│   ├── production
│   └── staging
├── playbooks                            # Ansible playbooks for specific automation tasks
│   ├── change_primary_ansible_user_password.yml
│   └── create_secondary_ansible_user.yml
└── roles                                # Placeholder for reusable role definitions


## Getting Started

### Prerequisites

* Ansible installed on your control node.

* A pre-shared vault password file (`.vault_pass`) in the root directory.

* A Windows Server prepared for WinRM (either manually or using the provided bootstrap script).

### Bootstrap a New Windows Server

1.  **Run the PowerShell Bootstrap Script:**
    On the new Windows server, run the `bootstrap-winrm.ps1` script as a Local Administrator. This script will set a static IP, configure WinRM over HTTP, and create the initial `ansible_primary_username` account with a temporary password.

2.  **Configure Ansible Inventory:**
    Ensure your `inventory/bootstrap/windows_servers` file is updated with the new server's IP address and the correct user variables. The `ansible_user` for the initial connection should match the user created by the bootstrap script.

3.  **Create Service Accounts:**
    Run the `create_secondary_ansible_user.yml` playbook. This playbook uses the primary bootstrap account to create a new, dedicated secondary service account.

    ```
    ansible-playbook playbooks/create_secondary_ansible_user.yml -i inventory/bootstrap/ --vault-password-file .secrets/.vault_pass
    
    ```

4.  **Rotate Primary Password:**
    After creating the secondary service account, it is a best practice to immediately change the primary account's password. The `change_primary_ansible_user_password.yml` playbook will connect with the new secondary account to set a new password for the primary account.

    ```
    ansible-playbook playbooks/change_primary_ansible_user_password.yml -i inventory/bootstrap/ --vault-password-file .secrets/.vault_pass
    
    ```

### Managing Secrets

Sensitive information such as passwords is encrypted using Ansible Vault. The vault password file (`.vault_pass`) is not stored in Git and must be kept secure.

To manage your vault files:

* **Edit a vault file:** `ansible-vault edit .secrets/primary_vault.yml`

* **View a vault file:** `ansible-vault view .secrets/primary_vault.yml`

* **Create a new vault file:** `ansible-vault create .secrets/new_vault.yml`