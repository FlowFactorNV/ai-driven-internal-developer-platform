---
title: "Building an AI-driven Internal Developer Platform (1/6): Why, and what was built"
series: "Building an AI-driven Internal Developer Platform"
part: 1
---

# Why an Internal Developer Platform, and what it actually does

Ask a developer to ship a service to Kubernetes and watch what happens. They write a Dockerfile - hopefully multi-stage, hopefully non-root. They write a CI pipeline to build and push it. They write a Deployment, a Service, an Ingress, a NetworkPolicy, a ServiceAccount. They wire up TLS, figure out the registry pull secret, pick resource limits out of the air, and try to remember whether `readOnlyRootFilesystem` was the thing that broke the last app or fixed it.

None of that is the developer's actual job. It's the tax they pay to get their code running. Multiply it across a team and you get copy-pasted YAML, drifting security baselines, and a lot of "works on my cluster."

This series is about the platform our intern Nand Beeckx built during his internship at FlowFactor to remove that tax - an **Internal Developer Platform (IDP)** with a twist: the developer never writes any of that YAML, and they don't fill out a form either. They have a conversation. An AI agent takes a repository URL and drives the whole thing to a live, hardened, GitOps-managed deployment.

Over the next six posts we'll take the platform apart layer by layer. This first one is the map: what it does, how the pieces fit, and the decisions that shaped it.

> **A note on scope.** This platform ran on a specific OVH Cloud + GitLab setup that is now decommissioned, and the source we reference is published as a **showcase repository** - read it to follow the architecture and the decisions, not as a copy-paste deploy.

## The goal: a golden path, not a form

The target experience was deliberately blunt: **give the platform a Git repository, get back a running application** - behind TLS, behind SSO, monitored, network-isolated, built from a hardened image, and reconciled continuously so it stays that way.

The industry term for this is a *golden path*: the paved, opinionated route from code to production that handles the boring-but-critical parts for you. The opinion matters as much as the paving. A golden path isn't "here are 40 knobs" - it's "here is the one correct shape, and the security-critical parts are not yours to change."

The twist that was added is the interface. Most IDPs give you a web portal or a CLI. Here we have a conversational **multi-agent AI system** in front, so onboarding an app feels like asking a colleague to set it up - while the guardrails underneath make sure that colleague can't do anything dangerous.

## The mental model: two planes and a contract

The easiest way to hold the whole system in your head is as **two planes plus a contract between them**:

- **The platform plane** - the Kubernetes cluster and everything running on it. *What exists.*
- **The control plane** - the AI agents that drive deployments. *How you ask for things.*
- **The golden path** - a template library that defines the one valid shape an app may take. *The contract the control plane must honour and the platform enforces.*

That split maps directly onto the four parts of the codebase:

| Layer | Directory | Role |
|-------|-----------|------|
| Foundation | `infrastructure/` | Terraform provisions the OVH Managed Kubernetes cluster and bootstraps GitOps. |
| Platform services | `gitops/` | An ArgoCD "app-of-apps" continuously syncs the registry, quality gate, observability, SSO, TLS, and the AI agents' backends. |
| Golden path | `templates/` | Hardened Dockerfiles, a CI template, and manifest templates - with an annotation system that lets an AI fill the blanks without touching the security-critical lines. |
| Control plane | `orchestrator/` | A Google ADK orchestrator agent that drives an 8-step workflow, delegating to GitLab and Kubernetes specialist agents. |

Here's how a single deployment travels through them:

```
Developer ── "here's my repo URL"
    │
    ▼
Control plane (orchestrator + GitLab/Kubernetes agents)
    │  pulls a template, fills the blanks
    ▼
Golden path (templates)
    │  branch + merge request on the developer's repo
    ▼
Platform plane (OVH Kubernetes: CI → Harbor → ArgoCD → live)
    │
    ▼
Live app - TLS, SSO, monitored, isolated
```

Concretely, the orchestrator analyses the repo, fetches the matching template, and fills in its placeholders. It opens a **merge request** on the developer's *own* repository (never a push to `main`, never a new repo) so a human approves the change. On merge, the generated pipeline builds the image with Kaniko, runs a SonarQube quality gate, and pushes to a private Harbor registry. Then an ArgoCD Application is created and the cluster reconciles the workload into existence - behind ingress, automatic Let's Encrypt TLS, and group-scoped SSO.

A detail that's easy to miss but holds the whole thing together: the AI agents can only act because the tools they call - the MCP servers for GitLab and Kubernetes - run *on the platform* that the lower layers provision. The control plane is a tenant of the platform plane, not a thing bolted on beside it.

## What "done" looks like

The proof that a platform like this works isn't a diagram - it's the artifact it produces without a human touching it. When the platform deploys an app, the Deployment it generates looks like this (abridged):

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
```

No developer asked for that. They asked to deploy a small web app. The hardening came for free, because the golden path makes "secure" the default shape and the only shape. That's the entire point: the safe way and the easy way are the same way.


## What's coming

1. **This post** - why an IDP, and the architecture map.
2. **From zero to a cluster** - OVH Managed Kubernetes with Terraform, isolated node pools, and a zero-trust network.
3. **GitOps bootstrap** - ArgoCD app-of-apps, and keeping secrets out of Git.
4. **Platform services** - Harbor, SonarQube, Prometheus/Grafana, SSO and automatic TLS.
5. **The golden path** - templating Dockerfiles, pipelines and manifests, and the annotation system that lets an AI edit them safely.
6. **The AI control plane** - Google ADK, multi-agent delegation, and guardrails written in English.

The full source is on GitHub, one directory per layer. In the next post we start at the bottom: turning an empty OVH account into a Kubernetes cluster that's ready to host a platform.
