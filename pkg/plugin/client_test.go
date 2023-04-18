package plugin

import (
	"github.com/hashicorp/go-hclog"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestClientConfigReturnsErrorWhenConfigIsNil(t *testing.T) {
	_, error := newClient(nil, hclog.NewNullLogger())
	expectedErrorMsg := "Client configuration nil"
	assert.EqualErrorf(t, error, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, error)
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
	_, error := newClient(testCloudConfig, hclog.NewNullLogger())
	expectedErrorMsg := "CCloud API Key Secret not defined"
	assert.EqualErrorf(t, error, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, error)
}

func TestClientConfigReturnsResponseWhenUrlIsNotDefined(t *testing.T) {
	testCloudConfig := &ccloudConfig{
		ApiKeyId:     "hashicorp-vault-plugin-testing",
		ApiKeySecret: "Testing!123",
		URL:          "",
	}
	_, error := newClient(testCloudConfig, hclog.NewNullLogger())

	expectedErrorMsg := "CCloud URL not defined"
	assert.EqualErrorf(t, error, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, error)
}

func TestClientConfigReturnsResponseWhenConfigIsNotNil(t *testing.T) {
	testCloudConfig := &ccloudConfig{
		ApiKeyId:     "hashicorp-vault-plugin-testing",
		ApiKeySecret: "Testing!123",
		URL:          "http://localhost:19090",
	}
	clientResponse, error := newClient(testCloudConfig, hclog.NewNullLogger())

	assert.NotNil(t, clientResponse)
	assert.Nil(t, error)
}

func TestCreateApiKey(t *testing.T) {

}
