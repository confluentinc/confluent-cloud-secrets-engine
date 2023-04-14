package plugin

import (
	"context"
	"fmt"
	"time"

	"github.com/hashicorp/vault/sdk/framework"
	"github.com/hashicorp/vault/sdk/logical"
)

// apikeyRoleEntry defines the data required for a Vault role to access and
// call the Confluent Cloud API Key endpoints
type apikeyRoleEntry struct {
	Owner    string `json:"owner"`
	OwnerEnv string `json:"owner_env,omitempty"`

	Resource    string `json:"resource,omitempty"`
	ResourceEnv string `json:"resource_env,omitempty"`

	TTL    time.Duration `json:"ttl,omitempty"`
	MaxTTL time.Duration `json:"max_ttl,omitempty"`

	DisplayNameTmpl string `json:"display_name_template,omitempty"`
	DescriptionTmpl string `json:"description_template,omitempty"`
}

// toResponseData returns response data for a role
func (r *apikeyRoleEntry) toResponseData() map[string]interface{} {
	respData := map[string]interface{}{
		"owner":                 r.Owner,
		"owner_env":             r.OwnerEnv,
		"resource":              r.Resource,
		"resource_env":          r.ResourceEnv,
		"ttl":                   r.TTL.Seconds(),
		"max_ttl":               r.MaxTTL.Seconds(),
		"display_name_template": r.DisplayNameTmpl,
		"description_template":  r.DescriptionTmpl,
	}
	return respData
}

// pathRole extends the Vault API with a `/role`
// endpoint for the backend. You can choose whether
// or not certain attributes should be displayed,
// required, and named. You can also define different
// path patterns to list all roles.
func pathRole(b *ccloudBackend) []*framework.Path {
	return []*framework.Path{
		{
			Pattern: "role/" + framework.GenericNameRegex("name"),
			Fields: map[string]*framework.FieldSchema{
				"name": {
					Type:        framework.TypeLowerCaseString,
					Description: "Name of the role",
					Required:    true,
				},
				"owner": {
					Type:        framework.TypeString,
					Description: "Confluent Cloud ID of the User or ServiceAccount which will own the API key.",
					Required:    true,
				},
				"owner_env": {
					Type:        framework.TypeString,
					Description: "The owner's CCloud Environment ID, if env-scoped.",
				},
				"resource": {
					Type:        framework.TypeString,
					Description: "Confluent Cloud ID of the Cluster for which the key will be created. If not specified, a Cloud API Key will be generated, instead.",
				},
				"resource_env": {
					Type:        framework.TypeString,
					Description: "The resource's CCloud Environment ID, if env-scoped.",
				},
				"ttl": {
					Type:        framework.TypeDurationSecond,
					Description: "Default lease for generated credentials. If not set or set to 0, will use system default.",
				},
				"max_ttl": {
					Type:        framework.TypeDurationSecond,
					Description: "Maximum lease time for generated credentials. If not set or set to 0, will use system default.",
				},
				//"display_name_template": {
				//    Type:        framwork.TypeString,
				//    Description: "Template describing how dynamic display names are generated.",
				//    Default: // TODO
				//},
				//"description_template": {
				//    Type:        framwork.TypeString,
				//    Description: "Template describing how dynamic descriptions are generated.",
				//    Default: // TODO
				//},
			},
			Operations: map[logical.Operation]framework.OperationHandler{
				logical.ReadOperation: &framework.PathOperation{
					Callback: b.pathRolesRead,
				},
				logical.CreateOperation: &framework.PathOperation{
					Callback: b.pathRolesWrite,
				},
				logical.UpdateOperation: &framework.PathOperation{
					Callback: b.pathRolesWrite,
				},
				logical.DeleteOperation: &framework.PathOperation{
					Callback: b.pathRolesDelete,
				},
			},
			HelpSynopsis:    pathRoleHelpSynopsis,
			HelpDescription: pathRoleHelpDescription,
		},
		{
			Pattern: "role/?$",
			Operations: map[logical.Operation]framework.OperationHandler{
				logical.ListOperation: &framework.PathOperation{
					Callback: b.pathRolesList,
				},
			},
			HelpSynopsis:    pathRoleListHelpSynopsis,
			HelpDescription: pathRoleListHelpDescription,
		},
	}
}

// pathRolesList makes a request to Vault storage to retrieve a list of roles for the backend
func (confluentCloudBackend *ccloudBackend) pathRolesList(ctx context.Context, req *logical.Request, d *framework.FieldData) (*logical.Response, error) {
	entries, err := req.Storage.List(ctx, "role/")
	if err != nil {
		return nil, err
	}

	return logical.ListResponse(entries), nil
}

// pathRolesRead makes a request to Vault storage to read a role and return response data
func (confluentCloudBackend *ccloudBackend) pathRolesRead(ctx context.Context, req *logical.Request, d *framework.FieldData) (*logical.Response, error) {
	entry, err := confluentCloudBackend.getRole(ctx, req.Storage, d.Get("name").(string))
	if err != nil {
		return nil, err
	}

	if entry == nil {
		return nil, nil
	}

	return &logical.Response{
		Data: entry.toResponseData(),
	}, nil
}

