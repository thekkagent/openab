## What problem does this solve?

OpenAB's Helm chart is currently strong on the minimal install path, but it is too thin for many real Kubernetes deployments.

It does not currently expose several common deployment controls that operators typically expect from a reusable open-source chart, including:

- `imagePullSecrets`
- probes (`livenessProbe`, `readinessProbe`, `startupProbe`)
- `lifecycle`
- `initContainers`
- sidecars
- extra volumes / volume mounts
- `serviceAccount`
- PodDisruptionBudget
- extra ConfigMap / Secret injection patterns
- other pod-level deployment settings that are common in production clusters

This leaves users with a few unattractive options:

1. rebuild a custom image for relatively minor deployment-specific needs
2. patch rendered manifests after `helm template`
3. fork the chart just to add standard Kubernetes fields

One immediate example is that the chart does not currently support `imagePullSecrets`, which makes private registry deployments harder than they need to be.

Closes #

Discord Discussion URL: https://discordapp.com/channels/1491295327620169908/1493841502529523732

## What's in this PR

| File | Purpose |
|---|---|
| `charts/openab/values.yaml` | Add first-phase Helm values for pod / deployment extensibility |
| `charts/openab/templates/_helpers.tpl` | Add helper resolution for per-agent image pull policy, image pull secrets, service account binding, and merged pod metadata |
| `charts/openab/templates/deployment.yaml` | Render pod-level extensibility controls into `Deployment.spec.template` |
| `charts/openab/tests/helm-template-test.sh` | Add coverage for the new Helm rendering behaviors and fix the test harness counter bug under `set -e` |

## Key decisions

- The first implementation is intentionally scoped to pod / deployment extensibility only
- Custom images remain the primary solution for stable toolchains
- `initContainers` + shared volumes are the supported lightweight bootstrap path
- `PodDisruptionBudget`, RBAC, and generic extra objects are deferred to follow-up PRs

## At a Glance

```text
┌──────────────────────────────┐
│ Current OpenAB Helm Chart    │
│ minimal install path         │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Missing common chart hooks   │
│ - imagePullSecrets           │
│ - probes / lifecycle         │
│ - initContainers / sidecars  │
│ - extra volumes / mounts     │
│ - serviceAccount / pdb       │
│ - extra config injection     │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Proposed change              │
│ phased Helm extensibility    │
│ without turning the chart    │
│ into a package manager       │
└──────────────────────────────┘
```

## Prior Art & Industry Research

**OpenClaw:**

I reviewed the local OpenClaw repository and its Kubernetes deployment manifests. While OpenClaw does not currently ship a Helm chart in this repo, it does treat startup bootstrap as a first-class deployment concern. In particular, it uses an `initContainer` to prepare configuration and workspace state before the main container starts.

This suggests:

- `initContainers` are a reasonable place for startup preparation
- bootstrap logic should be treated as deployment design, not an ad hoc workaround
- a hardened main container can stay simpler when initialization is separated

Reference:

- `scripts/k8s/manifests/deployment.yaml`

**Hermes Agent:**

I also reviewed Hermes Agent's Docker and deployment documentation. Hermes takes a clearer stance on tool installation: stable toolchains should primarily be handled through custom images or clearly defined mutable runtime environments, not by stretching the chart into a package manager.

This suggests:

- serious toolchains should prefer custom images
- runtime bootstrap can exist, but it should stay lightweight and bounded
- Helm should expose deployment extension points, not replace image design

References:

- `Dockerfile`
- `website/docs/user-guide/docker.md`
- `website/docs/getting-started/nix-setup.md`

**Other references:**

I also reviewed Bitnami charts and Helm / Kubernetes best practices.

Bitnami's more mature charts commonly expose capabilities such as:

- `imagePullSecrets`
- `serviceAccount`
- probes
- `lifecycle`
- `initContainers`
- sidecars
- `extraVolumes`
- `extraVolumeMounts`
- `extraEnvVarsCM`
- `extraEnvVarsSecret`
- `extraDeploy`
- `pdb`

