APP_NAME := terraform-enterprise
APP_NAMESPACE := terraform-enterprise

.PHONY: install
install:
	helm install -n ${APP_NAMESPACE} ${APP_NAME} hashicorp/terraform-enterprise --values overrides.yaml --values secrets.yaml

.PHONY: template
template:
	helm template -n ${APP_NAMESPACE} --release_name ${APP_NAME} hashicorp/terraform-enterprise --values overrides.yaml --secrets.yaml

.PHONY: uninstall
uninstall:
	helm uninstall -n ${APP_NAMESPACE} ${APP_NAME}

.PHONY: upgrade
upgrade:
	helm upgrade -n ${APP_NAMESPACE} ${APP_NAME} hashicorp/terraform-enterprise --values overrides.yaml --values secrets.yaml
