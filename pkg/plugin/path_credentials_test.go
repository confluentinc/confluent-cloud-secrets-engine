package plugin

import (
	"context"
	"github.com/hashicorp/vault/sdk/framework"
	"github.com/stretchr/testify/assert"
	"os"
	"strconv"
	"testing"
	"time"

	log "github.com/hashicorp/go-hclog"
	"github.com/hashicorp/vault/sdk/helper/logging"
	"github.com/hashicorp/vault/sdk/logical"
)

// The env variables from line 36- 39 should be set as env variables.
// newAcceptanceTestEnv creates a test environment for credentials
func newAcceptanceTestEnv() (*testEnv, error) {
	ctx := context.Background()

	maxLease, _ := time.ParseDuration("60s")
	defaultLease, _ := time.ParseDuration("30s")
	isMultiUse, _ := strconv.ParseBool(os.Getenv("TEST_MULTI_USE_KEY"))
	conf := &logical.BackendConfig{
		System: &logical.StaticSystemView{
			DefaultLeaseTTLVal: defaultLease,
			MaxLeaseTTLVal:     maxLease,
		},
		Logger: logging.NewVaultLogger(log.Debug),
	}
	b, err := Factory(ctx, conf)
	if err != nil {
		return nil, err
	}
	return &testEnv{
		KeyId:       os.Getenv(envVarCCloudKeyId),
		Secret:      os.Getenv(envVarCCloudSecret),
		URL:         os.Getenv(envVarCCloudURL),
		Owner:       os.Getenv(envVarCCloudOwner),
		OwnerEnv:    os.Getenv(envVarCCloudEnv),
		Resource:    os.Getenv(envVarCCloudResourceId),
		ResourceEnv: os.Getenv(envVarCCloudEnv),
		MultiUseKey: isMultiUse,
		Backend:     b,
		Context:     ctx,
		Storage:     &logical.InmemStorage{},
	}, nil
}

// TestAcceptanceUserToken tests a series of steps to make sure the role and token creation work correctly.
func TestAcceptanceUserToken(t *testing.T) {
	if !runAcceptanceTests {
		t.SkipNow()
	}

	acceptanceTestEnv, err := newAcceptanceTestEnv()
	if err != nil {
		t.Fatal(err)
	}

	t.Run("add config", acceptanceTestEnv.AddConfig)
	t.Run("add user token role", acceptanceTestEnv.AddSingleUseRole)
	t.Run("add user token role", acceptanceTestEnv.AddMultiUseRole)
	t.Run("list user token role", acceptanceTestEnv.ListRole)
	t.Run("read single use user token role", acceptanceTestEnv.ReadSingleUseRole)
	t.Run("read multi use user token role", acceptanceTestEnv.ReadMultiUseRole)
	t.Run("create and delete single use confluent cloud api key and secret", acceptanceTestEnv.ReadCredentialsSingleUsage)
	t.Run("create and delete multi use confluent cloud api key and secret", acceptanceTestEnv.ReadMultiUseKey)
}

// Unit Tests
func TestPathCredentialsReadReturnsErrorWhenNameIsMissing(t *testing.T) {
	_, logicalStorage := getTestBackend(t)
	b := newBackend()

	var expectedData = map[string]interface{}{
		"name":         "",
		"field":        "testField1",
		"newTestField": "testField2",
	}

	var schema = map[string]*framework.FieldSchema{
		"name": {
			Type:        framework.TypeString,
			Description: "name in the test schema",
		},
		"secondField": {
			Type:        framework.TypeString,
			Description: "SecondFieldInTestSchema",
		},
	}

	_, err := b.pathCredentialsRead(context.Background(), &logical.Request{
		Operation: logical.RevokeOperation,
		Path:      configStoragePath,
		Storage:   logicalStorage,
	},
		&framework.FieldData{
			Raw:    expectedData,
			Schema: schema,
		})

	expectedErrorMsg := "error retrieving role: missing role name"
	assert.EqualErrorf(t, err, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, err)
}

func TestPathCredentialsReadReturnsRoleIsNilError(t *testing.T) {
	_, logicalStorage := getTestBackend(t)
	b := newBackend()

	var expectedData = map[string]interface{}{
		"name":         "testName",
		"field":        "testField1",
		"newTestField": "testField2",
	}

	var schema = map[string]*framework.FieldSchema{
		"name": {
			Type:        framework.TypeString,
			Description: "name in the test schema",
		},
		"secondField": {
			Type:        framework.TypeString,
			Description: "SecondFieldInTestSchema",
		},
	}

	_, err := b.pathCredentialsRead(context.Background(), &logical.Request{
		Operation: logical.RevokeOperation,
		Path:      configStoragePath,
		Storage:   logicalStorage,
	},
		&framework.FieldData{
			Raw:    expectedData,
			Schema: schema,
		})

	expectedErrorMsg := "error retrieving role: role is nil"
	assert.EqualErrorf(t, err, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, err)
}
