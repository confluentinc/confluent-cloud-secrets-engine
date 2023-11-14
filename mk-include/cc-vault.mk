VAULT_INSTALLED_VERSION := $(shell vault -version 2>/dev/null | head -n 1 | awk '{ print $$2 }')

.PHONY: install-vault
install-vault:
ifndef VAULT_INSTALLED_VERSION
	@echo "vault is unexpectedly not installed"
	@exit 1
endif
