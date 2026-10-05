# templates (idp-dockerfile-templates)

> **⚠️ Showcase repository - not a copy-paste deploy.** Part of an AI-driven IDP published as a blog companion. It was built for a now-decommissioned OVH + GitLab environment and internal identifiers have been replaced with placeholders (`example.com`, `your-org`, `<CLUSTER_IP>`). See the [root README](../README.md).

The golden-path template library: hardened Dockerfiles, a generic CI pipeline, and Kubernetes manifest templates the AI agents fill in. This is the contract between the control plane and the platform.

## Agent Behaviour Rules

> Read this section first. It governs all interactions with this repository.

- **`# [AGENT-LOCK]:`** - Forbidden zone. Never modify this line or block under any circumstances.
- **`# [AGENT-EDIT]:`** - Injection zone. Replace placeholders with values inferred from the project (detect `package.json`, `pyproject.toml`, `pom.xml`, `go.mod`).
- When setting image tags, always prefer `CI_COMMIT_SHA` or the git short SHA.
- When creating Kubernetes secrets in CI, the pipeline must be idempotent: use `kubectl apply -f -`.

---

## Repository Structure

```text
idp-dockerfile-templates/
├── README.md
├── gitlab-ci.yml.template           # Generic CI pipeline: build/push + K8s secret creation
├── python/
│   └── Dockerfile.template          # FastAPI / Generic WSGI (multi-stage, pip)
├── nodejs/
│   └── Dockerfile.template          # Express / Generic Node backend (3-stage)
├── java-maven/
│   └── Dockerfile.template          # Generic Maven build (2-stage, JRE runtime)
├── java-springboot/
│   └── Dockerfile.template          # Spring Boot layered JAR (3-stage, JRE runtime)
├── java-springboot-gradle/
│   └── Dockerfile.template          # Spring Boot layered JAR with Gradle (3-stage, JRE runtime)
├── go/
│   └── Dockerfile.template          # Go module app (2-stage, scratch final image)
└── manifest_templates/              # Kubernetes manifests (namespace, deployment, service,
                                     # networkpolicy, ingress, ingress-tls, argocd-application)
```

---

## Placeholder Reference

Replace placeholders only within `# [AGENT-EDIT]:` blocks. Do not alter locked lines.

| Placeholder | Template(s) | Example value |
|---|---|---|
| `<INSERT_PYTHON_VERSION>` | python | `3.12` |
| `<INSERT_NODE_VERSION>` | nodejs | `22` |
| `<INSERT_BUILD_SCRIPT>` | nodejs | `build` |
| `<INSERT_JAVA_VERSION>` | java-maven, java-springboot, java-springboot-gradle | `17`, `21` |
| `<INSERT_MAVEN_VERSION>` | java-maven, java-springboot | `3.9` |
| `<INSERT_GRADLE_VERSION>` | java-springboot-gradle | `8.7` |
| `<INSERT_ARTIFACT_NAME>` | java-maven, java-springboot, java-springboot-gradle | Maven/Gradle output JAR name |
| `<INSERT_SPRING_PROFILE>` | java-springboot, java-springboot-gradle | `prod` |
| `<INSERT_GO_VERSION>` | go | `1.23` |
| `<INSERT_MAIN_PACKAGE_PATH>` | go | `./cmd/server` |
| `<INSERT_PORT>` | all | Application listening port |
| `<INSERT_START_CMD>` | python, nodejs | Full tokenised CMD array |
| `<INSERT_JVM_OPTS>` | java-maven | Optional JVM tuning flags |
| `<INSERT_ENV_KEY/VALUE>` | go | Runtime environment variables |
| `<INSERT_BUILD_CONTEXT>` | gitlab-ci | `.` or `python/` |
| `<INSERT_TARGET_NAMESPACE>` | gitlab-ci | `app-frontend-prod` |
| `<INSERT_SECRET_NAME>` | gitlab-ci | `registry-pull-secret` |
| `<INSERT_REGISTRY_USER>` | gitlab-ci | `gitlab+deploy-token-123` |

