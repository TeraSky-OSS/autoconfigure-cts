#!/bin/bash

########################
# include the magic
########################

. ./demo-magic.sh -n
TYPE_SPEED=80
clear

pe 'ls -l'
pe 'cd aws'
pe './get-kubecconfig.sh'
pe 'cp ./kubeconfig /tmp/kubeconfig'
pe 'export KUBECONFIG=/tmp/kubeconfig'
pe 'cd ../hcp'
pe 'ls -l'
pe 'cat outputs.tf'
pe 'export CONSUL_HTTP_TOKEN=$(terraform output --raw consul_root_token_secret_id )'
pe "echo ${CONSUL_HTTP_TOKEN}"

pe 'export CONSUL_PRIVATE_ADDRESS=$(terraform output --raw consul_private_endpoint)'

pe 'export CONSUL_PUBLIC_ADDRESS=$(terraform output --raw consul_public_endpoint)'

pe 'terraform output --raw consul_ca_file |  base64 -d> ./ca.pem'

pe "kubectl create secret generic \"consul-ca-cert\" --from-file='tls.crt=./ca.pem'"

pe 'terraform output --raw consul_config_file | base64 -d | jq > client_config.json'
pe 'cat client_config.json'
pe 'kubectl create secret generic "consul-gossip-key" --from-literal="key=$(jq -r .encrypt client_config.json)"'

pe 'kubectl create secret generic "consul-bootstrap-token" --from-literal="token=${CONSUL_HTTP_TOKEN}"'
# read about bootstrap ACL
#https://learn.hashicorp.com/tutorials/consul/access-control-setup-production?in=consul/security

pe 'export DATACENTER=$(jq -r .datacenter client_config.json)'
pe 'export RETRY_JOIN=$(jq -r --compact-output .retry_join client_config.json)'
pe 'export K8S_HTTP_ADDR=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$(kubectl config current-context)\")].cluster.server}")'
pe 'echo $DATACENTER && \
  echo $RETRY_JOIN && \
  echo $K8S_HTTP_ADDR'

cat > config.yaml << EOF
global:
  logLevel: "debug"
  name: terasky-consul
  enabled: false
  datacenter: ${DATACENTER}
  acls:
    manageSystemACLs: true
    bootstrapToken:
      secretName: consul-bootstrap-token
      secretKey: token
  gossipEncryption:
    secretName: consul-gossip-key
    secretKey: key
  tls:
    enabled: true
    enableAutoEncrypt: true
    caCert:
      secretName: consul-ca-cert
      secretKey: tls.crt
  enableConsulNamespaces: true
externalServers:
  enabled: true
  hosts: ${RETRY_JOIN}
  httpsPort: 443
  useSystemRoots: true
  k8sAuthMethodHost: ${K8S_HTTP_ADDR}
client:
  enabled: true
  join: ${RETRY_JOIN}
connectInject:
  enabled: true
controller:
  enabled: false
ingressGateways:
  enabled: false
syncCatalog:
  enabled: true
  syncClusterIPServices: false
EOF

# Must have connectInject for consul installation to pass

pe 'cat config.yaml'
pe 'helm install --wait consul -f config.yaml hashicorp/consul --version "0.43.0" --set global.image=hashicorp/consul-enterprise:1.12.0-ent'

pe 'kubectl get pods'

echo "Open $(terraform output consul_public_endpoint) and use ${CONSUL_HTTP_TOKEN} token to login" > ./open_consul
p "Open $(terraform output consul_public_endpoint) and use ${CONSUL_HTTP_TOKEN} token to login"
pe 'kubectl get svc'

########## Vault part ###########
# Currently not used was setup initially to demonstrate intgeration of CTS with vault for pulling terraform cloud token

pe 'export VAULT_TOKEN=$(terraform output --raw vault_admin_token)'
pe 'echo $VAULT_TOKEN'
pe 'export VAULT_ADDR=$(terraform output --raw vault_public_endpoint_url)'
pe 'echo $VAULT_ADDR'
pe 'export VAULT_PRIVATE_ADDR=$(terraform output --raw vault_private_endpoint_url)'
pe 'echo $VAULT_PRIVATE_ADDR'
p "Default namespace in hcp is admin"
pe "export VAULT_NAMESPACE=admin"
pe "vault status"

