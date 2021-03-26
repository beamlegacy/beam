#!/usr/bin/env node
let crypto = require("crypto")

console.log(encrypt("hello 😱"))
function encrypt(message){
  const KEY = crypto.randomBytes(32)
  const IV = crypto.randomBytes(16)
  const ALGORITHM = 'aes-256-gcm';

  const cipher = crypto.createCipheriv(ALGORITHM, KEY, IV);
  let encrypted = cipher.update(message, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const tag = cipher.getAuthTag()

  let output = {
    encrypted,
    KEY: KEY.toString('hex'),
    IV: IV.toString('hex'),
    TAG: tag.toString('hex'),
  }
  return output;
}
