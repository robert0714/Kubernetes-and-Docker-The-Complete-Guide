# Following OIDC and the API's interaction
Once kubectl has been configured, all of your API interactions will follow the following sequence:


The preceding diagram is from Kubernetes' authentication page at https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens. 

# Other authentication options

## Certificates

This may look like an attractive option, so why shouldn't you use certificates with Kubernetes?

*  Smartcard integration uses a standard called PKCS11, which neither kubectl or the API server support.
*  The API server has no way of checking certificate revocation lists or using OCSP, so once a certificate has been minted, there's no way to revoke it so that the API server can use it.
  
Additionally, the process to correctly generate a key pair is rarely used. It requires a complex interface to be built that is difficult for users to use combine with command-line tools that need to be run. To get around this, the certificate and key pair are generated for you and you download it or it's emailed to you, negating the security of the process.

The other reason you shouldn't use certificate authentication for users is that it's difficult to leverage groups. While you can embed groups into the subject of the certificate, you can't revoke a certificate. So, if a user's role changes, you can give them a new certificate but you can't keep them from using the old one.

As stated in the introduction to this section, using a certificate to authenticate in "break glass in case of emergencies" situations is a good use of certificate authentication. It may be the only way to get into a cluster if all other authentication methods are experiencing issues.

## Service accounts

Service accounts appear to provide an easy access method. Creating them is easy. The following command creates a service account object and a secret to go with it that stores the service account's token:
```bash
kubectl create sa mysa -n default
```
Next, the following command will retrieve the service account's token in JSON format and return only the value of the token. This token can then be used to access the API server:
```bash
kubectl get secret $(kubectl get sa mysa -n default -o json | jq -r '.secrets[0].name') -o json | jq -r '.data.token' | base64 -d
```
To show an example of this, let's call the API endpoint directly, without providing any credentials:
```bash
curl -v --insecure https://0.0.0.0:6443/api
```
You will receive the following:
```bash
*   Trying 0.0.0.0...
* TCP_NODELAY set
* Connected to 0.0.0.0 (127.0.0.1) port 6443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/ssl/certs/ca-certificates.crt
  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS Unknown, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Unknown (8):
* TLSv1.3 (IN), TLS Unknown, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Request CERT (13):
* TLSv1.3 (IN), TLS Unknown, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS Unknown, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS Unknown, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Client hello (1):
* TLSv1.3 (OUT), TLS Unknown, Certificate Status (22):
* TLSv1.3 (OUT), TLS handshake, Certificate (11):
* TLSv1.3 (OUT), TLS Unknown, Certificate Status (22):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=kube-apiserver
*  start date: Dec 21 04:07:58 2020 GMT
*  expire date: Dec 21 04:07:59 2021 GMT
*  issuer: CN=kubernetes
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* TLSv1.3 (OUT), TLS Unknown, Unknown (23):
* TLSv1.3 (OUT), TLS Unknown, Unknown (23):
* TLSv1.3 (OUT), TLS Unknown, Unknown (23):
* Using Stream ID: 1 (easy handle 0x557c6613a4f0)
* TLSv1.3 (OUT), TLS Unknown, Unknown (23):
> GET /api HTTP/2
> Host: 0.0.0.0:6443
> User-Agent: curl/7.58.0
> Accept: */*
> 
* TLSv1.3 (IN), TLS Unknown, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.3 (IN), TLS Unknown, Unknown (23):
* Connection state changed (MAX_CONCURRENT_STREAMS updated)!
* TLSv1.3 (OUT), TLS Unknown, Unknown (23):
* TLSv1.3 (IN), TLS Unknown, Unknown (23):
* TLSv1.3 (IN), TLS Unknown, Unknown (23):
* TLSv1.3 (IN), TLS Unknown, Unknown (23):
< HTTP/2 403 
< content-type: application/json
< x-content-type-options: nosniff
< content-length: 236
< date: Tue, 22 Dec 2020 02:18:33 GMT
< 
* TLSv1.3 (IN), TLS Unknown, Unknown (23):
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {
    
  },
  "status": "Failure",
  "message": "forbidden: User \"system:anonymous\" cannot get path \"/api\"",
  "reason": "Forbidden",
  "details": {
    
  },
  "code": 403
* Connection #0 to host 0.0.0.0 left intact
}
```
By default, most Kubernetes distributions do not allow anonymous access to the API server, so we receive a 403 error because we didn't specify a user.

Now, let's add our service account to an API request:

```bash
export KUBE_AZ=$(kubectl get secret $(kubectl get sa mysa -n default -o json | jq -r '.secrets[0].name') -o json | jq -r '.data.token'  | base64 -d)

curl  -H "Authorization: Bearer $KUBE_AZ" --insecure https://0.0.0.0:6443/api
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "172.18.0.2:6443"
    }
  ]
}
```
Success! This was an easy process, so you may be wondering, ***"Why do I need worry about all the complicated OIDC mess?"*** This solution's simplicity brings multiple security issues:

* ***Secure transmission of the token***: Service accounts are self-contained and need nothing to unlock them or verify ownership, so if a token is taken in transit, you have no way of stopping its use. You could set up a system where a user logs in to download a file with the token in it, but you now have a much less secure version of OIDC.

* ***No expiration***: When you decode a service account token, there is nothing that tell you when the token expires. That's because the token never expires. You can revoke a token by deleting the service account and recreating it, but that means you need a system in place to do that. Again, you've built a less capable version of OIDC.

* ***Auditing***: The service account can easily be handed out by the owner once the key has been retrieved. If there are multiple users using a single key, it becomes very difficult to audit use of the account.
  
In addition to these issues, you can't put a service account into arbitrary groups. This means that RBAC bindings have to either be direct to the service account or use one of the pre-built groups that service accounts are a member of. We'll explore why this is an issue when we talk about authorization, so just keep it in mind for now.

Finally, service accounts were never designed to be used outside of the cluster. It's like using a hammer to drive in a screw. With enough muscle and aggravation, you will drive it in, but it won't be pretty and no one will be happy with the result.

## TokenRequest API
At the time of writing, the TokenRequest API is still a beta feature.

The TokenRequest API lets you request a short-lived service account for a specific scope. While it provides slightly better security since it will expire and has a limited scope, it's still bound to a service account, which means no groups, and there's still the issue of securely getting the token to the user and auditing its use.

