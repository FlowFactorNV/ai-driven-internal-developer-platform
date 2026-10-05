# Kubernetes Manifest Templates

Standardised, production-ready manifest templates for the ADK Platform Orchestrator.

## Annotation System

Every template uses two annotation markers to separate **platform boilerplate** (never touched) from **deployment-specific values** (agent-customised).

### `[AGENT-LOCK]`

Lines or blocks marked `[AGENT-LOCK]` are **platform policy**. They must **never** be modified by an agent. These encode security guardrails, organisational standards, and infrastructure assumptions.

Examples: `securityContext`, `ingressClassName`, resource limit structure, network policy types.

### `[AGENT-EDIT]`

Lines or blocks marked `[AGENT-EDIT]` are **placeholders** that the agent must replace with deployment-specific values gathered during the workflow.

Placeholders use the format `<PLACEHOLDER_NAME>` (e.g., `<APP_NAME>`, `<NAMESPACE>`).

## Placeholder Reference

| Placeholder            | Description                                          | Example Value          |
|------------------------|------------------------------------------------------|------------------------|
| `<APP_NAME>`           | Application / deployment name                        | `my-api`               |
| `<NAMESPACE>`          | Target Kubernetes namespace                          | `team-alpha`           |
| `<CONTAINER_IMAGE>`    | Full container image URI (registry + tag)            | `registry.gitlab.com/group/app:latest` |
| `<CONTAINER_PORT>`     | Port the application listens on                      | `8080`                 |
| `<SERVICE_ACCOUNT>`    | Team / service account name                          | `team-alpha-sa`        |
| `<CPU_REQUEST>`        | CPU request (from resource tier)                     | `100m`                 |
| `<CPU_LIMIT>`          | CPU limit (from resource tier)                       | `250m`                 |
| `<MEMORY_REQUEST>`     | Memory request (from resource tier)                  | `128Mi`                |
| `<MEMORY_LIMIT>`       | Memory limit (from resource tier)                    | `256Mi`                |
| `<HOSTNAME>`           | Ingress hostname / domain                            | `my-api.example.com`   |
| `<ENDPOINT_PATH>`     | Application URL prefix / path                        | `/api/v1`              |
| `<TLS_SECRET_NAME>`    | Name of the manually provisioned TLS Secret          | `my-api-tls`           |
| `<GITLAB_REPO_URL>`    | GitLab deployment repository URL (for ArgoCD)        | `https://gitlab.com/group/app-deployment.git` |
| `<TARGET_BRANCH>`      | Git branch ArgoCD monitors                           | `main`                 |
| `<ARGOCD_PROJECT>`     | ArgoCD project (usually `default`)                   | `default`              |

## Resource Tier Mapping

| Tier     | `<CPU_REQUEST>` | `<CPU_LIMIT>` | `<MEMORY_REQUEST>` | `<MEMORY_LIMIT>` |
|----------|-----------------|---------------|---------------------|-------------------|
| Small    | `100m`          | `250m`        | `128Mi`             | `256Mi`           |
| Medium   | `250m`          | `500m`        | `256Mi`             | `512Mi`           |
| Large    | `500m`          | `1000m`       | `512Mi`             | `1Gi`             |

## Templates Included

| File                        | Description                                      |
|-----------------------------|--------------------------------------------------|
| `namespace.yaml`            | Namespace with standard labels                   |
| `service-account.yaml`      | Service Account for pod identity                 |
| `deployment.yaml`           | Deployment with security context and resource limits |
| `service.yaml`              | ClusterIP Service                                |
| `networkpolicy.yaml`        | Default-deny + allow ingress NetworkPolicy       |
| `ingress.yaml`              | NGINX Ingress (HTTP only)                        |
| `ingress-tls.yaml`          | NGINX Ingress (HTTPS with manual TLS Secret)     |
| `argocd-application.yaml`   | ArgoCD Application for GitOps sync               |
