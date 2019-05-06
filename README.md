# hobby-kube-oidc-sso

This is a Kubernetes manifests to setup OIDC single sign-on for a [hobby-kube](https://github.com/hobby-kube/guide) cluster.

* [Rook](https://rook.io/)
  * Storage manager for Kubernetes
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

* Service Accounts
  * A Cloud service suggested by [hobby-kube/guide](https://github.com/hobby-kube/guide)
  * [Cloudflare](https://dash.cloudflare.com) for DNS
    * Currently only Cloudflare is available
      * (To use other DNS services, you have to edit some files)
    * Make sure your Cloudflare SSL setting is "Full" (Navigate: Crypto -> SSL)
* Tools
  * [Terraform](https://www.terraform.io/)
  * [Helm](https://helm.sh/)
  * [helm-diff](https://github.com/databus23/helm-diff)
  * [Helmsman](https://github.com/Praqma/helmsman)

Make sure they are available in your environment.

## 1. Setup Kubernetes Cluster

### 1-1. Get hobby-kube/provisioning

Clone [hobby-kube/provisioning](https://github.com/hobby-kube/provisioning).

```sh
$ git clone https://github.com/hobby-kube/provisioning
$ cd provisioning
```

### 1-2. Apply the Patch for hobby-kube/provisioning

Apply this patch:

```diff
diff --git a/dns/cloudflare/main.tf b/dns/cloudflare/main.tf
index 9fb5613..35e3dd6 100644
--- a/dns/cloudflare/main.tf
+++ b/dns/cloudflare/main.tf
@@ -37,16 +37,6 @@ resource "cloudflare_record" "domain" {
   proxied = true
 }
 
-resource "cloudflare_record" "wildcard" {
-  depends_on = ["cloudflare_record.domain"]
-
-  domain  = "${var.domain}"
-  name    = "*"
-  value   = "${var.domain}"
-  type    = "CNAME"
-  proxied = false
-}
-
 output "domains" {
   value = ["${cloudflare_record.hosts.*.hostname}"]
 }
diff --git a/main.tf b/main.tf
index 5cda27b..f48d01e 100644
--- a/main.tf
+++ b/main.tf
@@ -121,10 +121,14 @@ module "etcd" {
 module "kubernetes" {
   source = "./service/kubernetes"
 
-  count          = "${var.node_count}"
-  connections    = "${module.provider.public_ips}"
-  cluster_name   = "${var.domain}"
-  vpn_interface  = "${module.wireguard.vpn_interface}"
-  vpn_ips        = "${module.wireguard.vpn_ips}"
-  etcd_endpoints = "${module.etcd.endpoints}"
+  count               = "${var.node_count}"
+  connections         = "${module.provider.public_ips}"
+  cluster_name        = "${var.domain}"
+  vpn_interface       = "${module.wireguard.vpn_interface}"
+  vpn_ips             = "${module.wireguard.vpn_ips}"
+  oidc_issuer_url     = "${var.oidc_issuer_url}"
+  oidc_username_claim = "${var.oidc_username_claim}"
+  oidc_groups_claim   = "${var.oidc_groups_claim}"
+  oidc_client_id      = "${var.oidc_client_id}"
+  etcd_endpoints      = "${module.etcd.endpoints}"
 }
diff --git a/service/kubernetes/main.tf b/service/kubernetes/main.tf
index e4b9c2c..661fc97 100644
--- a/service/kubernetes/main.tf
+++ b/service/kubernetes/main.tf
@@ -24,6 +24,22 @@ variable "overlay_cidr" {
   default = "10.96.0.0/16"
 }
 
+variable "oidc_issuer_url" {
+  type = "string"
+}
+
+variable "oidc_username_claim" {
+  type = "string"
+}
+
+variable "oidc_groups_claim" {
+  type = "string"
+}
+
+variable "oidc_client_id" {
+  type = "string"
+}
+
 resource "random_string" "token1" {
   length  = 6
   upper   = false
@@ -88,6 +104,10 @@ data "template_file" "master-configuration" {
 
   vars {
     api_advertise_addresses = "${element(var.vpn_ips, 0)}"
+    oidc_issuer_url         = "${var.oidc_issuer_url}"
+    oidc_username_claim     = "${var.oidc_username_claim}"
+    oidc_groups_claim       = "${var.oidc_groups_claim}"
+    oidc_client_id          = "${var.oidc_client_id}"
     etcd_endpoints          = "- ${join("\n    - ", var.etcd_endpoints)}"
     cert_sans               = "- ${element(var.connections, 0)}"
   }
diff --git a/service/kubernetes/templates/master-configuration.yml b/service/kubernetes/templates/master-configuration.yml
index 3a79224..4a26ca4 100644
--- a/service/kubernetes/templates/master-configuration.yml
+++ b/service/kubernetes/templates/master-configuration.yml
@@ -10,6 +10,12 @@ certificatesDir: /etc/kubernetes/pki
 apiServer:
   certSANs:
   ${cert_sans}
+  extraArgs:
+    service-node-port-range: 80-32767
+    oidc-issuer-url: ${oidc_issuer_url}
+    oidc-username-claim: ${oidc_username_claim}
+    oidc-groups-claim: ${oidc_groups_claim}
+    oidc-client-id: ${oidc_client_id}
 etcd:
   external:
     endpoints:
diff --git a/service/swap/templates/90-kubelet-extras.conf b/service/swap/templates/90-kubelet-extras.conf
index c7fd95a..59f9184 100644
--- a/service/swap/templates/90-kubelet-extras.conf
+++ b/service/swap/templates/90-kubelet-extras.conf
@@ -1,2 +1,2 @@
 [Service]
-Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false"
\ No newline at end of file
+Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false --volume-plugin-dir=/usr/libexec/kubernetes/kubelet-plugins/volume/exec"
diff --git a/variables.tf b/variables.tf
index b268638..eda0219 100644
--- a/variables.tf
+++ b/variables.tf
@@ -117,3 +117,11 @@ variable "google_managed_zone" {
 variable "google_credentials_file" {
   default = ""
 }
+
+variable "oidc_issuer_url" {}
+
+variable "oidc_username_claim" {}
+
+variable "oidc_groups_claim" {}
+
+variable "oidc_client_id" {}
```

```sh
$ cd provisioning
$ patch -p1 < /somewhere/hobby-kube-oidc-sso/hobby-kube-provisioning.patch
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

See [FlexVolume Configuration]([Rook Docs](https://www.projectatomic.io/) for more details.

### 1-3. Deploying Kubernetes

This example uses [Hetzner Cloud](https://www.hetzner.com/) for cloud service. You can choose another service.

Set environment variables:

```sh
$ export TF_VAR_node_count="3"
$ export TF_VAR_hcloud_type="cx21"
$ export TF_VAR_hcloud_image="ubuntu-16.04"
$ export TF_VAR_hcloud_token="abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012a"
$ export TF_VAR_hcloud_ssh_keys='["who@localhost.local"]'
$ export TF_VAR_domain=example.com
$ export TF_VAR_cloudflare_email="admin@example.com"
$ export TF_VAR_cloudflare_token="abcd0123abcd0123abcd0123abcd0123abcd0"
```

* Set `hcloud_type` to `cx11` if you want to reduce costs (and machine resources)
* `hcloud_image` must be a Linux distribution whose kernel supports RBD module
  * It is required by Rook (See [Prerequisites of Rook](https://rook.io/docs/rook/v1.0/k8s-pre-reqs.html))

Execute Terraform.

```sh
$ terraform init
$ terraform plan
$ terraform apply
```

## 2. Installing Apps

### 2-1. Helm Setup

Initialize Helm for your Kubernetes cluster:

```sh
$ cd somewhere/hobby-kube-oidc-sso
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

So edit `helmsman.yaml` to disable `a8r-oidc-auth-service` and `a8r-oidc-auth-service-activation`:

```diff
@@ -193,7 +193,7 @@
 
   a8r-oidc-auth-service:
     namespace: auth
-    enabled: true
+    enabled: false
     chart: ./a8r-oidc-auth-service
     version: 0.1.0
     name: a8r-oidc-auth-service
@@ -216,7 +216,7 @@
 
   a8r-oidc-auth-service-activation:
     namespace: auth
-    enabled: true
+    enabled: false
     chart: ./a8r-oidc-auth-service-activation
     version: 0.1.0
     name: a8r-oidc-auth-service-activation
```

Execute helmsman:

```sh
$ helmsman -f helmsman.yaml --apply
```

This takes very long time especially on creating Ceph block storages.

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

That's it!

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
