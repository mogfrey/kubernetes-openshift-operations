# Runbook: CrashLoopBackOff

## Trigger

A pod repeatedly starts and exits, and Kubernetes reports `CrashLoopBackOff`.

## First objective

Determine whether the failure is caused by the application, configuration, dependency, resource pressure, security policy or the platform. Do not delete the pod before collecting the previous container logs and object state.

## Evidence collection

```bash
NS=example
POD=example-pod

kubectl -n "$NS" get pod "$POD" -o wide
kubectl -n "$NS" describe pod "$POD"
kubectl -n "$NS" logs "$POD" --all-containers --timestamps
kubectl -n "$NS" logs "$POD" --all-containers --previous --timestamps
kubectl -n "$NS" get events --field-selector involvedObject.name="$POD" --sort-by='.lastTimestamp'
kubectl -n "$NS" get pod "$POD" -o yaml
```

Record the owning workload and rollout history:

```bash
kubectl -n "$NS" get pod "$POD" -o jsonpath='{.metadata.ownerReferences[0].kind}{"/"}{.metadata.ownerReferences[0].name}{"\n"}'
kubectl -n "$NS" rollout history deployment/<deployment-name>
```

## Decision path

### Exit code and reason

Inspect `lastState.terminated`:

```bash
kubectl -n "$NS" get pod "$POD" -o jsonpath='{range .status.containerStatuses[*]}{.name}{" reason="}{.lastState.terminated.reason}{" exit="}{.lastState.terminated.exitCode}{" signal="}{.lastState.terminated.signal}{"\n"}{end}'
```

Common interpretations:

- `OOMKilled`: memory limit or memory-growth problem;
- exit code `1`: application or configuration failure;
- exit code `126` or `127`: permission, entrypoint or missing executable;
- exit code `137`: SIGKILL, commonly OOM or forced termination;
- probe failures: application may be healthy eventually but probes are too aggressive, or it cannot serve the probe path.

### Configuration

Compare the pod template with its ConfigMaps, Secrets and environment sources. Confirm that referenced keys exist, projected files have the expected mode and the application is reading the intended path.

Do not print Secret values into tickets or public terminals. Verify key names and metadata unless an approved secure process allows content inspection.

### Dependencies

From a temporary diagnostic pod in the same namespace and network-policy context, test DNS, TCP and TLS separately:

```bash
kubectl -n "$NS" run netcheck --rm -it --restart=Never --image=curlimages/curl -- sh
nslookup dependency.example.svc.cluster.local
curl -vk --connect-timeout 5 https://dependency.example.svc.cluster.local:443/health
```

### Resources and node pressure

```bash
kubectl top pod -n "$NS" "$POD" --containers
kubectl describe node <node-name>
kubectl get node <node-name> -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{" "}{.reason}{"\n"}{end}'
```

### Security controls

Check Pod Security admission, OpenShift Security Context Constraints, seccomp, read-only filesystem, capabilities, SELinux denials and volume permissions. A deployment may work in a permissive test namespace and fail under a restricted production policy.

## Recovery options

Choose the least destructive option that addresses the proven cause:

1. correct a bad ConfigMap, Secret reference or deployment value;
2. roll back a failed release;
3. adjust probes based on measured startup behaviour;
4. fix dependency routing, DNS, certificate or authorization;
5. correct resource requests/limits after confirming resource pressure;
6. replace a failed node only after capturing node evidence.

A pod deletion is acceptable to restore service only when the controller will recreate it safely and evidence has already been captured. It is not a root-cause fix.

## Verification

```bash
kubectl -n "$NS" rollout status deployment/<deployment-name>
kubectl -n "$NS" get pods -w
kubectl -n "$NS" get events --sort-by='.lastTimestamp' | tail -n 30
```

Confirm the service-level signal—successful requests, latency and error rate—not merely pod state.
