#!/usr/bin/env node

// brew install node

const crypto = require("crypto");
const atob = require("atob");
const btoa = require("btoa");
const buffer = require("buffer");
const fromBase64 = base64String => Uint8Array.from(atob(base64String), c => c.charCodeAt(0));

let clearText = "✔ Ergonomic Granite Computer 7svhQcDlj4LraUa9BuC2p9Ek5OagBet2JpptTbls ✅"
let combined = fromBase64("6ykpONKB2A8zXqNbjpSTURkwpGHQgR2mF3fv+l8Jc5MNfFIm1CeaUuUad9U5PXP40mTXGazQCLQ/Xkq4efWEfRpezPZL2c8tJlBNYLuOtgyoJFGprr/cE9fltey4fUBVUWoSwCZ5yA==")
let privateKey = fromBase64("g77d4Ulrd7jfUJeKEXTQDU5JMd2FlIRbjm3N/o3pAeI=")

if (clearText == decrypt(privateKey, combined)) {
  console.log("Decrypt OK")
} else {
  console.log("Decrypt not ok")
}


let nonce = combined.slice(0, 12)
let tag = combined.slice(-16)
let cipher = combined.slice(12, -16)

function encrypt(key, str, nonce, tag) {
  // Hint: the `iv` should be unique (but not necessarily random).
  // `randomBytes` here are (relatively) slow but convenient for
  // demonstration.
  //const iv = new Buffer(crypto.randomBytes(16), "utf8");
  const cipher = crypto.createCipheriv("aes-256-gcm", key, nonce);

  // Hint: Larger inputs (it"s GCM, after all!) should use the stream API
  let enc = cipher.update(str, "utf8", "base64");
  enc += cipher.final("base64");
  return [enc, nonce, cipher.getAuthTag()];
}

function decrypt(key, combined) {
  let nonce = combined.slice(0, 12)
  let tag = combined.slice(-16)
  let cipher = combined.slice(12, -16)
  let decipher = crypto.createDecipheriv("aes-256-gcm", key, nonce);
  decipher.setAuthTag(tag);
  let str = decipher.update(cipher, "base64", "utf8");
  str += decipher.final("utf8");
  return str;
}
