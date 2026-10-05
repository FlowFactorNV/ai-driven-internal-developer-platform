# Blog series outline - "Building an AI-driven Internal Developer Platform"

A 6–7 post series, roughly one post per layer, published over ~2 months. Each post is standalone-readable and ends with an honest "what was hard / what we'd change" section. The companion source is this repository.

**Framing:** this is an *architecture-and-decisions* narrative, not a copy-paste tutorial. The platform ran on a now-decommissioned OVH + GitLab setup, so posts should narrate decisions and show real outputs rather than promise a reproducible deploy. Credit the team per FlowFactor's convention.

**Narrative order follows the dependency chain:** `infrastructure` → `gitops` → `templates` → `orchestrator` → demo.

---

## Post 1 - Why an IDP, and what we set out to build
- The golden-path problem: developers shouldn't hand-write Kubernetes YAML.
- Target experience: "give me a repo, get a live, hardened app."
- The mental model: two planes (control + platform) plus the golden-path contract.
- Full architecture map and the four-layer repo layout.
- **Show:** the architecture diagram; a teaser of the end-to-end demo.

## Post 2 - From zero to a cluster: OVH Managed Kubernetes with Terraform
- `infrastructure/` - provisioning the cluster with the OVH Terraform provider.
- The two-phase state strategy (local bootstrap bucket → remote S3 backend) and why.
- Isolated, tainted node pools (general / CI runners / Harbor / SonarQube) to beat the "noisy neighbour" problem.
- Zero-trust networking: private network, NAT gateway, no public node IPs.
- The `fmt → validate → plan → apply` pipeline with a manual approval gate.
- **Show:** Terraform snippets; the pipeline stages.

## Post 3 - GitOps bootstrap: ArgoCD app-of-apps and secret injection
- `gitops/` - the app-of-apps pattern with `recurse`, `prune`, `selfHeal`.
- Bootstrapping ArgoCD from the infrastructure pipeline.
- Keeping secrets out of Git and Terraform state: injecting them from masked CI variables into Kubernetes Secrets at bootstrap.
- **Show:** the root app tree; the secret-injection flow.

## Post 4 - Platform services: registry, quality gates and observability
- Harbor (private registry + Trivy scanning), SonarQube + Postgres, kube-prometheus-stack (Grafana + Alertmanager → Slack).
- oauth2-proxy group-scoped SSO + cert-manager automatic TLS.
- Least-privilege RBAC for the MCP service account.
- **Show:** the read-only MCP cluster role; a Grafana panel; the Alertmanager routing.

## Post 5 - The golden path: templating Dockerfiles, pipelines and manifests
- `templates/` - multi-stage, non-root, security-baselined Dockerfiles per language.
- The generic CI template: Kaniko build → SonarQube gate → Harbor push → idempotent pull-secret.
- The `[AGENT-LOCK]` / `[AGENT-EDIT]` annotation system: how to let an LLM fill blanks *safely* without touching security-critical lines.
- **Show:** a template before/after the agent fills it.

## Post 6 - An AI control plane with Google ADK: multi-agent orchestration over MCP
- `orchestrator/` - the orchestrator agent and its strict 8-step workflow.
- Delegation over A2A to silent GitLab and Kubernetes sub-agents, each talking to an on-cluster MCP server over SSE.
- Guardrails expressed in natural language (no root, branch + MR only, namespace-scoped) - "the product logic is a prompt," and where that's fragile.
- **Show:** the workflow; a real orchestration transcript.

## Post 7 - End-to-end demo + honest retrospective
- Deploy a sample app from repo URL to live workload; show the generated, hardened `deployment.yaml` (`runAsNonRoot`, `readOnlyRootFilesystem`, `drop: ALL`) as proof it works.
- Honest lessons: LLM non-determinism, human-in-the-loop MR approval, the absence of automated tests, and what we'd do differently.
- **Show:** the generated manifests; the ArgoCD "Synced + Healthy" state.

---

## Pre-publish checklist (status)

- [x] Merge the four repos into one monorepo (`infrastructure` / `gitops` / `templates` / `orchestrator`).
- [x] Scrub internal & personal identifiers (domain, ACME email, GitLab group, username, Slack channel, cluster IPs → placeholders).
- [x] Fix code bugs (template `<INSERT_IMAGE_NAME>` typo; duplicated `IMAGE_TAG`/`LATEST_TAG`; `HARBOR_ROBOT_PASS` naming).
- [x] Fix doc/code drift (branch+MR vs new-repo; cert-manager installed; Harbor vs GitLab registry; SSE vs stdio; phantom files removed).
- [x] Exclude third-party test repos; reference them instead.
- [x] Add the "showcase, not a deploy" disclaimer to the root README and each layer.
- [x] Add `LICENSE`, root `.gitignore`, and this outline.
- [ ] Confirm the license choice with whoever owns FlowFactor's OSS policy.
- [ ] Final human read-through before pushing to the public GitHub repo.
