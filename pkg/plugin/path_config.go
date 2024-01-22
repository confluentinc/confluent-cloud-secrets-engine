package plugin

import (
	"context"
	"errors"
	"fmt"

	"github.com/hashicorp/vault/sdk/framework"
	"github.com/hashicorp/vault/sdk/logical"
)

const (
	configStoragePath = "config"
)

// ccloudConfig includes the minimum configuration
// required to instantiate a new CCloud API client.
type ccloudConfig struct {
	ApiKeyId     string `json:"api_key_id"`
	ApiKeySecret string `json:"api_key_secret"`
	URL          string `json:"url"`
}

// pathConfig extends the Vault API with a `/config` endpoint for the backend.
func pathConfig(b *ccloudBackend) *framework.Path {
	return &framework.Path{
		Pattern: "config",
		Fields: map[string]*framework.FieldSchema{
			"ccloud_api_key_id": {
				Type:        framework.TypeString,
				Description: "The API Key ID to access Confluent Cloud API",
				Required:    true,
				DisplayAttrs: &framework.DisplayAttributes{
					Name:      "Confluent Cloud API Key ID",
					Sensitive: false,
				},
			},
			"ccloud_api_key_secret": {
				Type:        framework.TypeString,
				Description: "The API Key Secret to access Confluent Cloud API",
				Required:    true,
				DisplayAttrs: &framework.DisplayAttributes{
					Name:      "Confluent Cloud API Key Secret",
					Sensitive: true,
				},
			},
			"url": {
				Type:        framework.TypeString,
				Description: "The URL for the Confluent Cloud API",
				Required:    false,
				DisplayAttrs: &framework.DisplayAttributes{
					Name:      "URL",
					Sensitive: false,
				},
			},
		},
		Operations: map[logical.Operation]framework.OperationHandler{
			logical.ReadOperation: &framework.PathOperation{
				Callback: b.pathConfigRead,
			},
			logical.CreateOperation: &framework.PathOperation{
				Callback: b.pathConfigWrite,
			},
			logical.UpdateOperation: &framework.PathOperation{
				Callback: b.pathConfigWrite,
			},
			logical.DeleteOperation: &framework.PathOperation{
				Callback: b.pathConfigDelete,
			},
		},
		ExistenceCheck:  b.pathConfigExistenceCheck,
		HelpSynopsis:    pathConfigHelpSynopsis,
		HelpDescription: pathConfigHelpDescription,
	}
}

// pathConfigExistenceCheck verifies if the configuration exists.
func (b *ccloudBackend) pathConfigExistenceCheck(ctx context.Context, req *logical.Request, data *framework.FieldData) (bool, error) {
	out, err := req.Storage.Get(ctx, req.Path)
	if err != nil {
		return false, fmt.Errorf("existence check failed: %w", err)
	}

	return out != nil, nil
}

// pathConfigRead reads the configuration and outputs non-sensitive information.
func (b *ccloudBackend) pathConfigRead(ctx context.Context, req *logical.Request, data *framework.FieldData) (*logical.Response, error) {
	config, err := getConfig(ctx, req.Storage)
	if err != nil {
		return nil, err
	}

	return &logical.Response{
		Data: map[string]interface{}{
			"ccloud_api_key_id":     config.ApiKeyId,
			"ccloud_api_key_secret": config.ApiKeySecret,
			"url":                   config.URL,
		},
	}, nil
}

// pathConfigWrite updates the configuration for the backend
func (b *ccloudBackend) pathConfigWrite(ctx context.Context, req *logical.Request, data *framework.FieldData) (*logical.Response, error) {
	config, err := getConfig(ctx, req.Storage)
	if err != nil {
		return nil, err
	}

	createOperation := (req.Operation == logical.CreateOperation)

	if config == nil {
		if !createOperation {
			return nil, errors.New("config not found during update operation")
		}
		config = new(ccloudConfig)
	}

	if keyId, ok := data.GetOk("ccloud_api_key_id"); ok {
		config.ApiKeyId = keyId.(string)
	} else if !ok && createOperation {
		return nil, fmt.Errorf("missing ccloud_api_key_id in configuration")
	}
	if secret, ok := data.GetOk("ccloud_api_key_secret"); ok {
		config.ApiKeySecret = secret.(string)
	} else if !ok && createOperation {
		return nil, fmt.Errorf("missing ccloud_api_key_secret in configuration")
	}

	if url, ok := data.GetOk("url"); ok {
		config.URL = url.(string)
	} else if !ok && createOperation {
		config.URL = data.GetDefaultOrZero("url").(string)
	}

	entry, err := logical.StorageEntryJSON(configStoragePath, config)
	if err != nil {
		return nil, err
	}

	if err := req.Storage.Put(ctx, entry); err != nil {
		return nil, err
	}

	// reset the client so the next invocation will pick up the new configuration
	b.reset()

	return nil, nil
}

// pathConfigDelete removes the configuration for the backend
func (b *ccloudBackend) pathConfigDelete(ctx context.Context, req *logical.Request, data *framework.FieldData) (*logical.Response, error) {
	err := req.Storage.Delete(ctx, configStoragePath)

	if err == nil {
		b.reset()
	}

	return nil, err
}

func getConfig(ctx context.Context, s logical.Storage) (*ccloudConfig, error) {
	entry, err := s.Get(ctx, configStoragePath)
	if err != nil {
		return nil, err
	}

	config := new(ccloudConfig)

	if entry != nil {
		if err := entry.DecodeJSON(&config); err != nil {
			return nil, fmt.Errorf("error reading root configuration: %w", err)
		}
	}

	// return the config, we are done
	return config, nil
}

// pathConfigHelpSynopsis summarizes the help text for the configuration
const pathConfigHelpSynopsis = `Configure the CCloud backend.`

// pathConfigHelpDescription describes the help text for the configuration
const pathConfigHelpDescription = `
The Confluent Cloud secret backend requires credentials for managing
Cluster tokens using the Confluent Cloud API.

You must provide a Confluent Cloud API key with permission to manage Cluster
API tokens before using this secrets backend.
`