Tokens generated by the TokenRequest API are built for other systems to talk to your cluster; they are not meant to be used by users.

## Custom authentication webhooks
If you already have an identity platform that doesn't use an existing standard, a custom authentication webhook will let you integrate it without having to customize the API server. This feature is commonly used by cloud providers who host managed Kubernetes instances.

You can define an authentication webhook that the API server will call with a token to validate it and get information about the user. Unless you manage a public cloud with a custom IAM token system that you are building a Kubernetes distribution for, don't do this. Writing your own authentication is like writing your own encryption – just don't do it. Every custom authentication system we've seen for Kubernetes boils down to either a pale imitation of OIDC or "pass the password". Much like the analogy of driving a screw in with a hammer, you could do it, but it will be very painful. This is mostly because instead of driving the screw through a board, you're more likely to drive it into your own foot.

## Keystone
Those familiar with OpenStack will recognize the name Keystone as an identity provider. If you are not familiar with Keystone, it is the default identity provider used in an OpenStack deployment.

Keystone hosts the API that handles authentication and token generation. OpenStack stores users in Keystone's database. While using Keystone is more often associated with OpenStack, Kubernetes can also be configured to use Keystone for username and password authentication, with some limitations:

* The main limitation of using Keystone as an IdP for Kubernetes is that it only works with Keystone's LDAP implementation. While you could use this method, you should consider that only username and password are supported, so you're creating an identity provider with a non-standard protocol to authenticate to an LDAP server, which pretty much any OIDC IdP can do out of the box.
* You can't leverage SAML or OIDC with Keystone, even though Keystone supports both protocols for OpenStack, which limits how users can authenticate, thus cutting you off from multiple multi-factor options.
* Few, if any, applications know how to use the Keystone protocol outside of OpenStack. Your cluster will have multiple applications that make up your platform, and those applications won't know how to integrate with Keystone.

Using Keystone is certainly an appealing idea, especially if you're deploying on OpenStack, but ultimately, it's very limiting and you will likely put in just as much working getting Keystone integrated as just using OIDC.

The next section will take the details we've explored here and apply them to integrating authentication into a cluster. As you move through the implementation, you'll see how kubectl, the API server, and your identity provider interact to provide secure access to the cluster. We'll tie these features back to common enterprise requirements to illustrate why the details for understanding the OpenID Connect protocol are important.

# Configuring KinD for OpenID Connect
For our example deployment, we will use a scenario from our customer, FooWidgets.Foowidgets has a Kubernetes cluster that they would like integrated using OIDC. The proposed solution needs to address the following requirements:

* Kubernetes must use our central authentication system, Active Directory Federation Services.
* We need to be able map Active Directory groups into our RBAC RoleBinding objects.
* Users need access to the Kubernetes Dashboard.
* Users need to be able to use the CLI.
* All enterprise compliance requirements must be met.

Let's explore each of these in detail and explain how we can address the customer's requirements.

## Addressing the requirements
Our enterprise's requirements require multiple moving parts, both inside and outside our cluster. We'll examine each of these components and how they relate to building an authenticated cluster.

## Use Active Directory Federation Services
Most enterprises today use Active Directory from Microsoft™ to store information about users and their credentials. Depending on the size of your enterprise, it's not unusual to have multiple domain or forests where users live. If your IdP is well integrated into a Microsoft's Kerberos environment, it may know how to navigate these various systems. Most non-Microsoft applications are not, including most identity providers. Active Directory Federation Services (ADFS) is Microsoft's IdP that supports both SAML2 and OpenID Connect, and it knows how to navigate the domains and forest of an enterprise implementation. It's common in many large enterprises.

The next decision with ADFS is whether to use SAML2 or OpenID Connect. At the time of writing, SAML2 is much easier to implement and most enterprise environments with ADFS prefer to use SAML2. Another benefit of SAML2 is that it doesn't require a connection between our cluster and the ADFS servers; all of the important information is transferred through the user's browser. This cuts down on potential firewall rules that need to be implemented in order to get our cluster up and running.

#### Important Note

Don't worry – you don't need ADFS ready to go to run this exercise. We have a handy SAML testing identity provider we'll use. You won't need to install anything to use SAML2 with your KinD cluster.

## Mapping Active Directory Groups to RBAC RoleBindings
This will become important when we start talking about authorization. What's important to point out here is that ADFS has the capability to put a user's group memberships in the SAML assertion, which our cluster can then consume.

## Kubernetes Dashboard access
The dashboard is a powerful way to quickly access information about your cluster and make quick updates. When deployed correctly, the dashboard does not create any security issues. The proper way to deploy the dashboard is with no privileges, instead relying on the user's own credentials. We'll do this with a reverse proxy that injects the user's OIDC token on each request, which the dashboard will then use when it makes calls to the API server. Using this method, we'll be able to constrain access to our dashboard the same way we would with any other web application.

There are a few reasons why using the kubectl built-in proxy and port-forward aren't a great strategy for accessing the dashboard. Many enterprises will not install CLI utilities locally, forcing you to use a jump box to access privileged systems such as Kubernetes, meaning port forwarding won't work. Even if you can run kubectl locally, opening a port on loopback (127.0.0.1) means anything on your system can use it, not just you from your browser. While browsers have controls in place to keep you from accessing ports on loopback using a malicious script, that won't stop anything else on your workstation. Finally, it's just not a great user experience.

We'll dig into the details of how and why this works in Chapter 9, Deploying a Secured Kubernetes Dashboard.

## Kubernetes CLI access
Most developers want to be able to access kubectl and other tools that rely on the kubectl configuration. For instance, the Visual Studio Code Kubernetes plugin doesn't require any special configuration. It just uses the kubectl built-in configuration. Most enterprises tightly constrain what binaries you're able to install, so we want to minimize any additional tools and plugins we want to install.

## Enterprise compliance requirements
Being cloud-native doesn't mean you can ignore your enterprise's compliance requirements. Most enterprises have requirements such as having 20-minute idle timeouts, may require multi-factor authentication for privileged access, and so on. Any solution we put in place has to make it through the control spreadsheets needed to go live. Also, this goes without saying, but everything needs to be encrypted (and I do mean everything).

## Pulling it all together
To fulfill these requirements, we're going to use OpenUnison. It has prebuilt configurations to work with Kubernetes, the dashboard, the CLI, and SAML2 identity providers such as ADFS. It's also pretty quick to deploy, so we don't need to concentrate on provider-specific implementation details and instead focus on Kubernetes' configuration options. Our architecture will look like this:

