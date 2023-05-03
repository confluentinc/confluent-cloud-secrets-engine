package plugin

import (
	"context"
	"errors"
	"fmt"

	apikeys "github.com/confluentinc/ccloud-sdk-go-v2/apikeys/v2"
	"github.com/hashicorp/go-hclog"
)

type ccloudAPIKeyClient struct {
	client    *apikeys.APIClient
	authBasic *apikeys.BasicAuth

	log hclog.Logger
}

func newClient(config *ccloudConfig, logger hclog.Logger) (*ccloudAPIKeyClient, error) {
	if config == nil {
		return nil, errors.New("Client configuration nil")
	}

	if config.ApiKeyId == "" {
		return nil, errors.New("CCloud API Key ID not defined")
	}

	if config.ApiKeySecret == "" {
		return nil, errors.New("CCloud API Key Secret not defined")
	}

	if logger == nil {
		logger = hclog.NewNullLogger()
	}

	apikeysConfig := apikeys.NewConfiguration()

	if config.URL != "" {
		// Prepend custom URL, making it the new default.
		apikeysConfig.Servers = append(
			apikeys.ServerConfigurations{{
				URL:         config.URL,
				Description: "Custom Confluent Cloud API URL",
			}},
			apikeysConfig.Servers...,
		)
	}

	client := apikeys.NewAPIClient(apikeysConfig)

	return &ccloudAPIKeyClient{
		client: client,
		authBasic: &apikeys.BasicAuth{
			UserName: config.ApiKeyId,
			Password: config.ApiKeySecret,
		},

		log: logger,
	}, nil
}

func (c *ccloudAPIKeyClient) contextWithAuth(ctx context.Context) context.Context {
	if c.authBasic != nil {
		ctx = context.WithValue(ctx, apikeys.ContextBasicAuth, *c.authBasic)
	}

	return ctx
}

func (c *ccloudAPIKeyClient) CreateApiKey(
	ctx context.Context,
	owner, ownerEnv string,
	resource, resourceEnv string,
	displayName, description string,
) (keyId, keySecret string, err error) {
	ctx = c.contextWithAuth(ctx)

	v2ApiKey := apikeys.IamV2ApiKey{
		Spec: &apikeys.IamV2ApiKeySpec{
			Owner: &apikeys.ObjectReference{
				Id: owner,
			},
		},
	}
	if ownerEnv != "" {
		v2ApiKey.Spec.Owner.Environment = &ownerEnv
	}
	if resource != "" {
		v2ApiKey.Spec.Resource = &apikeys.ObjectReference{
			Id: resource,
		}
		if resourceEnv != "" {
			v2ApiKey.Spec.Resource.Environment = &resourceEnv
		}
	}
	if displayName != "" {
		v2ApiKey.Spec.DisplayName = &displayName
	}
	if description != "" {
		v2ApiKey.Spec.Description = &description
	}

	req := c.client.APIKeysIamV2Api.CreateIamV2ApiKey(ctx).IamV2ApiKey(v2ApiKey)
	v2ApiKey, _, err = req.Execute()

	if err != nil {
		if openAPIErr, ok := err.(apikeys.GenericOpenAPIError); ok {
			return "", "", fmt.Errorf("error creating CCloud Cluster API Key: %w. Ccloud response: %s", err, string(openAPIErr.Body()))
		}
		return "", "", fmt.Errorf("error creating CCloud Cluster API Key: %w", err)
	}

	return v2ApiKey.GetId(), v2ApiKey.Spec.GetSecret(), nil
}

// deleteToken calls the CCloud API client to sign out and revoke the token
func (c *ccloudAPIKeyClient) DeleteApiKey(ctx context.Context, keyId string) error {
	ctx = c.contextWithAuth(ctx)

	req := c.client.APIKeysIamV2Api.DeleteIamV2ApiKey(ctx, keyId)
	_, err := req.Execute()

	return err
}
