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