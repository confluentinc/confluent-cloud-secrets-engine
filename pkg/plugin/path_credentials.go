package plugin

import (
	"context"
	"errors"
	"fmt"
	"github.com/hashicorp/vault/sdk/framework"
	"github.com/hashicorp/vault/sdk/logical"
)

// pathCredentials extends the Vault API with a `/creds`
// endpoint for a role. You can choose whether
// or not certain attributes should be displayed,
// required, and named.
func pathCredentials(b *ccloudBackend) *framework.Path {
	return &framework.Path{
		Pattern: "creds/" + framework.GenericNameRegex("name"),
		Fields: map[string]*framework.FieldSchema{
			"name": {
				Type:        framework.TypeLowerCaseString,
				Description: "Name of the role",
				Required:    true,
			},
		},
		Callbacks: map[logical.Operation]framework.OperationFunc{
			logical.ReadOperation:   b.pathCredentialsRead,
			logical.UpdateOperation: b.pathCredentialsRead,
		},
		HelpSynopsis:    pathCredentialsHelpSyn,
		HelpDescription: pathCredentialsHelpDesc,
	}
}

// pathCredentialsRead creates a new Cluster API Key each time it is called if
// a role exists.
func (b *ccloudBackend) pathCredentialsRead(ctx context.Context, req *logical.Request, d *framework.FieldData) (*logical.Response, error) {
	roleName := d.Get("name").(string)

	roleEntry, err := b.getRole(ctx, req.Storage, roleName)
	if err != nil {
		b.Logger().Error("Error retrieving role: %v", roleName)
		return nil, fmt.Errorf("error retrieving role: %w", err)
	}

	if roleEntry == nil {
		b.Logger().Error("Role is nil")
		return nil, errors.New("error retrieving role: role is nil")
	}

	if roleEntry.MultiUseKey == false {
		return b.createCredential(ctx, req, roleName, roleEntry)
	} else {
		return b.readOrCreateCredential(ctx, req, roleName, roleEntry)
	}
}

// createCredential creates a new Cluster API Key to store into the Vault
// backend, generates a response with the secrets information, and checks the
// TTL and MaxTTL attributes.
func (b *ccloudBackend) createCredential(ctx context.Context, req *logical.Request, roleName string, role *apikeyRoleEntry) (*logical.Response, error) {
	token, err := b.createClusterKey(ctx, req, role)

	if err != nil {
		return nil, err
	}

	// The response is divided into two objects (1) internal data and (2) data.
	// If you want to reference any information in your code, you need to
	// store it in internal data!
	resp := b.Secret(ccloudClusterApiKeyType).Response(
		// Data
		map[string]interface{}{
			"key_id":           token.KeyId,
			"secret":           token.Secret,
			"sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username='" + token.KeyId + "' password='" + token.Secret + "';",
		},
		// Internal
		map[string]interface{}{
			"key_id": token.KeyId,
			"role":   roleName,
		},
	)

	if role.TTL > 0 {
		resp.Secret.TTL = role.TTL
	}

	if role.MaxTTL > 0 {
		resp.Secret.MaxTTL = role.MaxTTL
	}

	if role.MultiUseKey == true {
		role.CCKeyId = token.KeyId
		role.CCKeySecret = token.Secret
		role.UsageCount = 1
		setRole(ctx, req.Storage, roleName, role)
	}

	return resp, nil
}

// createCredential creates a new Cluster API Key to store into the Vault
// backend, generates a response with the secrets information, and checks the
// TTL and MaxTTL attributes.
func (b *ccloudBackend) removeCredential(ctx context.Context, req *logical.Request, keyId string) (*logical.Response, error) {
	client, err := b.getClient(ctx, req.Storage)

	deleteToken(ctx, client, keyId)

	return nil, err
}

// readOrCreateCredential reads an existing Cluster API key or creates it if it doesn't exist
// backend, generates a response with the secrets information, and checks the
// TTL and MaxTTL attributes.
func (b *ccloudBackend) readOrCreateCredential(ctx context.Context, req *logical.Request, roleName string, role *apikeyRoleEntry) (*logical.Response, error) {
	// first use = usage count 0 means the key has not been created yet
	if role.UsageCount == 0 {
		return b.createCredential(ctx, req, roleName, role)
	}

	// usage count > 0, we return the existing key
	role.UsageCount++
	setRole(ctx, req.Storage, roleName, role)

	return b.Secret(ccloudClusterApiKeyType).Response(
		// Data
		map[string]interface{}{
			"key_id":           role.CCKeyId,
			"secret":           role.CCKeySecret,
			"sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username='" + role.CCKeyId + "' password='" + role.CCKeySecret + "';",
		},
		// Internal
		map[string]interface{}{
			"key_id": role.CCKeyId,
			"role":   roleName,
		},
	), nil
}

// createClusterKey uses the CCloud client to sign in and get a new token
func (b *ccloudBackend) createClusterKey(ctx context.Context, req *logical.Request, roleEntry *apikeyRoleEntry) (*ccloudClusterApiKey, error) {
	client, err := b.getClient(ctx, req.Storage)
	if err != nil {
		return nil, err
	}

	var apiKey *ccloudClusterApiKey

	// TODO Populate Display Name Template
	displayName := "display_name"

	description := fmt.Sprintf("Key for role: %s%s (entity=%s, source=Vault CC plugin)", req.MountPoint, req.Path, req.DisplayName)
	if roleEntry.KeyDescription != "" {
		description = roleEntry.KeyDescription
	}

	apiKey, err = createToken(ctx, client, roleEntry.Owner, roleEntry.OwnerEnv, roleEntry.Resource, roleEntry.ResourceEnv, displayName, description)

	if err != nil {
		return nil, fmt.Errorf("error creating CCloud Cluster API token: %w", err)
	}

	if apiKey.KeyId == "" || apiKey.Secret == "" {
		b.Logger().Error("Invalid CCloud API Token")
		return nil, errors.New("received an invalid CCloud Cluster API token")
	} else {
		b.Logger().Info(`Created CC API key: %v`, apiKey.KeyId)
	}

	return apiKey, nil
}

const pathCredentialsHelpSyn = `
Generate a Confluent Cloud Cluster API token from a specific Vault role.
`

const pathCredentialsHelpDesc = `
This path generates Confluent Cloud Cluster API tokens based on a particular
role.
`
