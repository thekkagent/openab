# RFC 003: Helm Chart Extensibility for Real-World Kubernetes Deployments

| Field | Value |
|-------|-------|
| **RFC** | 003 |
| **Title** | Helm Chart Extensibility for Real-World Kubernetes Deployments |
| **Author** | @kirkchen0119 |
| **Status** | Draft |
| **Created** | 2026-04-15 |

---

## Summary

Expand the OpenAB Helm chart to support a standard Kubernetes extension surface suitable for real deployments.

The current chart is intentionally minimal, but it is missing many pod-level and operational controls that are common in mature open-source charts:

- `imagePullSecrets`
- container probes
- lifecycle hooks
- `initContainers`
- sidecars
- extra volumes and volume mounts
- pod labels and annotations
- ServiceAccount selection
- optional PodDisruptionBudget
- support for existing ConfigMaps and Secrets beyond the chart-managed ones

This RFC proposes a phased expansion of the chart so users can deploy OpenAB in private registries, policy-constrained clusters, and more opinionated production environments without forking the chart.

The proposal keeps one discipline intact:

- **Custom images remain the primary answer for stable toolchains**
- **Helm should expose Kubernetes extension points, not become a package manager**

## Motivation

OpenAB's current Helm chart works for the happy path, but starts to break down in ordinary cluster environments:

- Private registries require `imagePullSecrets`
- Security and policy layers often require pod annotations, labels, or ServiceAccounts
- Operators expect control over probes and lifecycle hooks
- Lightweight bootstrap tasks often need `initContainers`
- Existing cluster configuration is often stored in external ConfigMaps and Secrets

Without these extension points, users are pushed into one of three bad options:

1. Rebuild a custom image for every small environment-specific need
2. Patch rendered manifests after `helm template`
3. Fork the chart just to add standard Kubernetes fields

That is wasted friction. Mature Helm charts usually offer a broader but still disciplined values surface.

## Current State in OpenAB

OpenAB currently supports:

- global image repository, tag, and pull policy
- per-agent image override
- per-agent env, envFrom, resources, persistence, nodeSelector, tolerations, affinity
- chart-managed ConfigMap, Secret, PVC

OpenAB currently does not support:

- pod `imagePullSecrets`
- per-agent `imagePullPolicy`
- probes
- lifecycle hooks
- `initContainers`
- sidecars
- extra pod volumes and extra container volume mounts
- pod labels and annotations
- ServiceAccount selection
- chart-managed or optional RBAC objects
- PodDisruptionBudget
- generic raw extra objects such as extra ConfigMaps or Secrets

This gap is visible directly in the current chart:

- [charts/openab/values.yaml](/home/node/openab/charts/openab/values.yaml:1)
- [charts/openab/templates/deployment.yaml](/home/node/openab/charts/openab/templates/deployment.yaml:1)

## Prior Art and Industry Research

This RFC follows the contribution guidance proposed in PR #302: research first, implementation second.

### OpenClaw

OpenClaw does not currently ship a Helm chart in this repo, but its Kubernetes deployment manifests show one useful pattern clearly:

- it uses an `initContainer` to copy config and workspace bootstrap files into persistent storage before the main container starts

Reference:

- [openclaw/scripts/k8s/manifests/deployment.yaml](/home/node/openclaw/scripts/k8s/manifests/deployment.yaml:24)

What OpenClaw demonstrates:

- startup preparation is a first-class deployment concern
- `initContainers` are a reasonable place for config seeding and bootstrap work
- a hardened main container can stay simpler when initialization is split out

What OpenClaw does **not** provide here:

- a reusable Helm values interface for these behaviors

So OpenClaw is useful prior art for pod composition, not for chart UX.

### Hermes Agent

Hermes Agent takes a different approach. It solves "install extra tooling" primarily through the image and runtime environment model:

- its Docker image is intentionally broad and includes Python, Node.js, npm, ripgrep, ffmpeg, and Playwright
- its docs explicitly distinguish between immutable image installs and mutable runtime/container setups
- its Nix/container deployment docs acknowledge when users need a writable environment for `apt`, `pip`, or `npm`

References:

- [hermes-agent/Dockerfile](/home/node/hermes-agent/Dockerfile:12)
- [hermes-agent Docker docs](/home/node/hermes-agent/website/docs/user-guide/docker.md:195)
- [hermes-agent Nix setup docs](/home/node/hermes-agent/website/docs/getting-started/nix-setup.md:178)
- [hermes-agent Nix setup docs](/home/node/hermes-agent/website/docs/getting-started/nix-setup.md:594)
- [hermes-agent Nix setup docs](/home/node/hermes-agent/website/docs/getting-started/nix-setup.md:773)

