# Project Pre-Requisites

1. Install Go https://go.dev/doc/install
2. Install vault CLI https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install
3. Docker installed and running.
4. Confluent Cloud API key - This can be created under Cloud Api keys which is found within the top right hamburger within Confluent Cloud. If you don't already have one associated with your account go ahead and create one.

# Detailed Installation
After cloning this repo to install all the necessary dependencies inside pkg/plugin run  
```shell
go build
```

## 1. Generates the binary file hashicorp-vault-ccloud-secrets-engine under bin/hashicorp-vault-ccloud-secrets-engine

```shell
 GOOS=linux GOARCH=amd64  make build 
 ```

## 2. Spin up docker container
```shell
docker-compose up -d 
   ```

## 3.Get the SHA256 digest of the binary file:
Mac command:
```
export SHA256=$(shasum -a 256 bin/hashicorp-vault-ccloud-secrets-engine | cut -d' ' -f1)
```

Linux command:
```
export SHA256=$(sha256sum bin/vault-ccloud-secrets-engine | cut -d' ' -f1)
```

## 4. In another shell set the vault address, vault token and register the plugin with the type being a "secret" and passing in the SHA of the binary.

```
export VAULT_ADDR='http://0.0.0.0:8200
export VAULT_TOKEN=12345
vault plugin register -sha256="${SHA256}"  -command="hashicorp-vault-ccloud-secrets-engine" secret ccloud-secrets-engine
```

To confirm commands have run successfully you should see an output simialr to ```Success! Registered plugin: ccloud-secrets-engine```

## 5. Enable the new Secrets Engine
```
vault secrets enable -path="ccloud" -plugin-name="ccloud-secrets-engine" plugin
```
When successfully enabled you should see ```Success! Enabled the ccloud-secrets-engine secrets engine at: ccloud/```

## 6. Write to Confluent Cloud

These steps provide the backend with an API key and secret used to make authenticated calls to the Confluent Cloud
```
vault write ccloud/config ccloud_api_key_id="xxx" ccloud_api_key_secret="xxx" url="https://api.confluent.cloud"
```

On success you should see ```Success! Data written to: ccloud/config```

## 7. Configuring a Role
The following steps setup a new role.

Set up a role and pass in a name, environment_id (where cluster lives), owner_id (create keys under this user/service acct), and resource_id ( the kafka cluster to register keys with).
owner can be found in Accounts and Access then in the table it is the ID, resource_env is the same as owner_env

```
vault write ccloud/role/test name="test" owner="xxxx" owner_env="env-xxx" resource="lkc-xxx" resource_env="env-xxx"
```

On success you should see '''Success! Data written to: ccloud/role/test'''

## 8. To request a new dynamic API-key run this command in your terminal 
```
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

You should be able to see your new api key inside the list of api keys for the cluster under your account. It should look simialr to "INSERT PICTURE HERE"


# Possible Errors
```
command not found: vault
```
This error means that the hasicorp vault cli isnt installed on the local machine. Please read the Project Pre-Requisites for all necessary tools.

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

Make sure the api token was created under Cloud Api keys found in the top right hamburger.

# Tests
To run the tests you have to be in pkg/plugin. Then run the command 
```go test```