For our implementation, we're going to use two hostnames:

* k8s.apps.X-X-X-X.nip.io: Access to the OpenUnison portal, where we'll initiate our login and get our tokens
* k8sdb.apps.X-X-X-X.nip.io: Access to the Kubernetes dashboard
    #### Important Note
        * As a quick refresher, nip.io is a public DNS service that will return an IP address from the one embedded in your hostname. This is really useful in a lab environment where setting up DNS can be painful. In our examples, X-X-X-X is the IP of your Docker host.

When a user attempts to access https://k8s.apps.X-X-X-X.nip.io/, they'll be redirected to ADFS, which will collect their username and password (and maybe even a multi-factor authentication token). ADFS will generate an assertion that will be digitally signed and contain our user's unique ID, as well as their group assignments. This assertion is similar to id_token, which we examined earlier, but instead of being JSON, it's XML. The assertion is sent to the user's browser in a special web page that contains a form that will automatically submit the assertion back to OpenUnison. At that point, OpenUnison will create user objects in the OpenUnison namespace to store the user's information and create OIDC sessions.

Earlier, we described how Kubernetes doesn't have user objects. Kubernetes lets you extend the base API with Custom Resource Definitions (CRDs). OpenUnison defines a User CRD to help with high availability and to avoid needing a database to store state in. These user objects can't be used for RBAC.

Once the user is logged into OpenUnison, they can get their kubectl configuration to use the CLI or use the Kubernetes dashboard, https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/, to access the cluster from their browser. Once the user is ready, they can log out of OpenUnison, which will end their session and invalidate their refresh_token, making it impossible for them to use kubectl or the dashboard until after they log in again. If they walk away from their desk for lunch without logging out, when they return, their refresh_token will have expired, so they'll no longer be able to interact with Kubernetes without logging back in.

Now that we have walked through how users will log in and interact with Kubernetes, we'll deploy OpenUnison and integrate it into the cluster for authentication.

## Deploying OIDC
We have included two installation scripts to automate the deployment steps. These scripts, ***install-oidc-step1.sh*** and ***install-oidc-step2.sh***, are located in this book's GitHub repository, in the chapter7 directory.

This section will explain all of the manual steps that the script automates.

#### Important Note

If you install OIDC using the scripts, you must follow this process for a successful deployment:

Step 1: Run the ./install-oidc-step1.sh script.

Step 2: Register for an SAML2 test lab by following the procedure in the Registering for a SAML2 test lab section.

Step3: Run the ./install-oidc-step2.sh script to complete the OIDC deployment.

Deploying OIDC to a Kubernetes cluster using OpenUnison is a five-step process:

1  Deploy the dashboard.
2  Deploy the OpenUnison operator.
3  Create a secret.
4  Create a values.yaml file.
5  Deploy the chart.
   
  
  Let's perform these steps one by one.

## Deploying OpenUnison
The dashboard is a popular feature for many users. It provides a quick view into resources without us needing to use the kubectl CLI. Over the years, it has received some bad press for being insecure, but when deployed correctly, it is very secure. Most of the stories you may have read or heard about come from a dashboard deployment that was not set up correctly. We will cover this topic in Chapter 9, Securing the Kubernetes Dashboard:

1. First, we'll deploy the dashboard from https://github.com/kubernetes/dashboard:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.1.0/aio/deploy/recommended.yaml

namespace/kubernetes-dashboard created
serviceaccount/kubernetes-dashboard created
service/kubernetes-dashboard created
secret/kubernetes-dashboard-certs created
secret/kubernetes-dashboard-csrf created
secret/kubernetes-dashboard-key-holder created
configmap/kubernetes-dashboard-settings created
role.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrole.rbac.authorization.k8s.io/kubernetes-dashboard created
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
deployment.apps/kubernetes-dashboard created
service/dashboard-metrics-scraper created
deployment.apps/dashboard-metrics-scraper created

```

2. Next, we need to add the repository that contains OpenUnison to our Helm list. To add the Tremolo chart repository, use the Helm repo add command:

```bash
Helm repo add tremolo https://nexus.tremolo.io/repository/Helm/

https://nexus.tremolo.io/repository/Helm/"tremolo" has been added to your repositories
```

#### Important Note

Helm is a package manager for Kubernetes. Helm provides a tool that will deploy a "Chart" to your cluster and help you manage the state of the deployment. We're using Helm v3, which does not require you to deploy any components, such as Tiller, to your cluster to work.

3. Once added, you need to update the repository using the ***Helm repo update*** command:
```bash

helm repo update

Hang tight while we grab the latest from your chart repositories...

...Successfully got an update from the "tremolo" chart repository

Update Complete. Happy Helming!
```

You are now ready to deploy the OpenUnison operator using the Helm chart.

First, we want to deploy OpenUnison in a new namespace called openunison. We need to create the namespace before deploying the Helm chart:

```bash
kubectl create ns openunison

namespace/openunison created
```

With the namespace created, you can deploy the chart into the namespace using Helm. To install a chart using Helm, use Helm install <name> <chart> <options>:

```bash
helm install openunison tremolo/openunison-operator --namespace openunison

NAME: openunison
LAST DEPLOYED: Fri Apr 17 15:04:50 2020
NAMESPACE: openunison
STATUS: deployed
REVISION: 1
TEST SUITE: None
```
The operator will take a few minutes to finish deploying.


## Important Note

An operator is a concept that was pioneered by CoreOS with the goal of encapsulating many of the tasks an administrator may perform that can be automated. Operators are implemented by watching for changes to a specific CRD and acting accordingly. The OpenUnison operator looks for objects of the OpenUnison type and will create any objects that are needed. A secret is created with a PKCS12 file; Deployment, Service and Ingress objects are all created too. As you make changes to an OpenUnison object, the operator makes updates to the Kubernetes object as needed. For instance, if you change the image in the OpenUnison object, the operator updates the Deployment, which triggers Kubernetes to rollout new pods. For SAML, the operator also watches metadata so that if it changes, the updated certificates are imported.

6. Once the operator has been deployed, we need to create a secret that will store passwords used internally by OpenUnison. Make sure to use your own values for the keys in this secret (remember to base64 encode them):

```bash
kubectl create -f - <<EOF

apiVersion: v1
type: Opaque
metadata:
   name: orchestra-secrets-source
   namespace: openunison
