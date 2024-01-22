package plugin

import (
	"context"
	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/vault/sdk/logical"
	"github.com/stretchr/testify/require"
	"os"
	"testing"
)

const (
	envVarRunAccTests      = "VAULT_ACC"
	envVarCCloudKeyId      = "TEST_CCLOUD_KEY_ID"
	envVarCCloudSecret     = "TEST_CCLOUD_SECRET"
	envVarCCloudURL        = "TEST_CCLOUD_URL"
	envVarCCloudOwner      = "TEST_CCLOUD_OWNER"
	envVarCCloudEnv        = "TEST_CCLOUD_ENV_ID"
	envVarCCloudResourceId = "TEST_CCLOUD_RESOURCE_ID"
)

// getTestBackend will help you construct a test backend object. Update this function with your target backend.
func getTestBackend(testingBackground testing.TB) (*ccloudBackend, logical.Storage) {
	testingBackground.Helper()
	config := logical.TestBackendConfig()
	config.StorageView = new(logical.InmemStorage)
	config.Logger = hclog.NewNullLogger()
	config.System = logical.TestSystemView()

	factoryBackground, err := Factory(context.Background(), config)
	if err != nil {
		testingBackground.Fatal(err)
	}

	return factoryBackground.(*ccloudBackend), config.StorageView
}

// runAcceptanceTests will separate unit tests from
// acceptance tests, which will make active requests
// to your target API.
var runAcceptanceTests = os.Getenv(envVarRunAccTests) == "1"

// testEnv creates an object to store and track testing environment
// resources
type testEnv struct {
	KeyId       string
	Secret      string
	URL         string
	Owner       string
	OwnerEnv    string
	Resource    string
	ResourceEnv string

	Backend logical.Backend
	Context context.Context
	Storage logical.Storage

	// SecretToken tracks the API token, for checking rotations
	SecretToken string

	// Keys tracks the generated Cluster API keys, to make sure we clean up
	Keys []string
}

// AddConfig adds the configuration to the test backend. Make sure data includes all the configuration attributes you need and the `config` path!
func (testEnv *testEnv) AddConfig(testing *testing.T) {
	req := &logical.Request{
		Operation: logical.CreateOperation,
		Path:      "config",
		Storage:   testEnv.Storage,
		Data: map[string]interface{}{
			"ccloud_api_key_id":     testEnv.KeyId,
			"ccloud_api_key_secret": testEnv.Secret,
			"url":                   testEnv.URL,
		},
	}
	resp, err := testEnv.Backend.HandleRequest(testEnv.Context, req)
	require.Nil(testing, resp)
	require.Nil(testing, err)
}

// AddRole adds a role for CCloud Cluster API keys.
func (testEnv *testEnv) AddRole(testing *testing.T) {
	request := &logical.Request{
		Operation: logical.UpdateOperation,
		Path:      "role/testing",
		Storage:   testEnv.Storage,
		Data: map[string]interface{}{
			"owner":        testEnv.Owner,
			"owner_env":    testEnv.OwnerEnv,
			"resource":     testEnv.Resource,
			"resource_env": testEnv.ResourceEnv,
		},
	}
	response, err := testEnv.Backend.HandleRequest(testEnv.Context, request)
	require.Nil(testing, response)
	require.Nil(testing, err)
}

// ListRole lists the roles within the testing vault instance
func (testEnv *testEnv) ListRole(testing *testing.T) {
	request := &logical.Request{
		Operation: logical.ListOperation,
		Path:      "role",
		Storage:   testEnv.Storage,
		Data: map[string]interface{}{
			"owner":        testEnv.Owner,
			"owner_env":    testEnv.OwnerEnv,
			"resource":     testEnv.Resource,
			"resource_env": testEnv.ResourceEnv,
		},
	}
	response, err := testEnv.Backend.HandleRequest(testEnv.Context, request)
	require.NotNil(testing, response)
	require.Nil(testing, err)
}

// ReadRole retrieves the Cluster API key based on a Vault role.
func (testEnv *testEnv) ReadRole(testing *testing.T) {
	request := &logical.Request{
		Operation: logical.ReadOperation,
		Path:      "role/testing",
		Storage:   testEnv.Storage,
	}
	response, err := testEnv.Backend.HandleRequest(testEnv.Context, request)
	require.Nil(testing, err)
	require.NotNil(testing, response)

	require.Equal(testing, testEnv.Owner, response.Data["owner"].(string), "equals")
	require.Equal(testing, testEnv.OwnerEnv, response.Data["owner_env"].(string), "equals")
	require.Equal(testing, testEnv.Resource, response.Data["resource"].(string), "equals")
	require.Equal(testing, testEnv.ResourceEnv, response.Data["resource_env"].(string), "equals")
}
