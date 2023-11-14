#!/usr/bin/env bash
# accepts and forwards same args as go-test-wrapper.sh
# LOCAL_MODE_TEST_FAIL_CI controls pass/fail.
# LOCAL_MODE_BINARY_UNDER_TEST is the binary to test.

MK_INCLUDE_BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Fail CI if this test fails by setting to true
LOCAL_MODE_TEST_FAIL_CI=${LOCAL_MODE_TEST_FAIL_CI:-false}

if [ -z "${LOCAL_MODE_BINARY_UNDER_TEST}" ]; then
  echo "---------------------------------------------------------------------------"
  echo "❌ LOCAL_MODE_BINARY_UNDER_TEST is not defined; cannot run local mode test."
  echo "Learn more at https://go/local-mode"
  echo "---------------------------------------------------------------------------"
  # not a test failure, so not controlled by LOCAL_MODE_TEST_FAIL_CI.
  exit 1
fi

echo "-----------------------------------------------------------------------------------"
echo "💬 Project Pyramid: Running local mode test"
echo "LOCAL_MODE_BINARY_UNDER_TEST=${LOCAL_MODE_BINARY_UNDER_TEST}"
echo "LOCAL_MODE_TEST_FAIL_CI=${LOCAL_MODE_TEST_FAIL_CI}"
echo "Learn more at https://go/local-mode"
echo "-----------------------------------------------------------------------------------"

BINARY_BASENAME=$(basename "${LOCAL_MODE_BINARY_UNDER_TEST}")

# For services that prefer to rely on make target to test local mode:
# 1. write a test file that leverages the service-runtime-go library,
# 2. run the test to generate the JUnit report,
# 3. let testbreak collect the report.
# For more customization, use a go test file directly.
cat > ${PWD}/pyramid_localmode_${BINARY_BASENAME}_test.go <<EOF
package main_test

import (
	"testing"

	"github.com/confluentinc/service-runtime-go/libs/localmodetest"
)

func TestPyramidLocalMode(t *testing.T) {
	localmode := localmodetest.NewLocalModeTest("${LOCAL_MODE_BINARY_UNDER_TEST}", "localhost:6060")
	localmode.RunTest(t)
}
EOF

# update TEST_REPORT_FILE so it doesn't conflict with regular unit tests.
export TEST_REPORT_FILE="build/TEST-localmode-${BINARY_BASENAME}.xml"

# This step may fail if the service is not using service-runtime-go
# or a version that is too old.
${MK_INCLUDE_BIN}/go-test-wrapper.sh "$@" -run TestPyramidLocalMode
exit_code=$?

if [ -n "${SEMAPHORE_PROJECT_ID}" ]; then
  if [ -f "${LOCAL_MODE_BINARY_UNDER_TEST}.pyramid.log" ]; then
    artifact push job --force "${LOCAL_MODE_BINARY_UNDER_TEST}.pyramid.log"
  fi
  test-results publish "${TEST_REPORT_FILE}" --name "Pyramid Local Mode for ${LOCAL_MODE_BINARY_UNDER_TEST}"
fi

rm -f ${PWD}/pyramid_localmode_${BINARY_BASENAME}_test.go
if [ "${exit_code}" -ne 0 ] && [ "${LOCAL_MODE_TEST_FAIL_CI}" == "true" ]; then
  exit ${exit_code}
fi
exit 0
