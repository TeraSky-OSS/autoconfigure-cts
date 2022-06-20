locals {
  app_services        = { for k, v in var.services : k => v if length(regexall("app-.*", v.name)) > 0 }
  app_services_labels = { for k, v in data.kubernetes_service.app : k => v.metadata[0].labels }
}

data "kubernetes_service" "app" {
  for_each = local.app_services
  metadata {
    name = trimsuffix(each.value.name, "-${each.value.meta.external-k8s-ns}")
  }
}

# The "making DBA love you" section
resource "vault_database_secret_backend_role" "app_role" {
  for_each            = local.app_services_labels
  backend             = each.value["database"]
  name                = each.value.name
  db_name             = each.value["database"]
  creation_statements = ["CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE ${each.value["schema"]}.${each.value["table"]} TO \"{{name}}\";"]
}

resource "vault_policy" "app_policy" {
  for_each = local.app_services_labels
  name     = each.value["name"]

  policy = <<EOT
path "${each.value.database}/creds/${each.value.name}" {
  capabilities = ["read"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "app_auth_role" {
  for_each                         = local.app_services_labels
  backend                          = "kubernetes"
  role_name                        = "${each.value.name}-role"
  bound_service_account_names      = [each.value.name]
  bound_service_account_namespaces = ["default"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.app_policy[each.key].name]
}