data:
   K8S_DB_SECRET: cGFzc3dvcmQK
   unisonKeystorePassword: cGFzc3dvcmQK
kind: Secret
EOF

secret/orchestra-secrets-source created
```
## Important Note

From here on out, we'll assume you're using Tremolo Security's testing identity provider. This tool will let you customize the user's login information without having to stand up a directory and identity provider. Register by going to https://portal.apps.tremolo.io/ and clicking on Register.

To provide the accounts for the OIDC environment, we will use a SAML2 testing lab, so be sure to register before moving on.

7. First, we need to need to log into the testing identity provider by going to https://portal.apps.tremolo.io/ and clicking on the SAML2 Test Lab badge:


8. Once you've clicked on the badge, you'll be presented with a screen that shows your test IdP metadata URL:

Copy this value and store it in a safe place.

9. Now, we need to create a values.yaml file that will be used to supply configuration information when we deploy OpenUnison. This book's GitHub repository contains a base file in the chapter7 directory:
network:
```bash
  openunison_host: "k8sou.apps.XX-XX-XX-XX.nip.io"
  dashboard_host: "k8sdb.apps.XX-XX-XX-XX.nip.io"
  api_server_host: ""
  session_inactivity_timeout_seconds: 900
  k8s_url: https://0.0.0.0:6443
cert_template:
  ou: "Kubernetes"
  o: "MyOrg"
  l: "My Cluster"
  st: "State of Cluster"
  c: "MyCountry"
image: "docker.io/tremolosecurity/openunison-k8s-login-saml2:latest"
myvd_config_path: "WEB-INF/myvd.conf"
k8s_cluster_name: kubernetes
enable_impersonation: false
dashboard:
  namespace: "kubernetes-dashboard"
  cert_name: "kubernetes-dashboard-certs"
  label: "k8s-app=kubernetes-dashboard"
  service_name: kubernetes-dashboard
certs:
  use_k8s_cm: false
trusted_certs: []
monitoring:
  prometheus_service_account: system:serviceaccount:monitoring:prometheus-k8s
saml:
  idp_url: https://portal.apps.tremolo.io/idp-test/metadata/dfbe4040-cd32-470e-a9b6-809c840
  metadata_xml_b64: ""
```
You need to change the following values for your deployment:

* *Network*: openunison_host: This value should use the IP address of your cluster, which is the IP address of your Docker host; for example, k8sou.apps.192-168-2=131.nip.io.
* *Network*: dashboard_host: This value should use the IP address of your cluster, which is the IP address of your Docker host; for example, k8sdb.apps.192-168-2-131.nip.io.
* saml: idp url: This value should be the SAML2 metadata URL that you retrieved from the SAML2 lab page in the previous step.
After you've edited or created the file using your own entries, save the file and move on to deploying your OIDC provider.

To deploy OpenUnison using your values.yaml file, execute a Helm install command that uses the -f option to specify the values.yaml file:
```bash
helm install orchestra tremolo/openunison-k8s-login-saml2 --namespace openunison -f ./values.yaml

NAME: orchestra
LAST DEPLOYED: Fri Apr 17 16:02:00 2020
NAMESPACE: openunison
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

11. In a few minutes, OpenUnison will be up and running. Check the deployment status by getting the pods in the openunison namespace:

```bash

kubectl get pods -n openunison

NAME                                    READY   STATUS    RESTARTS   AGE
openunison-operator-858d496-zzvvt       1/1    Running   0          5d6h
openunison-orchestra-57489869d4-88d2v   1/1     Running   0          85s
```

There is one more step you need to follow to complete the OIDC deployment: you need to update the SAML2 lab with the relying party for your deployment.

12. Now that OpenUnison is running, we need to get the SAML2 metadata from OpenUnison using the host in network.openunison_host in our values.yaml file and the /auth/forms/saml2_rp_metadata.jsp path:

```bash
curl --insecure https://k8sou.apps.10-100-198-200.nip.io/auth/forms/saml2_rp_metadata.jsp
 
<?xml version="1.0" encoding="UTF-8"?><md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" ID="f275c76687cc91bdf29e327667daec0095ec233ff" entityID="https://k8sou.apps.10-100-198-200.nip.io/auth/SAML2Auth">
   <md:SPSSODescriptor WantAssertionsSigned="true" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
      <md:KeyDescriptor use="signing">
         <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <ds:X509Data>
               <ds:X509Certificate>MIID1jCCAr6gAwIBAgIGAXaKdUxuMA0GCSqGSIb3DQEBCwUAMIGHMRwwGgYDVQQDDBN1bmlzb24t&#13;
c2FtbDItcnAtc2lnMRMwEQYDVQQLDApLdWJlcm5ldGVzMQ4wDAYDVQQKDAVNeU9yZzETMBEGA1UE&#13;
BwwKTXkgQ2x1c3RlcjEZMBcGA1UECAwQU3RhdGUgb2YgQ2x1c3RlcjESMBAGA1UEBhMJTXlDb3Vu&#13;
dHJ5MB4XDTIwMTIyMjEyMzgzMVoXDTIxMTIyMjEyMzgzMVowgYcxHDAaBgNVBAMME3VuaXNvbi1z&#13;
YW1sMi1ycC1zaWcxEzARBgNVBAsMCkt1YmVybmV0ZXMxDjAMBgNVBAoMBU15T3JnMRMwEQYDVQQH&#13;
DApNeSBDbHVzdGVyMRkwFwYDVQQIDBBTdGF0ZSBvZiBDbHVzdGVyMRIwEAYDVQQGEwlNeUNvdW50&#13;
cnkwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCWlAE2jHtOUyp1MEX9EqlSHP7uEovb&#13;
9Cbup/6D/gOz8ijtIhRNjqQZQoLozIzliCwWfIMdkblhh30jhXzDpvDGG8dZ3fdzhFHc+skK9T9G&#13;
lqHjza2IBNg34PmA5du7tc1PCQy/U0kRzUp5FEkSSJFhR/HpZOYeWYfcCePjdJ0cmkEaV4NkDKME&#13;
kaeGfhTbJSiHAiG63k8HUGAowbIJmANePBFJQ3URyrkjXqq/XWsO7IpMNMW31H3/VG43uBp2URfk&#13;
QIn6tmxL/POrV/ckjTeE9VRVJhsaCHgLA4jC/hWDm5ZqI4udjdajHzgfid/A/F6GSlyYrlRCc7s6&#13;
pRwyKKaFAgMBAAGjRjBEMA4GA1UdDwEB/wQEAwICBDASBgNVHSUBAf8ECDAGBgRVHSUAMB4GA1Ud&#13;
EQQXMBWCE3VuaXNvbi1zYW1sMi1ycC1zaWcwDQYJKoZIhvcNAQELBQADggEBAIfNCSxRDOQVvM7P&#13;
/cm3k+L5xfs8vyf7kQfCoMcbY6qGJiSJQUcck2CpUexVIvnHum6+FLnB6AJ9lbH93YMcU9g4jyvK&#13;
1p39Fei+T/QxO7yOWKiVc3TPSy5K4rMibqpk1pTZaWd5ulkOFuZHI9cdJgbLwUwJpja+3tyVcwqa&#13;
cguhFziOEI5MQVn31g9I/4A/R2j5bbeNsTInGJbyVK1SLVTcwa5pfnPEYv1jRjJAdy31zQXWP6yh&#13;
ncYWcZM8zFtiWD/iuJP8wyYWn3n05AouZb6ehRBY9O4LfL9x3QPnqJOmzBxkhv5yg2UzSSmV5wln&#13;
YA/PDYQErBlEsOP3G0sTWtw=</ds:X509Certificate>
            </ds:X509Data>
         </ds:KeyInfo>
      </md:KeyDescriptor>
      <md:SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://k8sou.apps.10-100-198-200.nip.io/auth/SAML2Auth"/>
      <md:SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://k8sou.apps.10-100-198-200.nip.io/auth/SAML2Auth"/>
      <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://k8sou.apps.10-100-198-200.nip.io/auth/SAML2Auth" index="0" isDefault="true"/>
      <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://k8sou.apps.10-100-198-200.nip.io/auth/SAML2Auth" index="1"/>
   </md:SPSSODescriptor>
</md:EntityDescriptor>
```
13. Copy the output, paste it into the testing identity provider where it says Meta Data, and click Update Relying Party:

