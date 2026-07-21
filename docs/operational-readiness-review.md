# Kubernetes Operational Readiness Review

Use this review before a new production service or a major change is approved. The goal is not paperwork; it is to surface failure modes while they are still inexpensive to fix.

## 1. Ownership and service context

- [ ] Named service owner and operational escalation path
- [ ] Customer journey and critical business functions documented
- [ ] Source repository, deployment pipeline and artifact ownership identified
- [ ] Data classification and regulatory requirements recorded
- [ ] Dependencies and consumers mapped

## 2. Reliability objectives

- [ ] Customer-centred SLIs defined for availability, latency, correctness or freshness
- [ ] SLO target and measurement window approved
- [ ] Error-budget policy states what happens when reliability falls below target
- [ ] Capacity assumptions and expected growth documented
- [ ] Recovery time and recovery point objectives agreed

## 3. Workload resilience

- [ ] At least two replicas where the service requires availability during a single-pod failure
- [ ] Replicas spread across nodes and failure zones
- [ ] PodDisruptionBudget matches real quorum and availability requirements
- [ ] Rolling-update settings avoid unnecessary capacity loss
- [ ] Startup, readiness and liveness probes test distinct conditions
- [ ] Graceful shutdown and termination timing tested
- [ ] Resource requests are based on observed demand
- [ ] Limits are set deliberately and OOM behaviour is understood
- [ ] Autoscaling has realistic minimums, maximums and stabilization windows

## 4. Security

- [ ] Workload runs as non-root and drops unnecessary Linux capabilities
- [ ] Privilege escalation is disabled
- [ ] Read-only root filesystem used where practical
- [ ] Seccomp and applicable OpenShift SCC controls reviewed
- [ ] Service-account token is disabled unless the application needs Kubernetes API access
- [ ] Workload identity or short-lived credentials replace static secrets where supported
- [ ] Namespace uses default-deny network policy with explicit ingress and egress flows
- [ ] Container image is approved, scanned, signed and pinned to an immutable digest
- [ ] Secret rotation and certificate renewal are tested

## 5. Observability

- [ ] Metrics represent customer impact and dependency health
- [ ] Structured logs include request or correlation identifiers without sensitive data
- [ ] Distributed tracing is sampled intentionally and propagates across dependencies
- [ ] Dashboards show traffic, errors, latency and saturation
- [ ] Alerts are actionable, routed to an owner and linked to a runbook
- [ ] Synthetic or end-to-end checks cover the critical path
- [ ] Telemetry volume, retention and cost are understood

## 6. Dependency failure

- [ ] Timeouts are shorter than upstream request deadlines
- [ ] Retries use bounded exponential backoff and jitter
- [ ] Retry amplification has been assessed
- [ ] Circuit breaking, queues or load shedding are used where appropriate
- [ ] DNS, certificate, identity and network failures have been tested
- [ ] Behaviour under database, cache, object-store and message-broker degradation is known

## 7. Delivery and change safety

- [ ] Manifests or Helm charts are version controlled and validated
- [ ] Pipeline uses least-privilege identity and protected environments
- [ ] Deployment includes smoke tests and automated rollback criteria
- [ ] Database and schema changes are backward compatible
- [ ] Feature flags have owners, expiry dates and failure defaults
- [ ] Rollback steps are documented and rehearsed

## 8. Backup and disaster recovery

- [ ] Stateful data is backed up through the owning data service, not assumed to be protected by Kubernetes
- [ ] Restore tests demonstrate usable recovery, not merely successful backup jobs
- [ ] Cluster rebuild dependencies are captured as code
- [ ] Regional or site failure procedure is documented
- [ ] DNS, certificates, secrets and external dependencies are included in recovery planning

## 9. Operations

- [ ] Common incident runbooks exist and commands are safe to paste
- [ ] On-call staff can access required systems through approved paths
- [ ] Maintenance windows and disruption constraints are known
- [ ] Cost ownership and expected monthly run rate are recorded
- [ ] Known risks have explicit owners and target dates

## Decision

Record one of:

- **Ready:** all critical controls satisfied;
- **Conditionally ready:** limited, time-bound exceptions with owners and dates;
- **Not ready:** unresolved risk can materially affect customers, security or recoverability.

An ORR exception is a risk acceptance, not an undocumented omission.
