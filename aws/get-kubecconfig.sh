#!/bin/bash 
aws eks \
    --region eu-west-1 \
    update-kubeconfig \
    --name kubernetes  \
    --kubeconfig kubeconfig
