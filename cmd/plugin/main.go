package main

import (
	"log"
	"log/syslog"
	"os"

	ccloud "github.com/confluentinc/pie-cc-hashicorp-vault-plugin/pkg/plugin"
	"github.com/hashicorp/vault/api"
	"github.com/hashicorp/vault/sdk/plugin"
)

func main() {
	apiClientMeta := &api.PluginAPIClientMeta{}
	flags := apiClientMeta.FlagSet()
	flags.Parse(os.Args[1:])

	tlsConfig := apiClientMeta.GetTLSConfig()
	tlsProviderFunc := api.VaultPluginTLSProvider(tlsConfig)

	err := plugin.Serve(&plugin.ServeOpts{
		BackendFactoryFunc: ccloud.Factory,
		TLSProviderFunc:    tlsProviderFunc,
	})
	if err != nil {

		// Log to syslog
		file, err := syslog.New(syslog.LOG_SYSLOG, "Plugin vault main")
		if err != nil {
			log.Fatalln("Unable to set logfile:", err.Error())
		}
		// set the log output
		log.SetOutput(file)

		log.Println("plugin shutting down", "error", err)
		os.Exit(1)
	}
}
