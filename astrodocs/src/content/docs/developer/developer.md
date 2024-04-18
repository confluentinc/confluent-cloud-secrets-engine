---
title: Confluent Cloud Secrets Engine - Developer Guide
tableOfContents:
  maxHeadingLevel: 4
---

# Project Pre-Requisites

1. Install Go https://go.dev/doc/install
2. Install vault CLI https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install
3. Docker installed and running.
4. Ensure you have created a [Personal Access Token ](https://confluentinc.atlassian.net/wiki/spaces/Engineering/pages/1085800848/Setting+up+Accounts)in github. Please remember once the PAT is created to enable sso for confluent. 
5. Confluent Cloud Account
6. Confluent Cloud API key - This can be created under Cloud Api keys which is found within the top right hamburger within Confluent Cloud. If you don't already have one associated with your account go ahead and create one.
   After cloning this repo, to install all the necessary dependencies run

# Quick Start
After cloning this repo have docker running locally before continuing.

## 1. Download dependencies 
```shell
cd pkg/plugin
go build
```

## 2. Build
Run this command in the top level of the project. If you have just downloaded the project dependencies please cd into the top level. 
 ```shell
 make create
 ```
## 3. Start Docker Container
```shell
docker-compose up -d 
   ```

## 4. Export Config
This command exports the address and token for vault, gets the SHA256 digest of the binary file and enables the new secret's engine.
```shell
export VAULT_ADDR='http://0.0.0.0:8200'
export VAULT_TOKEN=12345
make enable
```
On success, you should see 
```Success! Registered plugin: ccloud-secrets-engine```

## 5. Export Environment Variables
Export the necessary environment variables and run make setup to enable plugin and configure a test role in Vault:
Log into confluent cloud to find these environment variables. 
If you have an existing confluent cloud api key and secret you can use that. If not go to Cloud API Keys and create a new key.
CONFLUENT_KEY (Confluent Cloud API key), CONFLUENT_SECRET (the secret for the Confluent Cloud API key), CONFLUENT_ENVIRONMENT_ID (where the cluster lives), CONFLUENT_OWNER_ID (create keys under this user/service acct), and CONFLUENT_RESOURCE_ID (the Kafka cluster to register keys with).
Owner can be found in Accounts and Access then in the table it is the ID, resource_env is the same as owner_env

```shell
export CONFLUENT_KEY="xxx"
export CONFLUENT_SECRET="xxx"
export CONFLUENT_ENVIRONMENT_ID="xxx"
export CONFLUENT_OWNER_ID="xxx"
export CONFLUENT_RESOURCE_ID="xxx"
```

## 6. Create Role
Single Use Role
```shell
make setup
```
Multi Use Role  
```shell
make setupMulti
```

## 7. Finally, Request a New Dynamic API-Key
```shell
vault read ccloud/creds/test
```
On success should return
```
Key                Value
---                -----
lease_id           ccloud/creds/test/xxxxxx
lease_duration     1h
lease_renewable    true
key_id             xxxx
secret             xxxxxxxxxx
```

# Detailed Installation
After cloning this repo, to install all the necessary dependencies run  
```shell
cd pkg/plugin
go build
```

## 1. Generate Binary File
Now that the project has been built cd into the top level of the project because we want to generate the binary file hashicorp-vault-ccloud-secrets-engine under bin/hashicorp-vault-ccloud-secrets-engine
```shell
 	GOOS=linux GOARCH=amd64  make build
 ```

## 2. Start Docker Container
```shell
docker-compose up -d 
   ```

## 3. Export SHA256
Get the SHA256 digest of the binary file:
Mac command:
```shell
export SHA256=$(shasum -a 256 bin/vault-ccloud-secrets-engine | cut -d' ' -f1)
```

Linux command:
```shell
export SHA256=$(sha256sum bin/vault-ccloud-secrets-engine | cut -d' ' -f1)
```

## 4. Export Config
In another shell set the vault address, vault token and register the plugin with the type being a "secret" and passing in the SHA of the binary.
```shell
export VAULT_ADDR='http://0.0.0.0:8200'
export VAULT_TOKEN=12345
vault plugin register -sha256="${SHA256}" -command="vault-ccloud-secrets-engine" secret ccloud-secrets-engine
```

To confirm commands have run successfully you should see an output simialr to ```Success! Registered plugin: ccloud-secrets-engine```

## 5. Enable The New Secrets Engine
```shell
vault secrets enable -path="ccloud" -plugin-name="ccloud-secrets-engine" plugin
```
When successfully enabled you should see ```Success! Enabled the ccloud-secrets-engine secrets engine at: ccloud/```

## 6. Write to Confluent Cloud

These steps provide the backend with an API key and secret used to make authenticated calls to the Confluent Cloud
```shell
vault write ccloud/config ccloud_api_key_id="xxx" ccloud_api_key_secret="xxx" url="https://api.confluent.cloud"
```

On success you should see ```Success! Data written to: ccloud/config```

## 7. Configuring a Role
The following steps setup a new role.

Set up a role and pass in a name, environment_id (where cluster lives), owner_id (create keys under this user/service acct), and resource_id ( the kafka cluster to register keys with).
owner can be found in Accounts and Access then in the table it is the ID, resource_env is the same as owner_env

```shell
vault write ccloud/role/test name="test" owner="xxxx" owner_env="env-xxx" resource="lkc-xxx" resource_env="env-xxx"
```

On success, you should see '''Success! Data written to: ccloud/role/test'''

## 8. Finally, Request a New Dynamic API-key
```shell
vault read ccloud/creds/test
```

Which on success should return
```
Key                Value
---                -----
lease_id           ccloud/creds/test/xxxxxx
lease_duration     1h
lease_renewable    true
key_id             xxxx
secret             xxxxxxxxxx
```

You should be able to see your new api key inside the list of api keys for the cluster under your account.


# Possible Errors
```
command not found: vault
```
This error means that the Hashicorp Vault CLI isn't installed on the local machine. Please read the Project Pre-Requisites for all necessary tools.

```
error creating CCloud Cluster API token - Error reading ccloud/creds/test: Error making API request.

URL: GET http://0.0.0.0:8200/v1/ccloud/creds/test
Code: 500. Errors:

* 1 error occurred:
	* error creating CCloud Cluster API token: error creating CCloud Cluster API Key: error creating CCloud Cluster API Key: 401 Unauthorized. Ccloud response: {
  "errors": [
    {
      "id": "xxxxx",
      "status": "401",
      "detail": "invalid API key: make sure you're using a Cloud API Key and not a Cluster API Key: https://docs.confluent.io/cloud/current/api.html#section/Authentication",
      "source": {}
    }
  ]
}
```

Make sure the API token was created under Cloud Api keys found in the top right (hamburger) menu.

# Tests
To run the tests you have to be in pkg/plugin. Then run the command 
```go test```

# Integration Testing
Go to ```TestAcceptanceUserToken``` in ```pie-cc-hashicorp-vault-plugin/pkg/plugin```.

In the run configurations you will need to set some environment config which can be found in confluent cloud. This is the same information needed in the quick start:

If you have an existing Confluent Cloud API key and secret you can use that. If not go to Cloud API Keys and create a new key.
CONFLUENT_KEY (Confluent Cloud API key), CONFLUENT_SECRET (secret of the Confluent Cloud API key), CONFLUENT_ENVIRONMENT_ID (where cluster lives), CONFLUENT_OWNER_ID (create keys under this user/service acct), and CONFLUENT_RESOURCE_ID (the Kafka cluster to register keys with).
Owner can be found in Accounts and Access then in the table it is the ID, resource_env is the same as owner_env

In the environment field for the tests add:
```
VAULT_ACC=1;TEST_CCLOUD_ENV_ID=Environment_id;TEST_CCLOUD_RESOURCE_ID=resource_id;TEST_CCLOUD_KEY_ID=cloudKey;TEST_CCLOUD_OWNER=Environment_id;TEST_CCLOUD_SECRET=cloudSecret;TEST_CCLOUD_URL=https://api.confluent.cloud;TEST_MULTI_USE_KEY=true;
```
The ```VAULT_ACC=1``` flag enables the integration tests. This flag is checked in ```path_credentials_test.go``` in ```if !runAcceptanceTests { t.SkipNow() }```. You can comment this line out if you don't want to set the flag in the environment variables.
The ```TEST_MULTI_USE_KEY=true;``` flag enables the creation of a multi use api key and secret in confluent cloud. 