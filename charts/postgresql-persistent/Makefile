APP_NAME := postgresql-persistent
APP_NAMESPACE := terraform-enterprise

.PHONY: install test uninstall upgrade
install:
	helm install -n ${APP_NAMESPACE} ${APP_NAME} .

.PHONY: test
test:
	helm template -n ${APP_NAMESPACE} --release-name ${APP_NAME} .

.PHONY: uninstall
uninstall:
	helm uninstall -n ${APP_NAMESPACE} ${APP_NAME}

.PHONY: upgrade
upgrade:
	helm upgrade -n ${APP_NAMESPACE} ${APP_NAME} .
