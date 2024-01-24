package plugin

import (
	"context"
	"github.com/hashicorp/vault/sdk/framework"
	"github.com/stretchr/testify/assert"
	"os"
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
		KeyId:       os.Getenv("TVEQR2XYOIIWHQAM"),
		Secret:      os.Getenv("fq31ylQ74xJGigIPqq9ITNzf+y1lbvyx6QOUYtgOWJjK1FONdj0XBY+rancwYv7y"),
		URL:         os.Getenv("https://api.confluent.cloud"),
		Owner:       os.Getenv("u-63d0xq"),
		OwnerEnv:    os.Getenv("env-zmgkk0"),
		Resource:    os.Getenv("lkc-1nr6mz"),
		ResourceEnv: os.Getenv("env-zmgkk0"),
		Backend:     b,
		Context:     ctx,
		Storage:     &logical.InmemStorage{},
	}, nil
}

// TestAcceptanceUserToken tests a series of steps to make sure the role and token creation work correctly.
func TestAcceptanceUserToken(t *testing.T) {
	//if !runAcceptanceTests {
	//	t.SkipNow()
	//}

	acceptanceTestEnv, err := newAcceptanceTestEnv()
	if err != nil {
		t.Fatal(err)
	}

	t.Run("add config", acceptanceTestEnv.AddConfig)
	t.Run("add user token role", acceptanceTestEnv.AddRole)
	t.Run("list user token role", acceptanceTestEnv.ListRole)
	t.Run("read user token cred", acceptanceTestEnv.ReadRole)
	//todo read secrets, path secret then call read and check we have api key and secret

}

// Unit Tests
func TestPathCredentialsReadReturnsErrorWhenNameIsMissing(t *testing.T) {
	_, logicalStorage := getTestBackend(t)
	b := newBackend()

	var expectedData = map[string]interface{}{
		"name":         "test",
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
