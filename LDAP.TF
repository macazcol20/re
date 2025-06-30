## 6-vault-ldap-auth.tf
# Enable LDAP auth backend
resource "vault_auth_backend" "ldap" {
  type = "ldap"
  path = "ldap"
  description = "LDAP auth for Vault"
}

# Configure LDAP connection
resource "vault_ldap_auth_backend" "ldap_config" {
  backend              = vault_auth_backend.ldap.path
  url                  = "ldaps://ldap.fcb.com"
  userdn               = "ou=Users,dc=fcb,dc=com"
  groupdn              = "ou=Groups,dc=fcb,dc=com"
  binddn               = "cn=vaultbinduser,ou=serviceUsers,dc=fcb,dc=com"
  bindpass             = "SuperSecureVaultBindPassword"
  userattr             = "sAMAccountName"
  groupfilter          = "(&(objectClass=group)(cn=*))"
  groupattr            = "cn"
  discoverdn           = true
  starttls             = false
  insecure_tls         = false
  upndomain            = "FCB.COM"
  token_ttl            = "1h"
  token_max_ttl        = "4h"
  token_policies       = ["default"]
  depends_on           = [vault_auth_backend.ldap]
}


## ldap_auth_backend_group.tf
resource "vault_ldap_auth_backend_group" "dev_group" {
  name    = "vault_dev_group" # LDAP group CN
  backend = vault_auth_backend.ldap.path
  policies = ["middleware-dev"]
}

resource "vault_ldap_auth_backend_group" "qa_group" {
  name    = "vault_qa_group"
  backend = vault_auth_backend.ldap.path
  policies = ["middleware-qa"]
}

resource "vault_ldap_auth_backend_group" "pstage_group" {
  name    = "vault_pstage_group"
  backend = vault_auth_backend.ldap.path
  policies = ["middleware-pstage"]
}

resource "vault_ldap_auth_backend_group" "prod_group" {
  name    = "vault_prod_group"
  backend = vault_auth_backend.ldap.path
  policies = ["middleware-prod"]
}
