#!/usr/bin/env ruby

require "openssl"
require "base64"

key = Base64.decode64 "pKPfCFvpfuAo7E0Lh6ZpplJrwEM9n4awtqpqlVGUOp4="
combined = Base64.decode64 "QZiDXJQ8mVAZ7wV2aMVyGcXTp8qa3rbWnrIg0S3TwlzZ9Njqt5z3An2M+SG0"

tag = Base64.decode64 "08Jc2fTY6rec9wJ9jPkhtA=="
nonce = Base64.decode64 "QZiDXJQ8mVAZ7wV2"
ciphertext = Base64.decode64 "aMVyGcXTp8qa3rbWnrIg0S0="
text = "Hello, playground"

# Combined version
combinedTag = combined[-16..-1]
combinedNonce = combined[0..11]
combinedCipherText = combined[12..(combined.size-17)]

decipher = OpenSSL::Cipher.new("chacha20-poly1305").decrypt
decipher.key = key

decipher.iv = combinedNonce
decipher.auth_tag = combinedTag

decrypted = decipher.update(combinedCipherText) + decipher.final
if decrypted == text
  puts "OK!"
end

# Non combined version

decipher = OpenSSL::Cipher.new("chacha20-poly1305").decrypt
decipher.key = key

decipher.iv = nonce
decipher.auth_tag = tag

decrypted = decipher.update(ciphertext) + decipher.final
if decrypted == text
  puts "OK!"
end

### AES GCM

key = Base64.decode64 "g77d4Ulrd7jfUJeKEXTQDU5JMd2FlIRbjm3N/o3pAeI="
combined = Base64.decode64 "6ykpONKB2A8zXqNbjpSTURkwpGHQgR2mF3fv+l8Jc5MNfFIm1CeaUuUad9U5PXP40mTXGazQCLQ/Xkq4efWEfRpezPZL2c8tJlBNYLuOtgyoJFGprr/cE9fltey4fUBVUWoSwCZ5yA=="
text = "✔ Ergonomic Granite Computer 7svhQcDlj4LraUa9BuC2p9Ek5OagBet2JpptTbls ✅"

# Combined version
combinedTag = combined[-16..-1]
combinedNonce = combined[0..11]
combinedCipherText = combined[12..(combined.size-17)]

decipher = OpenSSL::Cipher.new("AES-256-GCM").decrypt
decipher.key = key

decipher.iv = combinedNonce
decipher.auth_tag = combinedTag

decrypted = decipher.update(combinedCipherText) + decipher.final
if decrypted == text
  puts "OK!"
else
  puts "NOT OK! decrypted text: #{decrypted}"
end

# Encryption
cipher = OpenSSL::Cipher.new("AES-256-GCM").encrypt
iv = cipher.random_iv
cipher.key = key

cipher_text = cipher.update(text) + cipher.final

puts Base64.strict_encode64(iv + cipher_text + cipher.auth_tag)
