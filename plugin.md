# Plugins

## [vault-plugin-secrets-github](https://github.com/martinbaillie/vault-plugin-secrets-github)

`vault-plugin-secrets-github` is community managed plugin hence we need to install
binary ourself. kustomize component [plugin/secrets-github](plugin/secrets-github) can be added to add this plugin.

Plugin binary is added to `vault-toolkit` image for offline access.
This component adds a side car to vault which runs [install script](vault-toolkit/vault-install-plugin.sh).
install script moves plugin binary to required shared plugin path so its available 
for vault. It also make API calls to register and pin this binary to vault catalog.

This plugin is configured via [Terraform](https://github.com/utilitywarehouse/sys-vault-terraform/)

### updating plugin
To update plugin change value of the `SEC_GITHUB_PLUGIN_VERSION` in Make file 
and run 

`make update-secrets-github-plugin`

This target will download checksum file to extract plugins binary SHA based on version.
This sha value is used by script to register the plugin. vault will use this sha 
to verify plugin before the execution. 
