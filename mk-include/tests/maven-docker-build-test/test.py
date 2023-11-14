'''
maven docker build process:
- make init-ci
- make build
test mvn-docker-package
test BUILD_DOCKER_OVERRIDE
- make test
- make release-ci
- make epilogue-ci
'''
import pytest
import structlog

structlog.configure(logger_factory=structlog.stdlib.LoggerFactory())

from tests.test_utils import *


def test_version():
    assert_version()


def test_version_filter():
    assert_filtered_version()


def test_make_show_args():
    output, stderr = run_cmd("make show-args")
    assert_in_output(output, stderr, [
        "cache-docker-base-images",
        "deps",
        "docker-login-ci",
        "gcloud-install",
    ])


def test_make_init_ci():
    output, stderr = run_cmd("make init-ci")
    assert_in_output(output, stderr, [
        "cache restore 519856050701.dkr.ecr.us-west-2.amazonaws.com/docker/prod/confluentinc/cc-base:v18.6.0",
    ])
    assert_file(["/home/semaphore/.docker/config.json"])


def test_make_build():
    output, stderr = run_cmd("make build")
    assert_in_output(output, stderr, ["mvnw", "BUILD SUCCESS", "docker image save"])


def test_build_docker_override_one():
    output, stderr = run_cmd("make -f Makefile_test_mvn_docker_package build")
    assert_not_in_output(output, stderr, ["mvnw"])
    assert_in_output(output, stderr, ["BUILD SUCCESS", "docker image save"])


def test_build_docker_override_two():
    output, stderr = run_cmd("make -f Makefile_test_BUILD_DOCKER_OVERRIDE build")
    assert_not_in_output(output, stderr, ["mvnw"])
    assert_in_output(output, stderr, [
        "mvn --no-transfer-progress  --batch-mode", "BUILD SUCCESS",
        "docker image save"
    ])


def test_make_test():
    output, stderr = run_cmd("make test")
    assert_in_output(output, stderr, ["T E S T S", "BUILD SUCCESS"])


def test_make_release():
    # make build adds dirty changes to the repo, and $(GIT) is aliased to echo git for tests, so those
    # dirty changes are never cleaned up. So manually clean it up here
    run_cmd("git stash")

    output, stderr = run_cmd("make release-ci")
    assert_not_in_output(output, stderr, [
        "Changes not staged for commit:",
        "recipe for target 'pre-release-check' failed"
    ])
    assert_in_output(output, stderr, [
        "git add --verbose ./pom.xml", "git add release.svg",
    ])


def test_make_epilogue_ci():
    run_cmd("make epilogue-ci")