// pathRolesWrite makes a request to Vault storage to update a role based on the attributes passed to the role configuration
func (confluentCloudBackend *ccloudBackend) pathRolesWrite(ctx context.Context, req *logical.Request, d *framework.FieldData) (*logical.Response, error) {
	name, ok := d.GetOk("name")
	if !ok {
		return logical.ErrorResponse("missing role name"), nil
	}

	roleEntry, err := confluentCloudBackend.getRole(ctx, req.Storage, name.(string))
	if err != nil {
		return nil, err
	}

	if roleEntry == nil {
		roleEntry = &apikeyRoleEntry{}
	}

	createOperation := (req.Operation == logical.CreateOperation)

	if owner, ok := d.GetOk("owner"); ok {
		roleEntry.Owner = owner.(string)
	} else if !ok && createOperation {
		return nil, fmt.Errorf("missing owner in role")
	}

	if ownerEnv, ok := d.GetOk("owner_env"); ok {
		roleEntry.OwnerEnv = ownerEnv.(string)
	} else if !ok && createOperation {
		return nil, fmt.Errorf("missing owner_env in role")
	}

	if resource, ok := d.GetOk("resource"); ok {
		roleEntry.Resource = resource.(string)
	} else if !ok && createOperation {
		return nil, fmt.Errorf("missing resource in role")
	}

	if resourceEnv, ok := d.GetOk("resource_env"); ok {
		roleEntry.ResourceEnv = resourceEnv.(string)
	} else if !ok && createOperation {
		return nil, fmt.Errorf("missing resource_env in role")
	}

	if ttlRaw, ok := d.GetOk("ttl"); ok {
		roleEntry.TTL = time.Duration(ttlRaw.(int)) * time.Second
	} else if createOperation {
		roleEntry.TTL = time.Duration(d.Get("ttl").(int)) * time.Second
	}

	if maxTTLRaw, ok := d.GetOk("max_ttl"); ok {
		roleEntry.MaxTTL = time.Duration(maxTTLRaw.(int)) * time.Second
	} else if createOperation {
		roleEntry.MaxTTL = time.Duration(d.Get("max_ttl").(int)) * time.Second
	}

	if roleEntry.MaxTTL != 0 && roleEntry.TTL > roleEntry.MaxTTL {
		return logical.ErrorResponse("ttl cannot be greater than max_ttl"), nil
	}

	//if display_name_template, ok := d.GetOk("display_name_template"); ok {
	//    roleEntry.DisplayNameTmpl = display_name_template.(string)
	//} else if !ok && createOperation {
	//    return nil, fmt.Errorf("missing display_name_template in role")
	//}
	//
	//if description_template, ok := d.GetOk("description_template"); ok {
	//    roleEntry.DescriptionTmpl = description_template.(string)
	//} else if !ok && createOperation {
	//    return nil, fmt.Errorf("missing description_template in role")
	//}

	if err := setRole(ctx, req.Storage, name.(string), roleEntry); err != nil {
		return nil, err
	}

	return nil, nil
}

// pathRolesDelete makes a request to Vault storage to delete a role
func (confluentCloudBackend *ccloudBackend) pathRolesDelete(ctx context.Context, req *logical.Request, d *framework.FieldData) (*logical.Response, error) {
	err := req.Storage.Delete(ctx, "role/"+d.Get("name").(string))
	if err != nil {
		return nil, fmt.Errorf("error deleting apikey role: %w", err)
	}

	return nil, nil
}

// setRole adds the role to the Vault storage API
func setRole(ctx context.Context, s logical.Storage, name string, roleEntry *apikeyRoleEntry) error {
	entry, err := logical.StorageEntryJSON("role/"+name, roleEntry)
	if err != nil {
		return err
	}

	if entry == nil {
		return fmt.Errorf("failed to create storage entry for role")
	}

	if err := s.Put(ctx, entry); err != nil {
		return err
	}

	return nil
}

// getRole gets the role from the Vault storage API
func (confluentCloudBackend *ccloudBackend) getRole(ctx context.Context, s logical.Storage, name string) (*apikeyRoleEntry, error) {
	if name == "" {
		return nil, fmt.Errorf("missing role name")
	}

	entry, err := s.Get(ctx, "role/"+name)
	if err != nil {
		return nil, err
	}

	if entry == nil {
		return nil, nil
	}

	var role apikeyRoleEntry

	if err := entry.DecodeJSON(&role); err != nil {
		return nil, err
	}
	return &role, nil
}

const (
	pathRoleHelpSynopsis    = `Manages the Vault role for generating Confluent Cloud Cluster API keys.`
	pathRoleHelpDescription = `
This path allows you to read and write roles used to generate Confluent Cloud
Cluster API keys.
`

	pathRoleListHelpSynopsis    = `List the existing roles in CCloud backend`
	pathRoleListHelpDescription = `Roles will be listed by the role name.`
)