What Hermes Agent demonstrates:

- serious toolchains belong in images or well-defined mutable runtime environments
- "install tools" is an environment design problem, not just a Helm templating problem

What Hermes Agent does **not** provide here:

- a direct Helm chart pattern to copy

So Hermes is strong prior art for deployment philosophy:

- custom image first
- runtime bootstrap only when justified

### Bitnami Charts

Bitnami charts are useful prior art for what the Helm community generally treats as a normal extension surface.

The Bitnami `postgresql` and `nginx` charts expose values such as:

- global `imagePullSecrets`
- `serviceAccount`
- `rbac`
- probes
- lifecycle hooks
- `initContainers`
- sidecars
- `extraVolumes`
- `extraVolumeMounts`
- `extraEnvVarsCM`
- `extraEnvVarsSecret`
- `extraDeploy`
- `pdb`

References:

- Bitnami PostgreSQL values:
  https://raw.githubusercontent.com/bitnami/charts/main/bitnami/postgresql/values.yaml
- Bitnami PostgreSQL statefulset template:
  https://raw.githubusercontent.com/bitnami/charts/main/bitnami/postgresql/templates/primary/statefulset.yaml
- Bitnami common image helpers:
  https://raw.githubusercontent.com/bitnami/charts/main/bitnami/common/templates/_images.tpl
- Bitnami common tpl merge/render helpers:
  https://raw.githubusercontent.com/bitnami/charts/main/bitnami/common/templates/_tplvalues.tpl
- Bitnami nginx values:
  https://raw.githubusercontent.com/bitnami/charts/main/bitnami/nginx/values.yaml

What Bitnami demonstrates:

- a mature chart usually exposes pod composition hooks
- raw Kubernetes fragments can be passed through values without re-modeling every field
- merge/render helpers help keep templates readable when chart surface area expands

This is the strongest prior art for Helm UX in this RFC.

### Helm and Kubernetes Best Practices

Relevant upstream guidance:

- Helm best practices emphasize a values structure that is predictable and easy to override
- Helm pod template guidance treats image, pull policy, selectors, and PodTemplate structure as ordinary chart concerns
- Kubernetes documents `initContainers` as the place for setup utilities or scripts not present in the app image
- Kubernetes documents `imagePullSecrets` as the standard pod-level mechanism for pulling from private registries

References:

- Helm Chart Best Practices:
  https://v3-1-0.helm.sh/docs/chart_best_practices/
- Helm Templates Best Practices:
  https://helm.sh/docs/next/chart_best_practices/templates/
- Helm Pods and PodTemplates:
  https://docs.helm.sh/zh/docs/chart_best_practices/pods/
- Helm RBAC Best Practices:
  https://helm.sh/docs/chart_best_practices/rbac/
- Kubernetes init containers:
  https://kubernetes.io/docs/concepts/workloads/pods/init-containers/
- Kubernetes private registry image pull:
  https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/

## Design Goals

- Add standard pod-level Helm extension points without breaking existing installs.
- Support private registry usage directly via values.
- Support lightweight startup bootstrap through documented `initContainers` patterns.
- Improve operational controls for health checks and lifecycle management.
- Allow integration with policy-heavy clusters that require metadata, ServiceAccounts, or extra mounted configuration.
- Keep defaults simple and safe.

## Non-Goals

- Turn the chart into a full deployment framework.
- Replace custom images as the preferred path for large or security-sensitive toolchains.
- Add RBAC objects by default when OpenAB does not currently require Kubernetes API access.
- Model every Kubernetes field individually if a generic pass-through hook is cleaner.

## Proposal

This RFC proposes a phased chart expansion grouped into four categories.

### 1. Core Pod Extensibility

Add support for:

- global `imagePullSecrets`
- per-agent `imagePullSecrets`
- per-agent `imagePullPolicy`
- global and per-agent `podAnnotations`
- global and per-agent `podLabels`
- per-agent `initContainers`
- per-agent `sidecars`
- per-agent `extraVolumes`
- per-agent `extraVolumeMounts`

These are the minimum standard hooks expected in a reusable chart.

### 2. Operational Controls

Add optional support for:

- per-agent `livenessProbe`
- per-agent `readinessProbe`
- per-agent `startupProbe`
- per-agent `lifecycle`
- per-agent `terminationGracePeriodSeconds`

