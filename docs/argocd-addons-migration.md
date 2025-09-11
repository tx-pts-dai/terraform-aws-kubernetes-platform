# ArgoCD Addons Migration Guide

## Overview

This guide documents the migration process for deploying Kubernetes cluster addons using ArgoCD ApplicationSets with a label-based enablement strategy. This approach provides a scalable, GitOps-driven method for managing cluster tooling across multiple environments.

## Architecture

### Core Components

1. **Main Application**: `cluster-tools-apps` in `/configs/cluster-tools/cluster-tools.yaml`
   - Manages all addon ApplicationSets
   - Recursively processes all `appset.yaml` files in the apps directory
   - Deployed to the `argocd` namespace

2. **ApplicationSets**: Individual addon configurations in `/configs/cluster-tools/apps/`
   - Each addon has its own directory with an `appset.yaml`
   - Uses cluster generator with label selectors
   - Supports environment and team-specific configurations

### Label-Based Addon Installation

Addons are automatically deployed to clusters based on labels. Each addon's ApplicationSet uses a cluster generator that matches specific labels:

```yaml
generators:
- clusters:
    selector:
      matchLabels:
        enable-<addon-name>: "true"
```

## Migration Process

### Step 1: Prepare Cluster Labels

Label your clusters in ArgoCD to enable specific addons:


### Step 2: Create Addon ApplicationSet

For each addon, create a directory structure:

```
configs/cluster-tools/apps/<addon-name>/
├── appset.yaml           # ApplicationSet definition
├── values.yaml           # Default values (optional)
├── values-<env>.yaml     # Environment-specific values (optional)
└── values-<team>.yaml    # Team-specific values (optional)
└── values-<team>-<env>.yaml # Team and environment specific values (optional)
```

Example ApplicationSet template (`appset.yaml`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: <addon-name>
  namespace: argocd
  labels:
    team: platform
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - clusters:
      selector:
        matchLabels:
          enable-<addon-name>: "true"
  template:
    metadata:
      name: "{{.nameNormalized}}-<addon-name>"
      labels:
        team: "{{.metadata.labels.team}}"
        app: <addon-name>
        environment: "{{.metadata.labels.environment}}"
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: cluster-tools
      sources:
      - repoURL: <helm-chart-repo>
        chart: <chart-name>
        targetRevision: <version>
        helm:
          releaseName: <addon-name>
          namespace: <target-namespace>
          valueFiles:
          - $values/values.yaml
          - $values/values-{{.metadata.labels.environment}}.yaml
          - $values/values-{{.metadata.labels.team}}.yaml
          - $values/values-{{.metadata.labels.team}}-{{.metadata.labels.environment}}.yaml
          ignoreMissingValueFiles: true
      - repoURL: https://github.com/dnd-it/fission-argocd.git
        targetRevision: HEAD
        path: configs/cluster-tools/apps/<addon-name>
        directory:
          exclude: appset.yaml
        ref: values
      destination:
        server: "{{.server}}"
        namespace: <target-namespace>
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
          allowEmpty: true
        syncOptions:
          - CreateNamespace=true
          - ApplyOutOfSyncOnly=true
          - PruneLast=true
          - SkipDryRunOnMissingResource=true
          - ServerSideApply=true
```

### Step 3: Configure Values Hierarchy

The system supports a hierarchical values configuration:

1. `values.yaml` - Base configuration for all deployments
2. `values-<environment>.yaml` - Environment-specific overrides (dev, staging, production)
3. `values-<team>.yaml` - Team-specific configurations
4. `values-<team>-<environment>.yaml` - Team and environment specific combinations

Files are merged in order, with later files overriding earlier ones. Missing files are ignored (`ignoreMissingValueFiles: true`).
