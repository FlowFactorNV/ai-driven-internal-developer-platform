# AI-driven Internal Developer Platform

> ### ⚠️ Showcase repository - not a copy-paste deploy
> This is the companion source for a [FlowFactor](https://flowfactor.be) blog series on building an AI-driven Internal Developer Platform (IDP) on OVHcloud. It was built for a specific **OVH Cloud + GitLab** environment that has since been **decommissioned**, and it hard-codes assumptions about that setup (OVH Managed Kubernetes, a private GitLab group, a self-hosted Harbor registry, and DNS). Internal and personal identifiers have been replaced with neutral placeholders such as `example.com`, `your-org`, and `<CLUSTER_IP>`.
>
> Read it to understand the **architecture and the decisions behind it** - do not expect `terraform apply` or `kubectl apply` to work unmodified against your own environment.

---

## What this is

An AI-driven Internal Developer Platform (IDP) on **OVHcloud Managed Kubernetes**, built by FlowFactor as an experiment in AI platform engineering. It takes a developer's Git repository to a GitOps-managed workload on Kubernetes, guided by a conversational **AI multi-agent control plane** built with Google ADK. A developer gives the platform a repo URL; the agents analyse it, fill hardened, security-baselined deployment templates from the golden path, and open a merge request on the developer's own repo for review. After the merge, CI builds and analyses the image, and Argo CD reconciles the application onto the cluster.

**Stack:** OVHcloud Managed Kubernetes · Terraform · GitLab CI · Argo CD (app of apps) · Harbor · SonarQube · Prometheus/Grafana · cert-manager · oauth2-proxy · Google ADK agents (Gemini) · A2A · MCP servers.

The system is organised as **two planes plus a contract between them**:

- **Control plane** - how you ask for things: an AI agent system ([`orchestrator/`](orchestrator/)).
- **Platform plane** - what exists and runs: the cluster and its services ([`infrastructure/`](infrastructure/) + [`gitops/`](gitops/)).
- **Golden path** - the contract between them: a template library that defines the supported shape of a deployed app ([`templates/`](templates/)).

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
                   Live app (GitOps-managed)
```

The AI agents can only act because the **MCP servers they call run on the platform** that `infrastructure/` provisions and `gitops/` defines.

## The four layers

| Directory | Original repo | Role |
|-----------|---------------|------|
| [`infrastructure/`](infrastructure/) | `ovh-cicd` | **Foundation.** Terraform provisions the OVH Managed Kubernetes cluster (isolated, tainted node pools; private network) and the GitLab pipeline bootstraps ArgoCD. |
| [`gitops/`](gitops/) | `cluster_infrastructure` | **Platform services (GitOps desired state).** An ArgoCD app-of-apps continuously syncs Harbor, SonarQube, Prometheus/Grafana, oauth2-proxy, cert-manager, and the GitLab/Kubernetes MCP servers. |
| [`templates/`](templates/) | `idp-dockerfile-templates` | **Golden path.** Hardened, non-root Dockerfiles per language, a generic CI template, and manifest templates - with the `[AGENT-LOCK]`/`[AGENT-EDIT]` annotation system that tells the agent which placeholders to fill and which security-critical lines to preserve. The annotations guide the agent; they are not a technical enforcement mechanism. |
| [`orchestrator/`](orchestrator/) | `adk` | **AI control plane.** A Google ADK orchestrator agent driving an 8-step workflow, delegating over A2A to GitLab and Kubernetes sub-agents that talk to on-cluster MCP servers over SSE. |

A single deployment flows through them in that order; see each directory's README for detail.

## How a deployment flows

1. A developer gives the orchestrator a repo URL.
2. The agents analyse the repo, pull the matching templates from `templates/` and fill their `[AGENT-EDIT]` placeholders.
3. Via the GitLab agent it commits them to a branch (`deploy/<app>-<session_id>`) on the developer's **existing** repo and opens a **merge request** (the human approval gate).
4. On merge, the template's CI runs the SonarQube analysis, builds the image with Docker-in-Docker and pushes it to Harbor (short-SHA tag plus `latest`).
5. Via the Kubernetes agent the namespace is applied and an ArgoCD Application is created that points at the app repo's `manifests/`; ArgoCD reconciles it.
6. The app runs behind the platform's ingress controller. Platform UIs use cert-manager for TLS, oauth2-proxy provides GitLab SSO for the agent interface, and Prometheus/Grafana monitor the platform.

## Example target applications (not included)

The platform was demonstrated against several **third-party sample applications** used purely as deployment targets. They are **not included in this repository** to keep it free of third-party code and licensing concerns. They were, for example, Google's `golang/example`, an open-source Node.js game, a Spring Boot "hello world", and a small Python game. What you can inspect here instead are the hardened deployment assets the platform *generates* for such apps (see `templates/`).

## Prerequisites (for context - the environment is decommissioned)

Reproducing this would require a paid **OVH Cloud** account, a **GitLab** group with CI runners, a **Gemini API key**, and **DNS** for the ingress hostnames. This repository is meant to be read, not run end-to-end.

## Known limitations

- This is a proof of concept: the platform code has no automated test suite.
- The AI layer is non-deterministic. Much of the workflow logic lives in natural-language agent instructions, which guide the agents but do not execute like program logic.
- The implementation is tied to a specific OVHcloud, GitLab and Gemini setup.

## Documentation

- Per-layer detail: the `README.md` in each directory.
- The accompanying six-part blog series will be published on [flowfactor.be/insights](https://flowfactor.be/insights).

## About FlowFactor

[FlowFactor](https://flowfactor.be) is a Belgian DevOps consultancy for everything between code and production: platform engineering, CI/CD, Kubernetes and cloud, from audits and implementation to managed services. We built this platform to explore where AI fits in platform engineering.

Thinking about a platform like this for your teams? [Get in touch](https://flowfactor.be/contact).

## License

Built by FlowFactor. Licensed under the terms in [`LICENSE`](LICENSE).