Current OpenAB pods do not expose any probe configuration. That is too limiting for production operations, especially if future images or agents differ in startup characteristics.

### 3. Identity and Access Surface

Add support for:

- global and per-agent `serviceAccountName`
- optional chart-managed `serviceAccount.create`
- optional `serviceAccount.annotations`

Do **not** add Role or ClusterRole resources in phase 1 unless a concrete Kubernetes API permission need exists.

Rationale:

- many charts expose `serviceAccount` as standard
- not every app needs RBAC
- creating RBAC preemptively is worse than supporting an existing ServiceAccount first

### 4. Extra Configuration and Extra Objects

Add support for:

- per-agent `extraEnvVars`
- per-agent `extraEnvFrom`
- per-agent `extraEnvVarsCM`
- per-agent `extraEnvVarsSecret`
- optional chart-level `extraDeploy` or `extraObjects`

Rationale:

- "extra ConfigMap/Secret" is usually best expressed either as env injection or as raw extra objects
- mature charts rarely add one bespoke value for every possible ConfigMap and Secret use case
- `extraDeploy` is a common escape hatch, but it should stay optional and documented as advanced usage

### 5. Optional PodDisruptionBudget

Add optional:

- `pdb.create`
- `pdb.minAvailable`
- `pdb.maxUnavailable`

This should be disabled by default.

Rationale:

- PDB is a normal chart feature in the ecosystem
- but OpenAB currently deploys a single replica with `Recreate` strategy and usually a PVC-backed RWO workload
- a default PDB could block node drains without improving availability

So PDB belongs in the chart, but not as an always-on default.

## Recommended Values Shape

Keep the current chart layout, but extend it in a predictable way.

```yaml
image:
  repository: ghcr.io/openabdev/openab
  tag: ""
  pullPolicy: IfNotPresent

imagePullSecrets: []
podAnnotations: {}
podLabels: {}

serviceAccount:
  create: false
  name: ""
  annotations: {}

pdb:
  create: false
  minAvailable: ""
  maxUnavailable: ""

extraDeploy: []

agents:
  kiro:
    image: ""
    imagePullPolicy: ""
    imagePullSecrets: []

    podAnnotations: {}
    podLabels: {}

    serviceAccountName: ""

    extraEnvVars: []
    extraEnvFrom: []
    extraEnvVarsCM: ""
    extraEnvVarsSecret: ""

    initContainers: []
    sidecars: []
    extraVolumes: []
    extraVolumeMounts: []

    livenessProbe: {}
    readinessProbe: {}
    startupProbe: {}
    lifecycle: {}

    toolBootstrap:
      enabled: false
      path: /opt/openab-tools
      addToPath: true
```

## Merge Rules

The merge rules should stay boring.

- maps: global baseline merged with per-agent override, per-agent wins
- lists: per-agent replaces global unless explicitly documented otherwise
- empty string or empty object: fall back to default behavior

Do not invent complicated deep-merge behavior for lists. That is where Helm values become a nuisance.

## Tool Installation Guidance

This RFC recommends a two-lane strategy.

### Preferred Lane: Custom Image

Use a custom image when:

- the toolchain is stable
- tools are large or numerous
- startup time matters
- reproducibility matters
- security review matters

This follows the Hermes Agent philosophy and is the right production path.

### Supported Lane: `initContainers` Bootstrap

Use `initContainers` plus a shared volume when:

- you need one or two small binaries
- you need to seed a workspace or config
- the bootstrap logic is lightweight and deterministic

This follows the OpenClaw-style initialization split and Kubernetes guidance for setup utilities.

Example shape:

```yaml
agents:
  kiro:
    initContainers:
      - name: install-jq
        image: debian:bookworm-slim
        command:
          - bash
          - -lc
          - |
            apt-get update
            apt-get install -y --no-install-recommends ca-certificates curl
            mkdir -p /opt/openab-tools/bin
            curl -fsSL https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-linux-amd64 \
              -o /opt/openab-tools/bin/jq
            chmod +x /opt/openab-tools/bin/jq
        volumeMounts:
          - name: tool-bootstrap
            mountPath: /opt/openab-tools

    extraVolumes:
      - name: tool-bootstrap
        emptyDir: {}

    extraVolumeMounts:
      - name: tool-bootstrap
        mountPath: /opt/openab-tools

    toolBootstrap:
      enabled: true
      path: /opt/openab-tools
      addToPath: true
```

