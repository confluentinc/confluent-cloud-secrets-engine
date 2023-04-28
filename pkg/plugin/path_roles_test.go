package plugin

import (
	"context"
	"github.com/hashicorp/vault/sdk/framework"
	"github.com/hashicorp/vault/sdk/logical"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"strconv"
	"testing"
)

const (
	roleName     = "testccloud"
	owner        = "roleOwner"
	owner_env    = "roleOwnerEnv"
	resource     = "testResource"
	resource_env = "resource_envTest"
	testTTL      = int64(120)
	testMaxTTL   = int64(3600)
)

// TestUserRole uses a mock backend to check
// role create, read, update, and delete.
func TestUserRole(testingT *testing.T) {
	confluentCloudBackend, s := getTestBackend(testingT)

	testingT.Run("responseDataReturnedForARole", func(t *testing.T) {
		roleEntry := &apikeyRoleEntry{
			Owner:    owner,
			Resource: resource,
		}

		response := roleEntry.toResponseData()

		//todo check the response values
		assert.Equal(t, "roleOwner", response["owner"])
		assert.Equal(t, "testResource", response["resource"])

	})

	testingT.Run("List All Roles", func(t *testing.T) {
		for i := 1; i <= 10; i++ {
			_, err := testTokenRoleCreate(testingT, confluentCloudBackend, s,
				roleName+strconv.Itoa(i),
				map[string]interface{}{
					"owner":        owner,
					"owner_env":    owner_env,
					"resource":     resource,
					"resource_env": resource_env,
					"ttl":          testTTL,
					"max_ttl":      testMaxTTL,
				})
			require.NoError(t, err)
		}

		resp, err := testTokenRoleList(testingT, confluentCloudBackend, s)
		require.NoError(t, err)
		require.Len(t, resp.Data["keys"].([]string), 10)
	})

	testingT.Run("Create User Role", func(testingT *testing.T) {
		resp, err := testTokenRoleCreate(testingT, confluentCloudBackend, s, roleName, map[string]interface{}{
			"owner":        owner,
			"owner_env":    owner_env,
			"resource":     resource,
			"resource_env": resource_env,
			"ttl":          testTTL,
			"max_ttl":      testMaxTTL,
		})

		require.Nil(testingT, err)
		require.Nil(testingT, resp.Error())
		require.Nil(testingT, resp)
	})

	testingT.Run("Read User Role", func(testingT *testing.T) {
		_, _ = testTokenRoleCreate(testingT, confluentCloudBackend, s, roleName, map[string]interface{}{
			"owner":        owner,
			"owner_env":    owner_env,
			"resource":     resource,
			"resource_env": resource_env,
			"ttl":          testTTL,
			"max_ttl":      testMaxTTL,
		})

		resp, err := testTokenRoleRead(testingT, confluentCloudBackend, s)

		require.Nil(testingT, err)
		require.Nil(testingT, resp.Error())
		require.NotNil(testingT, resp)
		require.Equal(testingT, resp.Data["owner"], owner)
	})

	testingT.Run("Update User Role", func(testingT *testing.T) {
		resp, err := testPathRoleUpdate(testingT, confluentCloudBackend, s, map[string]interface{}{
			"ttl":     "1m",
			"max_ttl": "5h",
		})

		require.Nil(testingT, err)
		require.Nil(testingT, resp.Error())
		require.Nil(testingT, resp)
	})

	testingT.Run("Re-read User Role", func(testingT *testing.T) {

		resp, err := testTokenRoleRead(testingT, confluentCloudBackend, s)

		require.Nil(testingT, err)
		require.Nil(testingT, resp.Error())
		require.NotNil(testingT, resp)
		require.Equal(testingT, resp.Data["owner"], owner)
	})

	testingT.Run("Delete User Role", func(testingT *testing.T) {
		_, err := testTokenRoleDelete(testingT, confluentCloudBackend, s)

		require.NoError(testingT, err)
	})

	//todo this doesnt work
	testingT.Run("ttlIsPopulatedWhenOperationIsCreate", func(t *testing.T) {
		_, logicalStorage := getTestBackend(t)
		b := newBackend()

		var expectedData = map[string]interface{}{
			"name":         "nameTest",
			"owner":        nil,
			"owner_env":    owner_env,
			"field":        "testField1",
			"newTestField": "testField2",
			"resource":     resource,
			"resource_env": resource_env,
			"ttl":          testTTL,
			"max_ttl":      testMaxTTL,
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
			"resource": {
				Type:        framework.TypeString,
				Description: "resource of the test schema",
			},
			"resource_env": {
				Type:        framework.TypeString,
				Description: "resource_env of the test schema",
			},
			"owner": {
				Type:        framework.TypeString,
				Description: "owner in the test schema",
			},
			"owner_env": {
				Type:        framework.TypeString,
				Description: "owner env in the test schema",
			},
			"ttl": {
				Type:        framework.TypeDurationSecond,
				Description: "ttl in the test schema",
			},
			"max_ttl": {
				Type:        framework.TypeDurationSecond,
				Description: "max_ttl in the test schema",
			},
		}

		response, _ := b.pathRolesWrite(context.Background(), &logical.Request{
			Operation: logical.CreateOperation,
			Path:      configStoragePath,
			Storage:   logicalStorage,
		},
			&framework.FieldData{
				expectedData,
				schema,
			})

		//why does the main code return nil, nil here
		assert.NotNil(t, response)
	})

	testingT.Run("pathRolesReadReturnsErrorWhenTtlIsGreaterThanMaxTtl", func(t *testing.T) {
		_, logicalStorage := getTestBackend(t)
		b := newBackend()

		var expectedData = map[string]interface{}{
			"name":         "nameTest",
			"owner":        owner,
			"owner_env":    owner_env,
			"field":        "testField1",
			"newTestField": "testField2",
			"resource":     resource,
			"resource_env": resource_env,
			"max_ttl":      1,
			"ttl":          2,
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
			"owner": {
				Type:        framework.TypeString,
				Description: "owner of the test schema",
			},
			"owner_env": {
				Type:        framework.TypeString,
				Description: "owner env in the test schema",
			},
			"resource": {
				Type:        framework.TypeString,
				Description: "resource of the test schema",
			},
			"resource_env": {
				Type:        framework.TypeString,
				Description: "resource_env of the test schema",
			},
			"ttl": {
				Type:        framework.TypeDurationSecond,
				Description: "ttl in the test schema",
			},
			"max_ttl": {
				Type:        framework.TypeDurationSecond,
				Description: "max_ttl in the test schema",
			},
		}

		_, error := b.pathRolesWrite(context.Background(), &logical.Request{
			Operation: logical.UpdateOperation,
			Path:      configStoragePath,
			Storage:   logicalStorage,
		},
			&framework.FieldData{
				expectedData,
				schema,
			})

		expectedErrorMsg := "ttl cannot be greater than max_ttl"
		assert.EqualErrorf(t, error, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, error)
	})

	testingT.Run("pathRolesReadReturnsErrorWhenResourceIsMissingInRole", func(t *testing.T) {
		_, logicalStorage := getTestBackend(t)
		b := newBackend()

		var expectedData = map[string]interface{}{
			"name":         "nameTest",
			"owner":        owner,
			"owner_env":    owner_env,
			"field":        "testField1",
			"newTestField": "testField2",
			"resource":     nil,
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
			"owner": {
				Type:        framework.TypeString,
				Description: "owner of the test schema",
			},
			"owner_env": {
				Type:        framework.TypeString,
				Description: "owner env in the test schema",
			},
			"resource_env": {
				Type:        framework.TypeString,
				Description: "resource of the test schema",
			},
		}

		_, error := b.pathRolesWrite(context.Background(), &logical.Request{
			Operation: logical.CreateOperation,
			Path:      configStoragePath,
			Storage:   logicalStorage,
		},
			&framework.FieldData{
				expectedData,
				schema,
			})

		expectedErrorMsg := "missing resource in role"
		assert.EqualErrorf(t, error, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, error)
	})

	testingT.Run("pathRolesReadReturnsErrorWhenResourceEnvIsMissingInRole", func(t *testing.T) {
		_, logicalStorage := getTestBackend(t)
		b := newBackend()

		var expectedData = map[string]interface{}{
			"name":         "nameTest",
			"owner":        owner,
			"owner_env":    owner_env,
			"field":        "testField1",
			"newTestField": "testField2",
			"resource":     nil,
		}

		var schema = map[string]*framework.FieldSchema{
			"resource": {
				Type:        framework.TypeString,
				Description: "resource of the test schema",
			},
			"name": {
				Type:        framework.TypeString,
				Description: "name in the test schema",
			},
			"secondField": {
				Type:        framework.TypeString,
				Description: "SecondFieldInTestSchema",
			},
			"owner": {
				Type:        framework.TypeString,
				Description: "owner of the test schema",
			},
			"owner_env": {
				Type:        framework.TypeString,
				Description: "owner env in the test schema",
			},
		}

		_, error := b.pathRolesWrite(context.Background(), &logical.Request{
			Operation: logical.CreateOperation,
			Path:      configStoragePath,
			Storage:   logicalStorage,
		},
			&framework.FieldData{
				expectedData,
				schema,
			})

		expectedErrorMsg := "missing resource_env in role"
		assert.EqualErrorf(t, error, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, error)
	})

	testingT.Run("pathRolesReadReturnsErrorWhenOwnerIsMissingInRole", func(t *testing.T) {
		_, logicalStorage := getTestBackend(t)
		b := newBackend()

		var expectedData = map[string]interface{}{
			"name":         "nameTest",
			"owner":        nil,
			"owner_env":    owner_env,
			"field":        "testField1",
			"newTestField": "testField2",
			"resource":     resource,
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
			"resource": {
				Type:        framework.TypeString,
				Description: "resource of the test schema",
			},
			"owner_env": {
				Type:        framework.TypeString,
				Description: "owner env in the test schema",
			},
		}

		_, error := b.pathRolesWrite(context.Background(), &logical.Request{
			Operation: logical.CreateOperation,
			Path:      configStoragePath,
			Storage:   logicalStorage,
		},
			&framework.FieldData{
				expectedData,
				schema,
			})

		expectedErrorMsg := "missing owner in role"
		assert.EqualErrorf(t, error, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, error)
	})

	testingT.Run("pathRolesReadReturnsErrorWhenOwnerEnvIsMissingInRole", func(t *testing.T) {
		_, logicalStorage := getTestBackend(t)
		b := newBackend()

		var expectedData = map[string]interface{}{
			"name":         "nameTest",
			"owner":        nil,
			"owner_env":    owner_env,
			"field":        "testField1",
			"newTestField": "testField2",
			"resource":     resource,
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
			"resource": {
				Type:        framework.TypeString,
				Description: "resource of the test schema",
			},
			"owner": {
				Type:        framework.TypeString,
				Description: "owner in the test schema",
			},
		}

		_, error := b.pathRolesWrite(context.Background(), &logical.Request{
			Operation: logical.CreateOperation,
			Path:      configStoragePath,
			Storage:   logicalStorage,
		},
			&framework.FieldData{
				expectedData,
				schema,
			})

		expectedErrorMsg := "missing owner_env in role"
		assert.EqualErrorf(t, error, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, error)
	})

	testingT.Run("getRoleReturnsErrorWhenRoleIsEmpty", func(t *testing.T) {
		_, logicalStorage := getTestBackend(t)
		b := newBackend()
		response, error := b.getRole(context.Background(), logicalStorage, "")
		assert.Nil(t, response)
		expectedErrorMsg := "missing role name"
		assert.EqualErrorf(t, error, expectedErrorMsg, "Error should be: %v, got: %v", expectedErrorMsg, error)
	})

	testingT.Run("getRoleReturnsNilWhenRoleIsMissing", func(t *testing.T) {
		_, logicalStorage := getTestBackend(t)
		b := newBackend()
		response, _ := b.getRole(context.Background(), logicalStorage, "name")
		assert.Nil(t, response)
	})
}

