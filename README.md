# hobby-kube-oidc-sso

Kubernetes manifests to setup OIDC single sign-on on a [hobby-kube](https://github.com/hobby-kube/guide) cluster.

* [Rook](https://rook.io/)
  * Storage manager for Kubernetes
* [cert-manager](https://github.com/jetstack/cert-manager)
  * TLS certs manager
* [Ambassador](https://www.getambassador.io/)
  * API gateway
* [Keycloak](https://www.keycloak.org/)
  * Identity and access manager
  * OpenID Connect provider
* [a8r-oidc-auth-service](https://github.com/yatsu/a8r-oidc-auth-service)
  * Ambassador AuthService to enable single OIDC sign-on
  * Also provides kubectl configuration help page
* Redis
  * Used by a8r-oidc-auth-service
* PostgreSQL
  * Used by Keycloak

## Prerequisite

* Registered domain name
* Account of one of the cloud services suggested by [hobby-kube/guide](https://github.com/hobby-kube/guide)
* [Cloudflare](https://dash.cloudflare.com) account
  * You can choose another DNS service, but you will have to edit `helmsman.yaml` and a Helm values file
  * Make sure your Cloudflare SSL setting is "Full" (Navigate: Crypto -> SSL)
* Tools
  * [Terraform](https://www.terraform.io/)
  * [Helm](https://helm.sh/)
  * [helm-diff](https://github.com/databus23/helm-diff)
  * [Helmsman](https://github.com/Praqma/helmsman)

Make sure they are available in your environment.

## 1. Setup Kubernetes Cluster

### 1-1. Get hobby-kube/provisioning

Clone [hobby-kube/provisioning](https://github.com/hobby-kube/provisioning) and [hobby-kube-oidc-sso](https://github.com/yatsu/hobby-kube-oidc-sso):

```sh
$ git clone https://github.com/hobby-kube/provisioning
$ git clone https://github.com/yatsu/hobby-kube-oidc-sso
$ cd provisioning
```

### 1-2. Apply the Patch to hobby-kube/provisioning

Apply [the patch](https://github.com/yatsu/hobby-kube-oidc-sso/blob/master/hobby-kube-provisioning.patch).

```sh
$ cd provisioning
$ patch -p1 < ../hobby-kube-oidc-sso/hobby-kube-provisioning.patch
```

Modifications to `hobby-kube/provisioning`:

1. Disable DNS wildcard
2. Allow TCP port `80-32767` for NodePorts
3. Enable OIDC authentication of Kubernetes API server
4. Set volume plugin directory

#### Disabling DNS Wildcard

You have to disable the DNS wildcard (`CNAME *`) so that Cert Manager can add a record `_acme-challenge` to setup certs (See [Issuing an ACME certificate using DNS validation](https://docs.cert-manager.io/en/latest/tutorials/acme/dns-validation.html) for details).

#### Allowing TCP port 80-32767

[Ambassador doc](https://www.getambassador.io/user-guide/bare-metal/#exposing-ambassador-via-host-network) says we have two ways to deploy Ambassador on a bare metal Kubernetes cluster:

1. Exposing Ambassador via NodePort
2. Exposing Ambassador via Host Network

We choose NodePort with allowing Services to use TCP port under 30000. This seems to be so far the best way for our hobby setup.

#### Enabling OIDC Authentication of Kubernetes API Server

This setup allows users to access your Kubernetes API. Users are managed by Keycloak and permissions are managed by Kubernetes RBAC. To allow users to access Kubernetes API, OIDC configuration is required.

This feature can be disabled if you don't need it.

#### Volume Plugin Directory

Both kubelet and Rook use the same volume plugin directory.

The above patch adds `--volume-plugin-dir` option to kubelet as follows:

```sh
--volume-plugin-dir=/usr/libexec/kubernetes/kubelet-plugins/volume/exec
```

Rook Agent will be launched with this environment variable:

```sh
FLEXVOLUME_DIR_PATH=/usr/libexec/kubernetes/kubelet-plugins/volume/exec
```

See [FlexVolume Configuration](https://www.projectatomic.io/) for more details.

### 1-3. Deploying Kubernetes

Set environment variables:

```sh
export TF_VAR_node_count="3"
export TF_VAR_hcloud_type="cx21"
export TF_VAR_hcloud_token="abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012a"
export TF_VAR_hcloud_ssh_keys='["who@localhost.local"]'
export TF_VAR_domain="example.com"
export TF_VAR_cloudflare_email="admin@example.com"
export TF_VAR_cloudflare_token="abcd0123abcd0123abcd0123abcd0123abcd0"
```

This example uses [Hetzner Cloud](https://www.hetzner.com/) for cloud service. You can choose another service if you would like to. The cheapest hcloud_type `cx11` is also available but may not be enough to launch all apps. Calculate the required resources and the cost yourself.

Execute Terraform:

```sh
$ terraform init
$ terraform plan
$ terraform apply
```

This takes around 8 minutes.

## 2. Installing Apps

### 2-1. Helm Setup

Initialize Helm for your Kubernetes cluster:

```sh
$ cd ../hobby-kube-oidc-sso
$ make helm-init
```

### 2-2. Environment Variables

Create `.env` file and set environment variables:

```sh
CLOUDFLARE_EMAIL="admin@example.com"
CLOUDFLARE_APIKEY="abcd0123abcd0123abcd0123abcd0123abcd0"
ACME_EMAIL="admin@agendle.com"
KEYCLOAK_USERNAME="admin"
KEYCLOAK_PASSWORD="adminpass"
CLUSTER_NAME="example"
DOMAIN="example.com"
KUBECTL_CONTEXT="example"
SESSION_SECRET="a8r-auth"
OIDC_PROVIDER="https://example.com/auth/realms/example"
OIDC_CLIENT_ID="example"
```

Or export these environment variables from your shell manually:

```sh
export CLOUDFLARE_EMAIL="admin@example.com"
export CLOUDFLARE_APIKEY="abcd0123abcd0123abcd0123abcd0123abcd0"
export ACME_EMAIL="admin@agendle.com"
export KEYCLOAK_USERNAME="admin"
export KEYCLOAK_PASSWORD="adminpass"
export CLUSTER_NAME="example"
export DOMAIN="example.com"
export KUBECTL_CONTEXT="example"
export SESSION_SECRET="a8r-auth"
export OIDC_PROVIDER="https://example.com/auth/realms/example"
export OIDC_CLIENT_ID="example"
```

### 2-3. App Installation (1/2)

Now you can execute Helmsman, but you cannot release all apps at the first time, because Ambassador AuthService (`a8r-oidc-auth-service`) requires a OIDC client setting in your Keycloak instance.

Check that `a8r-oidc-auth-service` and `a8s-oidc-auth-service-activation` are disabled in ` helmsman.yaml`.

```yaml
   a8r-oidc-auth-service:
     # ...
     enabled: false
     # ...
 
   a8r-oidc-auth-service-activation:
     # ...
     enabled: false
     # ...
```

Execute helmsman:

```sh
$ helmsman -f helmsman.yaml --apply
```

This takes around 10 minutes.

### 2-4. Keycloak Setting

Open Keycloak with your browser:

```
https://<your-domain>/auth/
```

Create your realm, client, groups and users. The client must be a public client (without client secret).

### 2-5. App Installation (2/2)

Edit `helmsman.yaml` to enable `a8r-oidc-auth-service` and `a8r-oidc-auth-service-activation`:

```diff
@@ -193,7 +193,7 @@
 
   a8r-oidc-auth-service:
     namespace: auth
-    enabled: false
+    enabled: true
     chart: ./a8r-oidc-auth-service
     version: 0.1.0
     name: a8r-oidc-auth-service
@@ -216,7 +216,7 @@
 
   a8r-oidc-auth-service-activation:
     namespace: auth
-    enabled: false
+    enabled: true
     chart: ./a8r-oidc-auth-service-activation
     version: 0.1.0
     name: a8r-oidc-auth-service-activation
```

Execute helmsman again:

```sh
$ helmsman -f helmsman.yaml --apply
```

Wait until all Pods are ready.

Now you can open your site with your browser and see SSO is working.

```
https://<your-domain>
```

## Tips and Troubleshooting

### Ambassador AuthService

The Ambassador AuthService is divided into two charts: `a8r-oidc-auth-service` and `a8r-oidc-auth-service-activation` because the `Service` object must be created after the `Deployment` is ready. If the `Service` is created before the `Deployment` is ready, all URL routes become unreachable.

When you restart the AuthService, delete `a8r-oidc-auth-service-activation`, `a8r-oidc-auth-service` and `ambassador`, and then run `helmsman --apply`.

```sh
$ helm delete --purge a8r-oidc-auth-service-activation
$ helm delete --purge a8r-oidc-auth-service
$ helm delete --purge ambassador
$ helmsman -f helmsman.yaml --apply
```
