resource "boundary_host_catalog_static" "static" {
  scope_id = var.dev_scope_id
}

resource "boundary_host_static" "dev-service" {
  host_catalog_id = boundary_host_catalog_static.static.id
  for_each        = local.app_services
  name            = each.value.name
  description     = "static host ${each.value.name}"
  address         = each.value.address
}

resource "boundary_host_set_static" "dev" {
  for_each        = local.app_services
  host_catalog_id = boundary_host_catalog_static.static.id
  type            = "static"
  host_ids = [
    boundary_host_static.dev-service[each.key].id
  ]
}

resource "boundary_target" "dev_target" {
  for_each    = local.app_services
  name        = each.value.name
  description = "Target for ${each.value.name}"
  type        = "tcp"
  //  default_port = each.value.meta.port-tcp-postgresql
  default_port = "80"
  scope_id     = var.dev_scope_id
  host_source_ids = [
    boundary_host_set_static.dev[each.key].id
  ]
}