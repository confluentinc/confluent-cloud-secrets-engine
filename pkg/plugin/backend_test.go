package plugin

import (
	"context"
	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/vault/sdk/framework"
	"github.com/hashicorp/vault/sdk/logical"
	"github.com/stretchr/testify/require"
	"os"
	"testing"
)

const (
	envVarCCloudKeyId      = "TEST_CCLOUD_KEY_ID"
	envVarCCloudSecret     = "TEST_CCLOUD_SECRET"
	envVarCCloudURL        = "TEST_CCLOUD_URL"
	envVarCCloudOwner      = "TEST_CCLOUD_OWNER"
	envVarCCloudEnv        = "TEST_CCLOUD_ENV_ID"
	envVarCCloudResourceId = "TEST_CCLOUD_RESOURCE_ID"
	envVarMultiUseKey      = "TEST_MULTI_USE_KEY"
)

//todo rename the role "testing"

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
var runAcceptanceTests = os.Getenv("VAULT_ACC") == "1"

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
	MultiUseKey bool

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

	logicalBackend, _ := getTestBackend(testing)
	var expectedData = map[string]interface{}{
		"ccloud_api_key_id":     testEnv.KeyId,
		"ccloud_api_key_secret": testEnv.Secret,
		"url":                   testEnv.URL,
	}
	var schema = map[string]*framework.FieldSchema{
		"ccloud_api_key_id": {
			Type:        framework.TypeString,
			Description: "ccloud_api_key_id",
		},
		"ccloud_api_key_secret": {
			Type:        framework.TypeString,
			Description: "ccloud_api_key_secret",
		},
		"url": {
			Type:        framework.TypeString,
			Description: "url",
		},
	}
	resp, err := logicalBackend.pathConfigWrite(context.Background(), &logical.Request{
		Operation: logical.CreateOperation,
		Path:      "config",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})

	require.Nil(testing, resp)
	require.Nil(testing, err)
}

// AddSingleUseRole adds a single use role for CCloud Cluster API keys.
func (testEnv *testEnv) AddSingleUseRole(testing *testing.T) {
	logicalBackend, _ := getTestBackend(testing)

	var expectedData = map[string]interface{}{
		"ccloud_api_key_id":     testEnv.KeyId,
		"ccloud_api_key_secret": testEnv.Secret,
		"url":                   testEnv.URL,
		"owner":                 testEnv.Owner,
		"owner_env":             testEnv.OwnerEnv,
		"resource":              testEnv.Resource,
		"resource_env":          testEnv.ResourceEnv,
		"name":                  "singleUseRoleTest",
	}
	var schema = map[string]*framework.FieldSchema{
		"owner": {
			Type:        framework.TypeString,
			Description: "owner",
		},
		"owner_env": {
			Type:        framework.TypeString,
			Description: "owner_env",
		},
		"resource": {
			Type:        framework.TypeString,
			Description: "resource",
		},
		"resource_env": {
			Type:        framework.TypeString,
			Description: "resource_env",
		},
		"name": {
			Type:        framework.TypeString,
			Description: "name",
		},
	}

	response, err := logicalBackend.pathRolesWrite(context.Background(), &logical.Request{
		Operation: logical.UpdateOperation,
		Path:      "role/singleUseRoleTest",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})

	require.Nil(testing, response)
	require.Nil(testing, err)
}

// AddMultiUseRole adds a single use role for CCloud Cluster API keys.
func (testEnv *testEnv) AddMultiUseRole(testing *testing.T) {
	logicalBackend, _ := getTestBackend(testing)

	var expectedData = map[string]interface{}{
		"ccloud_api_key_id":     testEnv.KeyId,
		"ccloud_api_key_secret": testEnv.Secret,
		"url":                   testEnv.URL,
		"owner":                 testEnv.Owner,
		"owner_env":             testEnv.OwnerEnv,
		"resource":              testEnv.Resource,
		"resource_env":          testEnv.ResourceEnv,
		"name":                  "multiUseRoleTest",
		"multi_use_key":         testEnv.MultiUseKey,
	}
	var schema = map[string]*framework.FieldSchema{
		"owner": {
			Type:        framework.TypeString,
			Description: "owner",
		},
		"owner_env": {
			Type:        framework.TypeString,
			Description: "owner_env",
		},
		"resource": {
			Type:        framework.TypeString,
			Description: "resource",
		},
		"resource_env": {
			Type:        framework.TypeString,
			Description: "resource_env",
		},
		"name": {
			Type:        framework.TypeString,
			Description: "name",
		},
		"multi_use_key": {
			Type:        framework.TypeBool,
			Description: "multi_use_key",
		},
	}

	response, err := logicalBackend.pathRolesWrite(context.Background(), &logical.Request{
		Operation: logical.UpdateOperation,
		Path:      "role/multiUseRoleTest",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})

	require.Nil(testing, response)
	require.Nil(testing, err)
}

