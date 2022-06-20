#------------------- Configure boundary accesss to db
resource "boundary_host_catalog_static" "static" {
  scope_id = var.dba_scope_id
}

# Create static hosts for each db service
resource "boundary_host_static" "dba-service" {
  host_catalog_id = boundary_host_catalog_static.static.id
  for_each        = local.non_hl_services
  name            = each.value.name
  description     = "static host ${each.value.name}"
  address         = each.value.address
}

# Group hosts into host set
resource "boundary_host_set_static" "dba" {
  for_each        = local.non_hl_services
  host_catalog_id = boundary_host_catalog_static.static.id
  type            = "static"
  host_ids = [
    boundary_host_static.dba-service[each.key].id
  ]
}

# Creste target for the host set (define on which port we're going to connect)
resource "boundary_target" "dba_target" {
  for_each     = local.non_hl_services
  name         = each.value.name
  description  = "Target for ${each.value.name}"
  type         = "tcp"
  default_port = each.value.meta.port-tcp-postgresql
  scope_id     = var.dba_scope_id
  host_source_ids = [
    boundary_host_set_static.dba[each.key].id
  ]
  application_credential_source_ids = [
    boundary_credential_library_vault.db_support_library[each.key].id
  ]
}

# Configure vault connection for boundary to pull dynamic secrets
resource "boundary_credential_store_vault" "vault_cred_store" {
  namespace   = "admin"
  name        = "vault_store"
  description = "Vault Credential store"
  address     = var.vault_addr
  token       = var.vault_boundary_token
  scope_id    = var.dba_scope_id
}

# Configure which dynamic secret to use when connecting to target
resource "boundary_credential_library_vault" "db_support_library" {
  for_each            = local.non_hl_services
  name                = each.value.name
  description         = "credential library for ${each.value.name}"
  credential_store_id = boundary_credential_store_vault.vault_cred_store.id
  path                = "${vault_mount.dbs[each.key].path}/creds/${vault_database_secret_backend_role.support[each.key].name}"
  http_method         = "GET"
}