UPDATE_MK_INCLUDE := true
UPDATE_MK_INCLUDE_AUTO_MERGE := true

GO_BINS = github.com/confluentinc/pie-cc-hashicorp-vault-plugin/cmd/plugin=vault-ccloud-secrets-engine

include ./mk-include/cc-begin.mk
include ./mk-include/cc-semaphore.mk
include ./mk-include/cc-semver.mk
include ./mk-include/cc-go.mk
include ./mk-include/cc-end.mk
