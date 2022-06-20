# ---------------- database onboard -----------------
locals {
  non_hl_services = { for k, v in var.services : k => v if length(regexall(".*-hl-.*| app-.*", v.name)) == 0 }
}

resource "vault_mount" "dbs" {
  for_each = local.non_hl_services
  path     = each.value.name
  type     = "database"
}
# wait until load balancer is available

resource "null_resource" "wait_for_elb_dns" {
  for_each = local.non_hl_services
  triggers = {
    loadbalancer_address = each.value.address
  }

  provisioner "local-exec" {
    command = "until nc -vzw 2 ${each.value.address} ${each.value.meta.port-tcp-postgresql}; do sleep 2; done"
  }
}

# get password from secret
data "kubernetes_secret_v1" "postgresql_password" {
  for_each = local.non_hl_services
  metadata {
    name = trimsuffix(each.value.name, "-${each.value.meta.external-k8s-ns}")
  }
}

#configure connection
resource "vault_database_secret_backend_connection" "postgres" {
  for_each      = local.non_hl_services
  backend       = vault_mount.dbs[each.key].path
  name          = each.value.name
  allowed_roles = ["*"]

  postgresql {
    connection_url = "postgres://postgres:${nonsensitive(data.kubernetes_secret_v1.postgresql_password[each.key].data.postgres-password)}@${each.value.address}:${each.value.meta.port-tcp-postgresql}/postgres?sslmode=disable"
  }
  depends_on = [null_resource.wait_for_elb_dns]
}

# configure support role
resource "vault_database_secret_backend_role" "support" {
  for_each            = local.non_hl_services
  backend             = vault_mount.dbs[each.key].path
  name                = "${each.value.name}-support"
  db_name             = vault_database_secret_backend_connection.postgres[each.key].name
  creation_statements = ["CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"]
}