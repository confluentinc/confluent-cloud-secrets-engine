package plugin

import (
	"context"
	"errors"
	"fmt"
	"github.com/hashicorp/vault/sdk/framework"
	"github.com/hashicorp/vault/sdk/logical"
)

const (
	ccloudClusterApiKeyType = "ccloud_cluster_apikey"
)

// ccloudClusterApiKey defines a secret for the CCloud Cluster API Key
type ccloudClusterApiKey struct {
	KeyId      string `json:"key_id"`
	Secret     string `json:"secret"`
	UsageCount int    `json:"usage_count"`
}

// ccloudClusterApiKey defines a secret to store for a given role
// and how it should be revoked or renewed.
func (b *ccloudBackend) ccloudClusterApiKey() *framework.Secret {
	return &framework.Secret{
		Type: ccloudClusterApiKeyType,
		Fields: map[string]*framework.FieldSchema{
			"id": {
				Type:        framework.TypeString,
				Description: "Confluent Cloud Cluster API Key ID",
			},
			"secret": {
				Type:        framework.TypeString,
				Description: "Confluent Cloud Cluster API Key Secret",
			},
		},
		Revoke: b.tokenRevoke,
		Renew:  b.tokenRenew,
	}
}

// tokenRevoke removes the token from the Vault storage API and calls the client to revoke the token
func (b *ccloudBackend) tokenRevoke(ctx context.Context, req *logical.Request, d *framework.FieldData) (*logical.Response, error) {
	client, err := b.getClient(ctx, req.Storage)
	if err != nil {
		return nil, fmt.Errorf("error getting client: %w", err)
	}

	keyId := ""
	if keyIdRaw, ok := req.Secret.InternalData["key_id"]; ok {
		keyId, ok = keyIdRaw.(string)
		if !ok {
			return nil, fmt.Errorf("invalid value for token in secret internal data")
		}
	}

	var roleName = req.Secret.InternalData["role"].(string)
	var role, _ = b.getRole(ctx, req.Storage, roleName)
	role.UsageCount--

	setRole(ctx, req.Storage, roleName, role)

	//delete from cc if usage count is 0
	if role.UsageCount == 0 {
		role.CCKeyId = ""
		role.CCKeySecret = ""
		setRole(ctx, req.Storage, roleName, role)

		if err := client.DeleteApiKey(ctx, keyId); err != nil {
			return nil, fmt.Errorf("error revoking user token: %w", err)
		}
		b.Logger().Info("Deleting CC API key: %v", keyId)

	}
	return nil, nil
}

// tokenRenew calls the client to create a new token and stores it in the Vault storage API
func (b *ccloudBackend) tokenRenew(ctx context.Context, req *logical.Request, d *framework.FieldData) (*logical.Response, error) {
	roleRaw, ok := req.Secret.InternalData["role"]
	if !ok {
		return nil, fmt.Errorf("secret is missing role internal data")
	}

	// get the role entry
	role := roleRaw.(string)
	roleEntry, err := b.getRole(ctx, req.Storage, role)
	if err != nil {
		return nil, fmt.Errorf("error retrieving role: %w", err)
	}

	if roleEntry == nil {
		return nil, errors.New("error retrieving role: role is nil")
	}

	resp := &logical.Response{Secret: req.Secret}

	if roleEntry.TTL > 0 {
		resp.Secret.TTL = roleEntry.TTL
	}

	if roleEntry.MaxTTL > 0 {
		resp.Secret.MaxTTL = roleEntry.MaxTTL
	}

	return resp, nil
}

// createToken calls the CCloud client to create a new Cluster API Key
func createToken(
	ctx context.Context, c *ccloudAPIKeyClient,
	owner, ownerEnv string,
	resource, resourceEnv string,
	displayName, description string,
) (*ccloudClusterApiKey, error) {
	keyId, secret, err := c.CreateApiKey(ctx, owner, ownerEnv, resource, resourceEnv, displayName, description)

	if err != nil {
		return nil, fmt.Errorf("error creating CCloud Cluster API Key: %w", err)
	}

	return &ccloudClusterApiKey{
		KeyId:  keyId,
		Secret: secret,
	}, nil
}

// deleteToken calls the CCloud API client to sign out and revoke the token
func deleteToken(ctx context.Context, c *ccloudAPIKeyClient, keyId string) error {
	err := c.DeleteApiKey(ctx, keyId)

	if err != nil {
		return fmt.Errorf("error deleting CCloud Cluster API Key: %w", err)
	}

	return nil
}
