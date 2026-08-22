# homelab-service

An opinionated Helm chart for deploying relatively simple applications (Deployment, Service, Persistent Volume) while automatically handling the automation around that core: Traefik IngressRoutes, cert-manager certificates, Vault secrets, CNPG Databases, Prometheus ServiceMonitors, and Homepage dashboards.

## Requirements

- Kubernetes 1.25+
- Helm 3.x

### Chart Managed services

| Dependency | Required for |
|---|---|
| [Traefik](https://traefik.io/) | IngressRoute resources (`ingress.create`) |
| [cert-manager](https://cert-manager.io/) | TLS certificates (`ingress.create`) |
| [External Secrets Operator](https://external-secrets.io/) | ExternalSecret resources (`externalSecrets`) |
| [CloudNativePG](https://cloudnative-pg.io/) | Database resources (`databases`) |
| [Prometheus Operator](https://prometheus-operator.dev/) | ServiceMonitor resources (`monitoring.serviceMonitor`) |
| [external-dns](https://github.com/kubernetes-sigs/external-dns) | Automatic DNS records (`ingress.defaultRoute.externalDns`) |
| [Homepage](https://gethomepage.dev/) | Dashboard integration (`homepage`) |

## Installation

### Add the Helm repository

```bash
helm repo add homelab-charts https://atanaspamukchiev.github.io/charts
helm repo update
```

### Install the chart

```bash
helm install my-app homelab-charts/homelab-service -f values.yaml
```

## Quick start

A minimal `values.yaml` to deploy an application with ingress and TLS:

```yaml
topLevelDomain: example.com
subDomain: internal
clusterName: k3s

deployment:
  container:
    image: "ghcr.io/org/my-app:latest"
    ports:
      - name: http
        containerPort: 8080
        protocol: TCP

ingress:
  create: true
  issuer:
    name: letsencrypt-prod-issuer
```

This creates a Deployment, Service, Traefik IngressRoute, and cert-manager Certificate. The application is accessible at `my-app.internal.example.com`.

## Features

### Domain construction

Each deployed app gets assigned an FQDN as follows:
```
my-app.internal.example.com
└─────┘ └──────┘ └─────────┘
release subDomain topLevelDomain
```

### Traefik IngressRoute

Creates a Traefik IngressRoute (not standard Ingress) with HTTPS via cert-manager. Supports extra middlewares on the default route, and additional, separate IngressRoute objects for the same backend Service via `extraIngressRoutes`:

```yaml
ingress:
  create: true
  issuer:
    name: letsencrypt-prod-issuer
  defaultRoute:
    externalDns:
      enabled: true
    extraMiddlewares:
      - name: keycloak-openid
        namespace: traefik
```

#### TLS certificate modes (`ingress.tls.mode`)

- **`wildcard`** (default) — no per-app `Certificate` is created. The IngressRoute's TLS is left
  empty (`tls: {}`), so it falls back to the cluster's Traefik `TLSStore` default certificate — a
  single wildcard cert covering every app on that cluster. `extraIngressRoutes` entries that set
  `certificateHostname` still get a `Certificate` of their own (for hostnames outside the
  cluster's own domain, e.g. `auth.example.com`, or outside whichever tier's wildcard covers
  them), and that IngressRoute's `tls.secretName` is set accordingly — the default route's
  hostname still falls back to the TLSStore default via SNI.
- **`perHost`** — the pre-wildcard-cert behavior: every app gets its own `Certificate`, and
  `tls.secretName` on the IngressRoute always points to it. Set this per-cluster until that
  cluster's Traefik has a `TLSStore` default certificate configured.

### Vault secrets

Integrates with HashiCorp Vault via the External Secrets Operator. Secrets are synced from Vault KV-v2 (through the `vault-backend` ClusterSecretStore) into Kubernetes Secrets:

```yaml
externalSecrets:
  - name: "{{ $.Release.Name }}"
    path: software/{{ $.Values.clusterName }}/{{ $.Release.Name }}
    refreshInterval: 300s
```

### CloudNativePG databases

Creates CNPG Database resources targeting an existing PostgreSQL cluster:

```yaml
databases:
  - name: "{{ $.Release.Name }}"
    owner: "{{ $.Release.Name }}-owner"
    targetClusterName: shared
    targetClusterNamespace: cnpg
    reclaimPolicy: retain
```

### Monitoring

**ServiceMonitor** for Prometheus Operator:

```yaml
monitoring:
  serviceMonitor:
    create: true
    port: monitoring
    interval: 1m
    scrapeTimeout: 10s
```

**Exportarr sidecar** for *arr-stack applications (Sonarr, Radarr, etc.) — injects a sidecar container exposing Prometheus metrics on port 9707:

```yaml
monitoring:
  exportarr:
    create: true
    version: v2.0.1
    apiKeySecretName: "api_key"
```

### Homepage dashboard integration

Adds [gethomepage.dev](https://gethomepage.dev/) annotations to the IngressRoute:

```yaml
homepage:
  enabled: true
  name: "{{ $.Release.Name }}"
  icon: "{{ $.Release.Name }}"
  group: services
  weight: "10"
```

### RBAC

Optionally create a ServiceAccount, ClusterRole, and ClusterRoleBinding:

```yaml
serviceAccount:
  create: true
  secret:
    create: true

clusterRole:
  rules:
    - apiGroups: [""]
      resources: ["namespaces", "pods", "nodes"]
      verbs: ["get", "list"]

clusterRoleBinding:
  role: "{{ $.Release.Name }}"
  serviceAccount:
    name: "{{ $.Release.Name }}"
    namespace: "{{ $.Release.Namespace }}"
```

### Jobs

One-off batch jobs with optional ArgoCD hook annotations:

```yaml
job:
  enabled: true
  name: db-migrate
  command: ["python"]
  args: ["manage.py", "migrate"]
  annotations:
    argocd.argoproj.io/hook: PreSync
```

### Template rendering in values

Values containing `{{ }}` template expressions are rendered at deploy time. This allows dynamic references throughout and thus fewer values overrides.

```yaml
externalSecrets:
  - name: "{{ $.Release.Name }}"
    path: software/{{ $.Values.clusterName }}/{{ $.Release.Name }}

databases:
  - name: "{{ $.Release.Name }}"
    owner: "{{ $.Release.Name }}-owner"
```

### Extensibility

Two additional extension points beyond the built-in resources:

1. **Extra deployments** — additional Deployment specs via `extraDeployments[]`
Useful when some apps require a second deployment to function correctly.
2. **Extra objects** — arbitrary Kubernetes manifests via `extraObjects[]`, rendered with template support
Catch all for any apps that require special Kubernetes resources

```yaml
extraObjects:
  - apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: extra-data
      namespace: "{{ $.Release.Namespace }}"
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
```

## Design decisions

This chart is opinionated for homelab use:

- **Recreate strategy** instead of rolling updates — suitable for single-replica workloads without zero-downtime requirements
- **Traefik IngressRoute** instead of standard Ingress — native Traefik CRD support with middleware chaining
- **ExternalSecret** instead of native Secrets — centralized secret management via HashiCorp Vault + External Secrets Operator
- **Revision history limit of 2** — conserves etcd storage in small clusters

## Development

A `Makefile` is provided in the repo root with common targets (`make lint`, `make test`, `make template`, `make validate`, `make all`).

Unit tests require the helm-unittest plugin: `helm plugin install https://github.com/helm-unittest/helm-unittest`

```bash
# Lint the chart
helm lint charts/homelab-service

# Run unit tests
helm unittest charts/homelab-service

# Render with custom values
helm template my-app ./charts/homelab-service --namespace test -f values.yaml

# Validate against Kubernetes schemas
helm template charts/homelab-service > rendered.yaml
docker run --rm -v $(pwd):/work ghcr.io/yannh/kubeconform:latest \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  /work/rendered.yaml
```