// ListRole lists the roles within the testing vault instance
func (testEnv *testEnv) ListRole(testing *testing.T) {
	logicalBackend, _ := getTestBackend(testing)

	var expectedData = map[string]interface{}{
		"owner":        testEnv.Owner,
		"owner_env":    testEnv.OwnerEnv,
		"resource":     testEnv.Resource,
		"resource_env": testEnv.ResourceEnv,
	}
	var schema = map[string]*framework.FieldSchema{
		"owner": {
			Type:        framework.TypeString,
			Description: "owner",
		},
		"owner_env": {
			Type:        framework.TypeString,
			Description: "owner_env",
		},
		"resource": {
			Type:        framework.TypeString,
			Description: "resource",
		},
		"resource_env": {
			Type:        framework.TypeString,
			Description: "resource_env",
		},
	}

	response, err := logicalBackend.pathRolesList(context.Background(), &logical.Request{
		Operation: logical.ListOperation,
		Path:      "role",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})

	require.Equal(testing, 2, len(response.Data["keys"].([]string)), "equals")
	require.NotNil(testing, response.Data["keys"])
	require.Nil(testing, err)
}

// ReadRole reads the role "singleUseRoleTest"
func (testEnv *testEnv) ReadSingleUseRole(testing *testing.T) {
	logicalBackend, _ := getTestBackend(testing)

	var expectedData = map[string]interface{}{
		"owner":        testEnv.Owner,
		"owner_env":    testEnv.OwnerEnv,
		"resource":     testEnv.Resource,
		"resource_env": testEnv.ResourceEnv,
		"name":         "singleUseRoleTest",
	}
	var schema = map[string]*framework.FieldSchema{
		"owner": {
			Type:        framework.TypeString,
			Description: "owner",
		},
		"owner_env": {
			Type:        framework.TypeString,
			Description: "owner_env",
		},
		"resource": {
			Type:        framework.TypeString,
			Description: "resource",
		},
		"resource_env": {
			Type:        framework.TypeString,
			Description: "resource_env",
		},
		"name": {
			Type:        framework.TypeString,
			Description: "name",
		},
	}

	response, err := logicalBackend.pathRolesRead(context.Background(), &logical.Request{
		Operation: logical.ReadOperation,
		Path:      "role/singleUseRoleTest",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})

	require.NotNil(testing, response.Data)
	require.Nil(testing, err)

	require.Equal(testing, testEnv.Owner, response.Data["owner"].(string), "equals")
	require.Equal(testing, testEnv.OwnerEnv, response.Data["owner_env"].(string), "equals")
	require.Equal(testing, testEnv.Resource, response.Data["resource"].(string), "equals")
	require.Equal(testing, testEnv.ResourceEnv, response.Data["resource_env"].(string), "equals")
	require.Equal(testing, false, response.Data["multi_use_key"], "equals")
	require.Equal(testing, 0, response.Data["usage_count"].(int), "equals")
}

// ReadRole reads the role "multiUseRoleTest"
func (testEnv *testEnv) ReadMultiUseRole(testing *testing.T) {
	logicalBackend, _ := getTestBackend(testing)

	var expectedData = map[string]interface{}{
		"ccloud_api_key_id":     testEnv.KeyId,
		"ccloud_api_key_secret": testEnv.Secret,
		"url":                   testEnv.URL,
		"owner":                 testEnv.Owner,
		"owner_env":             testEnv.OwnerEnv,
		"resource":              testEnv.Resource,
		"resource_env":          testEnv.ResourceEnv,
		"name":                  "multiUseRoleTest",
		"multi_use_key":         testEnv.MultiUseKey,
	}
	var schema = map[string]*framework.FieldSchema{
		"owner": {
			Type:        framework.TypeString,
			Description: "owner",
		},
		"owner_env": {
			Type:        framework.TypeString,
			Description: "owner_env",
		},
		"resource": {
			Type:        framework.TypeString,
			Description: "resource",
		},
		"resource_env": {
			Type:        framework.TypeString,
			Description: "resource_env",
		},
		"name": {
			Type:        framework.TypeString,
			Description: "name",
		},
		"multi_use_key": {
			Type:        framework.TypeBool,
			Description: "multi_use_key",
		},
	}

	response, err := logicalBackend.pathRolesRead(context.Background(), &logical.Request{
		Operation: logical.ReadOperation,
		Path:      "role/multiUseRoleTest",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})

	require.NotNil(testing, response.Data)
	require.Nil(testing, err)

	require.Equal(testing, testEnv.Owner, response.Data["owner"].(string), "equals")
	require.Equal(testing, testEnv.OwnerEnv, response.Data["owner_env"].(string), "equals")
	require.Equal(testing, testEnv.Resource, response.Data["resource"].(string), "equals")
	require.Equal(testing, testEnv.ResourceEnv, response.Data["resource_env"].(string), "equals")
	require.Equal(testing, true, response.Data["multi_use_key"], "equals")
	require.Equal(testing, 0, response.Data["usage_count"].(int), "equals")
}

