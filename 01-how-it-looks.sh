#!/bin/bash

########################
# include the magic
########################
wget
. ./demo-magic.sh
TYPE_SPEED=80
clear

#p "Getting consul hcp token and address"
cd aws
export KUBECONFIG=/tmp/kubeconfig
#cd ../hcp
#export CONSUL_HTTP_TOKEN=$(terraform output --raw consul_root_token_secret_id )
#export CONSUL_PRIVATE_ADDRESS=$(terraform output --raw consul_private_endpoint)
#export CONSUL_PUBLIC_ADDRESS=$(terraform output --raw consul_public_endpoint)
#p "Open $(terraform output consul_public_endpoint) and use ${CONSUL_HTTP_TOKEN} token to login"
#p "$(cat ./open_consul)"
########## Vault part ###########
#p "Getting vault hcp token"
#export VAULT_TOKEN=$(terraform output --raw vault_admin_token)
#export VAULT_ADDR=$(terraform output --raw vault_public_endpoint_url)
#export VAULT_PRIVATE_ADDR=$(terraform output --raw vault_private_endpoint_url)
#export VAULT_NAMESPACE=admin
#p "Open ${VAULT_ADDR} and use ${VAULT_TOKEN} token to login"
#p "$(cat ./open_vault)"
cd ../boundary
export BOUNDARY_ADDR=$(kubectl get svc boundary-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
#export DEV_SCOPE_ID=$(terraform output --raw dev_scope_id)
#export DBA_SCOPE_ID=$(terraform output --raw dba_scope_id)
#p "Open http://${BOUNDARY_ADDR}:9200 and login"
#############################
pe 'kubectl get pods'
pe 'kubectl get svc'

p "Deploying database"

pe 'helm repo add bitnami https://charts.bitnami.com/bitnami'
pe 'helm install --wait db1 bitnami/postgresql  --set primary.service.type=LoadBalancer'
pe 'kubectl get pods'
pe 'kubectl get svc'
p  "show what changed in Consul, Vault and Boundary"

p "Deploying sample application"
pe 'bat ../service-sample.yaml'
pe 'kubectl apply -f ../service-sample.yaml'
pe 'kubectl get pods'
pe 'kubectl get svc'
pe "export SAMPLE_CONTAINER=$(kubectl get pods | grep 'postgresql-deployment'| awk '{print $1}')"
pe "kubectl wait pods -n default ${SAMPLE_CONTAINER} --for condition=Ready --timeout=90s"
p  "show what changed in Consul, Vault and Boundary"


pe "kubectl exec -it ${SAMPLE_CONTAINER}  -c postgresql -- cat /vault/secrets/check"
pe "kubectl exec -it ${SAMPLE_CONTAINER}  -c postgresql  -- bash /vault/secrets/check"
cd ..
pe "export BOUNDARY_ADDR=http://${BOUNDARY_ADDR}:9200"
pe "export PRIMARY_SCOPE_ID=$(boundary scopes list | grep -B2 primary | grep ID| awk '{print $2}')"
pe "export AUTH_METHOD_ID=$(boundary auth-methods list -scope-id=${PRIMARY_SCOPE_ID} | grep ID| awk '{print $2}')"
pe "boundary authenticate password -auth-method-id=${AUTH_METHOD_ID} -login-name=jeff"
while [ $? -ne 0 ] ; do p "shaky hands?!"; pe "boundary authenticate password -auth-method-id=${AUTH_METHOD_ID} -login-name=jeff" ; done
#pe "export APP_SAMPLE_TARGET=$(boundary targets list -scope-id=${DEV_SCOPE_ID} | grep ID | awk '{print $2}')"
#pe "export DB_TARGET=$(boundary targets list -scope-id=${DBA_SCOPE_ID} | grep -B3 db1-postgresql-default | grep ID | awk '{print $2}')"
pe "boundary connect http -target-name=app-sample-default -target-scope-name=dev-access -scheme=http"
pe "boundary connect postgres  -dbname postgres -target-name=db1-postgresql-default -target-scope-name=dba-support"