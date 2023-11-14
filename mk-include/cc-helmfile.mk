# Common make targets for using https://github.com/roboll/helmfile
# Helmfile is a tool for automated git-ops style deployments

HELMFILES ?= $(strip $(shell find -type f -name helmfile.yaml -printf '%p '))

# Don't add helmfile-test to TEST_TARGETS since it introduces a potential dependency on Vault prod secrets
#TEST_TARGETS += helmfile-test

.PHONY: helmfile-test
helmfile-test: $(HELMFILES:%=helmfile-test.%)

# Run both `helmfile lint` and `helmfile template` since `helm lint` does not
# fail when required values are missing.
# Redirect `helmfile template` output to /dev/null to avoid leaking secrets in build logs
$(HELMFILES:%=helmfile-test.%):
	helmfile --file $(@:helmfile-test.%=%) template --skip-deps > /dev/null
	helmfile --file $(@:helmfile-test.%=%) lint --skip-deps

# You will typically need an aws-update-kubeconfig target in your project's Makefile and declare it as
# a prerequisite to helmfile-apply-ci.  For example:
# helmfile-apply: aws-update-kubeconfig
# aws-update-kubeconfig:
# 	aws eks update-kubeconfig --name k8s-mz-monitoring-eks--prod--796641d1f56d5fea --alias k8s-mz-monitoring-eks

.PHONY: helmfile-apply-ci
helmfile-apply: $(HELMFILES:%=helmfile-apply.%)

$(HELMFILES:%=helmfile-apply.%):
	helmfile --file $(@:helmfile-apply.%=%) apply --suppress-diff
