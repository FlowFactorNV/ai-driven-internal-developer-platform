---
title: "Building an AI-driven Internal Developer Platform (5/6): The golden path"
series: "Building an AI-driven Internal Developer Platform"
part: 5
---

# The golden path: templating Dockerfiles, pipelines and manifests for an AI

So far we have a cluster and a set of platform services. This post is about the contract that sits between those services and the deployments that run on them: the `templates/` layer (originally `idp-dockerfile-templates`). It is the smallest layer by line count and arguably the most important, because it is what makes the whole thing both repeatable and safe. It is also the most directly reusable piece of the project on its own.

## A library of opinions

The templates layer is a set of hardened, opinionated building blocks: a Dockerfile per language (Python, Node.js, Java with Maven, Spring Boot with Maven or Gradle, and Go), one generic CI pipeline template, and a set of Kubernetes manifest templates (namespace, service account, deployment, service, network policy, ingress, and an ArgoCD application).

The Dockerfiles encode a baseline that is the same across every language: multi-stage builds, a non-root `appuser` running as UID 1001, system packages upgraded in every stage, minimal final images (a JRE for Java, `scratch` for Go, `slim` for Python and Node), no development dependencies in the production image, and SHA-based image tags. A developer deploying a Go service gets a statically linked binary in a `scratch` container with no shell and almost no attack surface, without knowing or caring that any of those were decisions.

The CI template is equally opinionated. It runs the SonarQube gate first, then builds the image with Kaniko, pushes to Harbor, and creates the Kubernetes image pull secret idempotently. The build only runs on `main`, and the pipeline as a whole only runs on merge requests and `main`, so nothing fires on a random feature branch.

## The real problem: letting an AI edit a template safely

Here is the tension at the centre of this layer. The platform's whole premise is that an AI agent fills these templates in. But a template is full of lines you absolutely do not want an AI to touch: the security context, the ingress class, the network policy type, the non-root user. How do you let a language model edit the safe parts of a file while treating the dangerous parts as off-limits?

The answer Nand came up with is a simple annotation system, and it is the clever heart of the project. Every template line is implicitly locked, and two markers carve out the exceptions:

- `# [AGENT-LOCK]:` marks a forbidden zone. It is platform policy: security guardrails, organisational standards, infrastructure assumptions. The agent must never modify, remove, or rewrite these lines, no matter what it is asked.
- `# [AGENT-EDIT]:` marks an injection zone. These lines carry placeholders like `<INSERT_PORT>` or `<APP_NAME>` that the agent is expected to fill with values inferred from the project.

Anything unmarked is treated as locked by default. Here is the idea in a Dockerfile fragment:

```dockerfile
# [AGENT-LOCK]: non-root runtime user, do not modify
RUN addgroup -g 1001 appuser && adduser -u 1001 -G appuser -S appuser
USER appuser

# [AGENT-EDIT]: set the application's listening port
EXPOSE <INSERT_PORT>
```

The agent may change the `EXPOSE` line all day. It may not touch the two lines above it. The same system governs the manifests, where the locked blocks include exactly the parts you would least want improvised:

```yaml
# [AGENT-LOCK]: platform security baseline, do not modify
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
```

And the network policy templates default to deny, allowing ingress only from the ingress controller's namespace and egress only to DNS, so an app is isolated the moment it is created rather than as a later hardening step.

## Policy as data, not trust

What makes this approach hold up is that the lock is not a polite request buried in a prompt. It is a convention expressed in the files themselves, reinforced by instructions in the agent, and backed by the pipeline that strips the annotations out when it commits the final, clean manifests. When the agent finishes, it emits production-ready YAML with the markers removed, having only ever changed the lines it was allowed to change.

This is also why the templates layer is the most reusable part of the project. The annotation convention is independent of OVH, GitLab, and the specific AI stack. Any system that programmatically fills templates, whether driven by an LLM or not, can borrow the "locked by default, edit only inside marked zones" idea to keep security-critical configuration out of reach.

## What's next

1. Why an IDP, and the architecture map.
2. From zero to a cluster - OVH Managed Kubernetes with Terraform.
3. GitOps bootstrap - ArgoCD app-of-apps, and keeping secrets out of Git.
4. Platform services - Harbor, SonarQube, Prometheus/Grafana, SSO and automatic TLS.
5. **This post** - templating Dockerfiles, pipelines and manifests, and the annotation system that lets an AI edit them safely.
6. **The AI control plane** - Google ADK, multi-agent delegation, and guardrails written in English.

We now have the contract. The final post puts the driver behind the wheel: the multi-agent AI system that reads a repository, fills these templates, and walks a deployment all the way to live.
