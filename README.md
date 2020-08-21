<img src="https://pngimage.net/wp-content/uploads/2018/06/secure-icon-png-6.png" alt="logo" width="100" height="100" />

![Swift](https://github.com/MatheusMBispo/SwiftSecretKeys/workflows/Swift/badge.svg)

# Swift Secret Keys

Swift Secrets is a command line tool written in Swift that generates obfuscated keys file to your Swift project using a configuration file (yml).

* ✅ Generate obfuscated keys using hexadecimal numbers.
* ✅ Easily configuration using a yml file
* ✅ Use a custom salt key size with **--factor** flag
* ✅ Use **local** keys or **environment** keys
* ✅ Generate from anywhere including on **CI**

Given a very simple project spec file like this:

```yaml
output: Generated/
keys:
  api: ${API}
  password: myPassword
```

## Why use it

The SwiftSecretKeys generates an obfuscated keys file for make it difficult to dump the contents of the decrypted binary and extract the keys. At runtime, the keys are unscrambled for use in your app.

## Installing

#### Mint

```shell
mint install MatheusMBispo/SwiftSecretKeys@0.2.0
```

#### Make
```bash
make install
```

### Binary
You can download the executable from the link: https://github.com/MatheusMBispo/SwiftSecretKeys/releases

## Getting Started

To use this tool just type on terminal:

```bash
sskeys generate
```

To use a especific generation factor, just use the flag "--factor"(Int) to set your custom factor:

```bash
sskeys generate -f 128
```

## Usage

Simply run:

```bash
sskeys generate
```

This will look for a configuration file in the current directory called ```sskeys.yml``` and generate a file with the name defined in the **output** property in the config.

Options:

* **--config**: An optional path to a ```.yml``` configuration file. Defaults to ```sskeys.yml```
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

* **output: String** -  (Optional) Relative path to generate the ```SecretKeys.swift``` file.
* **keys: [String: String]** -  (Optional) The keys that you want obfuscate. The dictionary key will be the variable name and the value will be obsfuscated.
  * You can also use environment variables in your configuration file by using ```${VALUE}``` .

## On Code:

Using the example configuration file above, we can use the keys generated in our project like this:

```swift
let example = SecretKeys.example
let x = SecretKeys.environmentExample
```

## Uninstalling

To uninstall you can remove the binary from the `/usr/local/bin` folder or execute the command below:
```bash
make uninstall
```

## Other libraries

There are also others obfuscation tools in the Swift and iOS community.

* [CocoaPodsKeys](https://github.com/orta/cocoapods-keys)
* [SwiftShield](https://github.com/rockbruno/swiftshield)
* [Obfuscator](https://gist.github.com/DejanEnspyra/80e259e3c9adf5e46632631b49cd1007)