Figure 7.5 – Testing the identity provider with the relying party metadata
14. Finally, we need to add some attributes to our test user. Add the attributes shown in the following screenshot:

Figure 7.6 – Identity provider test user configuration

15. Next, click Update Test User Data to save your attributes. With that, you're ready to log in.
16. You can log into the OIDC provider using any machine on your network by using the assigned nip.io address. Since we will test access using the dashboard, you can use any machine with a browser. Navigate your browser to network.openunison_host in your values.yaml file. Enter your testing identity provider credentials, if needed, and then click Finish Login at the bottom of the screen. You should now be logged into OpenUnison:

Figure 7.7 – OpenUnison home screen

17. Let's test the OIDC provider by clicking on the Kubernetes Dashboard link. Don't panic when you look at the initial dashboard screen – you'll see something like the following:

Figure 7.8 – Kubernetes Dashboard before SSO integration has been completed with the API server

That looks like a lot of errors! We're in the dashboard, but nothing seems to be authorized.That's because the API server doesn't trust the tokens that have been generated by OpenUnison yet. The next step is to tell Kubernetes to trust OpenUnison as its OpenID Connect Identity Provider.

## Configuring the Kubernetes API to use OIDC
At this point, you have deployed OpenUnison as an OIDC provider and it's working, but your Kubernetes cluster has not been configured to use it as a provider yet. To configure the API server to use an OIDC provider, you need to add the OIDC options to the API server and provide the OIDC certificate so that the API will trust the OIDC provider.

Since we are using KinD, we can add the required options using a few kubectl and docker commands.

To provide the OIDC certificate to the API server, we need to retrieve the certificate and copy it over to the KinD master server. We can do this using two commands on the Docker host:

1. The first command extracts OpenUnison's TLS certificate from its secret. This is the same secret referenced by OpenUnison's Ingress object. We use the jq utility to extract the data from the secret and then base64 decode it:
kubectl get secret ou-tls-certificate -n openunison -o json | jq -r '.data["tls.crt"]' | base64 -d > ou-ca.pem

2. The second command will copy the certificate to the master server into the /etc/Kubernetes/pki directory:
docker cp ou-ca.pem cluster01-control-plane:/etc/kubernetes/pki/ou-ca.pem

3. As we mentioned earlier, to integrate the API server with OIDC, we need to have the OIDC values for the API options. To list the options we will use, describe the api-server-config ConfigMap in the openunison namespace:
  
```bash
kubectl describe configmap api-server-config -n openunison

Name:         api-server-config
Namespace:    openunison
Labels:       <none>
Annotations:  <none>
Data

====

oidc-api-server-flags:

----

--oidc-issuer-url=https://k8sou.apps.192-168-2-131.nip.io/auth/idp/k8sIdp
--oidc-client-id=kubernetes
--oidc-username-claim=sub
--oidc-groups-claim=groups
--oidc-ca-file=/etc/kubernetes/pki/ou-ca.pem
```

Next, edit the API server configuration. OpenID Connect is configured by changing flags on the API server. This is why managed Kubernetes generally doesn't offer OpenID Connect as an option, but we'll cover that later in this chapter. Every distribution handles these changes differently, so check with your vendor's documentation. For KinD, shell into the control plane and update the manifest file:
```bash
docker exec -it cluster-auth-control-plane bash

apt-get update

apt-get install vim

vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

5. Look for two options under command called --oidc-client and –oidc-issuer-url. Replace those two with the output from the preceding command that produced the API server flags. Make sure to add spacing and a dash (-) in front. It should look something like this when you're done:
```bash
    - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
    - --oidc-issuer-url=https://k8sou.apps.192-168-2-131.nip.io/auth/idp/k8sIdp
    - --oidc-client-id=kubernetes
    - --oidc-username-claim=sub
    - --oidc-groups-claim=groups
    - --oidc-ca-file=/etc/kubernetes/pki/ou-ca.pem
    - --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
```
6. Exit vim and the Docker environment (ctl+d) and then take a look at the api-server pod:

```bash
kubectl get pod kube-apiserver-cluster-auth-control-plane -n kube-system

