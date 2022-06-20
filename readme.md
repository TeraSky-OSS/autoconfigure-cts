# Auto-configure Vault and Boundary with CTS

This repo can help you setup the demo environment and show demonstration of database and application deployment.


## Assumed software on the machine
This guide was tested on MacOs (M1) and assumes you have the following software present:
- terraform binary
- vault binary
- boundary binary 
- kubectl
- helm

## Assumed services accounts
This guide assumes you have Hashicorp cloud account, with organization and service principals and keys configured. 
This guide also assumes you have Terraform enterprise account and performed ```terraform login```.
This guide assumes you have AWS account and performed ```aws configure``` .

## Create Terraform Cloud workspaces
- create terraform cloud workspace for aws ( can be configured with VCS or as cli driven )
- create terraform cloud workspace for hcp ( can be configured with VCS or as cli driven )
- create variable set with the following environment variables:
	- HCP_CLIENT_ID
	- HCP_CLIENT_SECRET
	- AWS_ACCESS_KEY_ID
	- AWS_DEFAULT_REGION
	- AWS_SECRET_ACCESS_KEY
- apply variable set to aws and hcp workspaces
- in ```aws``` directory edit remote.tf to represent your Terraform cloud configuration
```
terraform {  
  backend "remote" {  
    hostname = "app.terraform.io"  
	organization = "Your Organization>"  
  
	workspaces {  
      name = "aws"  
    }  
  }  
  required_providers {  
    aws = {  
      source = "registry.terraform.io/hashicorp/aws"  
	  version = "4.14.0"  
	}  
  }  
}
```
- in ```hcp``` directory edit remote.tf to represent your Terraform cloud configuration similar to previous step
- (optional) in ```boundary/kubernetes/boundary_config.tf``` you may change configuration of worker ```public_addr``` from ```boundary.lev-labs.com``` to your preferred FQDN

## The flow
- ```terraform apply``` your aws directory/worksteps
- wait until the first step is completed 
- ```terraform apply``` your hcp directory/worksteps
- if you're looking for "slower" and interactive setup of environment (boundary deploy, consul deployment, cts deployment ,etc ) you can edit ```00-how-to-setup.sh``` and change the ```. ./demo-magic.sh -n``` to ```. ./demo-magic.sh``` ( removing -n)
- run ```./00-how-to-setup.sh```
- upon completion get FQDN of the boundary service
	- run ``export KUBECONFIG=/tmp/kubeconfig```
	- run ```kubectl get svc```
		- option 1:  get the IP of the LoadBalancer of ```boundary-controller``` service and save in your /etc/hosts the following record 
		```<IP of ELB> <FQDN you used for public address of boundary worker```
		for example
		```34.251.77.58 boundary.lev-labs.com```
		- option 2: configure your CNAME you used for public address of boundary worker to point to 	  load balancer FQDN,
- run ```./01-how-it-looks.sh```
- run ```./02-how-it-works.sh```