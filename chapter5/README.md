# Installing KinD
## Install Kubectl
```bash
sudo snap install kubectl --classic
```
## Installing Go
```bash
sh go.sh
```
or
```bash
sudo snap install go  --classic
cat << 'EOF' >> ~/.profile
export GOROOT=/usr/local/go
export GOPATH=~/go/kind
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
EOF
echo -e "Variables added"
```


## Installing the KinD binary
```bash
sh install-kind.sh
```
or
```bash
GO111MODULE="on"  go get sigs.k8s.io/kind@v0.8.0
kind --version
```
or
```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.9.0/kind-linux-amd64
chmod +x ./kind
mv ./kind /bin/kind
kind --version
```

## Creating a simple cluster 
```bash
$ kind create cluster
```
## Creating a custom KinD cluster 
```bash
$ kind create cluster  --name cluster01  --config cluster01-kind.yaml 
```

 
## Install Calico
```bash
echo -e "\n \n*******************************************************************************************************************"
echo -e "Step 4: Install Calico from local file, using 10.240.0.0/16 as the pod CIDR"
echo -e "*******************************************************************************************************************"

kubectl apply -f calico.yaml
```

## Deploy NGINX
```bash
echo -e "\n \n*******************************************************************************************************************"
echo -e "Step 5: Install NGINX Ingress Controller"
echo -e "*******************************************************************************************************************"

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.28.0/deploy/static/mandatory.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.27.0/deploy/static/provider/baremetal/service-nodeport.yaml
```
## Patch NGINX for to forward 80 and 443
```bash
echo -e "\n \n*******************************************************************************************************************"
echo -e "Step 6: Patch NGINX deployment to expose pod on HOST ports 80 ad 443"
echo -e "*******************************************************************************************************************"

kubectl patch deployments -n ingress-nginx nginx-ingress-controller -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx-ingress-controller","ports":[{"containerPort":80,"hostPort":80},{"containerPort":443,"hostPort":443}]}]}}}}'
```
## Find IP address of Docker Host
```bash
hostip=$(hostname  -I | cut -f1 -d' ')
echo -e "\n \n*******************************************************************************************************************"
echo -e "Cluster Creation Complete.  Please see the summary beloq for key information that will be used in later chapters"
echo -e "*******************************************************************************************************************"
```

## Destroying a custom KinD cluster 
```bash
$ kind delete cluster  --name cluster01
```

## Creating a custom KinD cluster 
```bash
$ kind create cluster  --name cluster02  --config cluster02-kind.yaml 

```

## How to debug when Kubernetes nodes are in 'Not Ready' state

Steps to debug:-

In case you face any issue in kubernetes, first step is to check if kubernetes self applications are running fine or not.

Command to check:- 

```bash
kubectl get pods -n kube-system
```

If you see any pod is crashing, check it's logs

if getting NotReady state error, verify network pod logs.

if not able to resolve with above, follow below steps:-

1. Check which node is not in ready state.
```bash
kubectl get nodes 
```
2. nodename which is not in readystate
```bash
kubectl describe node nodename 
```
or
```bash
$ kubectl describe nodes
Conditions:
  Type              Status
  ----              ------
  OutOfDisk         False
  MemoryPressure    False
  DiskPressure      False
  Ready             True
Capacity:
 cpu:       2
 memory:    2052588Ki
 pods:      110
Allocatable:
 cpu:       2
 memory:    1950188Ki
 pods:      110
```

3. ssh to that node

4. Make sure kubelet is running
```bash
systemctl status kubelet
```
5.  Make sure docker service is running

```bash
systemctl status docker 
```

6. To Check logs in depth
```bash
journalctl -u kubelet 
```

Most probably you will get to know about error here, After fixing it reset kubelet with below commands:-
```bash
systemctl daemon-reload
systemctl restart kubelet
```
In case you still didn't get the root cause, check below things:-

Make sure your node has enough space and memory. Check for /var directory space especially. command to check: -df -kh, free -m

Verify cpu utilization with top command. and make sure any process is not taking an unexpected memory.




