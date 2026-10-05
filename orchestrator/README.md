# ADK Platform Orchestrator

An AI-powered control plane for an **Internal Developer Platform (IDP)**, built with the [Google Agent Development Kit (ADK)](https://google.github.io/adk-docs/). It automates the full lifecycle of deploying a containerised application - from repository analysis to a live, GitOps-managed workload on Kubernetes - through a conversational, multi-agent architecture.

> This directory is the **control plane**. It assumes the platform it drives already exists: the OVH Kubernetes cluster (`../infrastructure`), the GitOps-managed services including the MCP servers (`../gitops`), and the golden-path templates (`../templates`). See the repository root `README.md` for the full picture and the "showcase, not a copy-paste deploy" disclaimer.

---

## Table of contents

- [Overview](#overview)
- [Architecture](#architecture)
  - [Agent hierarchy](#agent-hierarchy)
  - [Technology stack](#technology-stack)
- [Deployment workflow](#deployment-workflow)
- [Project structure](#project-structure)
- [Agents in detail](#agents-in-detail)
- [Platform infrastructure](#platform-infrastructure)
- [Security & guardrails](#security--guardrails)
- [Running it](#running-it)
- [Resource tiers](#resource-tiers)

---

## Overview

Developers interact with a single **orchestrator agent** in natural language. Behind the scenes the orchestrator silently coordinates two specialist sub-agents - one for **GitLab** operations and one for **Kubernetes** cluster management - to:

1. Analyse a developer's source repository and detect the tech stack.
2. Fetch the matching golden-path templates (Dockerfile, CI pipeline, manifests) and fill in their `[AGENT-EDIT]` placeholders.
3. Commit those files to a **new branch (`deploy/<app_name>-<session_id>`) on the developer's existing repository** and open a **merge request** - the developer's original files are never modified, and nothing is pushed to the default branch directly.
4. After the merge builds and pushes the image to Harbor, generate and apply an **ArgoCD Application** for continuous GitOps delivery.

The entire process is guardrailed with strict policies: no root containers, no plaintext secrets, no modification of the developer's existing files, and no out-of-scope cluster changes.

---

## Architecture

### Agent hierarchy

```
┌──────────────────────────────────────────────┐
│                Developer (user)               │
└──────────────────┬────────────────────────────┘
                   │  natural language
                   ▼
┌──────────────────────────────────────────────┐
│             Orchestrator agent                │
│  - Gemini Flash (latest)                      │
│  - Drives the 8-step deployment workflow      │
│  - The ONLY agent that speaks to the user     │
│  - Delegates over A2A (HTTP)                  │
└───────┬────────────────────────┬──────────────┘
        │  A2A (HTTP)             │  A2A (HTTP)
        ▼                         ▼
┌───────────────┐        ┌────────────────────┐
│ GitLab agent  │        │ Kubernetes agent   │
│ (sub-agent)   │        │ (sub-agent)        │
│  │ SSE        │        │  │ SSE             │
│  ▼            │        │  ▼                 │
│ gitlab-mcp    │        │ kubernetes-mcp     │
│ (on-cluster)  │        │ (on-cluster)       │
└───────────────┘        └────────────────────┘
```

Sub-agents are discovered through Kubernetes DNS (`*-agent-svc.adk-platform.svc.cluster.local`) and each connects to its Model Context Protocol (MCP) server - deployed on the cluster (see `../gitops/manifests/`) - over **Server-Sent Events (SSE)**. SSE is why the MCP servers are dockerised and run in-cluster rather than spawned as local processes.

### Technology stack

| Layer              | Technology                                                            |
|--------------------|----------------------------------------------------------------------|
| Agent framework    | [Google ADK](https://google.github.io/adk-docs/) (Python)            |
| LLM                | Gemini Flash (latest)                                                 |
| Tool protocol      | [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) over SSE |
| Inter-agent comms  | Agent-to-Agent (A2A) over HTTP                                        |
| GitLab integration | `gitlab-mcp-server` (deployed on-cluster, see `../gitops`)            |
| K8s integration    | `kubernetes-mcp-server` (deployed on-cluster, RBAC-scoped)           |
| Container registry | Harbor (private, self-hosted)                                        |
| GitOps             | ArgoCD                                                                |
| Ingress / TLS      | ingress-nginx + cert-manager (Let's Encrypt)                         |
| Cloud provider     | OVH Cloud (Managed Kubernetes)                                        |

---

## Deployment workflow

The orchestrator enforces a strict **8-step sequential workflow**. Every step has explicit success conditions and failure paths - the agent never skips ahead.

```
Step 1 - Greeting & repository intake
  │      Ask for the developer's GitLab repository URL.
  │      Validate it belongs to the authorised group.
  ▼
Step 2 - Repository analysis
  │      Delegate to the GitLab agent to inspect the repo.
  │      Identify tech stack, ports, existing Dockerfiles.
  ▼
Step 3 - Requirements gathering
  │      Collect: namespace, service account, resource tier (S/M/L),
  │      ingress requirements (hostname, TLS).
  ▼
Step 4 - Branch & merge request on the developer's repo
  │      Fetch Dockerfile + CI templates, fill [AGENT-EDIT] placeholders,
  │      commit to branch deploy/<app>-<session_id> on the SAME repo,
  │      and open a merge request against the default branch.
  ▼
Step 5 - Wait for pipeline success
  │      After the developer merges, the CI builds the image with Kaniko,
  │      runs the SonarQube gate, and pushes to Harbor. Poll until green.
  ▼
Step 6 - Manifest generation & push
  │      Generate Namespace, Deployment, Service, NetworkPolicy,
  │      (optional) Ingress manifests; create the namespace on the cluster;
  │      push the filled manifests to the branch.
  ▼
Step 7 - ArgoCD bootstrap
  │      Generate & apply an ArgoCD Application manifest.
  │      Poll until Synced + Healthy (timeout: 3 min).
  ▼
Step 8 - Completion summary
         Present deployment details: branch/MR, namespace, resource tier,
         ingress hostname, ArgoCD status, and a scoped kubeconfig.
```

---

## Project structure

```
orchestrator/
├── README.md
├── requirements.txt
├── .gitlab-ci.yml                 # Builds the 3 agent images (Kaniko) → Harbor
├── .dockerignore
├── .gitignore
│
├── orchestrator_agent/
│   └── __init__.py                # Lead agent: system instructions + 8-step workflow
│
├── gitlab_agent/
│   ├── __init__.py                # GitLab sub-agent: MCP (SSE) toolset + instructions
│   └── agent.json                 # A2A agent card
│
├── kubernetes_agent/
│   ├── __init__.py                # Kubernetes sub-agent: MCP (SSE) toolset + instructions
│   └── agent.json                 # A2A agent card
│
├── docker/
│   ├── Dockerfile.orchestrator
│   ├── Dockerfile.gitlab-agent
│   └── Dockerfile.kubernetes-agent
│
└── k8s/
    ├── namespace.yaml
    ├── adk-service-account.yaml   # RBAC for the kubernetes-mcp service account
    ├── orchestrator-agent.yaml
    ├── gitlab-agent.yaml
    ├── kubernetes-agent.yaml
    ├── argocd-application.yaml
    └── secrets.yaml.template      # Template only - real secrets are never committed
```

> Runtime files such as `.env`, a local `kubeconfig`, and ADK session artifacts are **not** part of this repository - they are git-ignored and supplied at run time (see [Running it](#running-it)).

---

## Agents in detail

### Orchestrator agent

**File:** `orchestrator_agent/__init__.py` · **Model:** `gemini-flash-latest`

The single user-facing agent. It owns the entire deployment conversation and delegates silently to sub-agents.

- **Communication gatekeeper** - sub-agents never speak to the user; all results are relayed by the orchestrator.
- **Workflow enforcer** - follows the 8-step process strictly; never skips steps, never proceeds on failure.
- **Security enforcer** - refuses root containers, plaintext secrets, out-of-scope cluster modifications, and production deployments.
- **Task delegation** - sends structured `[TASK]` blocks to sub-agents over A2A.

### GitLab agent

**File:** `gitlab_agent/__init__.py` · **Model:** `gemini-flash-latest`
**MCP server:** `gitlab-mcp-server` on-cluster, over SSE (`GITLAB_MCP_SERVER_URL`).

| Capability            | Description                                                         |
|-----------------------|---------------------------------------------------------------------|
| Repository inspection | Browse projects, file trees, and settings                           |
| File operations       | Add **new** files on a branch (never modifies or deletes existing)  |
| Branch management     | Create branches from the default branch                             |
| Merge requests        | Open and inspect MRs from the deploy branch to the default branch   |
| Template fetching     | Pull Dockerfile/CI/manifest templates (see `../templates`)          |
| Pipeline monitoring   | Poll CI/CD pipeline status                                           |

Constraints:
- Scoped to the authorised GitLab group and its subgroups only.
- **Never creates new repositories.** All deployment files go to a new branch on the developer's existing repo, surfaced via a merge request.
- **Never** modifies, overwrites, or deletes existing files, and never pushes to the default branch directly.
- **Never** generates CI/Dockerfile logic from scratch - only fills `[AGENT-EDIT]` placeholders in fetched templates and preserves every `[AGENT-LOCK]` line.

### Kubernetes agent

**File:** `kubernetes_agent/__init__.py` · **Model:** `gemini-flash-latest`
**MCP server:** `kubernetes-mcp-server` on-cluster, over SSE (`KUBERNETES_MCP_SERVER_URL`).

| Capability          | Description                                               |
|---------------------|-----------------------------------------------------------|
| Manifest generation | Deployment, Service, NetworkPolicy, Ingress, ArgoCD App   |
| Namespace mgmt      | Create target namespaces on the cluster                   |
| ArgoCD bootstrap    | Apply ArgoCD Application manifests, poll sync/health       |
| Resource validation | Map S/M/L tiers to exact CPU/Memory requests & limits     |

Constraints: never creates `ClusterRoleBindings` or grants `cluster-admin`, never deletes namespaces or touches resources outside the target namespace, and operates only within the orchestrator's task boundaries. The MCP service account's RBAC is intentionally least-privilege (see `k8s/adk-service-account.yaml`).

---

## Platform infrastructure

| Component          | Details                                                       |
|--------------------|---------------------------------------------------------------|
| Cluster            | OVH Managed Kubernetes (region set via Terraform variable)     |
| Ingress controller | `ingress-nginx` (class: `nginx`)                              |
| External IP        | `<CLUSTER_IP>` (assigned by the OVH load balancer)            |
| Ports              | `80` (HTTP), `443` (HTTPS)                                     |
| Exposure           | `LoadBalancer`                                                 |
| TLS                | Automated via `cert-manager` + Let's Encrypt (`letsencrypt-prod` ClusterIssuer) |
| GitOps engine      | ArgoCD                                                         |
| Container registry | Harbor (private, self-hosted, with Trivy scanning)            |

---

## Security & guardrails

| Policy                           | Enforcement                                                             |
|----------------------------------|-------------------------------------------------------------------------|
| No root containers               | Deployment templates enforce `runAsNonRoot`, non-root UID, dropped caps, read-only root FS. |
| No plaintext secrets             | Pull secrets are generated in-namespace by the pipeline from Harbor robot accounts. |
| Existing-file immutability       | The developer's existing files are never modified; only new files are added on a branch. |
| Namespace isolation              | Agents operate only within the target namespace.                        |
| No cluster-wide RBAC changes     | `ClusterRoleBindings` / `cluster-admin` are explicitly forbidden.       |
| No production deployments        | Production environments are out of scope.                               |
| Sequential workflow enforcement  | Steps cannot be skipped, even on request.                               |
| Scoped GitLab access             | All operations limited to the authorised GitLab group.                  |

---

## Running it

> This is a **showcase repository**. The platform ran on a now-decommissioned OVH cluster and GitLab group; it is not a copy-paste deploy. The steps below describe how the control plane was run against a live platform.

### Prerequisites

- Python 3.10+ and the Google ADK (`pip install google-adk`)
- A **Gemini API key** (or Vertex AI credentials)
- A **GitLab personal access token** with the `api` scope
- Network reachability to the on-cluster `gitlab-mcp-server` and `kubernetes-mcp-server` (the agents run inside the cluster in production)

### Configuration

The agents read configuration from the environment (supplied as git-ignored `.env` files locally, or as Kubernetes secrets in production - see `k8s/secrets.yaml.template`):

```env
GOOGLE_API_KEY=<your-gemini-api-key>
GITLAB_TOKEN=<your-gitlab-personal-access-token>
GITLAB_API_URL=https://gitlab.com
GITLAB_MCP_SERVER_URL=http://gitlab-mcp-server.gitlab-mcp-server.svc.cluster.local:3000/sse
KUBERNETES_MCP_SERVER_URL=http://kubernetes-mcp-server.kubernetes-mcp-server.svc.cluster.local:8000/sse
```

### Launch

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
adk run orchestrator_agent      # interactive CLI
# or:
adk web                         # browser-based chat; select orchestrator_agent
```

---

## Resource tiers

| Tier   | CPU request | CPU limit | Memory request | Memory limit |
|--------|-------------|-----------|----------------|--------------|
| Small  | 100m        | 250m      | 128Mi          | 256Mi        |
| Medium | 250m        | 500m      | 256Mi          | 512Mi        |
| Large  | 500m        | 1000m     | 512Mi          | 1Gi          |

---

<p align="center"><sub>Built with Google ADK · Gemini · MCP · ArgoCD</sub></p>
