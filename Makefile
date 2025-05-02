.SHELL := /usr/bin/bash
.EXPORT_ALL_VARIABLES:

export TF_IN_AUTOMATION = 1
export README_INCLUDES ?= $(file://$(shell pwd)/?type=text/plain)

WIZ_POLICIES="Dan - Demo Vulnerabilities Policy,Dan - Sensitive Data Default"

help:
	@grep -E '^[a-zA-Z_-_\/]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## Build website
	@docker buildx build --platform linux/amd64 . -t ifunky/site:latest
	#@docker image inspect ifunky/site:latest

deploy: ## Deploy website
	@helm upgrade secsite-hugo ./helm/ifunky-secsite --debug \
		--namespace=ifunky \
		--create-namespace \
		--wait \
		--install \
		--values helm/ifunky-secsite/values.yaml \
		--set image.repository=ifunky/site \
		--set image.tag=latest

scan/layers: ## Scan image with mount and layers
	@docker run --security-opt apparmor:unconfined --cap-add SYS_ADMIN -v /var/lib/docker:/var/lib/docker -v /var/run/docker.sock:/var/run/docker.sock -v ~/.wiz:/cli wiziocli.azurecr.io/wizcli:latest docker scan --image ifunky/site:latest --driver mountWithLayers

scan/dir: ## Scan image
	wizcli dir scan  --sensitive-data  --policy 'Dan - Sensitive Data Default' --path . $(if $(WIZ_PROJECT),--project $(WIZ_PROJECT))

scan: scan/dir ## Scan image
	@wizcli docker scan \
		--sensitive-data=true \
		--secrets \
		--policy $(WIZ_POLICIES) \
		--image ifunky/site:latest \
		--dockerfile Dockerfile \
		$(if $(WIZ_PROJECT),--project $(WIZ_PROJECT))

scan/help: ## 📘 Help for scan target
	@echo "🔍  Usage: make scan [WIZ_PROJECT=your-project-name] [WIZ_POLICIES=your-policy-name]"
	@echo ""
	@echo "💡  Description:"
	@echo "    Scans the Docker image 'ifunky/site:latest' using Wiz CLI with optional project and policies."
	@echo ""
	@echo "⚙️  Options:"
	@echo "    WIZ_PROJECT   – (optional) Project name to associate with the scan"
	@echo "    WIZ_POLICIES  – (optional) Comma-separated list of policy IDs to evaluate"
	@echo ""
	@echo "✅  Example:"
	@echo "    WIZ_PROJECT=my-app WIZ_POLICIES=default make scan"

sbom: ## Generate an SBOM report
	wizcli dir scan --sbom-format cyclonedx-json --sbom-output-file sbom.json  --sensitive-data  --policy 'Dan - Sensitive Data Default' --path .

delete: ## Deploy website
	@helm uninstall secsite-hugo \
		--namespace=ifunky 

run: ## Run site in docker
	echo "Goto http://localhost:8080/"
	docker run -p 8080:80 ifunky/site

push: ## Piush to docker repo
	docker tag ifunky/site:latest ifunky/site:latest
	docker push ifunky/site:latest
	wizcli docker tag -i ${IMAGE_REPO}:${IMAGE_TAG}