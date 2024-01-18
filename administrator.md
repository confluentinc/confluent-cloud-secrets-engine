# Hashicorp Vault Confluent Cloud Plugin - Administrator Guide

This document assumes that you have a Vault server up and running. You'll also need a working Confluent Cloud account and cluster.

If you need help setting up Vault, you can consult [Hashicorp Vault's web site](https://www.hashicorp.com/products/vault). It is also useful to look at the way we configure the server in the plugin's demo.

## Setup & Deployment

To install the Vault plugin, you have to register it with Vault and configure it with your Confluent Cloud details (mainly the Cloud API key).   

### Vault setup

Files provided:
- `vault/server.hcl`: example of a minimal Vault server config for the plugin, in HCL format (https://developer.hashicorp.com/vault/docs/configuration)
- `bin/vault-ccloud-secrets-engine`: the plugin's binary

1. Get the directory for plugins from your Vault server and copy the plugin's binary into it.
2. Get the SHA256 sum of the plugin (you can verify it's the same as the one we provide)
```shell
sha256sum bin/vault-ccloud-secrets-engine | cut -d' ' -f1
```
3. Register the plugin: 
```shell
vault plugin register -sha256="<SHA256>" -command="vault-ccloud-secrets-engine" secret ccloud-secrets-engine
```
In the above command, replace `<SHA256>` with the result from step 2.
3. Enable it: 
```shell
vault secrets enable -path="ccloud" -plugin-name="ccloud-secrets-engine" plugin
```
Please note: You can set a default and a maximum duration for leases in this command with the options `-default-lease-ttl` and `-max-lease-ttl` respectively. Read the section on leases below for more details.

### Plugin setup and configuration

The plugin configuration consists simply in providing the CC Cloud API key details.

Where to get the information you need:

**CC_CLOUD_API_KEY + CC_CLOUD_API_SECRET**

On the top right menu (aka hamburger menu), click `Cloud API keys`

![](./img/cloud-api-keys.png)

**CC_OWNER_ID**

On the top right menu (aka hamburger menu), click your name, the ID will be in the details in the center box.

![](./img/owner-id.png)

**CC_ENVIRONMENT_ID**

Select the desired environment, then copy its ID from the URL.

![](./img/env-id.png)

**CC_CLUSTER_ID**

Select the desired cluster, then copy its ID from the center box.

![](./img/cluster-id.png)

1. Provide the CC Could API key to the plugin:
```shell
vault write ccloud/config ccloud_api_key_id=<CC_CLOUD_API_KEY> ccloud_api_key_secret=<CC_CLOUD_API_SECRET> url="https://api.confluent.cloud"
```

2. Configure the role/app
Under the `role` path, you'll configure your applications' Confluent Cloud API keys. For each role/app, you'll need to provide the owner ID, the environment ID and the cluster ID.

```shell
vault write ccloud/role/app1 name="app1" owner=<CC_OWNER_ID> owner_env=<CC_ENVIRONMENT_ID> resource=<CC_CLUSTER_ID> resource_env=<CC_ENVIRONMENT_ID>
```

The app will read the secret using the path defined above. Here is an example using the Vault CLI:

```shell
vault read ccloud/creds/app1
```

## The Lease

Not the title of a movie, but simply when a secret is requested to Vault, it returns it with a lease. 

```
Along with the lease ID, a lease duration can be read. The lease duration is a Time To Live value: the time in seconds for which the lease is valid. A consumer of this secret must renew the lease within that time.
```
https://developer.hashicorp.com/vault/docs/concepts/lease

If the lease is not renewed within its TTL, then the lease is revoked and the Confluent Could API key may be removed (for situations when it's removed or not, see Key Management Strategies below).

**If the CC API key is removed then your application will not be able to interact with Confluent Cloud anymore.**

To extend a lease:
```shell
vault lease renew -increment=<VALUE> <LEASE-ID>
```

- The lease ID will look like this: `ccloud/creds/app1/2gCWMHufo7RjK6zF5AChPkTn`
- `-increment` is in seconds and defines a new value for the expiry that starts at the time of the command execution.

## Key Management Strategies

Things to consider:
- Lease Expiry
- App restart planned
- App able to react to (or crashing)
- Environment restarting stopped apps automatically

Strategies
- App launched with no planned restart
-- long to quasi-infinite key expiry 
-- short key expiry
- App restarted periodically
-- key expiry = app restart frequency

## Notes

