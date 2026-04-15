# Proposal: Helm Chart Extensibility for Real-World Kubernetes Deployments

## Summary

OpenAB's Helm chart is currently optimized for a minimal install path, but it is missing many deployment extension points that operators typically expect from a reusable open-source chart.

This proposal suggests expanding the chart in phases so it can better support:

- private registry deployments
- startup bootstrap workflows
- policy-heavy or production-oriented Kubernetes clusters
- common pod-level customization without requiring users to fork the chart

The intended direction is:

- keep the default chart simple
- expose standard Kubernetes extension points directly in the chart
- treat custom images as the primary answer for stable toolchains
- support `initContainers` bootstrap as a lightweight complement, not the main packaging model

## What problem does this solve?

Today, the OpenAB Helm chart does not expose many common deployment controls that operators expect in real Kubernetes environments.

Examples include:

- `imagePullSecrets`
- probes (`livenessProbe`, `readinessProbe`, `startupProbe`)
- `lifecycle`
- `initContainers`
- sidecars
- extra volumes / volume mounts
- `serviceAccount`
- PodDisruptionBudget
- extra ConfigMap / Secret injection patterns
- other common pod-level deployment settings that are currently not exposed

This leaves users with a few unattractive options:

1. rebuild a custom image for relatively minor deployment-specific needs
2. patch rendered manifests after `helm template`
3. fork the chart just to add standard Kubernetes fields

One immediate example is that the chart does not currently support `imagePullSecrets`, which makes private registry deployments harder than they need to be.

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
│ Proposal                     │
│ phased Helm extensibility    │
│ for real-world Kubernetes    │
│ deployments                  │
└──────────────────────────────┘
```

## Prior Art & Industry Research

### OpenClaw

I reviewed the local OpenClaw repository and its Kubernetes deployment manifests.

While OpenClaw does not currently expose a Helm chart in this repo, it does treat startup bootstrap as a first-class deployment concern. In particular, it uses an `initContainer` to prepare configuration and workspace state before the main container starts.

This suggests:

- `initContainers` are a reasonable place for startup preparation
- bootstrap logic should be treated as deployment design, not an ad hoc workaround
- a hardened main container can stay simpler when initialization is separated

Reference:

- `scripts/k8s/manifests/deployment.yaml`

### Hermes Agent

I also reviewed Hermes Agent's Docker and deployment documentation.

Hermes takes a clearer stance on tool installation: stable toolchains should primarily be handled through custom images or clearly defined mutable runtime environments, not by stretching the chart into a package manager.

This suggests:

- serious toolchains should prefer custom images
- runtime bootstrap can exist, but it should stay lightweight and bounded
- Helm should expose deployment extension points, not replace image design

References:

- `Dockerfile`
- `website/docs/user-guide/docker.md`
- `website/docs/getting-started/nix-setup.md`

### Other references

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

That does not mean OpenAB needs to implement everything immediately, but it does show the normal shape of a production-oriented Helm chart in the wider ecosystem.

## Proposed Solution

I would like to propose a phased expansion of the OpenAB Helm chart so it exposes a more standard Kubernetes extension surface, instead of requiring users to fork the chart for ordinary deployment needs.

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

For the "install tools" question specifically, I think the chart should support two clear paths:

1. **Custom image**
   the preferred path for stable, repeatable, production-grade toolchains

2. **`initContainers` + shared volume**
   a lightweight bootstrap path for small binaries or startup initialization

## Why this approach?

I do not think OpenAB should turn its chart into a giant schema or try to model every Kubernetes field at once.

At the same time, the current chart is thin enough that users are pushed toward forking it for fairly normal deployment requirements. That is unnecessary friction.

This proposal tries to take the middle path:

- keep the chart simple by default
- add the extension points that operators commonly expect
- keep custom images as the primary answer for serious tool installation
- treat `initContainers` bootstrap as a lightweight complement, not the main packaging model

That feels closer to how open-source Helm charts are usually expected to evolve.

## Alternatives Considered

### 1. Keep the chart minimal and add nothing

Not recommended.

This keeps the chart simple, but it remains too restrictive for private registries, policy-heavy clusters, and normal startup bootstrap use cases.

### 2. Add only `imagePullSecrets`

Not recommended as the complete answer.

It solves the most obvious gap, but still leaves the chart without probes, lifecycle hooks, pod composition hooks, and other common deployment controls.

### 3. Add only a generic `extraPodSpec`

Not recommended as the primary design.

It is flexible, but too opaque. It shifts too much chart knowledge onto the user. A small set of first-class fields plus a limited escape hatch is usually a better user experience.

### 4. Model every possible Kubernetes field individually

Not recommended.

That would cause the values schema to grow too quickly and become harder to maintain. A phased rollout is more realistic.

## Open Questions

1. Would maintainers be open to expanding the OpenAB chart toward a more standard Helm / Kubernetes extensibility surface?
2. Should `imagePullSecrets`, probes, lifecycle hooks, and ServiceAccount binding be the first priority?
3. Should `initContainers`, sidecars, and extra volumes / mounts be handled as a second phase?
4. Should `pdb`, `extraDeploy`, and RBAC be deferred so the chart does not grow too quickly?
5. For extra ConfigMap / Secret support, would maintainers prefer:
   - explicit fields such as `extraEnvVarsCM` / `extraEnvVarsSecret`
   - or a more generic `extraDeploy` / `extraObjects` style escape hatch?

If this direction seems reasonable, I can follow up with a more concrete values schema and template change proposal before opening an implementation PR.
