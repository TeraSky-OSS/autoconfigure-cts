resource "boundary_host_catalog" "databases" {
  name        = "databases"
  description = "Database targets"
  type        = "static"
  scope_id    = boundary_scope.dba_support.id
}
