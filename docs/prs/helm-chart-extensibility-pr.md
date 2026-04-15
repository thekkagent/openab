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

**Other references (optional):**

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

This PR is intended as a proposal-first change, not an implementation PR yet.

The proposed direction is to expand the OpenAB Helm chart in phases so it exposes a more standard Kubernetes extension surface without turning the chart into a giant schema.

Suggested phases:

### Phase 1: highest-value gaps

- `imagePullSecrets`
- per-agent `imagePullPolicy`
- pod annotations / labels
- probes
- `lifecycle`
- ServiceAccount binding support

### Phase 2: pod composition hooks

- `initContainers`
- sidecars
- `extraVolumes`
- `extraVolumeMounts`
- extra ConfigMap / Secret injection patterns

### Phase 3: advanced / optional controls

- optional `pdb`
- optional `extraDeploy` / raw extra objects
- possibly chart-managed ServiceAccount / RBAC, if needed

For the "install tools" question specifically, the proposal recommends two clear paths:

1. **Custom image**
   the preferred path for stable, repeatable, production-grade toolchains

2. **`initContainers` + shared volume**
   a lightweight bootstrap path for small binaries or startup initialization

The practical outcome of this PR, if accepted, would be to align on the proposal first and follow up with a smaller implementation PR or phased implementation PRs.

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

### 1. Keep the chart minimal and add nothing

Rejected.

This keeps the chart simple, but it remains too restrictive for private registries, policy-heavy clusters, and common startup bootstrap use cases.

### 2. Add only `imagePullSecrets`

Rejected as the full answer.

It solves the most obvious gap, but still leaves the chart without probes, lifecycle hooks, pod composition hooks, and other common deployment controls.

### 3. Add only a generic `extraPodSpec`

Rejected as the main design.

It is flexible, but too opaque. It shifts too much chart knowledge onto the user. A smaller set of first-class fields plus a limited escape hatch is usually a better experience.

### 4. Model every possible Kubernetes field individually

Rejected.

That would cause the values schema to grow too quickly and become harder to maintain. A phased rollout is more realistic.

## Validation

- [ ] `cargo check` passes
- [ ] `cargo test` passes (including new tests)
- [x] Manual review of the current chart structure and deployment gaps
- [x] Prior art research across OpenClaw, Hermes Agent, Bitnami charts, Helm docs, and Kubernetes docs
- [x] Proposal / RFC documents prepared before implementation
- [ ] Screenshots, logs, or terminal output demonstrating the feature working end-to-end

Notes:

- This PR markdown is proposal-only and does not claim implementation is complete.
- The appropriate next step would be to align on scope first, then open an implementation PR using this proposal as the design basis.
