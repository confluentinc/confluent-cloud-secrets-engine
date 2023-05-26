package plugin

import (
	"github.com/hashicorp/go-hclog"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestClientConfigReturnsErrorWhenConfigIsNil(t *testing.T) {
	_, clientError := newClient(nil, hclog.NewNullLogger())
	expectedErrorMsg := "Client configuration nil"
	assert.EqualErrorf(t, clientError, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, clientError)
}

func TestClientConfigReturnsErrorWhenCloudApiKeyIdIsNotDefined(t *testing.T) {
	testCloudConfig := &ccloudConfig{
		ApiKeyId:     "hashicorp-vault-plugin-testing",
		ApiKeySecret: "Testing!123",
		URL:          "http://localhost:19090",
	}

	clientResponse, _ := newClient(testCloudConfig, hclog.NewNullLogger())
	assert.NotNil(t, clientResponse)
}

func TestClientConfigReturnsResponseWhenApiKeySecretIsNotDefined(t *testing.T) {
	testCloudConfig := &ccloudConfig{
		ApiKeyId:     "hashicorp-vault-plugin-testing",
		ApiKeySecret: "",
		URL:          "http://localhost:19090",
	}
	_, clientError := newClient(testCloudConfig, hclog.NewNullLogger())
	expectedErrorMsg := "CCloud API Key Secret not defined"
	assert.EqualErrorf(t, clientError, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, clientError)
}

func TestClientConfigReturnsResponseWhenUrlIsNotDefined(t *testing.T) {
	testCloudConfig := &ccloudConfig{
		ApiKeyId:     "hashicorp-vault-plugin-testing",
		ApiKeySecret: "Testing!123",
		URL:          "",
	}
	_, clientError := newClient(testCloudConfig, hclog.NewNullLogger())

	expectedErrorMsg := "CCloud URL not defined"
	assert.EqualErrorf(t, clientError, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, clientError)
}

func TestClientConfigReturnsResponseWhenConfigIsNotNil(t *testing.T) {
	testCloudConfig := &ccloudConfig{
		ApiKeyId:     "hashicorp-vault-plugin-testing",
		ApiKeySecret: "Testing!123",
		URL:          "http://localhost:19090",
	}
	clientResponse, clientError := newClient(testCloudConfig, hclog.NewNullLogger())

	assert.NotNil(t, clientResponse)
	assert.Nil(t, clientError)
}
