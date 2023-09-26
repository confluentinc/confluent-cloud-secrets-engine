SOPS_VERSION ?= 3.7.3
SOPS_ARTIFACT_VERSION := v$(SOPS_VERSION)

INIT_CI_TARGETS += install-sops

SOPS_INSTALLED_VERSION := $(shell $(BIN_PATH)/sops --version 2>/dev/null | head -n 1 | awk '{ print $$2 }')
SOPS_OS := $(shell uname | tr A-Z a-z)

.PHONY: show-sops
show-sops:
	@echo "SOPS_VERSION: $(SOPS_VERSION)"
	@echo "SOPS_INSTALLED_VERSION: $(SOPS_INSTALLED_VERSION)"
	@echo "SOPS_OS: $(SOPS_OS)"

.PHONY: install-sops
install-sops:
ifneq ($(SOPS_VERSION),$(SOPS_INSTALLED_VERSION))
	@echo "Installing sops $(SOPS_ARTIFACT_VERSION)..."
	@wget -q -O $(BIN_PATH)/sops https://github.com/mozilla/sops/releases/download/$(SOPS_ARTIFACT_VERSION)/sops-$(SOPS_ARTIFACT_VERSION).$(SOPS_OS)
	@chmod +x $(BIN_PATH)/sops
endif
