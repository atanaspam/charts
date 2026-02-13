CHART_DIR := charts/homelab-service

.PHONY: lint test template template-test validate all

lint:
	helm lint $(CHART_DIR)

test:
	helm unittest $(CHART_DIR)

template:
	helm template $(CHART_DIR)

template-test:
	helm template test-svc $(CHART_DIR) --namespace test --create-namespace --values test-values.yaml

validate: template
	helm template $(CHART_DIR) > rendered.yaml
	docker run --rm -v $(PWD):/work ghcr.io/yannh/kubeconform:latest \
		-schema-location default \
		-schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
		/work/rendered.yaml
	rm -f rendered.yaml

all: lint test
