TILLER_NAMESPACE ?= kube-system
TILLER_SERVICE_ACCOUNT ?= tiller
TILLER_CLUSTER_ROLE ?= cluster-admin  # must already exist
TILLER_CLUSTER_ROLE_BINDING ?= tiller-cluster-role-binding

.PHONY: check-kubectl
check-kubectl:
	@type kubectl >& /dev/null || (echo "kubectl not found\nHave you already setup Kubernetes?"; exit 1)

.PHONY: check-helm
check-helm:
	@type helm >& /dev/null || (echo "helm not found\nPlease install it from https://helm.sh/"; exit 1)

.PHONY: check-helmsman
check-helmsman:
	@type helmsman >& /dev/null || (echo "helmsman not found\nPlease install it from https://github.com/Praqma/helmsman"; exit 1)

.PHONY: tiller-init
tiller-init: check-kubectl check-helm
	kubectl create serviceaccount -n ${TILLER_NAMESPACE} ${TILLER_SERVICE_ACCOUNT}
	kubectl create clusterrolebinding ${TILLER_CLUSTER_ROLE_BINDING} \
		--clusterrole=${TILLER_CLUSTER_ROLE} \
		--serviceaccount=${TILLER_NAMESPACE}:${TILLER_SERVICE_ACCOUNT}

.PHONY: helm-init
helm-init: tiller-init
	helm init --service-account ${TILLER_SERVICE_ACCOUNT} --upgrade
