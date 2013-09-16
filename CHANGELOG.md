# sidekiq-encryptor changelog

## 0.1.3

Fix bug with Ruby 1.9 compatibility.

## 0.1.2

Upgrade to Fernet 2.0rc2.

## 0.1.1

Fix bug with processing unencrypted jobs.

## 0.1.0

Backwards incompatible changes:

* Protocol version change from 0 to 1. Jobs encrypted by previous
  versions cannot be decrypted by this version.

Changes:

* Switch to Fernet 2.0
* Use a distinct protocol version number
* Support binary, hexadecimal, and base64 keys. Note that many ASCII
  keys will be detected as base64. Base64 assumes RFC 2045.
* Enforce 256 bit key length
* Recommend 32 byte keys in README
* Allow an optional `adapter` to be passed in. The adapter must follow
  the following standards:
  * Define a `encrypt` and `decrypt` class methods that accept two
    arguments: `String key, String data`. `key` will always have length
    32, `data` will be of arbitrary length.
  * `encrypt` must return a String.
  * `decrypt` must return a String or nil if the decryption fails.

## 0.0.1

Initial release
