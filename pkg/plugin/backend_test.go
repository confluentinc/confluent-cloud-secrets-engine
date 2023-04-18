package plugin

import (
	"context"
	"os"
	"testing"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/vault/sdk/logical"
	"github.com/stretchr/testify/require"
)

const (
	envVarRunAccTests  = "VAULT_ACC"
	envVarCCloudKeyId  = "TEST_CCLOUD_KEY_ID"
	envVarCCloudSecret = "TEST_CCLOUD_SECRET"
	envVarCCloudURL    = "TEST_CCLOUD_URL"
	envVarCCloudOwner  = "TEST_CCLOUD_OWNER"
)

// getTestBackend will help you construct a test backend object.
// Update this function with your target backend.
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
	KeyId  string
	Secret string
	URL    string
	Owner  string

	Backend logical.Backend
	Context context.Context
	Storage logical.Storage

	// SecretToken tracks the API token, for checking rotations
	SecretToken string

	// Keys tracks the generated Cluster API keys, to make sure we clean up
	Keys []string
}

// AddConfig adds the configuration to the test backend.
// Make sure data includes all the configuration
// attributes you need and the `config` path!
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
	require.NotNil(testing, resp)
	require.Nil(testing, err)
}

// AddRole adds a role for CCloud Cluster API keys.
func (testEnv *testEnv) AddRole(testing *testing.T) {
	request := &logical.Request{
		Operation: logical.UpdateOperation,
		Path:      "role/test-cluster-role",
		Storage:   testEnv.Storage,
		Data: map[string]interface{}{
			"owner": testEnv.Owner,
		},
	}
	response, err := testEnv.Backend.HandleRequest(testEnv.Context, request)
	require.NotNil(testing, response)
	require.Nil(testing, err)
}

// ReadKey retrieves the Cluster API key based on a Vault role.
func (testEnv *testEnv) ReadToken(testing *testing.T) {
	request := &logical.Request{
		Operation: logical.ReadOperation,
		Path:      "creds/test-cluster-token",
		Storage:   testEnv.Storage,
	}
	response, err := testEnv.Backend.HandleRequest(testEnv.Context, request)
	require.Nil(testing, err)
	require.NotNil(testing, response)

	if t, ok := response.Data["token"]; ok {
		testEnv.Keys = append(testEnv.Keys, t.(string))
	}
	require.NotEmpty(testing, response.Data["token"])

	if testEnv.SecretToken != "" {
		require.NotEqual(testing, testEnv.SecretToken, response.Data["token"])
	}

	// collect secret IDs to revoke at end of test
	require.NotNil(testing, response.Secret)
	if testToken, ok := response.Secret.InternalData["token"]; ok {
		testEnv.SecretToken = testToken.(string)
	}
}

//todo - this doesnt work right now.
// CleanupTokens removes the tokens
// when the test completes.
//func (testEnv *testEnv) CleanupTokens(testing *testing.T) {
//	if len(testEnv.Keys) == 0 {
//		testing.Fatalf("expected 2 tokens, got: %d", len(testEnv.Keys))
//	}
//
//	for _, token := range testEnv.Keys {
//		confluentCloudBackend := testEnv.Backend.(*ccloudBackend)
//		client, err := confluentCloudBackend.getClient(testEnv.Context, testEnv.Storage)
//		if err != nil {
//			testing.Fatal("fatal getting client")
//		}
//		client.Client.Token = string(token)
//		if err := client.SignOut(); err != nil {
//			testing.Fatalf("unexpected error deleting token: %s", err)
//		}
//	}
//}
