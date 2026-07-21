SHELL := /usr/bin/env bash

.PHONY: render validate apply status health clean

render:
	kubectl kustomize manifests/

validate:
	kubectl apply --dry-run=client -k manifests/

apply:
	kubectl apply -k manifests/

status:
	kubectl -n platform-demo get deployment,pod,service,hpa,pdb,networkpolicy

health:
	NAMESPACE=platform-demo ./scripts/platform-health-check.sh

clean:
	kubectl delete -k manifests/ --ignore-not-found
