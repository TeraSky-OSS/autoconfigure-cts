resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "eks" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.KUBE_HOST
  kubernetes_ca_cert     = var.KUBE_CA_CERT
  token_reviewer_jwt     = var.TOKEN_REVIEW_JWT
  issuer                 = var.ISSUER
  disable_iss_validation = "true"
}

resource "vault_mount" "secret" {
  path = "secret"
  type = "kv-v2"
}

resource "vault_generic_secret" "tfe_token" {
  path = "${vault_mount.secret.path}/creds"
  data_json = jsonencode(
    {
      "tfe_token" = var.TFE_TOKEN
    }
  )
}