func (testEnv *testEnv) ReadCredentialsSingleUsage(testing *testing.T) {
	logicalBackend, _ := getTestBackend(testing)

	var expectedData = map[string]interface{}{
		"ccloud_api_key_id":     testEnv.KeyId,
		"ccloud_api_key_secret": testEnv.Secret,
		"url":                   testEnv.URL,
		"owner":                 testEnv.Owner,
		"owner_env":             testEnv.OwnerEnv,
		"resource":              testEnv.Resource,
		"resource_env":          testEnv.ResourceEnv,
		"name":                  "singleUseRoleTest",
	}
	var schema = map[string]*framework.FieldSchema{
		"owner": {
			Type:        framework.TypeString,
			Description: "owner",
		},
		"owner_env": {
			Type:        framework.TypeString,
			Description: "owner_env",
		},
		"resource": {
			Type:        framework.TypeString,
			Description: "resource",
		},
		"resource_env": {
			Type:        framework.TypeString,
			Description: "resource_env",
		},
		"name": {
			Type:        framework.TypeString,
			Description: "name",
		},
	}
	response, err := logicalBackend.pathCredentialsRead(context.Background(), &logical.Request{
		Operation: logical.ReadOperation,
		Path:      "creds/singleUseRoleTest",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})

	require.NotNil(testing, response)
	require.Nil(testing, err)

	require.NotNil(testing, response.Data["key_id"])
	require.NotNil(testing, response.Data["secret"])
	require.NotNil(testing, response.Data["sasl.jaas.config"])

	//now read role to check usage count
	readRole, err := logicalBackend.pathRolesRead(context.Background(), &logical.Request{
		Operation: logical.ReadOperation,
		Path:      "role/singleUseRoleTest",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})
	require.Equal(testing, 0, readRole.Data["usage_count"].(int), "equals")

	//logicalBackend.tokenRevoke(context.Background(), &logical.Request{
	//	Operation: logical.RevokeOperation,
	//	Path:      "creds/singleUseRoleTest",
	//	Storage:   testEnv.Storage,
	//}, &framework.FieldData{
	//	Raw:    expectedData,
	//	Schema: schema,
	//})

}

// ReadRole retrieves the Cluster API key based on a Vault role.
func (testEnv *testEnv) ReadMultiUseKey(testing *testing.T) {

	logicalBackend, _ := getTestBackend(testing)

	var expectedData = map[string]interface{}{
		"ccloud_api_key_id":     testEnv.KeyId,
		"ccloud_api_key_secret": testEnv.Secret,
		"url":                   testEnv.URL,
		"owner":                 testEnv.Owner,
		"owner_env":             testEnv.OwnerEnv,
		"resource":              testEnv.Resource,
		"resource_env":          testEnv.ResourceEnv,
		"name":                  "multiUseRoleTest",
		"multi_use_key":         testEnv.MultiUseKey,
	}
	var schema = map[string]*framework.FieldSchema{
		"owner": {
			Type:        framework.TypeString,
			Description: "owner",
		},
		"owner_env": {
			Type:        framework.TypeString,
			Description: "owner_env",
		},
		"resource": {
			Type:        framework.TypeString,
			Description: "resource",
		},
		"resource_env": {
			Type:        framework.TypeString,
			Description: "resource_env",
		},
		"name": {
			Type:        framework.TypeString,
			Description: "name",
		},
		"multi_use_key": {
			Type:        framework.TypeBool,
			Description: "multi_use_key",
		},
	}
	firstRequestResponse, err := logicalBackend.pathCredentialsRead(context.Background(), &logical.Request{
		Operation: logical.ReadOperation,
		Path:      "creds/multiUseRoleTest",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})

	require.NotNil(testing, firstRequestResponse)

	keyId := firstRequestResponse.Data["key_id"]
	secret := firstRequestResponse.Data["secret"]

	require.Nil(testing, err)
	require.NotNil(testing, keyId)
	require.NotNil(testing, secret)
	require.NotNil(testing, firstRequestResponse.Data["sasl.jaas.config"])

	//now read role to check usage count
	readRole, err := logicalBackend.pathRolesRead(context.Background(), &logical.Request{
		Operation: logical.ReadOperation,
		Path:      "role/multiUseRoleTest",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})
	require.Equal(testing, 1, readRole.Data["usage_count"].(int), "equals")

	secondRequestReponse, err := logicalBackend.pathCredentialsRead(context.Background(), &logical.Request{
		Operation: logical.ReadOperation,
		Path:      "creds/multiUseRoleTest",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})

	require.Equal(testing, keyId, secondRequestReponse.Data["key_id"].(string), "equals")
	require.Equal(testing, secret, secondRequestReponse.Data["secret"].(string), "equals")

	//read role again to check usage count has increased
	readRoleSecondTime, err := logicalBackend.pathRolesRead(context.Background(), &logical.Request{
		Operation: logical.ReadOperation,
		Path:      "role/multiUseRoleTest",
		Storage:   testEnv.Storage,
	}, &framework.FieldData{
		Raw:    expectedData,
		Schema: schema,
	})
	require.Equal(testing, 2, readRoleSecondTime.Data["usage_count"].(int), "equals")

}