NAME                                        READY   STATUS    RESTARTS  AGE 
kube-apiserver-cluster-auth-control-plane   1/1     Running   0         73s  
```

Notice that it's only 73s old. That's because KinD saw that there was a change in the manifest and restarted the API server.

### Important Note

The API server pod is known as a "static pod". This pod can't be changed directly; its configuration has to be changed from the manifest on disk. This gives you a process that's managed by the API server as a container, but without giving you a situation where you need to edit pod manifests in EtcD directly if something goes wrong.

## Verifying OIDC integration
Once OpenUnison and the API server have been integrated, we need to test that the connection is working:

1. To test the integration, log back into OpenUnison and click on the Kubernetes Dashboard link again.
2. Click on the bell in the upper right and you'll see a different error:

Figure 7.9 – SSO enabled but the user is not authorized to access any resources

SSO between OpenUnison and you'll see that Kubernetes is working! However, the new error, service is forbidden: User https://..., is an authorization error, not an authentication error. The API server knows who we are, but isn't letting us access the APIs.

3. We'll dive into the details of RBAC and authorizations in the next chapter, but for now, create this RBAC binding:
```
kubectl create -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
   name: ou-cluster-admins
subjects:
- kind: Group
   name: k8s-cluster-admins
   apiGroup: rbac.authorization.k8s.io
roleRef:
   kind: ClusterRole
   name: cluster-admin
   apiGroup: rbac.authorization.k8s.io
EOF

clusterrolebinding.rbac.authorization.k8s.io/ou-cluster-admins created
```
1.  Finally, go back to the dashboard and you'll see that you have full access to your cluster and all that of error messages are gone.
The API server and OpenUnison are now connected. Additionally, an RBAC policy has been created to enable our test user to manage the cluster as an administrator. Access was verified by logging into the Kubernetes dashboard, but most interactions will take place using the kubectl command. The next step is to verify we're able to access the cluster using kubectl.

## Using your tokens with kubectl

Important Note

This section assumes you have a machine on your network that has a browser and kubectl running.

Using the Dashboard has its use cases, but you will likely interact with the API server using kubectl, rather than the dashboard, for the majority of your day. In this section, we will explain how to retrieve your JWT and how to add it to your Kubernetes config file:

1.  You can retrieve you token from the OpenUnison dashboard. Navigate to the OpenUnison home page and click on the key that says Kubernetes Tokens. You'll see a screen that looks as follows:

Figure 7.10 – OpenUnison kubectl configuration tool

OpenUnison provides a command line that you can copy and paste into your host session that adds all the required information to your config.

2. First, click on the double documents button next to the kubectl command to copy your kubectl command into your buffer. Leave the web browser open in the background.
3. You may want to back up your original config file before pasting the kubectl command from OpenUnison:
```bash
cp .kube/config .kube/config.bak
export KUBECONFIG=/tmp/k
kubectl get nodes

W0423 15:46:46.924515    3399 loader.go:223] Config not found: /tmp/k error: no configuration has been provided, try setting KUBERNETES_MASTER environment variable
```
4. Then, go to your host console and paste the command into the console (the following output has been shortened, but your paste will start with the same output):

```bash
export TMP_CERT=$(mktemp) && echo -e "-----BEGIN CER. . .
Cluster "kubernetes" set.
Context "kubernetes" modified.
User "mlbiamext" set.
Switched to context "kubernetes".
```

5.  Now, verify that you can view the cluster nodes using kubectl get nodes:

```bash
kubectl get nodes

NAME                         STATUS   ROLES    AGE   VERSION
cluster-auth-control-plane   Ready    master   47m   v1.17.0
cluster-auth-worker          Ready    <none>   46m   v1.17.0
```
6. You are now using your login credentials instead of the master certificate! As you work, the session will refresh. Log out of OpenUnison and watch the list of nodes. Within a minute or two, your token will expire and no longer work:

```bash
$ kubectl get nodes

Unable to connect to the server: failed to refresh token: oauth2: cannot fetch token: 401 Unauthorized
```

Congratulations! You've now set up your cluster so that it does the following:

* Authenticate using SAML2 using your enterprise's existing authentication system.
* Use groups from your centralized authentication system to authorize access to Kubernetes (we'll get into the details of how in the next chapter).
* Give access to your users to both the CLI and the dashboard using the centralized credentials.
* Maintain your enterprise's compliance requirements by having short-lived tokens that provide a way to time out.
* Everything uses TLS from the user's browser, to the Ingress Controller, to OpenUnison, the dashboard, and finally the API server.
Next, you'll learn how to integrate centralized authentication into your managed clusters.

## Introducing impersonation to integrate authentication with cloud-managed clusters
It's very popular to use managed Kubernetes services from cloud vendors such as Google, Amazon, Microsoft, and DigitalOcean (among many others). When it comes to these services, its generally very quick to get up and running, and they all share a common thread: they don't support OpenID Connect.

Earlier in this chapter, we talked about how Kubernetes supports custom authentication solutions through webhooks and that you should never, ever, use this approach unless you are a public cloud provider or some other host of Kubernetes systems. It turns out that pretty much every cloud vendor has its own approach to using these webhooks that uses their own identity and access management implementations. In that case, why not just use what the vendor provides? There are several reasons why you may not want to use a cloud vendor's IAM system:

*  ***Technical***: You may want to support features not offered by the cloud vendor, such as the dashboard, in a secure fashion.

*  ***Organizational***: Tightly coupling access to managed Kubernetes with that cloud's IAM puts an additional burden on the cloud team, which means that they may not want to manage access to your clusters.

*  ***User Experience*** : Your developers and admins may have to work across multiple clouds. Providing a consistent login experience makes it easier on them and requires learning fewer tools.
  
* ***Security and Compliance***: The cloud implementation may not offer choices that line up with your enterprise's security requirements, such as short-lived tokens and idle timeouts.
* 
All that being said, there may be reasons to use the cloud vendor's implementation. You'll need to balance out the requirements, though. If you want to continue to use centralized authentication and authorization with hosted Kubernetes, you'll need to learn how to work with Impersonation.

## What is Impersonation?
Kubernetes Impersonation is a way of telling the API server who you are without knowing your credentials or forcing the API server to trust an OpenID Connect IdP. When you use kubectl, instead of the API server receiving your id_token directly, it will receive a service account or identifying certificate that will be authorized to impersonate users, as well as a set of headers that tell the API server who the proxy is acting on behalf of:

The reverse proxy is responsible for determining how to map from id_token, which the user provides (or any other token, for that matter), to the Impersonate-User and Impersonate-Group HTTP headers. The dashboard should never be deployed with a privileged identity, which the ability to impersonate falls under. To allow Impersonation with the 2.0 dashboard, use a similar model, but instead of going to the API server, you go to the dashboard:

The user interacts with the reverse proxy just like any web application. The reverse proxy uses its own service account and adds the impersonation headers. The dashboard passes this information through to the API server on all requests. The dashboard never has its own identity.

## Security considerations
The service account has a certain superpower: it can be used to impersonate anyone (depending on your RBAC definitions). If you're running your reverse proxy from inside the cluster, a service account is OK, especially if combined with the TokenRequest API to keep the token short-lived. Earlier in the chapter, we talked about ServiceAccount objects having no expiration. That's important here because if you're hosting your reverse proxy off cluster, then if it were compromised, someone could use that service account to access the API service as anyone. Make sure you're rotating that service account often. If you're running the proxy off cluster, it's probably best to use a shorter-lived certificate instead of a service account.

When running the proxy on a cluster, you want to make sure it's locked down. It should run in its own namespace at a minimum. Not kube-system either. You want to minimize who has access. Using multi-factor authentication to get to that namespace is always a good idea, as are network policies that control what pods can reach out to the reverse proxy.

Based on the concepts we've just learned about regarding impersonation, the next step is to update our cluster's configuration to use impersonation instead of using OpenID Connect directly. You don't need a cloud-managed cluster to work with impersonation.

## Configuring your cluster for impersonation
Let's deploy an impersonating proxy for our cluster. Assuming you're reusing your existing cluster, we first need to delete our orchestra Helm deployment (this will not delete the operator; we want to keep the OpenUnison operator). So, let's begin:

1.  Run the following command to delete our orchestra Helm deployment:
```bash
$ helm delete orchestra --namespace openunison

