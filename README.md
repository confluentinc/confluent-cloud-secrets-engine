# Project Pre-Requisites

1. Install Go https://go.dev/doc/install
2. Install vault CLI https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install
3. Docker installed and running.
4. Confluent Cloud API key - This can be created under Cloud Api keys which is found within the top right hamburger within Confluent Cloud. If you don't already have one associated with your account go ahead and create one.

# Detailed Installation

GOOS=linux GOARCH=amd64 make build

## 1. Generates the binary file hashicorp-vault-ccloud-secrets-engine under bin/hashicorp-vault-ccloud-secrets-engine

``` GOOS=linux GOARCH=amd64  make build ```

## 2. ``` docker-compose up -d ```

## 3. Mac command:
```
export SHA256=$(shasum -a 256 bin/hashicorp-vault-ccloud-secrets-engine | cut -d' ' -f1)
```

Linux command:
```
export SHA256=$(sha256sum bin/vault-ccloud-secrets-engine | cut -d' ' -f1)
```

## 4. Now run these commands
```
export VAULT_ADDR='http://0.0.0.0:8200
export VAULT_TOKEN=12345
vault plugin register -sha256="${SHA256}"  -command="hashicorp-vault-ccloud-secrets-engine" secret ccloud-secrets-engine
```

To confirm commands have ran successfully you should see an output simialr to ```Success! Registered plugin: ccloud-secrets-engine```

## 5. To enable the new secrets engine run this command 
```
vault secrets enable -path="ccloud" -plugin-name="ccloud-secrets-engine" plugin
```
When successfully enabled you should see ```Success! Enabled the ccloud-secrets-engine secrets engine at: ccloud/```

## 6. Run this command in your terminal 
```
vault write ccloud/config ccloud_api_key_id="xxx" ccloud_api_key_secret="xxx" url="https://api.confluent.cloud"
```

On success you should see ```Success! Data written to: ccloud/config```

## 7. Next run this command in your terminal 

owner can be found in Accounts and Access then in the table it is the ID.
owner_env can be found in the confluent environment list command under CLI and Tools which is found at the bottom left of the Clusters Overview page.
resource can be found in the command to list clusters command under CLI and Tools which is found at the bottom left of the Clusters Overview page.
resource_env is the same as owner_env

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