echo "Open ${VAULT_ADDR} and use ${VAULT_TOKEN} token to login" > ./open_vault
p "Let install vault injector in EKS"
pe "helm repo add hashicorp https://helm.releases.hashicorp.com && helm repo update"
cat > values.yaml << EOF
injector:
   enabled: true
   externalVaultAddr: "${VAULT_PRIVATE_ADDR}"
EOF

pe "cat values.yaml"
pe "helm install --wait vault -f values.yaml hashicorp/vault"

pe "kubectl get pods"

pe "clear"

p "Configure how EKS workloads authenticate with Vault"

echo '#example of configuration' > config_example
echo "export TF_VAR_TOKEN_REVIEW_JWT=\$(kubectl get secret \$(kubectl get serviceaccount vault -o jsonpath='{.secrets[0].name}')  -o jsonpath='{ .data.token }' | base64 --decode)" >> config_example
echo "export TF_VAR_KUBE_CA_CERT=\$(kubectl get secret  \$(kubectl get serviceaccount vault -o jsonpath='{.secrets[0].name}') -o jsonpath='{ .data.ca\.crt }' | base64 --decode)" >> config_example
echo "export TF_VAR_KUBE_HOST=\$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')" >> config_example

pe "cat config_example"
export TF_VAR_TOKEN_REVIEW_JWT=$(kubectl get secret \
   $(kubectl get serviceaccount vault -o jsonpath='{.secrets[0].name}') \
   -o jsonpath='{ .data.token }' | base64 --decode)

export TF_VAR_KUBE_CA_CERT=$(kubectl get secret  $(kubectl get serviceaccount vault -o jsonpath='{.secrets[0].name}') -o jsonpath='{ .data.ca\.crt }' | base64 --decode)
echo
export TF_VAR_KUBE_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
echo
p "Let's get oidc issuer"
pe "kubectl proxy &"
pe "curl --silent http://127.0.0.1:8001/.well-known/openid-configuration | jq -r .issuer"
export TF_VAR_ISSUER="$(curl --silent http://127.0.0.1:8001/.well-known/openid-configuration | jq -r .issuer)"
pe "kill %1"
pe 'export TF_VAR_TFE_TOKEN=$(cat ~/.terraform.d/credentials.tfrc.json | jq -r ".credentials.\"app.terraform.io\".token")'
pe "pwd"
pe "cd ../vault"
pe "cat providers.tf"
pe "cat main.tf"
pe "terraform init"
pe "terraform apply --auto-approve"


