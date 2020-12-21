# Using MetalLB as a layer 4 load balancer

## Important note
Remember that in Chapter 4 Deploying Kubernetes using KinD we had a 
diagram showing the flow of traffic between a workstation and the KinD 
nodes. Because KinD was running in a nested Docker container, a layer 4 
load balancer would have had certain limitations when it came to networking 
connectivity. Without additional network configuration on the Docker host, 
you will not be able to target the services that use the LoadBalancer type 
outside of the Docker host itself.  

If you deploy MetalLB to a standard Kubernetes cluster running on a host, you 
will not be limited to accessing services outside of the host itself.

## Installing MetalLB

```bash
sh install-metallb.sh

```

## Integrating external-dns and CoreDNS

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```
Now, using Helm, we can create the ETCD cluster that we will integrate with CoreDNS.
The following command will deploy the ETCD operator and create the ETCD cluster:

```bash
helm repo add hkube https://hkube.io/helm/
helm install etcd-dns --set customResources.createEtcdClusterCRD=true stable/etcd-operator --namespace  kube-system

```

## Adding an ETCD zone to CoreDNS
***external-dns*** requires the CoreDNS zone to be stored on an ETCD server. Earlier, we 
created a new zone for foowidgets, but that was just a standard zone that would require 
manually adding new records for new services. Users do not have time to wait to test their 
deployments, and using an IP address may cause issues with proxy servers or internal 
policies. To help the users speed up their delivery and testing of application, we need to 
provide dynamic name resolution for their services. To enable an ETCD-integrated zone 
for foowidgets, edit the CoreDNS configmap, and add the following bold lines.

You may need to change the endpoint to the IP address of the new ETCD service that was 
retrieved on the previous page:

```yaml
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
          lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
          ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
                 etcd foowidgets.k8s {
                 stubzones
                    path /skydns
                    endpoint http://10.96.181.53:2379
                } 
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
```
The next step is to deploy external-dns to the cluster.

We have provided a manifest in the GitHub repository in the chapter6 directory that 
will patch the deployment with your ETCD service endpoint. You can deploy externaldns 
using this manifest by executing the following command, from the chapter6 
directory. The following command will query the service IP for the ETCD cluster and 
create a deployment file using that IP as the endpoint.

The newly created deployment will then install external-dns in your cluster: 

```bash
ETCD_URL=$(kubectl -n kube-system get svc etcd-cluster-client  -o go-template='{{ .spec.clusterIP }}')

cat external-dns.yaml | sed -E "s/<ETCD_URL>/${ETCD_URL}/" > external-dns-deployment.yaml

kubectl apply -f external-dns-deployment.yaml

```

To deploy external-dns to your cluster manually, create a new manifest called 
external-dns-deployment.yaml with the following content, using your ETCD 
service IP address on the last line:

```bash
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: external-dns
rules:
- apiGroups: [""]
  resources: ["services","endpoints","pods"]
  verbs: ["get","watch","list"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.opensource.zalan.do/teapot/externaldns:latest
        args:
        - --source=service
        - --provider=coredns
        - --log-level=info
        env:
        - name: ETCD_URLS
          value: http://10.96.181.53:2379
```
Remember, if your ETCD server's IP address is not 10.96.181.53, change it before deploying the manifest.

Deploy the manifest using kubectl apply -f external-dns-deployment.yaml.
