#!/bin/bash

cd hcp
export VAULT_TOKEN=$(terraform output --raw vault_admin_token)
export VAULT_ADDR=$(terraform output --raw vault_public_endpoint_url)
export VAULT_PRIVATE_ADDR=$(terraform output --raw vault_private_endpoint_url)
export VAULT_NAMESPACE=admin
cd ..
export TF_VAR_TFE_TOKEN=$(cat ~/.terraform.d/credentials.tfrc.json | jq -r '.credentials."app.terraform.io".token')
helm uninstall consul
rm ./hcp/ca.pem
kubectl delete secret consul-ca-cert
rm ./hcp/client_config.json
kubectl delete secret consul-gossip-key
kubectl delete secret consul-bootstrap-token
rm ./hcp/config.yaml
rm ./hcp/config_example
rm ./hcp/values.yaml
kubectl get pods
cd ./vault ;terraform destroy ;cd ../
vault lease revoke -namespace=admin -force  -prefix  "db1-postgresql-default"
rm boundary-controller-policy.hcl
vault policy delete boundary-controller
vault policy delete read-db-creds-policy
helm uninstall vault
export BOUNDARY_ADDR=$(kubectl get svc boundary-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
cd ./boundary; terraform destroy -var boundary_addr="http://${BOUNDARY_ADDR}:9200" ; cd ../
kubectl delete -f ./boundary/cts.yaml
rm ./boundary/cts.yaml
rm ./boundary/cts.hcl
kubectl delete secret cts-config
kubectl delete secret auto-onboard-module
rm ./boundary/vault.tfvars
kubectl delete secret vault-vars
helm uninstall db1
kubectl delete svc consul
kubectl delete sa cts
kubectl delete clusterrolebinding dontdothisathome
for pvc in $(kubectl get pvc | grep -v NAME| awk '{print $1}');do kubectl delete pvc $pvc; done
pwd
kubectl delete -f service-sample.yaml
kubectl delete secret auto-app-module
rm /tmp/kubeconfig