#------ Boundary in Kubernetes setup -----------------------------------
p "deploying boundary according to boundary-reference-architecture github"
# https://github.com/hashicorp/boundary-reference-architecture
pe 'cd ../boundary'
pe 'terraform init'
pe 'terraform apply -auto-approve -target module.kubernetes'
export BOUNDARY_ADDR=$(kubectl get svc boundary-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
until nc -vzw 2 ${BOUNDARY_ADDR} 9200; do sleep 2;echo "waiting for boundary address to propogate"; done
terraform apply -auto-approve -target module.boundary -var boundary_addr="http://${BOUNDARY_ADDR}:9200"
export DEV_SCOPE_ID=$(terraform output --raw dev_scope_id)
export DBA_SCOPE_ID=$(terraform output --raw dba_scope_id)

#############################

#------ CTS deploy in kubernetes

#####hashicorp/consul-terraform-sync
cat > cts.hcl << EOF
log_level = "TRACE"
consul {
  address = "${CONSUL_PUBLIC_ADDRESS}"
  token = "${CONSUL_HTTP_TOKEN}"
  service_registration {
    enabled = false
  }
}
license {
         auto_retrieval {
                 enabled = true
        }
}
vault {
  address = "${VAULT_ADDR}"
  enabled = true
  namespace = "admin"
  renew_token = false
  token = "${VAULT_TOKEN}"
}
task {
  name = "auto-onboard-task"
  description = "Writes the service name, id, and IP address to a file"
  module      = "./auto-onboard-module"
  providers = ["local","vault","kubernetes","boundary"]
  variable_files = ["/consul-terraform-sync/vars/vault.tfvars"]
  condition "services" {
    regexp = ".*postgresql.*"
  }
}
task {
  name = "auto-app-task"
  description = "Writes the service name, id, and IP address to a file"
  module      = "./auto-app-module"
  providers = ["local","vault","kubernetes","boundary"]
  variable_files = ["/consul-terraform-sync/vars/vault.tfvars"]
  condition "services" {
    regexp = ".*app.*"
  }
}
driver "terraform" {
  backend "local" {
    path = "./terraform.tfstate"
  }
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "2.1.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.6.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.11.0"
    }
    boundary = {
      source = "hashicorp/boundary"
      version = "1.0.8"
    }
  }
}
terraform_provider "local" {
}
terraform_provider "kubernetes" {
}
terraform_provider "vault" {
  address = "${VAULT_ADDR}"
  namespace = "admin"
  token = "${VAULT_TOKEN}"
}
terraform_provider "boundary" {
  addr             = "http://${BOUNDARY_ADDR}:9200"
  recovery_kms_hcl = <<EOT
kms "aead" {
  purpose = "recovery"
  aead_type = "aes-gcm"
  key = "8fZBjCUfN0TzjEGLQldGY4+iE9AkOvCfjh7+p0GtRBQ="
  key_id = "global_recovery"
}
EOT
}
EOF
pe 'cat cts.hcl'
pe 'kubectl create secret generic cts-config --from-file=./cts.hcl'
pe "pwd"
pe 'kubectl create secret generic auto-onboard-module --from-file=../auto-onboard-module'
pe 'kubectl create secret generic auto-app-module --from-file=../auto-app-module'
pe "curl https://boundaryproject.io/data/vault/boundary-controller-policy.hcl -O -s -L"
pe "cat boundary-controller-policy.hcl"
pe "cat read-db-creds-policy.hcl"
pe "vault policy write boundary-controller boundary-controller-policy.hcl"
pe "pwd"
pe "vault policy write read-db-creds-policy read-db-creds-policy.hcl"
echo "vault_addr=\"${VAULT_ADDR}\"" > ./vault.tfvars
pe "export VAULT_BOUNDARY_TOKEN=$(vault token create -no-default-policy=true -policy='boundary-controller' -policy='read-db-creds-policy' -orphan=true -period=300m -renewable=true -namespace=admin| grep '^token ' | awk '{print $2}')"
echo "vault_boundary_token=\"${VAULT_BOUNDARY_TOKEN}\"" >> ./vault.tfvars
echo "dev_scope_id=\"${DEV_SCOPE_ID}\"" >> ./vault.tfvars
echo "dba_scope_id=\"${DBA_SCOPE_ID}\"" >> ./vault.tfvars
pe "cat ./vault.tfvars"
pe 'kubectl create secret generic vault-vars --from-file=./vault.tfvars'

p "Let's deploy terraform consul sync"
cat > cts.yaml <<EOF
---
apiVersion: v1
kind: Pod
metadata:
  name: cts
  labels:
    app: cts
spec:
  serviceAccountName: cts
  containers:
    - name: cts
      image: hashicorp/consul-terraform-sync-enterprise:0.6-ent
      args:
      - "-config-file"
      - "/etc/cts/cts.hcl"
      volumeMounts:
      - name: cts-config
        mountPath: "/etc/cts"
      - name: auto-onboard-module
        mountPath: "/consul-terraform-sync/auto-onboard-module"
      - name: auto-app-module
        mountPath: "/consul-terraform-sync/auto-app-module"
      - name: vault-vars
        mountPath: "/consul-terraform-sync/vars"
  volumes:
  - name: cts-config
    secret:
      secretName: cts-config
  - name: auto-onboard-module
    secret:
      secretName: auto-onboard-module
  - name: auto-app-module
    secret:
      secretName: auto-app-module
  - name: vault-vars
    secret:
      secretName: vault-vars
EOF
pe "kubectl create sa cts"
pe "kubectl create clusterrolebinding dontdothisathome --serviceaccount=default:cts --clusterrole=cluster-admin"
pe 'cat cts.yaml'
pe 'kubectl apply -f cts.yaml'
pe 'kubectl wait pod/cts --for condition=ready'
pe 'kubectl logs cts'
p 'update the cname/hosts for the boundary service'
p "$(cat ../hcp/open_vault)"
p "$(cat ../hcp/open_consul)"
p "Open http://${BOUNDARY_ADDR}:9200 and login"
