UPDATE_MK_INCLUDE := true
UPDATE_MK_INCLUDE_AUTO_MERGE := true

GO_BINS = github.com/confluentinc/cire-vault-plugin-ccloud/cmd/plugin=vault-ccloud-secrets-engine
#GO_USE_VENDOR ?= -mod=vendor

include ./mk-include/cc-begin.mk
include ./mk-include/cc-semaphore.mk
include ./mk-include/cc-semver.mk
include ./mk-include/cc-go.mk
include ./mk-include/cc-end.mk
