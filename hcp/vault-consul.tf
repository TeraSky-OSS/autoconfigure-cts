resource "hcp_vault_cluster" "terasky_hcp_vault" {
  hvn_id          = hcp_hvn.terasky_hcp_hvn.hvn_id
  cluster_id      = "terasky-vault"
  public_endpoint = true
}

resource "hcp_vault_cluster_admin_token" "demo_hcp_vault_token" {
  cluster_id = hcp_vault_cluster.terasky_hcp_vault.cluster_id
}

resource "hcp_consul_cluster" "demo_hcp_consul" {
  hvn_id          = hcp_hvn.terasky_hcp_hvn.hvn_id
  cluster_id      = "terasky-consul"
  tier            = "development"
  public_endpoint = true
}

#TODO set fixed versions