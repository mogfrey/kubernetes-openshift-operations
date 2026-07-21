#!/usr/bin/env bash
set -uo pipefail

KUBE_CONTEXT="${KUBE_CONTEXT:-}"
NAMESPACE="${NAMESPACE:-}"
MAX_EVENTS="${MAX_EVENTS:-30}"

KUBECTL=(kubectl)
if [[ -n "$KUBE_CONTEXT" ]]; then
  KUBECTL+=(--context "$KUBE_CONTEXT")
fi

failures=0

section() {
  printf '\n==== %s ====\n' "$1"
}

warn() {
  printf 'WARN: %s\n' "$1" >&2
  failures=$((failures + 1))
}

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is not installed or not on PATH." >&2
  exit 2
fi

if ! "${KUBECTL[@]}" version --request-timeout=10s >/dev/null 2>&1; then
  echo "ERROR: Kubernetes API is not reachable with the selected context." >&2
  exit 2
fi

if [[ -n "$KUBE_CONTEXT" ]]; then
  CURRENT_CONTEXT="$KUBE_CONTEXT"
else
  CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || true)
fi

section "Context"
printf 'Context: %s\n' "${CURRENT_CONTEXT:-unknown}"
printf 'Namespace scope: %s\n' "${NAMESPACE:-all namespaces}"

if [[ -n "$NAMESPACE" ]] && ! "${KUBECTL[@]}" get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "ERROR: Namespace '$NAMESPACE' does not exist." >&2
  exit 2
fi

NS_ARGS=(-A)
if [[ -n "$NAMESPACE" ]]; then
  NS_ARGS=(-n "$NAMESPACE")
fi

section "Nodes"
"${KUBECTL[@]}" get nodes -o wide
while IFS=$'\t' read -r node ready; do
  [[ -z "$node" ]] && continue
  if [[ "$ready" != "True" ]]; then
    warn "Node $node is not Ready (Ready=$ready)."
  fi
done < <("${KUBECTL[@]}" get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\n"}{end}')

section "Unhealthy pods"
UNHEALTHY_PODS=$("${KUBECTL[@]}" get pods "${NS_ARGS[@]}" --no-headers 2>/dev/null | awk '$4 != "Running" && $4 != "Completed" {print}' || true)
if [[ -n "$UNHEALTHY_PODS" ]]; then
  printf '%s\n' "$UNHEALTHY_PODS"
  warn "One or more pods are not Running or Completed."
else
  echo "No unhealthy pods found."
fi

section "Deployments with unavailable replicas"
DEPLOYMENT_ISSUES=$("${KUBECTL[@]}" get deployments "${NS_ARGS[@]}" -o jsonpath='{range .items[?(@.status.unavailableReplicas)]}{.metadata.namespace}{"/"}{.metadata.name}{" unavailable="}{.status.unavailableReplicas}{"\n"}{end}' 2>/dev/null || true)
if [[ -n "$DEPLOYMENT_ISSUES" ]]; then
  printf '%s' "$DEPLOYMENT_ISSUES"
  warn "One or more deployments have unavailable replicas."
else
  echo "No deployment availability issues found."
fi

section "Persistent volume claims"
PVC_ISSUES=$("${KUBECTL[@]}" get pvc "${NS_ARGS[@]}" --no-headers 2>/dev/null | awk '$2 != "Bound" {print}' || true)
if [[ -n "$PVC_ISSUES" ]]; then
  printf '%s\n' "$PVC_ISSUES"
  warn "One or more persistent volume claims are not Bound."
else
  echo "No unbound persistent volume claims found."
fi

section "Pod disruption budgets"
"${KUBECTL[@]}" get pdb "${NS_ARGS[@]}" 2>/dev/null || true

section "Recent warning events"
"${KUBECTL[@]}" get events "${NS_ARGS[@]}" \
  --field-selector type=Warning \
  --sort-by='.lastTimestamp' 2>/dev/null | tail -n "$MAX_EVENTS" || true

if "${KUBECTL[@]}" api-resources --api-group=config.openshift.io -o name 2>/dev/null | grep -q '^clusteroperators'; then
  section "OpenShift ClusterOperators"
  "${KUBECTL[@]}" get clusteroperators.config.openshift.io

  OPERATOR_ISSUES=$("${KUBECTL[@]}" get clusteroperators.config.openshift.io -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[?(@.type=="Available")]}{.status}{end}{"\t"}{range .status.conditions[?(@.type=="Degraded")]}{.status}{end}{"\n"}{end}' | awk '$2 != "True" || $3 == "True" {print}' || true)
  if [[ -n "$OPERATOR_ISSUES" ]]; then
    printf '%s\n' "$OPERATOR_ISSUES"
    warn "One or more OpenShift ClusterOperators are unavailable or degraded."
  fi
fi

if "${KUBECTL[@]}" api-resources --api-group=machineconfiguration.openshift.io -o name 2>/dev/null | grep -q '^machineconfigpools'; then
  section "OpenShift MachineConfigPools"
  "${KUBECTL[@]}" get machineconfigpools.machineconfiguration.openshift.io
fi

section "Result"
if (( failures > 0 )); then
  printf 'Health check completed with %d warning condition(s).\n' "$failures"
  exit 1
fi

echo "Health check completed without detected warning conditions."