This should be documented as a convenience pattern, not sold as the primary installation mechanism.

## Why This Approach

This RFC chooses a middle path.

It does **not** propose:

- baking every possible deployment concern into one giant schema
- adding RBAC before it is needed
- defaulting on features like PDB that may be harmful for current single-replica behavior

It **does** propose:

- exposing the deployment hooks that the broader Helm ecosystem already treats as normal
- aligning OpenAB with chart patterns users already expect from Bitnami and similar projects
- separating runtime bootstrap from serious image design

This gives OpenAB a practical chart without turning it into a kitchen sink.

## Alternatives Considered

### A. Keep the chart minimal and require custom images for everything

Rejected.

This is defensible for internal charts, but too rigid for an open-source chart intended for varied environments. It also fails the basic private-registry use case because `imagePullSecrets` is still missing.

### B. Add only `imagePullSecrets`

Rejected.

This solves the most urgent gap, but leaves the chart much thinner than user expectations for probes, lifecycle hooks, pod metadata, and bootstrap patterns.

### C. Add a generic `extraPodSpec` and nothing else

Rejected as the primary design.

This is flexible, but too opaque. It pushes too much chart knowledge onto the user and makes documentation weaker. A small set of first-class fields plus a limited escape hatch is better.

### D. Add every possible Kubernetes field individually

Rejected.

This leads to schema sprawl. Some areas deserve first-class fields; others are better served by `extraDeploy`, `extraVolumes`, `extraEnvFrom`, and similar generic hooks.

## Phased Implementation Plan

### Phase 1: Highest-Value Gaps

- `imagePullSecrets`
- per-agent `imagePullPolicy`
- pod labels and annotations
- ServiceAccount binding
- probes
- lifecycle hooks

Why first:

- these cover private registry support, observability, policy compatibility, and operational health
- template risk is low
- value is immediate

### Phase 2: Pod Composition Hooks

- `initContainers`
- sidecars
- `extraVolumes`
- `extraVolumeMounts`
- `extraEnvVarsCM`
- `extraEnvVarsSecret`

Why second:

- these increase chart power significantly
- they require more template rendering discipline

### Phase 3: Advanced Escape Hatches

- `extraDeploy` or `extraObjects`
- optional chart-managed ServiceAccount
- optional PDB

Why third:

- these are useful, but easier to misuse
- they should be documented after the core chart surface is settled

### Phase 4: Optional RBAC

- `rbac.create`
- `rbac.rules`
- Role/RoleBinding, and only ClusterRole if a concrete feature requires cluster-scoped access

Why last:

- OpenAB does not currently demonstrate a clear Kubernetes API need
- RBAC should follow a feature requirement, not precede it

## Testing and Validation

Expand Helm template tests to cover at minimum:

1. global `imagePullSecrets`
2. per-agent `imagePullSecrets`
3. per-agent `imagePullPolicy`
4. probe rendering
5. lifecycle rendering
6. `initContainers`
7. sidecars
8. extra volumes and volume mounts
9. ServiceAccount selection
10. PDB rendering when enabled
11. `extraEnvVarsCM` and `extraEnvVarsSecret`
12. empty defaults preserving current manifest shape

Validation commands should include:

- `helm template`
- existing chart test scripts
- at least one rendered example for private registry usage
- at least one rendered example for `initContainers` bootstrap

## Security Considerations

- `imagePullSecrets` must live in the same namespace as the workload
- `initContainers` and sidecars increase the runtime surface and should be treated as advanced features
- a chart-managed ServiceAccount should not auto-create RBAC unless explicitly requested
- `extraDeploy` is powerful and should be documented accordingly
- startup-time install scripts are user-managed logic and outside the support boundary of the base chart

## Open Questions

1. Should `extraDeploy` be included in the first extensibility PR, or deferred until the core pod surface lands?
2. Should `serviceAccount.create` be included immediately, or should the first PR only support binding an existing ServiceAccount?
3. Should list-type values such as `imagePullSecrets` merge or replace? This RFC recommends replace.
4. Should OpenAB add `extraPodSpec` at all, or keep the surface narrower and more explicit?

## Recommendation

Approve the direction of this RFC and implement it in phases, starting with the highest-signal gaps:

- `imagePullSecrets`
- probes
- lifecycle hooks
- pod metadata
- ServiceAccount binding

Then add pod composition hooks:

- `initContainers`
- sidecars
- extra volumes and mounts

This gives OpenAB a chart that still feels simple, but no longer feels unfinished.