---

## Security Baselines (AGENT-LOCK enforced)

These are locked constraints. Do not attempt to modify them.

| Baseline | Enforcement |
|---|---|
| Non-root user | All final stages create and enforce `appuser` (UID 1001 / GID 1001) |
| System upgrades | `apt-get upgrade` runs in every stage of every template |
| Minimal runtime images | JRE-only for Java; `scratch` for Go; `slim` for Python/Node |
| No dev dependencies in prod | Python uses `--prefix` copy; Node uses `--omit=dev`; Java skips test scope |
| Static Go binaries | `CGO_ENABLED=0` and `-trimpath` are locked |
| Spring Boot layer order | Dependency layers copied before application layers to maximise cache reuse |
| CI image tagging | SHA-based image tags enforced |
| K8s secret creation | Idempotent via `kubectl apply -f -` |

---

## Dockerfile Templates - Per-Language Expectations

### Python
- Multi-stage build with `pip`.
- Final stage: `python:<INSERT_PYTHON_VERSION>-slim`.
- App runs as `appuser` on `<INSERT_PORT>` with `CMD` set to `<INSERT_START_CMD>`.

### Node.js
- 3-stage build: install → build → runtime.
- Final stage: `node:<INSERT_NODE_VERSION>-slim`.
- Production stage uses `--omit=dev`.
- App runs as `appuser` on `<INSERT_PORT>` with `CMD` set to `<INSERT_START_CMD>`.

### Java (Maven)
- 2-stage build: Maven build → JRE runtime.
- Skips test scope in production.
- Optional JVM tuning via `<INSERT_JVM_OPTS>`.

### Java (Spring Boot)
- 3-stage build with layered JAR.
- Dependency layers copied before application layers.
- Activated Spring profile: `<INSERT_SPRING_PROFILE>`.
- Available in both Maven (`java-springboot`) and Gradle (`java-springboot-gradle`) variants.

### Go
- 2-stage build: Go build → `scratch` final image.
- `CGO_ENABLED=0` and `-trimpath` locked.
- Entry point: `<INSERT_MAIN_PACKAGE_PATH>`.

---

## GitLab CI Pipeline

**File:** `gitlab-ci.yml.template`

The pipeline builds, tags (SHA-based), pushes images, and creates/updates Kubernetes image pull secrets.

CI-specific placeholders to inject:

| Placeholder | Description |
|---|---|
| `<INSERT_BUILD_CONTEXT>` | Directory containing the Dockerfile (e.g. `.`, `python/`) |
| `<INSERT_TARGET_NAMESPACE>` | Kubernetes namespace (e.g. `app-frontend-prod`) |
| `<INSERT_SECRET_NAME>` | Name of the Kubernetes image pull secret |
| `<INSERT_REGISTRY_USER>` | GitLab Deploy Token username |
| `<INSERT_IMAGE_NAME>` | Name of the Docker Image (e.g. `app_name`), should default to the app_name variable set by the user|


---

## Kubernetes Manifest Templates

**Location:** `manifest_templates/`

Includes: namespace, deployment, service, networkpolicy, ingress, ingress-tls, argocd-application.

- `# [AGENT-LOCK]:` blocks encode platform policy - never modify.
- `# [AGENT-EDIT]:` blocks contain placeholders such as `<APP_NAME>`, `<NAMESPACE>`, `<CONTAINER_IMAGE>`.
- For ArgoCD-driven deployments, update `argocd-application.yaml` with `<GITLAB_REPO_URL>` and `<TARGET_BRANCH>`.
- Apply with `kubectl apply -f <manifest>` or commit into your GitOps repo.

See `manifest_templates/README.md` for the full placeholder table and resource-tier mapping (Small / Medium / Large).
