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