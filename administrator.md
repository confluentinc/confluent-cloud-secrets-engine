# Hashicorp Vault Confluent Cloud Plugin - Administrator Guide

This document assumes that you have a Vault up and running. You'll also need a working Confluent Cloud account and cluster.

If you need help setting up Vault, you can consult [Hashicorp Vault's web site](https://www.hashicorp.com/products/vault). It is also useful to look at the way we configure the server in the plugin's demo.

## Setup & Deployment

To install the Vault plugin, you have to register it with Vault and configure it with your Confluent Cloud details (mainly the Cloud API key).   

### Vault setup



### Plugin setup and configuration




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

