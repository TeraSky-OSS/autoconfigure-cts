#!/bin/bash

########################
# include the magic
########################

. ./demo-magic.sh
TYPE_SPEED=80
clear

pe 'tree --filesfirst | ccat'
export KUBECONFIG=/tmp/kubeconfig
cd hcp
#pe "export CONSUL_HTTP_TOKEN=$(terraform output --raw consul_root_token_secret_id )"
#pe "export CONSUL_PRIVATE_ADDRESS=$(terraform output --raw consul_private_endpoint)"
#pe "export CONSUL_PUBLIC_ADDRESS=$(terraform output --raw consul_public_endpoint)"

#pe "bat  config.yaml"
#pe 'kubectl get svc'
########## Vault part ###########

#export VAULT_TOKEN=$(terraform output --raw vault_admin_token)
#export VAULT_ADDR=$(terraform output --raw vault_public_endpoint_url)
#export VAULT_PRIVATE_ADDR=$(terraform output --raw vault_private_endpoint_url)
#export VAULT_NAMESPACE=admin
#pe "bat values.yaml"
cd ../vault
pe "cd ../boundary"
pe 'tree'


pe "bat ./kubernetes/boundary.tf #images"
pe "bat ./kubernetes/boundary_config.tf #worker"
pe "bat ./boundary/scopes.tf #scopes"

#p "Getting boundary IP and scopes"
#pe "export BOUNDARY_ADDR=$(kubectl get svc boundary-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
#pe "export DEV_SCOPE_ID=$(terraform output --raw dev_scope_id)"
#pe "export DBA_SCOPE_ID=$(terraform output --raw dba_scope_id)"

pe 'bat cts.hcl'
pe 'bat cts.yaml'
#pe "bat ./vault.tfvars"
pe 'kubectl exec -it cts -- ls -l /consul-terraform-sync/sync-tasks/auto-onboard-task'
pe "kubectl exec -it cts -- cat /consul-terraform-sync/sync-tasks/auto-onboard-task/terraform.tfvars"


pe "code ../"
#pe 'ls -l ../auto-onboard-module'
#pe 'bat  ../auto-onboard-module/main.tf'
#pe 'bat  ../auto-onboard-module/boundary.tf'
#pe 'ls -l ../auto-app-module'
#pe 'bat  ../auto-app-module/main.tf'
#pe 'bat  ../auto-app-module/boundary.tf'
#pe "kubectl get clusterrolebinding dontdothisathome -o yaml"