release "orchestra" uninstalled
```

The only pod running in the openunison namespace is our operator. Notice that all the Secrets, Ingress, Deployments, Services, and other objects that were created by the operator when the orchestra Helm chart was deployed are all gone.

2. Next, redeploy OpenUnison, but this time, update our Helm chart to use impersonation. Edit the values.yaml file and add the two bold lines shown in the following example file:

```yaml
network:
  openunison_host: "k8sou.apps.192-168-2-131.nip.io"
  dashboard_host: "k8sdb.apps.192-168-2-131.nip.io"
  api_server_host: "k8sapi.apps.192-168-2-131.nip.io"
  session_inactivity_timeout_seconds: 900
  k8s_url: https://192.168.2.131:32776
cert_template:
  ou: "Kubernetes"
  o: "MyOrg"
  l: "My Cluster"
  st: "State of Cluster"
  c: "MyCountry"
image: "docker.io/tremolosecurity/openunison-k8s-login-saml2:latest"
myvd_config_path: "WEB-INF/myvd.conf"
k8s_cluster_name: kubernetes
enable_impersonation: true
dashboard:
  namespace: "kubernetes-dashboard"
  cert_name: "kubernetes-dashboard-certs"
  label: "k8s-app=kubernetes-dashboard"
  service_name: kubernetes-dashboard
certs:
  use_k8s_cm: false
trusted_certs: []
monitoring:
  prometheus_service_account: system:serviceaccount:monitoring:prometheus-k8s
saml:
  idp_url: https://portal.apps.tremolo.io/idp-test/metadata/dfbe4040-cd32-470e-a9b6-809c8f857c40
  metadata_xml_b64: ""
```
We have made two changes here:

*  Added a host for the API server proxy
*  Enabled impersonation
These changes enable OpenUnison's impersonation features and generate an additional RBAC binding to enable impersonation on OpenUnison's service account.

3. Run the Helm chart with the new values.yaml file:
```bash
helm install orchestra tremolo/openunison-k8s-login-saml2 –namespace openunison -f ./values.yaml

NAME: orchestra
LAST DEPLOYED: Thu Apr 23 20:55:16 2020
NAMESPACE: openunison
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

Just like with our OpenID Connect integration with Kubernetes, finish the integration with the testing identity provider. First, get the metadata:

```bash
 curl --insecure https://k8sou.apps.10-100-198-200.nip.io/auth/forms/saml2_rp_metadata.jsp
 
<?xml version="1.0" encoding="UTF-8"?><md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" ID="f275c76687cc91bdf29e327667daec0095ec233ff" entityID="https://k8sou.apps.10-100-198-200.nip.io/auth/SAML2Auth">
   <md:SPSSODescriptor WantAssertionsSigned="true" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
      <md:KeyDescriptor use="signing">
         <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <ds:X509Data>
               <ds:X509Certificate>MIID1jCCAr6gAwIBAgIGAXaKdUxuMA0GCSqGSIb3DQEBCwUAMIGHMRwwGgYDVQQDDBN1bmlzb24t&#13;
c2FtbDItcnAtc2lnMRMwEQYDVQQLDApLdWJlcm5ldGVzMQ4wDAYDVQQKDAVNeU9yZzETMBEGA1UE&#13;
BwwKTXkgQ2x1c3RlcjEZMBcGA1UECAwQU3RhdGUgb2YgQ2x1c3RlcjESMBAGA1UEBhMJTXlDb3Vu&#13;
dHJ5MB4XDTIwMTIyMjEyMzgzMVoXDTIxMTIyMjEyMzgzMVowgYcxHDAaBgNVBAMME3VuaXNvbi1z&#13;
YW1sMi1ycC1zaWcxEzARBgNVBAsMCkt1YmVybmV0ZXMxDjAMBgNVBAoMBU15T3JnMRMwEQYDVQQH&#13;
DApNeSBDbHVzdGVyMRkwFwYDVQQIDBBTdGF0ZSBvZiBDbHVzdGVyMRIwEAYDVQQGEwlNeUNvdW50&#13;
cnkwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCWlAE2jHtOUyp1MEX9EqlSHP7uEovb&#13;
9Cbup/6D/gOz8ijtIhRNjqQZQoLozIzliCwWfIMdkblhh30jhXzDpvDGG8dZ3fdzhFHc+skK9T9G&#13;
lqHjza2IBNg34PmA5du7tc1PCQy/U0kRzUp5FEkSSJFhR/HpZOYeWYfcCePjdJ0cmkEaV4NkDKME&#13;
kaeGfhTbJSiHAiG63k8HUGAowbIJmANePBFJQ3URyrkjXqq/XWsO7IpMNMW31H3/VG43uBp2URfk&#13;
QIn6tmxL/POrV/ckjTeE9VRVJhsaCHgLA4jC/hWDm5ZqI4udjdajHzgfid/A/F6GSlyYrlRCc7s6&#13;
pRwyKKaFAgMBAAGjRjBEMA4GA1UdDwEB/wQEAwICBDASBgNVHSUBAf8ECDAGBgRVHSUAMB4GA1Ud&#13;
EQQXMBWCE3VuaXNvbi1zYW1sMi1ycC1zaWcwDQYJKoZIhvcNAQELBQADggEBAIfNCSxRDOQVvM7P&#13;
/cm3k+L5xfs8vyf7kQfCoMcbY6qGJiSJQUcck2CpUexVIvnHum6+FLnB6AJ9lbH93YMcU9g4jyvK&#13;
1p39Fei+T/QxO7yOWKiVc3TPSy5K4rMibqpk1pTZaWd5ulkOFuZHI9cdJgbLwUwJpja+3tyVcwqa&#13;
cguhFziOEI5MQVn31g9I/4A/R2j5bbeNsTInGJbyVK1SLVTcwa5pfnPEYv1jRjJAdy31zQXWP6yh&#13;
ncYWcZM8zFtiWD/iuJP8wyYWn3n05AouZb6ehRBY9O4LfL9x3QPnqJOmzBxkhv5yg2UzSSmV5wln&#13;
YA/PDYQErBlEsOP3G0sTWtw=</ds:X509Certificate>
            </ds:X509Data>
         </ds:KeyInfo>
      </md:KeyDescriptor>
      <md:SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://k8sou.apps.10-100-198-200.nip.io/auth/SAML2Auth"/>
      <md:SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://k8sou.apps.10-100-198-200.nip.io/auth/SAML2Auth"/>
      <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://k8sou.apps.10-100-198-200.nip.io/auth/SAML2Auth" index="0" isDefault="true"/>
      <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://k8sou.apps.10-100-198-200.nip.io/auth/SAML2Auth" index="1"/>
   </md:SPSSODescriptor>
</md:EntityDescriptor>

```