Relevant upstream guidance also supports this direction:

- Helm chart values and template best practices
- Kubernetes guidance for `initContainers`
- Kubernetes guidance for private registry pulls via `imagePullSecrets`

## Proposed Solution

This PR implements the first phase of pod / deployment extensibility for the OpenAB Helm chart.

Implemented scope:

- `imagePullSecrets`
- per-agent `imagePullPolicy`
- pod annotations / labels
- probes
- `lifecycle`
- `initContainers`
- sidecars
- `extraVolumes`
- `extraVolumeMounts`
- existing `serviceAccountName` binding

For the "install tools" question specifically, the proposal recommends two clear paths:

1. **Custom image**
   the preferred path for stable, repeatable, production-grade toolchains

2. **`initContainers` + shared volume**
   a lightweight bootstrap path for small binaries or startup initialization

Explicitly out of scope in this PR:

- `PodDisruptionBudget`
- chart-managed ServiceAccount creation
- RBAC resources
- generic extra objects such as `extraDeploy`

This keeps the implementation focused on `Deployment.spec.template`, solves the highest-value deployment gaps first, and avoids mixing pod extensibility with broader chart resource management.

## Why this approach?

I do not think OpenAB should model every Kubernetes field at once, and I do not think Helm should become the primary mechanism for packaging arbitrary tools.

At the same time, the current chart is thin enough that users are pushed toward forking it for fairly normal deployment requirements. That creates unnecessary friction for a public chart.

This approach takes the middle path:

- keep the default chart simple
- expose the extension points that operators commonly expect
- keep custom images as the primary answer for serious tool installation
- treat `initContainers` bootstrap as a lightweight complement, not the main packaging model
- phase the work so the chart does not grow all at once

Tradeoffs and limitations:

- the chart surface will grow
- some values need careful merge rules to stay predictable
- features like PDB or RBAC should stay optional to avoid over-designing the chart too early

## Alternatives Considered

The main implementation question is not whether Helm extensibility should be improved, but how much should be included in the first implementation PR.

### 1. Do the minimum: only `imagePullSecrets`

Rejected.

This would solve the most immediate private-registry gap, but it would still leave the chart without probes, lifecycle hooks, and pod composition controls such as `initContainers`, sidecars, and extra volumes. The result would still feel incomplete for real deployments.

### 2. Implement pod / deployment extensibility only

Chosen.

This keeps the first implementation focused on a single surface area: `Deployment.spec.template`. It addresses the highest-value deployment gaps first, including private registry support, health / lifecycle controls, and pod composition hooks, while keeping the PR cohesive and reviewable.

### 3. Implement everything at once, including PDB, RBAC, and generic extra objects

Rejected.

Although these features are valid chart capabilities, they extend beyond pod template extensibility and would make the first implementation significantly broader. Mixing pod-level changes with additional chart-managed resources would increase review complexity and make the initial rollout harder to reason about.

## Validation

- [x] Helm chart template tests pass
- [x] Prior art research across OpenClaw, Hermes Agent, Bitnami charts, Helm docs, and Kubernetes docs
- [x] Manual rendering coverage added for:
  - `imagePullSecrets`
  - per-agent `imagePullPolicy`
  - `initContainers`
  - sidecars
  - extra volumes / mounts
  - probes
  - `lifecycle`
  - `serviceAccountName`
  - pod annotations / labels

Validation command used:

```bash
bash charts/openab/tests/helm-template-test.sh
```

Result:

- `14 passed, 0 failed`

## Open questions

1. Should follow-up work add `PodDisruptionBudget` before or after chart-managed ServiceAccount support?
2. Should generic extra objects be exposed via `extraDeploy`, `extraObjects`, or deferred further?
3. Should `serviceAccountName` remain binding-only for now, or should chart-managed creation be the next step?
