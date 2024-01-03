#Pre -requisite:
In order for the Ingress resource to work, the cluster must have an ingress controller running.

_https://kubernetes.github.io/ingress-nginx/deploy/_

If the nginx-ingress-controller is deployed in a non-cloud environment such as local cluster, then serviceType: LoadBalancer will expect a ExternalIP to be assigned to the service, this will leave the status in <pending>
For baremetal setup or local k8s cluster there are other options available
1. use baremetal LB 
_https://kubernetes.github.io/ingress-nginx/deploy/baremetal/_

2. Use Traefik 

3. Setup IngressController service with NodePort 
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml

#setup (uses ExternalIP)
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
## Manual
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

output:
You can watch the status by running 'kubectl get service --namespace ingress-nginx ingress-nginx-controller --output wide --watch'

If TLS is enabled for the Ingress, a Secret containing the certificate and key must also be provided:

  apiVersion: v1
  kind: Secret
  metadata:
    name: example-tls
    namespace: foo
  data:
    tls.crt: <base64 encoded cert>
    tls.key: <base64 encoded key>
  type: kubernetes.io/tls

how to create cert and secret
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=nginxsvc/O=nginxsvc"
kubectl create secret tls tls-secret --key tls.key --cert tls.crt

#Simple fan out configuration

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
	namespace: 
  annotations:
    nginx.org/rewrites: "serviceName=tea-svc rewrite=/;serviceName=coffee-svc rewrite=/beans/"
spec:
  rules:
  - host: cafe.example.com
    http:
      paths:
      - path: /service1/
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 2746
      - path: /service2/
        pathType: Prefix
        backend:
          service:
            name: minio-svc
            port:
              number: 9000


Since Ingress are nothing but routing rules, you could define such rules anywhere in the cluster (in any namespace) and controller should pick them up as it monitors creation of such resources and react accordingly.

Here's how to create ingress easily using kubectl

kubectl create ingress <name> -n namespaceName --rule="host/prefix=serviceName:portNumber"

Note: Add --dry-run=client -oyaml to generate yaml manifest file

Or you may create a service of type ExternalName in the same namespace where you have defined your ingress. such external service can point to any URL (a service that lives outside namespace or even k8s cluster)

Here's an example that shows how to create an ExternalName service using kubectl:

kubectl create service externalname ingress-ns -n namespaceName --external-name=serviceName.namespace.svc.cluster.local --tcp=80:80 --dry-run=client -oyaml

this should generate something similar to the following:

kind: Service
apiVersion: v1
metadata:
  name: nginx
  namespace: ingress-ns
spec:
  type: ExternalName
  externalName: serviceName.namespace.svc.cluster.local #or any external svc
  ports:
  - port: 80 #specify the port of service you want to expose 
    targetPort: 80 #port of external service 
As described above, create an ingress as below: kubectl create ingress <name> -n namespaceName --rule="host/prefix=serviceName:portNumber" 

Note: Add --dry-run=client -oyaml to generate yaml manifest file

