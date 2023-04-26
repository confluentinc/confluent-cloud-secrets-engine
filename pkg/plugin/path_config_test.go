package plugin

import (
	"context"
	"github.com/hashicorp/vault/sdk/logical"
	"github.com/stretchr/testify/assert"
	"testing"
)

const (
	apiKeyId     = "vault-plugin-testing"
	apiKeySecret = "Testing!123"
	url          = "http://localhost:19090"
)

/*
*
Using t as the go testing variable is the standard.
*/
func TestPathConfigExistenceCheck(t *testing.T) {
	b := newBackend()

	configExists := pathConfig(b)
	assert.NotNil(t, configExists.ExistenceCheck)
}

func TestConfigDeleteReturnsNoErrors(t *testing.T) {
	logicalBackend, logicalStorage := getTestBackend(t)
	resp, err := logicalBackend.HandleRequest(context.Background(), &logical.Request{
		Operation: logical.DeleteOperation,
		Path:      configStoragePath,
		Storage:   logicalStorage,
	})

	assert.NoError(t, err)
	assert.Nil(t, resp)

}

func TestConfigCreateReturnsNoErrors(t *testing.T) {
	logicalBackend, logicalStorage := getTestBackend(t)
	var expectedData = map[string]interface{}{
		"ccloud_api_key_id":     apiKeyId,
		"ccloud_api_key_secret": apiKeySecret,
		"url":                   url,
	}
	resp, err := logicalBackend.HandleRequest(context.Background(), &logical.Request{
		Operation: logical.CreateOperation,
		Path:      configStoragePath,
		Data:      expectedData,
		Storage:   logicalStorage,
	})

	assert.NoError(t, err)
	assert.Nil(t, resp)
}

func TestConfigUpdateReturnsNoErrors(t *testing.T) {
	logicalBackend, logicalStorage := getTestBackend(t)
	var expectedData = map[string]interface{}{
		"ccloud_api_key_id":     apiKeyId,
		"ccloud_api_key_secret": apiKeySecret,
		"url":                   "http://ccloud:19090",
	}
	resp, err := logicalBackend.HandleRequest(context.Background(), &logical.Request{
		Operation: logical.UpdateOperation,
		Path:      configStoragePath,
		Data:      expectedData,
		Storage:   logicalStorage,
	})

	assert.NoError(t, err)
	assert.Nil(t, resp)

}

func TestConfigReadReturnsNoErrors(t *testing.T) {
	logicalBackend, logicalStorage := getTestBackend(t)
	var expectedData = map[string]interface{}{
		"ccloud_api_key_id":     apiKeyId,
		"ccloud_api_key_secret": apiKeySecret,
		"url":                   "http://ccloud:19090",
	}
	resp, err := logicalBackend.HandleRequest(context.Background(), &logical.Request{
		Operation: logical.ReadOperation,
		Path:      configStoragePath,
		Data:      expectedData,
		Storage:   logicalStorage,
	})

	assert.NoError(t, err)
	assert.NotNil(t, resp)
}
