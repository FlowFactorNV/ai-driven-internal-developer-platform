# AI-driven Internal Developer Platform

> ### ⚠️ Showcase repository - not a copy-paste deploy
> This is the companion source for a FlowFactor blog series on building an AI-driven Internal Developer Platform (IDP). It was built for a specific **OVH Cloud + GitLab** environment that has since been **decommissioned**, and it hard-codes assumptions about that setup (OVH Managed Kubernetes, a private GitLab group, a self-hosted Harbor registry, and DNS). Internal and personal identifiers have been replaced with neutral placeholders such as `example.com`, `your-org`, and `<CLUSTER_IP>`.
>
> Read it to understand the **architecture and the decisions behind it** - do not expect `terraform apply` or `kubectl apply` to work unmodified against your own environment.

---

## What this is

An Internal Developer Platform that takes a developer's Git repository all the way to a live, GitOps-managed workload on Kubernetes - driven by a conversational **AI multi-agent control plane**. A developer gives the platform a repo URL; the platform analyses it, generates hardened, security-baselined deployment assets from golden-path templates, opens a merge request on the developer's own repo, builds and scans the image, and reconciles it onto the cluster through GitOps - behind automatic TLS and SSO.

The system is organised as **two planes plus a contract between them**:

- **Control plane** - how you ask for things: an AI agent system ([`orchestrator/`](orchestrator/)).
- **Platform plane** - what exists and runs: the cluster and its services ([`infrastructure/`](infrastructure/) + [`gitops/`](gitops/)).
- **Golden path** - the contract between them: a template library that defines the *only* shape a deployed app may take ([`templates/`](templates/)).

## Architecture at a glance

```
                       Developer ── "here's my repo URL"
                           │
                           ▼
        ┌──────────────────────────────────────────────┐
        │  CONTROL PLANE  -  orchestrator/ (Google ADK) │
        │  orchestrator → gitlab_agent / kubernetes_agent│
        └───────┬──────────────────────────────┬────────┘
                │ fills templates               │ applies manifests
                ▼                               │
        ┌──────────────────────┐               │
        │  GOLDEN PATH          │               │
        │  templates/           │  the contract │
        │  [AGENT-LOCK]/[EDIT]  │               │
        └───────┬──────────────┘               │
                │ branch + merge request        │
                ▼                               ▼
        ┌──────────────────────────────────────────────┐
        │  PLATFORM PLANE  -  OVH Managed Kubernetes     │
        │  infrastructure/ provisions it (Terraform)     │
        │  gitops/ defines it (ArgoCD app-of-apps):      │
        │  ArgoCD · Harbor · SonarQube · Prometheus/     │
        │  Grafana · cert-manager · oauth2-proxy · MCP   │
        └──────────────────────────────────────────────┘
                           │ GitOps reconcile
                           ▼
                   Live app (TLS + SSO + monitored)
```

The AI agents can only act because the **MCP servers they call run on the platform** that `infrastructure/` provisions and `gitops/` defines.

## The four layers

| Directory | Original repo | Role |
|-----------|---------------|------|
| [`infrastructure/`](infrastructure/) | `ovh-cicd` | **Foundation.** Terraform provisions the OVH Managed Kubernetes cluster (isolated, tainted node pools; private network) and the GitLab pipeline bootstraps ArgoCD. |
| [`gitops/`](gitops/) | `cluster_infrastructure` | **Platform services (GitOps desired state).** An ArgoCD app-of-apps continuously syncs Harbor, SonarQube, Prometheus/Grafana, oauth2-proxy, cert-manager, and the GitLab/Kubernetes MCP servers. |
| [`templates/`](templates/) | `idp-dockerfile-templates` | **Golden path.** Hardened, non-root Dockerfiles per language, a generic CI template, and manifest templates - with the `[AGENT-LOCK]`/`[AGENT-EDIT]` annotation system that lets an LLM fill blanks without touching security-critical lines. |
| [`orchestrator/`](orchestrator/) | `adk` | **AI control plane.** A Google ADK orchestrator agent driving an 8-step workflow, delegating over A2A to GitLab and Kubernetes sub-agents that talk to on-cluster MCP servers over SSE. |

A single deployment flows through them in that order; see each directory's README for detail, and [`docs/blog-series-outline.md`](docs/blog-series-outline.md) for the narrative.

## How a deployment flows

1. A developer gives the orchestrator a repo URL.
2. The orchestrator pulls the matching template from `templates/` and fills its `[AGENT-EDIT]` placeholders.
3. Via the GitLab agent it commits them to a branch (`deploy/<app>-<session_id>`) on the developer's **existing** repo and opens a **merge request** (the human approval gate).
4. On merge, the template's CI builds the image with Kaniko, runs the SonarQube quality gate, and pushes to Harbor.
5. Via the Kubernetes agent the manifests are applied and an ArgoCD Application is created; ArgoCD reconciles it.
6. The app goes live behind ingress + automatic TLS (cert-manager) + SSO (oauth2-proxy), monitored by Prometheus/Grafana.

## Example target applications (not included)

The platform was demonstrated against several **third-party sample applications** used purely as deployment targets. They are **not included in this repository** to keep it free of third-party code and licensing concerns. They were, for example, Google's `golang/example`, an open-source Node.js game, a Spring Boot "hello world", and a small Python game. The blog series links to their upstreams; what you can inspect here instead are the hardened deployment assets the platform *generates* for such apps (see `templates/`).

## Prerequisites (for context - the environment is decommissioned)

Reproducing this would require a paid **OVH Cloud** account, a **GitLab** group with CI runners, a **Gemini API key**, and **DNS** for the ingress hostnames. This repository is meant to be read, not run end-to-end.

## Documentation

- Per-layer detail: the `README.md` in each directory.
- Blog series outline: [`docs/blog-series-outline.md`](docs/blog-series-outline.md).

## Credits & license

Built as a FlowFactor internship project. Licensed under the terms in [`LICENSE`](LICENSE).
