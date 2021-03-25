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

key = Base64.decode64 "nc0ogib3Ymdink8ys3pf2wuoZTjdQLK0MF3LwAPqP6A="
combined = Base64.decode64 "OMlHyj4XvkfG0hp1rCVzm9dFLN0gR6HPv4r/HRSi6IKFHYQhY4fMlN5/GqRTgxa75wUlasnFa136Hj6hXkrouSyaEvGjqLy8gn27NIpJd3GqDayNLJvE"
text = "Small Cotton Chair dLRKbPUjmfTmnGNjd0z7iYs6MdWVJNTIOyfactPI"

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
end
