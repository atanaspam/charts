# Homelab Helm Charts

My personal Helm charts.

## Available charts

| Chart | Description |
|---|---|
| [homelab-service](charts/homelab-service/) | A generic chart for deploying homelab applications with batteries included |

## Usage

### Add the repository

```bash
helm repo add homelab-charts https://atanaspamukchiev.github.io/charts
helm repo update
```

### Install a chart

```bash
helm install my-app homelab-charts/homelab-service -f values.yaml
```

See each chart's README for detailed configuration options.

## Development

### Rendering templates

```bash
# With default values
helm template charts/homelab-service

# With test values
helm template test-svc ./charts/homelab-service --namespace test --create-namespace --values test-values.yaml

# Debug invalid YAML
helm template test-svc ./charts/homelab-service --values test-values.yaml --debug
```

### Schema validation

```bash
helm template charts/homelab-service > rendered.yaml
docker run --rm -v $(pwd):/work ghcr.io/yannh/kubeconform:latest \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  /work/rendered.yaml
```
