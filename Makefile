UPDATE_MK_INCLUDE := true
UPDATE_MK_INCLUDE_AUTO_MERGE := true

GO_BINS = github.com/confluentinc/pie-cc-hashicorp-vault-plugin/cmd/plugin=hashicorp-vault-ccloud-secrets-engine
#GO_USE_VENDOR ?= -mod=vendor


include ./mk-include/cc-begin.mk
include ./mk-include/cc-semaphore.mk
include ./mk-include/cc-semver.mk
include ./mk-include/cc-go.mk
include ./mk-include/cc-end.mk

# Disable CGO by default, to allow static binaries
export CGO_ENABLED := 0
