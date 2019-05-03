# hobby-kube-sso

[hobby-kube/guide](https://github.com/hobby-kube/guide)

## 1. Setup Kubernetes Cluster

### 1-1. Getting Kubernetes Provisioning

Clone [hobby-kube/provisioning](https://github.com/hobby-kube/provisioning).

```sh
$ git clone https://github.com/hobby-kube/provisioning
$ cd provisioning
```

### 1-2. Disabling DNS Wildcard

You have to disable the DNS wildcard (`CNAME *`) so that Cert Manager can add a record `_acme-challenge` to setup certs (See [Issuing an ACME certificate using DNS validation](https://docs.cert-manager.io/en/latest/tutorials/acme/dns-validation.html) for details).

Edit `dns/cloudflare/main.tf`:

```diff
@@ -37,15 +37,15 @@ resource "cloudflare_record" "domain" {
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
+# resource "cloudflare_record" "wildcard" {
+#   depends_on = ["cloudflare_record.domain"]
+#
+#   domain  = "${var.domain}"
+#   name    = "*"
+#   value   = "${var.domain}"
+#   type    = "CNAME"
+#   proxied = false
+# }
```

### 1-3. Modifying NodePort Range

[Ambassador doc](https://www.getambassador.io/user-guide/bare-metal/#exposing-ambassador-via-host-network) says we have two ways to deploy Ambassador on a bare metal Kubernetes cluster:

1. Exposing Ambassador via NodePort
2. Exposing Ambassador via Host Network

We choose NodePort with allowing Services to use TCP port under 30000. This seems to be so far the best way for our hobby setup.

Edit `service/kubernetes/templates/master-configuration.yml`:

```diff
@@ -10,6 +10,8 @@ certificatesDir: /etc/kubernetes/pki
 apiServer:
   certSANs:
   ${cert_sans}
+  extraArgs:
+    service-node-port-range: 80-32767
 etcd:
   external:
     endpoints:
```

### 1-4. Deploying Kubernetes

This example uses [Hetzner Cloud](https://www.hetzner.com/) for cloud service and [Cloudflare](https://dash.cloudflare.com) for DNS service. You can choose other cloud services, but regarding DNS, Cloudflare is the only one available. If you want to use other DNS services, you have to edit some files.

Make sure your Cloudflare SSL setting is "Full" (Navigate: Crypto -> SSL).

Set environment variables:

```sh
$ export TF_VAR_hcloud_token="abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012a"
$ export TF_VAR_hcloud_ssh_keys='["who@localhost.local"]'
$ export TF_VAR_domain=example.com
$ export TF_VAR_cloudflare_email="admin@example.com"
$ export TF_VAR_cloudflare_token="abcd0123abcd0123abcd0123abcd0123abcd0"
```

Execute Terraform.

```sh
$ terraform init
$ terraform plan
$ terraform apply
```

## 2. Installing Apps

### 2-1. Tool Setup

Install the following tools:

* [Helm](https://helm.sh/)
* [helm-diff](https://github.com/databus23/helm-diff)
* [Helmsman](https://github.com/Praqma/helmsman)

Initialize Helm:

```sh
$ cd somewhere/hobby-kube-sso
$ make helm-init
```

### 2-2. Installing Apps with Helmsman

Create `.env` file:

```sh
DOMAIN="example.com"
ACME_EMAIL="admin@example.com"
CLOUDFLARE_EMAIL="admin@example.com"
CLOUDFLARE_APIKEY="abcd0123abcd0123abcd0123abcd0123abcd0"
KEYCLOAK_USERNAME="admin"
KEYCLOAK_PASSWORD="adminpass"
OIDC_PROVIDER="https://example.com/auth/realms/example"
OIDC_CLIENT_ID="example-client"
OIDC_REDIRECT_URI="https://example.com/oidc/callback"
SESSION_SECRET="a8r-auth-sess"
OIDC_DEBUG="a8r-oidc-auth-service:*"
```

Or export these environment variables from your shell manually:

```sh
export DOMAIN="example.com"
export ACME_EMAIL="admin@example.com"
export CLOUDFLARE_EMAIL="admin@example.com"
export CLOUDFLARE_APIKEY="abcd0123abcd0123abcd0123abcd0123abcd0"
export KEYCLOAK_USERNAME="admin"
export KEYCLOAK_PASSWORD="adminpass"
export OIDC_PROVIDER="https://example.com/auth/realms/example"
export OIDC_CLIENT_ID="example-client"
export OIDC_REDIRECT_URI="https://example.com/oidc/callback"
export SESSION_SECRET="a8r-auth-sess"
export OIDC_DEBUG="a8r-oidc-auth-service:*"
```

Execute helmsman:

```sh
$ helmsman -f helmsman.yaml apply
```

Open Keycloak with your browser:

```
https://<your-domain>/auth/
```
