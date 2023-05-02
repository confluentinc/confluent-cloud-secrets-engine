package plugin

import (
	"context"
	"github.com/hashicorp/vault/sdk/framework"
	"github.com/hashicorp/vault/sdk/logical"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestCloudClusterApiKeyReturnsAnIDandSecret(t *testing.T) {
	b := newBackend()
	var configExists = b.ccloudClusterApiKey()

	assert.NotNil(t, configExists.Fields["id"])
	assert.NotNil(t, configExists.Fields["secret"])
}

func TestRevokeTokenReturnsErrorGettingClient(t *testing.T) {
	b := newBackend()
	_, logicalStorage := getTestBackend(t)
	_, err := b.tokenRevoke(context.Background(), &logical.Request{
		Operation: logical.RevokeOperation,
		Path:      configStoragePath,
		Storage:   logicalStorage,
	},
		&framework.FieldData{})

	expectedErrorMsg := "error getting client: CCloud API Key ID not defined"
	assert.EqualErrorf(t, err, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, err)
}

// this doesn't work as client is nil
func TestRevokeTokenReturnsErrorGettingKeyId(t *testing.T) {
	b := newBackend()

	_, logicalStorage := getTestBackend(t)
	_, err := b.tokenRevoke(context.Background(), &logical.Request{
		Operation: logical.CreateOperation,
		Path:      "config",
		Storage:   logicalStorage,
		Data: map[string]interface{}{
			"ccloud_api_key_id":     apiKeyId,
			"ccloud_api_key_secret": apiKeySecret,
			"url":                   url,
		},
	},
		&framework.FieldData{})

	expectedErrorMsg := "invalid value for token in secret internal data"
	assert.EqualErrorf(t, err, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, err)
}
