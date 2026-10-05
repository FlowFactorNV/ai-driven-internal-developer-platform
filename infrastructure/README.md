# infrastructure (ovh-cicd)

> **⚠️ Showcase repository - not a copy-paste deploy.** Part of an AI-driven IDP published as a blog companion. It was built for a now-decommissioned OVH + GitLab environment and internal identifiers have been replaced with placeholders (`example.com`, `your-org`, `<CLUSTER_IP>`). See the [root README](../README.md). Read it for the architecture and decisions, not to `terraform apply` unmodified.

## Overview

This repository manages the Infrastructure as Code (IaC) and CI/CD pipeline for provisioning and configuring a Kubernetes cluster on OVH. It uses Terraform to provision the cluster and GitLab CI to automate the full deployment lifecycle, including bootstrapping ArgoCD as the GitOps delivery engine.

## Repository Structure

```
ovh-cicd/
├── .gitlab-ci.yml          # GitLab CI/CD pipeline definition
├── .gitignore              # Ignores secrets, state files, and local configs
└── iac/
    ├── bootstrap/          # Bootstrap-phase Terraform configs
    └── k8s/                # Kubernetes infrastructure Terraform configs
        └── manifests/
            └── root-app.yaml   # ArgoCD root Application manifest
```

## CI/CD Pipeline

The pipeline is defined in `.gitlab-ci.yml` and uses the `hashicorp/terraform:latest` and `bitnami/kubectl:latest` Docker images (no runner tags are pinned). It operates on Terraform code in `iac/k8s/`.

### Pipeline Stages

| Stage | Job | Description |
|---|---|---|
| `fmt` | `format` | Runs `terraform fmt -check` to enforce formatting |
| `validate` | `validate` | Runs `terraform validate` to check syntax |
| `plan` | `plan` | Creates a Terraform plan, saved as a pipeline artifact (1h TTL) |
| `apply` | `apply` | Applies the plan - **manual trigger**, `main` branch only |
| `deploy-argocd` | `deploy-argocd` | Installs ArgoCD and configures repository credentials |

### ArgoCD Deployment (`deploy-argocd`)

After infrastructure apply, this stage uses `bitnami/kubectl` to:

1. Check if ArgoCD is already installed; if not, install it from the stable manifest and wait for readiness.
2. Inject group-scoped GitLab repository credentials as a Kubernetes Secret (an ArgoCD `repo-creds` entry for the GitLab group) so ArgoCD can pull the platform manifests.
3. Create the `gitlab-runner` namespace and inject the GitLab Runner token as a Secret.
4. Restart the `argocd-repo-server` deployment and apply the ArgoCD root application from `iac/k8s/manifests/root-app.yaml`.

## Required CI/CD Variables

These must be set as masked variables in GitLab CI settings:

| Variable | Purpose |
|---|---|
| `ARGOCD_GITLAB_TOKEN` | GitLab personal access token for ArgoCD repo access |
| `GITLAB_RUNNER_TOKEN` | Registration token for the GitLab Runner |

## IaC Layout

| Path | Purpose |
|---|---|
| `iac/k8s/` | Main Terraform root module for the Kubernetes cluster |
| `iac/bootstrap/` | One-time bootstrap resources (OVH provider setup, remote state, etc.) |

## Ignored Files

The `.gitignore` excludes sensitive and generated files:

- `.aws/`, `.terraform/` - provider/tool caches
- `*.env`, `*.tfvars` - environment secrets
- `*.tfstate*`, `*.tfplan` - Terraform state and plans
- `*.lock.hcl` - provider lock files
- `kubeconfig.yaml` - cluster access credentials

## Related layers

This is the `infrastructure/` layer of the monorepo. The services it bootstraps via ArgoCD live in [`../gitops`](../gitops); the golden-path templates in [`../templates`](../templates); the AI control plane in [`../orchestrator`](../orchestrator). See the [root README](../README.md) for how they fit together.

> In the original internship setup these layers were separate GitLab repositories (plus a separate test-environment manifests repo). The ArgoCD `repoURL`s under `iac/k8s/manifests/` still reflect that multi-repo origin.
