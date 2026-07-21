# Kubernetes & OpenShift Operations

Production-inspired operational patterns for Kubernetes and Red Hat OpenShift. This repository focuses on the work around a workload—not merely deploying it: resilience, security context, resource control, health diagnostics, operational readiness and incident response.

## What this repository demonstrates

- A hardened, highly available example workload
- Readiness, liveness and startup probes with explicit resource requests and limits
- Pod disruption budgets, horizontal scaling and topology spread
- Default-deny network policy with documented application and DNS flows
- A reusable platform health-check script
- Operational Readiness Review criteria
- Runbooks for `CrashLoopBackOff` and `NodeNotReady`
- Safe investigation that preserves evidence before disruptive recovery actions

## Repository layout

```text
.
├── manifests/
│   ├── workload.yaml
│   ├── network-policies.yaml
│   └── kustomization.yaml
├── scripts/platform-health-check.sh
├── runbooks/crashloopbackoff.md
├── runbooks/node-not-ready.md
├── docs/operational-readiness-review.md
└── Makefile
```

## Deploy the lab workload

```bash
kubectl apply -k manifests/
kubectl -n platform-demo rollout status deployment/platform-demo
kubectl -n platform-demo get pods,service,hpa,pdb
```

The workload uses a public non-root NGINX image only to make the operational controls testable. Replace it with an approved, signed internal image in a real platform.

## Run the health check

```bash
chmod +x scripts/platform-health-check.sh
./scripts/platform-health-check.sh
```

To target a specific context and namespace:

```bash
KUBE_CONTEXT=my-cluster NAMESPACE=platform-demo ./scripts/platform-health-check.sh
```

The script is read-only. It collects evidence and returns a non-zero exit code when it finds failed nodes, unhealthy workloads, unbound persistent volumes or recent warning events.

## OpenShift notes

The standard Kubernetes objects apply to OpenShift, but production adoption should also evaluate:

- Security Context Constraints and namespace service-account permissions
- Routes versus Ingress and the selected ingress controller
- MachineConfig and MachineConfigPool health
- ClusterOperator status and upgradeable conditions
- Operator Lifecycle Manager subscriptions and install plans
- image streams, internal registry policy and trusted registries
- cluster monitoring and user-workload monitoring boundaries

## Operating principle

A restart is not a root-cause analysis. Before deleting pods, draining nodes or restarting operators, capture logs, events, object state, node pressure, recent changes and dependency health. Recovery and diagnosis should be parallel tracks whenever service impact permits.

## Data-safety note

All names, namespaces, addresses and examples are synthetic. No employer manifests, cluster identifiers, production logs or private registry information are included.
