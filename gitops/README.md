# gitops (cluster_infrastructure)

> **⚠️ Showcase repository - not a copy-paste deploy.** Part of an AI-driven IDP published as a blog companion. It was built for a now-decommissioned OVH + GitLab environment and internal identifiers have been replaced with placeholders (`example.com`, `your-org`, `<CLUSTER_IP>`). See the [root README](../README.md). Read it for the architecture and decisions, not to `kubectl apply` unmodified.

## Overview

This is the **GitOps desired state** for the platform: the single source of truth for every cluster-wide service, reconciled by ArgoCD using the **app-of-apps** pattern. The root application watches `manifests/` recursively and keeps the cluster in sync (`prune` + `selfHeal`). The foundation that hosts all of this - the cluster itself and the ArgoCD bootstrap - lives in [`../infrastructure`](../infrastructure).

## What `manifests/` contains

- **cert-manager** - Let's Encrypt automation; provides the `letsencrypt-prod` ClusterIssuer so any ingress gets automatic TLS via an annotation.
- **ingress-nginx** - the ingress controller (OVH load balancer, proxy protocol).
- **oauth** - oauth2-proxy for GitLab group-scoped SSO in front of platform UIs.
- **harbor** - the private container registry (Trivy scanning, block-storage PVCs).
- **prometheus** - kube-prometheus-stack: Prometheus, Grafana, Alertmanager (Slack routing).
- **sonarqube** - SonarQube + a dedicated Postgres for the code-quality gate.
- **gitlab-runner** - CI runners pinned to the isolated CI node pool.
- **gitlab-mcp / kubernetes-mcp** - the MCP servers the AI agents call, with least-privilege RBAC.
- **argocd-expose** - ingress for the ArgoCD UI.

## Why the MCP servers run on the cluster

The agents in [`../orchestrator`](../orchestrator) communicate with their MCP servers over **Server-Sent Events (SSE)**. Dockerising the MCP servers and exposing an SSE endpoint in-cluster lets the agents reach them over Kubernetes DNS, which is the transport the ADK agents rely on - rather than spawning the servers as local processes.
