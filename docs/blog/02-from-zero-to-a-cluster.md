---
title: "Building an AI-driven Internal Developer Platform (2/6): From zero to a cluster"
series: "Building an AI-driven Internal Developer Platform"
part: 2
---

# From zero to a cluster: OVH Managed Kubernetes with Terraform

In the first post we looked at the platform from above: two planes and a contract between them. Now we start at the bottom, with the layer everything else stands on. Before there can be a registry, a GitOps engine, or an AI agent, there has to be a cluster, and that cluster has to be built in a way that is repeatable, isolated, and safe to tear down. This is the `infrastructure/` layer (originally the `ovh-cicd` repository), and it is pure Infrastructure as Code: Terraform to provision an OVH Managed Kubernetes cluster, and a GitLab pipeline to drive it.

The node pools and private network we build here sit at the base of the full platform, which Post 4 maps out in one diagram once all the services are in place.

## The chicken-and-egg of Terraform state

The first problem shows up before a single cluster resource exists. Terraform needs somewhere to store its state, and the sensible place is remote object storage so that CI runs do not clobber each other. But you want to create that bucket with Terraform too, and Terraform cannot store its state in a bucket that does not exist yet.

The layer solves this with a deliberate two-phase split:

- **Bootstrap phase** (`iac/bootstrap/`) runs once, locally, with local state. It provisions an OVH Object Storage bucket and a dedicated IAM user (`objectstore_operator`) whose policy is restricted to exactly `GetObject`, `PutObject`, and `DeleteObject` on that one bucket. Least privilege from the very first resource.
- **Kubernetes phase** (`iac/k8s/`) then configures its `backend "s3"` to use that bucket for remote state. From here on, state lives remotely and is safe for concurrent CI.

It is a small thing, but it sets the tone: the foundation is itself provisioned by code, and nothing gets broader permissions than it needs.

## Four node pools, on purpose

The cluster is not one big pool of identical nodes. It is four separate autoscaling node pools, and the separation is the point.

```hcl
resource "ovh_cloud_project_kube_nodepool" "runner_node_pool" {
  name          = "${var.team}-${var.project_name}-runner-node-pool"
  flavor_name   = "b2-7"
  min_nodes     = 1
  max_nodes     = 5
  desired_nodes = 1
  autoscale     = true

  template {
    spec {
      taints = [
        { key = "workload", value = "ci", effect = "NoSchedule" }
      ]
    }
  }
}
```

The reasoning is the classic "noisy neighbour" problem. CI workloads are bursty and greedy: a single container build or a code scan can eat an entire node's CPU and memory. If that build runs next to a user's application, the application suffers. So the platform gives the greedy workloads their own nodes and keeps them off everyone else's.

There are four pools:

- `node_pool_1` for general application workloads (no taint, open to everything).
- `runner_node_pool` for GitLab CI runners, tainted `workload=ci:NoSchedule`.
- `harbor_node_pool` for the container registry, tainted `workload=harbor:NoSchedule`.
- `sonar_node_pool` for SonarQube, tainted `workload=sonar:NoSchedule`.

The taints turn the isolation into an enforceable scheduler rule rather than a convention: a generic pod simply cannot land on the CI, Harbor, or Sonar nodes unless it explicitly tolerates the taint. Every pool autoscales (the runner pool scales up to five nodes under load and back down to one when idle) and all of them bill hourly, so capacity follows demand and the idle cost stays low.

## A network that assumes the worst

Rather than putting nodes on public IP space, the whole cluster lives inside a private OVH network on an isolated VLAN, with addresses handed out by DHCP and a small NAT gateway for outbound traffic.

```hcl
resource "ovh_cloud_project_network_private" "mks-private-network" {
  name    = "${var.team}-${var.project_name}-pn"
  regions = [var.region]
  vlan_id = 10
}
```

This is zero-trust at the infrastructure level. Worker nodes with public IPs invite SSH brute-force attempts and unauthenticated Kubelet probing. By keeping every node private, those attack vectors are gone. The NAT gateway still lets nodes pull images and updates, but nothing on the internet can start a conversation with a node. Application traffic comes in through an ingress controller and load balancer instead, which gives one explicit, auditable way in.

## The pipeline: automatic checks, manual destruction

The GitLab pipeline runs the Terraform lifecycle, but not all stages are equal. `fmt`, `validate`, and `plan` run automatically on every commit, giving continuous feedback on the infrastructure code. The `apply` stage is different: it is restricted to the `main` branch and requires a manual click.

That manual gate is deliberate. Infrastructure changes can be catastrophic in a way application changes rarely are: destroying a node pool, deleting a subnet, or corrupting networking. Forcing a human to read the plan and consciously approve it turns "oops" into "are you sure." After a successful apply, the pipeline saves the generated `kubeconfig.yaml` as an artifact and hands off to the next stage, which installs the GitOps engine.

## Keeping secrets out of the state file

One decision here pays off repeatedly later. The pipeline injects credentials (the GitLab runner token, the Harbor admin password, repository access) into the cluster at runtime using masked GitLab CI variables and `kubectl`, rather than creating them through the Terraform Kubernetes provider.

The reason is that anything Terraform manages ends up in the state file, in plaintext. Anyone who can read the state bucket could then read those secrets. By injecting them from CI variables straight into Kubernetes Secrets, they exist only briefly in memory during the pipeline run and never touch Terraform state. Post 3 picks up exactly here, where the cluster exists and the pipeline is about to bootstrap ArgoCD.

## What's next

1. Why an IDP, and the architecture map.
2. **This post** - OVH Managed Kubernetes with Terraform, isolated node pools, and a zero-trust network.
3. **GitOps bootstrap** - ArgoCD app-of-apps, and keeping secrets out of Git.
4. Platform services - Harbor, SonarQube, Prometheus/Grafana, SSO and automatic TLS.
5. The golden path - templating Dockerfiles, pipelines and manifests, and the annotation system that lets an AI edit them safely.
6. The AI control plane - Google ADK, multi-agent delegation, and guardrails written in English.

The cluster is up and locked down. Next we hand it over to ArgoCD and let GitOps take the wheel.
