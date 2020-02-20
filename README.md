<img src="https://pngimage.net/wp-content/uploads/2018/06/secure-icon-png-6.png" alt="logo" width="100" height="100" />

# Swift Secrets

Swift Secrets is a command line tool written in Swift that generates obfuscated keys file to your Swift project using a configuration file (yml).

* ✅ Generate obfuscated keys using hexadecimal numbers.
* ✅ Easily configuration using a yml file
* ✅ Use a custom salt key size with **--factor** flag
* ✅ Use **local** keys or **environment** keys
* ✅ Generate from anywhere including on **CI**

Given a very simple project spec file like this:

```yaml
output: Generated/Secrets.swift
keys:
  api: ${API}
  bundle: br.com.teste
```



## Installing

#### Homebrew

```shell
brew tap MatheusMBispo/SwiftSecrets
brew install SwiftSecrets
```

#### Make

```bash
make install
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

## Usage

Simply run:

```bash
swiftsecrets generate
```

This will look for a configuration file in the current directory called ```SecretsConfig.yml``` and generate a file with the name defined in the **output** property in the config.

Options:

* **--config**: An optional path to a ```.yml``` configuration file. Defaults to ```SecretsConfig.yml```
* **--factor**: An optional value to generate a salt key. Defaults to ```32```.



## Configuration

The configuration file must be written in YAML.

#### Properties

```yaml
output: Generated/
keys:
  example: exampleValue
  environmentExample: ${example} 
```

* **output: String** -  (Optional) Relative path to generate the ```Secrets.swift``` file.
* **keys: [String: String]** -  (Optional) The keys that you want obfuscate. The dictionary key will be the variable name and the value will be obsfuscated.
  * You can also use environment variables in your configuration file by using ```${VALUE}``` .

## On Code:

Using the example configuration file above, we can use the keys generated in our project like this:

```swift
let example = Secrets.example
let x = Secrets.environmentExample
```

