# hobby-kube-sso

[hobby-kube/guide](https://github.com/hobby-kube/guide)

## 1. Setup Kubernetes Cluster

Clone [hobby-kube/provisioning](https://github.com/hobby-kube/provisioning).

```sh
$ git clone https://github.com/hobby-kube/provisioning
$ cd provisioning
```

Before executing Terraform, disable `CNAME: *` from Cloudflare DNS settings because you will need a record for ACME to generate TLS cert.

Edit `dns/cloudflare/main.tf`

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

## 2. Update kubeapiserver Settings

(This step should be improved later)

We need to launch Ambassador on TCP port `80` and `443`. The following doc describe how to setup Ambassador on a bare metal Kubernetes cluster.

[Deploying Ambassador on a Bare Metal Kubernetes Installation](https://www.getambassador.io/user-guide/bare-metal/)

We choose the first method "Exposing Ambassador via NodePort" because it has restriction configuring Ambassador modules by Service metadata.

However, you have to manually configure kube-apiserver because by default Kubernetes does not allow binding TCP port under 30000 to NodePorts.

Login the master node and edit `/etc/kubernetes/manifests/kube-apiserver.yaml` as follows

```diff
@@ -34,6 +34,7 @@
     - --service-cluster-ip-range=10.96.0.0/12
     - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
     - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
+    - --service-node-port-range=80-32767
     image: k8s.gcr.io/kube-apiserver:v1.14.1
     imagePullPolicy: IfNotPresent
     livenessProbe:
```

Restart kubelet.

```sh
$ systemctl restart kubelet
```

The above manual step is necessary because I still can not find a way to automate it. I have edited `service/kubernetes/templates/master-configuration.yml` as follows but it does not affect.

```diff
@@ -14,6 +14,8 @@ etcd:
   external:
     endpoints:
     ${etcd_endpoints}
+apiServerExtraArgs:
+  service-node-port-range: "80-32767"
 ---
 apiVersion: kubelet.config.k8s.io/v1beta1
 kind: KubeletConfiguration
```

```sh
$ systemctl restart kubelet
```

* [Helm](https://helm.sh/)
* [helm-diff](https://github.com/databus23/helm-diff)
* [Helmsman](https://github.com/Praqma/helmsman)
* [onessl](https://github.com/kubepack/onessl)

```sh
$ cd somewhere/hobby-managed-kube
$ make helm-init
```

* `TILLER_NAMESPACE`
* `TILLER_SERVICE_ACCOUNT`
* `TILLER_CLUSTER_ROLE`
* `TILLER_CLUSTER_ROLE_BINDING`

```sh
$ alias hm="helmsman -f helmsman.yaml"
```
