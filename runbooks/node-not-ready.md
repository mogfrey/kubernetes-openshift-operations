# Runbook: NodeNotReady

## Trigger

A Kubernetes or OpenShift node reports `NotReady`, workloads are being evicted, or scheduling capacity has unexpectedly reduced.

## Safety rule

Do not reboot, drain or delete the node before capturing node conditions, events, kubelet/runtime state and infrastructure reachability. Those actions can remove the evidence needed to distinguish platform, operating-system, network and storage failures.

## Determine scope

```bash
kubectl get nodes -o wide
kubectl get pods -A --field-selector spec.nodeName=<node-name> -o wide
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -n 100
```

Questions:

- Is one node affected or an entire zone/pool?
- Is the API reachable from healthy nodes?
- Did a machine configuration, image, certificate, CNI or storage change occur?
- Is capacity still sufficient to protect service SLOs and disruption budgets?

## Capture Kubernetes evidence

```bash
NODE=<node-name>

kubectl describe node "$NODE"
kubectl get node "$NODE" -o yaml
kubectl get pods -A --field-selector spec.nodeName="$NODE" -o wide
kubectl get events -A --field-selector involvedObject.kind=Node,involvedObject.name="$NODE" --sort-by='.lastTimestamp'
```

Review these node conditions:

- `Ready`
- `MemoryPressure`
- `DiskPressure`
- `PIDPressure`
- `NetworkUnavailable`

Check taints and lease freshness:

```bash
kubectl get node "$NODE" -o jsonpath='{.spec.taints}{"\n"}'
kubectl get lease -n kube-node-lease "$NODE" -o yaml
```

## Capture host evidence

Use the approved access mechanism for the environment. On a systemd-based node:

```bash
sudo systemctl status kubelet --no-pager
sudo journalctl -u kubelet --since '-30 minutes' --no-pager
sudo crictl info
sudo crictl ps -a
sudo df -hT
sudo df -ih
sudo free -m
sudo ss -s
sudo ip route
sudo resolvectl status 2>/dev/null || cat /etc/resolv.conf
```

For OpenShift, prefer an approved debug session when direct SSH is not part of the support model:

```bash
oc debug node/<node-name>
chroot /host
journalctl -u kubelet --since '-30 minutes'
```

## Common fault domains

### Kubelet or container runtime

Look for certificate errors, cgroup failures, image-filesystem exhaustion, runtime socket errors and repeated kubelet restarts.

### Network and CNI

Check node routes, MTU, CNI daemon pods, overlay connectivity, API-server reachability and DNS. A node can remain powered on while losing the network paths required for heartbeats.

### Disk and inode pressure

Inspect container storage, logs and ephemeral volumes. Cleaning files without understanding their owner may restore space but destroy evidence or break the runtime.

### Cloud or virtualization layer

Confirm instance health, hypervisor events, security-group or NSG changes, route changes, NIC state and zone-wide incidents.

### OpenShift machine configuration

```bash
oc get machineconfigpools
oc describe machineconfigpool <pool>
oc get clusteroperators
```

A degraded MachineConfigPool or pending reboot can explain coordinated node issues.

## Recovery decision

### Cordon

Cordon when the node should receive no new workloads while diagnosis continues:

```bash
kubectl cordon "$NODE"
```

### Drain

Drain only after checking disruption budgets, local storage, daemonsets and remaining cluster capacity:

```bash
kubectl get pdb -A
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=15m
```

Do not use `--force` or disable eviction casually. Escalate when a workload lacks a controller or a PDB blocks safe maintenance.

### Reboot or replace

Reboot only after evidence collection and after confirming the issue is host-local. Replace the node when immutable infrastructure makes replacement safer and faster than repair.

## Verification

```bash
kubectl get node "$NODE" -w
kubectl get pods -A --field-selector spec.nodeName="$NODE" -o wide
kubectl get events -A --sort-by='.lastTimestamp' | tail -n 50
```

Confirm workload availability, scheduling headroom and service SLOs before uncordoning:

```bash
kubectl uncordon "$NODE"
```
