resource "boundary_scope" "global" {
  global_scope = true
  name         = "global"
  scope_id     = "global"
}

resource "boundary_scope" "org" {
  scope_id    = boundary_scope.global.id
  name        = "primary"
  description = "Primary organization scope"
}

resource "boundary_scope" "dba_support" {
  name                     = "dba-support"
  description              = "Databases project"
  scope_id                 = boundary_scope.org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_scope" "dev_accss" {
  name                     = "dev-access"
  description              = "Project for accessing endpoints"
  scope_id                 = boundary_scope.org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}
