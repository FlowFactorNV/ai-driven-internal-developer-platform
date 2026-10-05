---
title: "Building an AI-driven Internal Developer Platform (3/6): GitOps bootstrap"
series: "Building an AI-driven Internal Developer Platform"
part: 3
---

# GitOps bootstrap: ArgoCD app-of-apps, and keeping secrets out of Git

The previous post left off with a cluster that exists, is locked down, and has nothing running on it yet. This post is about the handover: how the infrastructure pipeline installs a GitOps engine and then steps out of the way, so that from that moment on the cluster's desired state lives in Git and reconciles itself. This is the `gitops/` layer (originally the `cluster_infrastructure` repository).

## Two timelines, one clean seam

A useful way to think about this platform is as two separate timelines. Terraform owns the "raw hardware" timeline: the cluster, the networking, the storage. ArgoCD owns the "software" timeline: everything deployed onto that hardware. The two should not be tangled together.

The seam between them is a single step at the end of the infrastructure pipeline. It installs ArgoCD onto the fresh cluster and then applies one manifest: the root application. After that, Terraform never deploys application software, and ArgoCD never provisions infrastructure. The cluster can be rebuilt without losing track of what software belongs on it, and software can be redeployed without touching the cluster.

## The app-of-apps pattern

The root application is where the GitOps magic starts. Instead of pointing ArgoCD at a few hand-picked manifests, it points at a folder and tells ArgoCD to manage everything it finds, recursively.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-manifests
  namespace: argocd
spec:
  source:
    repoURL: "https://gitlab.com/your-org/idp-platform/cluster_infrastructure.git"
    path: manifests
    directory:
      recurse: true
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Three settings carry most of the weight here. `recurse: true` means the root app discovers every application manifest under `manifests/` on its own, so adding a new platform service is just a matter of committing a file. `prune: true` means that deleting a manifest from Git deletes the resource from the cluster, so Git is genuinely the source of truth rather than an append-only log. And `selfHeal: true` means that if someone changes a live resource by hand, ArgoCD quietly reverts it back to what Git says. Drift does not survive.

Under that one root application sits the whole platform: ingress-nginx, cert-manager, oauth2-proxy, the GitLab runner, Harbor, the Prometheus stack, SonarQube, and the two MCP servers the AI agents depend on. Each is its own Application, managed as a child of the root. We will tour those services in the next post.

## The hard part: secrets in a GitOps world

GitOps has an awkward tension at its heart. The whole model says "everything is in Git," but the one thing you must never put in Git is a secret. So where do the Harbor admin password, the GitLab tokens, the OAuth client secret, and the Grafana credentials come from?

The answer, set up during the bootstrap step, is to inject them at deploy time from masked GitLab CI variables straight into Kubernetes Secrets, so they never land in Git and never land in Terraform state either. The pattern used throughout is an idempotent `kubectl apply`:

```bash
kubectl create secret generic harbor-admin-credentials \
  --from-literal=HARBOR_ADMIN_PASSWORD="${HARBOR_ADMIN_PASSWORD}" \
  --namespace=harbor \
  --dry-run=client -o yaml | kubectl apply -f -
```

The `--dry-run=client -o yaml | kubectl apply -f -` trick is worth internalising: it renders the Secret as YAML without creating it, then pipes that through `apply`, which creates it if absent and updates it if present. Running the pipeline twice does not error and does not duplicate anything. The same approach injects a group-scoped repository credential so ArgoCD can pull the platform manifests, the GitLab runner registration token, the OAuth2 proxy client and cookie secrets, the SonarQube and Postgres passwords, the Grafana admin credentials, and the Slack webhook URL for alerts.

One subtlety: ArgoCD's repo-server caches its git credentials at startup, so after injecting the repository secret the pipeline restarts that deployment to force it to pick the new credential up. Without that restart, ArgoCD would keep failing to pull from a private repository it technically has access to.

## Why this matters

The result is a cluster whose entire software state is described in a Git repository, reconciled continuously, with the only non-Git inputs being secrets that arrive through a narrow, auditable channel. You can read the repository and know exactly what runs on the cluster. You can delete the cluster and rebuild it, and ArgoCD will put everything back. And no credential ever sits in a file that gets committed or stored in state.

## What's next

1. Why an IDP, and the architecture map.
2. From zero to a cluster - OVH Managed Kubernetes with Terraform.
3. **This post** - ArgoCD app-of-apps, and keeping secrets out of Git.
4. **Platform services** - Harbor, SonarQube, Prometheus/Grafana, SSO and automatic TLS.
5. The golden path - templating Dockerfiles, pipelines and manifests, and the annotation system that lets an AI edit them safely.
6. The AI control plane - Google ADK, multi-agent delegation, and guardrails written in English.

With GitOps in charge, the next post walks through the platform services it manages: the registry, the quality gate, observability, SSO and automatic TLS.
