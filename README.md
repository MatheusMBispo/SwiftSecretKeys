# Swift Secrets

Command line tool that generates obfuscated keys file to your Swift project.

* Installation
* Getting Started
* Configuration



## Installation

```shell
brew tap MatheusMBispo/SwiftSecrets
brew install SwiftSecrets
```



## Getting Started

To use this tool just type on terminal:

```bash
swiftsecrets generate
```

To use a especific generation factor, just use the flag "--factor"(Int) to set your custom factor:

```bash
swiftsecrets generate -f 128
```



## Configuration

Use a SecretsConfig.yml to configure your project by default. You can rename the configuration file to any other name using the "-c" or "--config" flag:

```bash
swiftsecrets generate --config CustomConfig.yml
```

You can use this parameters to configure your **swiftsecrets**:

```yaml
output: Folder/Secrets.swift ## Filename (with path)
keys: ## Local keys
 example: value 
environments: ## Environment keys, you must to set on your environment with the same name
 - EXAMPLE ## By example, type on your terminal: "export EXAMPLE=value"
 - EXAMPLE2
```

