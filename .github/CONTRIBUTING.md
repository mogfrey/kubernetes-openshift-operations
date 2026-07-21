# Contributing

This repository contains public, production-inspired Kubernetes and OpenShift examples. Contributions must stay synthetic and must not include real cluster exports, registry names, credentials, incident evidence or internal topology.

## Design expectations

- Prefer restricted security contexts and explicit service-account permissions.
- Preserve evidence before proposing disruptive recovery steps.
- Document customer impact, rollback and verification—not only the command that changes state.
- Treat PodDisruptionBudgets, topology, probes and resource settings as workload-specific decisions.

## Validation

```bash
bash -n scripts/platform-health-check.sh
kubectl apply --dry-run=client -k manifests/
```

Use a disposable cluster before applying changes. Never test an unreviewed operational procedure directly in production.
