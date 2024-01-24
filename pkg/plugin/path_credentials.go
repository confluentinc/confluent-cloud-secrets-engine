package plugin

import (
	"context"
	"errors"
	"fmt"
	"github.com/hashicorp/vault/sdk/framework"
	"github.com/hashicorp/vault/sdk/logical"
	"log"
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
		return nil, fmt.Errorf("error retrieving role: %w", err)
	}

	if roleEntry == nil {
		return nil, errors.New("error retrieving role: role is nil")
	}

	/**
	What happens when a user creates a multi use role for the first time, should we also do the create then if the role exists then read.
	if roleEntry is multi use we should read it.
	*/
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
			"key_id": token.KeyId,
			"secret": token.Secret,
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

	role.CCKeyId = token.KeyId
	role.UsageCount = 1

	log.Println("this is on create")
	log.Println(role)

	return resp, nil
}

/**
read credential
*/

// readOrCreateCredential reads an existing Cluster API key or creates it if it doesn't exist
// backend, generates a response with the secrets information, and checks the
// TTL and MaxTTL attributes.
func (b *ccloudBackend) readOrCreateCredential(ctx context.Context, req *logical.Request, roleName string, role *apikeyRoleEntry) (*logical.Response, error) {
	log.Println("into multi")
	// first use = usage count 0 means the key has not been created yet
	if role.UsageCount == 0 {
		return b.createCredential(ctx, req, roleName, role)
	}

	// usage count > 0, we return the existing key
	role.UsageCount++

	log.Println(role)

	var keyId = role.CCKeyId
	var keySecret any

	for i, k := range b.Secrets {
		if _, ok := k.Fields["key_id"]; ok {
			keySecret = k.Fields["secret"]
			return b.Secret(ccloudClusterApiKeyType).Response(
				// Data
				map[string]interface{}{
					"key_id": keyId,
					"secret": keySecret,
				},
				// Internal
				map[string]interface{}{
					"key_id": keyId,
					"role":   roleName,
				},
			), nil
		}
		log.Println(i, k)
	}
	return nil, errors.New("Unable to find key and secret")
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

	// TODO Populate Description Template
	description := fmt.Sprintf("Created by Vault: path=%s%s entity=%s)", req.MountPoint, req.Path, req.DisplayName)

	apiKey, err = createToken(ctx, client, roleEntry.Owner, roleEntry.OwnerEnv, roleEntry.Resource, roleEntry.ResourceEnv, displayName, description)
	if err != nil {
		return nil, fmt.Errorf("error creating CCloud Cluster API token: %w", err)
	}

	if apiKey.KeyId == "" || apiKey.Secret == "" {
		return nil, errors.New("received an invalid CCloud Cluster API token")
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
