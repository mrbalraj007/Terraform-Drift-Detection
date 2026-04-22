# Pull Request (PR) Template

## 📋 PR Summary

> _Provide a concise, informative title and a short summary (2–3 sentences) of what this PR does and why._

**Title:** <!-- e.g., feat(auth): add Azure OIDC federated identity support -->

**Summary:**
<!--
  What problem does this solve? What value does it add?
  Link to the relevant issue, epic, or feature request.
-->

Closes # <!-- Issue number -->
Related to # <!-- Optional: linked issues/epics -->

---

## 🔍 Type of Change

> _Select all that apply._

| Type | Description |
|------|-------------|
| ☐ `feat` | New feature or capability |
| ☐ `fix` | Bug fix |
| ☐ `hotfix` | Critical production fix |
| ☐ `refactor` | Code restructure without behaviour change |
| ☐ `perf` | Performance improvement |
| ☐ `docs` | Documentation only |
| ☐ `test` | Adding or updating tests |
| ☐ `ci/cd` | Pipeline / workflow changes |
| ☐ `chore` | Dependency updates, config, tooling |
| ☐ `security` | Security fix or hardening |
| ☐ `breaking` | ⚠️ Breaking change — requires migration steps |

---

## 🎯 Scope & Impact

### Services / Components Affected

<!--
  List the services, modules, APIs, or infrastructure components touched.
  Example: Auth Service · GitHub Actions Workflow · Azure Resource Manager
-->

- [ ] Frontend
- [ ] Backend / API
- [ ] Database / Schema
- [ ] Infrastructure / IaC (Terraform / Bicep / ARM)
- [ ] CI/CD Pipeline
- [ ] Security / IAM / Identity
- [ ] Configuration / Secrets
- [ ] Documentation
- [ ] Other: <!-- specify -->

### Blast Radius

> _Estimate the potential impact if this change causes a regression._

| Area | Impact Level | Notes |
|------|-------------|-------|
| Production Traffic | 🔴 High / 🟡 Medium / 🟢 Low | |
| Data Integrity | 🔴 High / 🟡 Medium / 🟢 Low | |
| Security Posture | 🔴 High / 🟡 Medium / 🟢 Low | |
| External Integrations | 🔴 High / 🟡 Medium / 🟢 Low | |

---

## 🛠️ Implementation Details

### What Changed & Why

<!--
  Walk through the key decisions made. Explain the "why", not just the "what".
  Include architecture diagrams, ADR links, or design doc references if relevant.
-->

### Key Design Decisions

<!--
  Were there alternative approaches considered? Why was this approach chosen?
-->

### Dependencies & Prerequisites

<!--
  List any PRs that must be merged first, infra changes required, 
  feature flags to enable, or config values to update.
-->

- [ ] Dependent PR: #
- [ ] Infrastructure provisioned: <!-- Yes / No / N/A -->
- [ ] Feature flag enabled: <!-- Yes / No / N/A -->
- [ ] Configuration / secret updated: <!-- Yes / No / N/A -->

---

## ✅ Testing

### Test Coverage

| Test Type | Status | Notes |
|-----------|--------|-------|
| Unit Tests | ☐ Added ☐ Updated ☐ N/A | |
| Integration Tests | ☐ Added ☐ Updated ☐ N/A | |
| E2E / Regression Tests | ☐ Added ☐ Updated ☐ N/A | |
| Load / Performance Tests | ☐ Added ☐ Updated ☐ N/A | |
| Security / SAST Scan | ☐ Passed ☐ Suppressed (justified) ☐ N/A | |

### How to Test Locally

```bash
# Step-by-step instructions to reproduce and verify the change locally
# e.g.:
# 1. git checkout <branch>
# 2. az login --use-device-code
# 3. terraform plan -var-file=dev.tfvars
```

### Evidence of Testing

<!--
  Attach screenshots, test run logs, Azure portal screenshots,
  pipeline run links, or Postman collection results.
-->

---

## 🔒 Security & Compliance

> _Answer all that apply. If not applicable, mark N/A._

| Checklist Item | Status |
|----------------|--------|
| No secrets, tokens, or credentials committed | ☐ Confirmed / N/A |
| Least-privilege IAM roles / RBAC applied | ☐ Confirmed / N/A |
| Input validation and sanitisation in place | ☐ Confirmed / N/A |
| Sensitive data encrypted at rest and in transit | ☐ Confirmed / N/A |
| Dependencies scanned for known CVEs | ☐ Confirmed / N/A |
| Audit / access logs retained where required | ☐ Confirmed / N/A |
| GDPR / data residency requirements considered | ☐ Confirmed / N/A |
| Pen-test or threat model updated | ☐ Required / Not required |

> ⚠️ **If any security concern is identified**, tag `@security-team` and do **not** merge until resolved.

---

## 🚀 Deployment

### Deployment Strategy

- [ ] Standard deployment (no special steps)
- [ ] Blue/Green deployment
- [ ] Canary rollout — target: `___%` of traffic
- [ ] Feature flag controlled
- [ ] Scheduled maintenance window required
- [ ] Manual approval gate required

### Pre-Deployment Checklist

- [ ] All CI checks green
- [ ] Staging / UAT environment validated
- [ ] Runbook / SOP updated or linked: <!-- URL -->
- [ ] Monitoring & alerting reviewed
- [ ] On-call team notified (if high-risk)

### Rollback Plan

<!--
  How do we revert if this causes issues in production?
  e.g., revert commit hash, feature flag toggle, Terraform state rollback steps.
-->

---

## 📈 Observability

| Concern | Detail |
|---------|--------|
| Metrics | <!-- New or updated dashboards? Datadog / Azure Monitor / Grafana --> |
| Alerts | <!-- New alert rules added or thresholds changed? --> |
| Logs | <!-- Relevant log queries or Kusto queries --> |
| Traces | <!-- Distributed tracing updated? --> |

---

## 📝 Documentation

- [ ] `README.md` updated
- [ ] `CHANGELOG.md` updated
- [ ] Architecture / runbook docs updated: <!-- link -->
- [ ] API docs / OpenAPI spec updated
- [ ] No documentation changes required

---

## 👥 Reviewers

> _Assign at least **two** reviewers. Tag domain owners for cross-cutting changes._

| Role | Reviewer | Required |
|------|----------|----------|
| Tech Lead / Architect | `@` | ✅ Yes |
| Domain Owner | `@` | ✅ Yes |
| Security (if applicable) | `@security-team` | ⚠️ If flagged |
| DevOps / Platform (if infra) | `@` | ⚠️ If infra |
| Product Owner (if UX / behaviour) | `@` | ⚠️ If UX |

---

## 📌 Additional Notes

<!--
  Anything else the reviewer should know?
  Open questions, known limitations, follow-up tickets, TODOs, technical debt introduced.
-->

---

> **Merge Criteria:**
> - All required reviewers approved
> - All CI checks passed
> - No unresolved review comments
> - Security sign-off obtained (if flagged)
> - Deployment checklist complete