5. Next, log into https://portal.apps.tremolo.io/, choose the testing identity provider, and copy and paste the resulting metadata into the testing identity provider where it says Meta Data.
6. Finally, to update the change, click Update Relying Party.
  

The new OpenUnison deployment is configured as a reverse proxy for the API server and has been re-integrated with our SAML2 identity provider. There are no cluster parameters to set because impersonation doesn't need any cluster-side configuration. The next step is to test the integration.

## Testing impersonation
Now, let's test our impersonation setup. Follow these steps:

1. In a browser, enter the URL for your OpenUnison deployment. This is the same URL you used for your initial OIDC deployment.
2. Log into OpenUnison and then click on the dashboard. You should recall that the first time you opened the dashboard on the your initial OpenUnison deployment, you received a lot of errors until you created the new RBAC role, which granted access to the cluster.
After you've enabled impersonation and opened the dashboard, you shouldn't see any error messages, even though you were prompted for new certificate warnings and didn't tell the API server to trust the new certificates you're using with the dashboard.

3. Click on the little circular icon in the upper right-hand corner to see who you're logged in as.
   
4. Next, go back to the main OpenUnison dashboard and click on the Kubernetes Tokens badge.
Notice that the --server flag being passed to kubectl no longer has an IP. Instead, it has the hostname from network.api_server_host in the values.yaml file. This is impersonation. Instead of interacting directly with the API server, you're now interacting with OpenUnison's reverse proxy.

5. Finally, let's copy and paste our kubectl command into a shell:
```bash
export TMP_CERT=$(mktemp) && echo -e "-----BEGIN CERTIFI...
Cluster "kubernetes" set.
Context "kubernetes" created.
User "mlbiamext" set.
Switched to context "kubernetes".
```
6.To verify you have access, list the cluster nodes:
```bash
kubectl get nodes

NAME                         STATUS   ROLES    AGE    VERSION
cluster-auth-control-plane   Ready    master   6h6m   v1.17.0
cluster-auth-worker          Ready    <none>   6h6m   v1.17.0
```
7. Just like when you integrated the original deployment of OpenID Connect, once you've logged out of the OpenUnison page, within a minute or two, the tokens will expire and you won't be able to refresh them:

```bash
kubectl get nodes

Unable to connect to the server: failed to refresh token: oauth2: cannot fetch token: 401 Unauthorized
```

You've now validated that your cluster is working correctly with impersonation. Instead of authenticating directly to the API server, the impersonating reverse proxy (OpenUnison) is forwarding all requests to the API server with the correct impersonation headers. You're still meeting your enterprise's needs by providing both a login and logout process and integrating your Active Directory groups.

## Configuring Impersonation without OpenUnison
The OpenUnison operator automated a couple of key steps to get impersonation working. There are other projects designed specifically for Kubernetes, such as JetStack's OIDC Proxy (https://github.com/jetstack/kube-oidc-proxy), that are designed to make using impersonation easier. You can use any reverse proxy that can generate the correct headers. There are two critical items to understand when doing this on your own.

### Impersonation RBAC policies
RBAC will be covered in the next chapter, but for now, the correct policy to authorize a service account for impersonation is as follows:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: impersonator
rules:
- apiGroups:
  - ""
  resources:
  - users
  - groups
  verbs:
  - impersonate
```

To constrain what accounts can be impersonated, add resourceNames to your rule.

### Default groups
When impersonating a user, Kubernetes does not add the default group, system:authenticated, to the list of impersonated groups. When using a reverse proxy that doesn't specifically know to add the header for this group, configure the proxy to add it manually. Otherwise, simple acts such as calling the /api endpoint will fail as this will be unauthorized for anyone except cluster administrators.

## Summary
This chapter detailed how Kubernetes identifies users and what groups their members are in. We detailed how the API server interacts with identities and explored several options for authentication. Finally, we detailed the OpenID Connect protocol and how it's applied to Kubernetes.

Learning how Kubernetes authenticates users and the details of the OpenID Connect protocol are an important part of building security into a cluster. Understanding the details and how they apply to common enterprise requirements will help you decide the best way to authenticate to clusters, and also provide justification regarding why the anti-patterns we explored should be avoided.

In the next chapter, we'll apply our authentication process to authorizing access to Kubernetes resources. Knowing who someone is isn't enough to secure your clusters. You also need to control what they have access to.
