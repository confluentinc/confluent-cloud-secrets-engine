package plugin

import (
	"context"
	"strconv"
	"testing"

	"github.com/hashicorp/vault/sdk/logical"
	"github.com/stretchr/testify/require"
)

const (
	roleName    = "testccloud"
	owner       = "roleOwner"
	ownerEnv    = "roleOwnerEnv"
	resource    = "testResource"
	resourceEnv = "resource_env"
	resourceID  = "resource_id"
	apiKey      = "apiKey"
	testTTL     = int64(120)
	testMaxTTL  = int64(3600)
)

// TestUserRole uses a mock backend to check
// role create, read, update, and delete.
func TestUserRole(testingT *testing.T) {
	confluentCloudBackend, s := getTestBackend(testingT)

	testingT.Run("List All Roles", func(testingT *testing.T) {
		for i := 1; i <= 10; i++ {
			_, err := testTokenRoleCreate(testingT, confluentCloudBackend, s,
				roleName+strconv.Itoa(i),
				map[string]interface{}{
					"owner":        owner,
					"ttl":          testTTL,
					"max_ttl":      testMaxTTL,
					"owner_env":    ownerEnv,
					"resource":     resource,
					"resource_env": resourceEnv,
				})
			require.NoError(testingT, err)
		}

		resp, err := testTokenRoleList(testingT, confluentCloudBackend, s)
		require.NoError(testingT, err)
		require.Len(testingT, resp.Data["keys"].([]string), 10)
	})

	testingT.Run("Create User Role", func(testingT *testing.T) {
		resp, err := testTokenRoleCreate(testingT, confluentCloudBackend, s, roleName, map[string]interface{}{
			"api_key":        apiKey,
			"environment_id": ownerEnv,
			"owner_id":       owner,
			"resource_id":    resourceID,
			"owner":          owner,
			"ttl":            testTTL,
			"max_ttl":        testMaxTTL,
			"owner_env":      ownerEnv,
			"resource":       resource,
			"resource_env":   resourceEnv,
		})

		require.Nil(testingT, err)
		require.Nil(testingT, resp.Error())
		require.Nil(testingT, resp)
	})

	testingT.Run("Read User Role", func(testingT *testing.T) {
		resp, err := testTokenRoleRead(testingT, confluentCloudBackend, s)

		require.Nil(testingT, err)
		require.Nil(testingT, resp.Error())
		require.NotNil(testingT, resp)
		require.Equal(testingT, resp.Data["owner"], owner)
	})

	testingT.Run("Update User Role", func(testingT *testing.T) {
		resp, err := testRoleUpdate(testingT, confluentCloudBackend, s, map[string]interface{}{
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
func testRoleUpdate(t *testing.T, b *ccloudBackend, s logical.Storage, d map[string]interface{}) (*logical.Response, error) {
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

// Utility function to list roles and return any errors
func testTokenRoleList(testingT *testing.T, confluentCloudBackend *ccloudBackend, logicalStorage logical.Storage) (*logical.Response, error) {
	testingT.Helper()
	return confluentCloudBackend.HandleRequest(context.Background(), &logical.Request{
		Operation: logical.ListOperation,
		Path:      "role/",
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
