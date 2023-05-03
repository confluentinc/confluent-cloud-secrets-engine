package plugin

import (
	"context"
	"strings"
	"sync"

	"github.com/hashicorp/vault/sdk/framework"
	"github.com/hashicorp/vault/sdk/logical"
)

func Factory(ctx context.Context, conf *logical.BackendConfig) (logical.Backend, error) {
	b := newBackend()
	if err := b.Setup(ctx, conf); err != nil {
		return nil, err
	}
	return b, nil
}

// ccloudBackend defines an object that
// extends the Vault backend and stores the
// target API's client.
type ccloudBackend struct {
	*framework.Backend
	lock   sync.RWMutex
	client *ccloudAPIKeyClient
}

// backend defines the target API backend
// for Vault. It must include each path
// and the secrets it will store.
func newBackend() *ccloudBackend {
	var b = &ccloudBackend{}

	b.Backend = &framework.Backend{
		Help: strings.TrimSpace(backendHelp),
		Paths: framework.PathAppend(
			pathRole(b),
			[]*framework.Path{
				pathConfig(b),
				pathCredentials(b),
			},
		),
		PathsSpecial: &logical.Paths{
			LocalStorage: []string{},
			SealWrapStorage: []string{
				"config",
				"role/*",
			},
		},
		Secrets: []*framework.Secret{
			b.ccloudClusterApiKey(),
		},
		BackendType: logical.TypeLogical,
		Invalidate:  b.invalidate,
	}
	return b
}

// reset clears any client configuration for a new
// backend to be configured
func (b *ccloudBackend) reset() {
	b.lock.Lock()
	defer b.lock.Unlock()
	b.client = nil
}

// invalidate clears an existing client configuration in
// the backend
func (b *ccloudBackend) invalidate(ctx context.Context, key string) {
	if key == "config" {
		b.reset()
	}
}

// getClient locks the backend as it configures and creates a
// a new client for the target API
func (b *ccloudBackend) getClientCached(ctx context.Context, s logical.Storage) *ccloudAPIKeyClient {
	b.lock.RLock()
	defer b.lock.RUnlock()

	return b.client
}

func (b *ccloudBackend) getClient(ctx context.Context, s logical.Storage) (*ccloudAPIKeyClient, error) {
	client := b.getClientCached(ctx, s)
	if client != nil {
		return client, nil
	}

	// RW lock for updating the client object reference
	b.lock.Lock()
	defer b.lock.Unlock()

	// Check for a race
	if b.client != nil {
		return b.client, nil
	}

	// Build a new client
	config, err := getConfig(ctx, s)
	if err != nil {
		return nil, err
	}

	client, err = newClient(config, b.Logger())
	if err != nil {
		return nil, err
	}

	b.client = client

	return client, nil
}

// backendHelp should contain help information for the backend
const backendHelp = `
The Confluent Cloud secrets backend dynamically generates CCloud Cluster API
keys. After mounting this backend, Confluent Cloud credentials to manage
Cluster API keys must be configured with the "config" endpoint.
`