// Utility function to list roles and return any errors
func testTokenRoleList(t *testing.T, b *ccloudBackend, s logical.Storage) (*logical.Response, error) {
	t.Helper()
	return b.HandleRequest(context.Background(), &logical.Request{
		Operation: logical.ListOperation,
		Path:      "role/",
		Storage:   s,
	})
}

// Utility function to create a role while, returning any response (including errors)
func testTokenRoleCreate(testingT *testing.T, confluentCloudBackend *ccloudBackend, logicalStorage logical.Storage, name string, data map[string]interface{}) (*logical.Response, error) {
	testingT.Helper()
	//this fails because there is no logical operation for create inside the confluent cloud backend
	//should an operator be added to the confluent cloud dependency or is this test using the wrong import?
	resp, err := confluentCloudBackend.HandleRequest(context.Background(), &logical.Request{
		Operation: logical.CreateOperation,
		Path:      "role/" + name,
		Data:      data,
		Storage:   logicalStorage,
	})

	if err != nil {
		return nil, err
	}

	return resp, nil
}

// Utility function to update a role while, returning any response (including errors)
func testPathRoleUpdate(t *testing.T, b *ccloudBackend, s logical.Storage, d map[string]interface{}) (*logical.Response, error) {
	t.Helper()
	resp, err := b.HandleRequest(context.Background(), &logical.Request{
		Operation: logical.UpdateOperation,
		Path:      "role/" + roleName,
		Data:      d,
		Storage:   s,
	})

	if err != nil {
		return nil, err
	}

	if resp != nil && resp.IsError() {
		t.Fatal(resp.Error())
	}
	return resp, nil
}

// Utility function to read a role and return any errors
func testTokenRoleRead(testingT *testing.T, confluentCloudBackend *ccloudBackend, logicalStorage logical.Storage) (*logical.Response, error) {
	testingT.Helper()
	return confluentCloudBackend.HandleRequest(context.Background(), &logical.Request{
		Operation: logical.ReadOperation,
		Path:      "role/" + roleName,
		Storage:   logicalStorage,
	})
}

// Utility function to delete a role and return any errors
func testTokenRoleDelete(testingT *testing.T, confluentCloudBackend *ccloudBackend, logicalStorage logical.Storage) (*logical.Response, error) {
	testingT.Helper()
	return confluentCloudBackend.HandleRequest(context.Background(), &logical.Request{
		Operation: logical.DeleteOperation,
		Path:      "role/" + roleName,
		Storage:   logicalStorage,
	})
}
