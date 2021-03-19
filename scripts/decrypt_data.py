#!/usr/bin/env python3
# 
# This script is just a test to make sure we can decrypt data
#
# Imported from https://pycryptodome.readthedocs.io/en/latest/src/cipher/chacha20_poly1305.html

# Installation:
# pip install pycryptodome

import json
import Crypto
from base64 import b64decode
from Crypto.Cipher import ChaCha20_Poly1305

clearText = "Hello, playground"

key = "pKPfCFvpfuAo7E0Lh6ZpplJrwEM9n4awtqpqlVGUOp4="

combined = "QZiDXJQ8mVAZ7wV2aMVyGcXTp8qa3rbWnrIg0S3TwlzZ9Njqt5z3An2M+SG0"

tag = "08Jc2fTY6rec9wJ9jPkhtA=="
nonce = "QZiDXJQ8mVAZ7wV2"
ciphertext = "aMVyGcXTp8qa3rbWnrIg0S0="

# With combined sealbox
combinedNonce = b64decode(combined)[:12]
combinedTag = b64decode(combined)[:-16]
combinedCipher = b64decode(combined)[12:-16]
chacha = Crypto.Cipher.ChaCha20_Poly1305.new(key=b64decode(key), nonce=combinedNonce)
clear = chacha.decrypt(combinedCipher).decode()

if clearText == clear:
    print("OK!")
else:
    print(f"Not equal: {clear}")

# With nonce and tag
cipher = Crypto.Cipher.ChaCha20_Poly1305.new(key=b64decode(key), nonce=b64decode(nonce))
clear = cipher.decrypt(b64decode(ciphertext)).decode()

if clearText == clear:
    print("OK!")
else:
    print(f"Not equal: {clear}")
