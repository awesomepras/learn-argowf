#!/bin/bash
echo ##########
echo
echo 'Starting installation of argo server'
echo 
echo '
alias k=kubectl
k create ns argo
k config set-context --current --namespace=argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.2/install.yaml
kubectl -n argo get deploy workflow-controller argo-server
kubectl -n argo wait deploy --all --for condition=Available --timeout 2m
'
echo 
echo ###############

kubectl create ns argo
kubectl config set-context --current --namespace=argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.2/install.yaml
kubectl -n argo get deploy workflow-controller argo-server
kubectl -n argo wait deploy --all --for condition=Available --timeout 2m
echo "argo started......."
ARGO_SERVER=0.0.0.0:2746
ARGO_SECURE=false

echo "set up port forwarding"
kubectl -n argo port-forward --address 0.0.0.0 svc/argo-server 2746:2746 > /dev/null &
echo "---------------------------------"
echo "install argo cli"

curl -sLO https://github.com/argoproj/argo-workflows/releases/download/v3.5.2/argo-linux-amd64.gz
gunzip argo-linux-amd64.gz
chmod +x argo-linux-amd64
sudo mv ./argo-linux-amd64 /usr/local/bin/argo
argo version

echo "get token for login"
kubectl create role jenkins --verb=create,get,list --resource=workflows.argoproj.io --resource=workfloweventbindings --resource=workflowtemplates
kubectl create sa jenkins
kubectl create rolebinding jenkins --role=jenkins --serviceaccount=argo:jenkins
export ARGO_TOKEN="Bearer $(kubectl create token jenkins)"
echo $ARGO_TOKEN

echo "submit job"
argo submit -n argo --serviceaccount argo --watch https://raw.githubusercontent.com/argoproj/argo-workflows/master/examples/hello-world.yaml

echo "###############ALL DONE#####"
echo "some commands: "
echo 
echo " argo list -n argo ; argo list -n argo @latest "
