# hobby-managed-kube

[hobby-kube/guide](https://github.com/hobby-kube/guide)

```sh
$ git clone https://github.com/hobby-kube/provisioning
$ cd provisioning
$ export TF_VAR_hcloud_token="abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012abcXYZ012a"
$ export TF_VAR_hcloud_ssh_keys='["who@localhost.local"]'
$ export TF_VAR_domain=example.com
$ export TF_VAR_cloudflare_email="admin@example.com"
$ export TF_VAR_cloudflare_token="abcd0123abcd0123abcd0123abcd0123abcd0"
$ terraform init
$ terraform plan
$ terraform apply
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
