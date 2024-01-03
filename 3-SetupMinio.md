# Argo install and config:
```bash
curl -s https://raw.githubusercontent.com/argoproj-labs/training-material/main/argo-workflows/install.sh | sh
kubectl config set-context --current --namespace=argo
kubectl -n argo wait deploy --all --for condition=Available --timeout 2m
kubectl -n argo port-forward --address 0.0.0.0 svc/argo-server 80:2746 > /dev/null &
kubectl create role jenkins --verb=create,get,list --resource=workflows.argoproj.io --resource=workfloweventbindings --resource=workflowtemplates
kubectl create sa jenkins
kubectl create rolebinding jenkins --role=jenkins --serviceaccount=argo:jenkins
export ARGO_TOKEN="Bearer $(kubectl create token jenkins)"
export ARGO_HTTP1=true  
export ARGO_SECURE=true
#export ARGO_SERVER='80-port-bd1da864ee284afb.labs.kodekloud.com:443' 
argo submit -n argo --serviceaccount argo --watch https://raw.githubusercontent.com/argoproj/argo-workflows/master/examples/hello-world.yaml
```

## Install Minio Object
MinIO Object Storage for Kubernetes
https://min.io/docs/minio/kubernetes/upstream/index.html
Community docs:
https://github.com/minio/minio/tree/master/helm/minio


`curl https://raw.githubusercontent.com/minio/docs/master/source/extra/examples/minio-dev.yaml -O`

The file describes two Kubernetes resources:

A new namespace minio-dev, and

A MinIO pod using a drive or volume on the Worker Node for serving data

> Edit the file to change the node label match the k8s worker node
> for eg: spec.nodeSelector: kubernetes.io/hostname: node01
```yaml
spec:
  nodeSelector:
    kubernetes.io/hostname: node01
```
`kubectl apply -f minio-dev.yaml`
In kodekloud, the master node has taints if u created a 2 node cluster. The worker node cannot expose the UI via browser URL so add the nodeSelected to master node(controlplane) then remove the taints using following commands:
 k taint nodes controlplane node-role.kubernetes.io/control-plane:NoSchedule-
 kubectl taint nodes controlplane node-role.kubernetes.io/master:NoSchedule- 

kubectl get pods -n minio-dev

kubectl logs pod/minio -n minio-dev

*Port forward :*
`kubectl port-forward --address 0.0.0.0 pod/minio 9000 9090 -n minio-dev &`

### create service 
If the cluster is going to use nginx-ingress controller, expose the service using externalName

```yaml
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio-dev
spec:
  type: ExternalName
  externalName: <servicename>.<namespace>.svc.cluster.local #or any external svc
  ports:
  - name: minio
    port: 9000
    targetPort: 9090    
  selector:
    app: minioapiVersion: v1
```

### Install minio client:
https://min.io/docs/minio/linux/reference/minio-mc.html#command-mc

```bash
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/

mc --help

mc alias set k8s-minio-dev http://127.0.0.1:9000 minioadmin minioadmin
mc admin info k8s-minio-dev
```

---
## Whats next
#Add STS:
https://gist.github.com/manics/305f4cc56d0ac6431893cde17b1ba8c4


### MinIo Operator 
_https://min.io/docs/minio/kubernetes/upstream/operations/installation.html_ 

The following approach can be used to install minio as an operator

```bash
wget https://github.com/minio/operator/releases/download/v5.0.11/kubectl-minio_5.0.11_linux_amd64
mv kubectl-minio_5.0.11_linux_amd64 kubectl-minio
chmod +x kubectl-minio 
mv kubectl-minio /usr/local/bin/kubectl-minio
kubectl-minio version
alias kmio='kubectl-minio'
kmio version
kmio init
```

### HELM INSTALL
```bash
 helm repo add minio-operator https://operator.min.io
 helm search repo minio-operator
 helm install \
  --namespace minio-operator \
  --create-namespace \
  operator minio-operator/operator
```

```bash
namespace/minio-operator created
serviceaccount/minio-operator created
clusterrole.rbac.authorization.k8s.io/minio-operator-role created
clusterrolebinding.rbac.authorization.k8s.io/minio-operator-binding created
customresourcedefinition.apiextensions.k8s.io/tenants.minio.min.io created
customresourcedefinition.apiextensions.k8s.io/policybindings.sts.min.io created
service/operator created
service/sts created
deployment.apps/minio-operator created
serviceaccount/console-sa created
secret/console-sa-secret created
clusterrole.rbac.authorization.k8s.io/console-sa-role created
clusterrolebinding.rbac.authorization.k8s.io/console-sa-binding created
configmap/console-env created
service/console created
deployment.apps/console created
`
*Validate*:

`kubectl get all --namespace minio-operator`

*Port forward:*
kmio proxy -n minio-operator

For KodeKloud find the hostname based on ARGO_SERVER port 80 portforward, then change the port to port 9090 in the URL
for eg:
https://80-port-bd1da864ee284afb.labs.kodekloud.com/workflows/?&limit=50
change 80 to 9090
https://9090-port-bd1da864ee284afb.labs.kodekloud.com/login

Enter the JWT to login

### Complete tenant setup
_https://min.io/docs/minio/kubernetes/upstream/operations/install-deploy-manage/deploy-minio-tenant.html#complete-the-tenant-setup_

Create StorageClass:
https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner/tree/master/helm


`helm install ./helm/provisioner -f helm/examples/gke.yaml --namespace kube-system  --generate-name`

```bash
NAME: provisioner-1703740713
LAST DEPLOYED: Thu Dec 28 05:18:33 2023
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
provisioner installed

Access key: 9e5qD
Secret Key: nFPOjXhdlaB
```
--
