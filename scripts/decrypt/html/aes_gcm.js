
/*
 *
 * Interesting links
 *
 * https://github.com/diafygi/webcrypto-examples#aes-gcm---encrypt
 * https://dev.to/shahinghasemi/fullstack-aes-gcm-encryption-decryption-in-node-js-and-the-client-side-8bm
 * https://gist.github.com/shahinghasemi/8008ba4918feeed08b14f7b9b3a32610
 * https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/encrypt
 * https://github.com/mdn/dom-examples
 * https://stackoverflow.com/questions/55390714/aes-gcm-encrypt-in-nodejs-and-decrypt-in-browser
 */

const fromBase64 = base64String => Uint8Array.from(atob(base64String), c => c.charCodeAt(0))

let clearText = "✔ Ergonomic Granite Computer 7svhQcDlj4LraUa9BuC2p9Ek5OagBet2JpptTbls ✅"
let combined = fromBase64("6ykpONKB2A8zXqNbjpSTURkwpGHQgR2mF3fv+l8Jc5MNfFIm1CeaUuUad9U5PXP40mTXGazQCLQ/Xkq4efWEfRpezPZL2c8tJlBNYLuOtgyoJFGprr/cE9fltey4fUBVUWoSwCZ5yA==")
let privateKey = fromBase64("g77d4Ulrd7jfUJeKEXTQDU5JMd2FlIRbjm3N/o3pAeI=")

let nonce = combined.slice(0, 12)
let tag = combined.slice(-16)
let cipher = combined.slice(12, -16)

async function test() {
  add_log("step 0")
  var key = await window.crypto.subtle.importKey("raw",
    privateKey,
    { name: "AES-GCM" },
    true,
    ["decrypt", "encrypt"])
  add_log("key imported")

  try {
    add_log("step 1")
    var encrypted = await window.crypto.subtle.encrypt(
      {
        name: "AES-GCM",
        iv: nonce,
      },
      key,
      new TextEncoder().encode(clearText)
    )

    combinedEncrypted = _append2Buffer(nonce, encrypted)
    add_log(_arrayBufferToBase64(combinedEncrypted))

    add_log("step 2")
    var decrypted = await window.crypto.subtle.decrypt(
      {
        name: "AES-GCM",
        iv: nonce
      },
      key,
      encrypted)
    add_log(new TextDecoder().decode(decrypted))
  } catch(e) {
    add_log(e)
  }

  try {
    var decrypted = await window.crypto.subtle.decrypt(
      {
        name: "AES-GCM",
        iv: nonce,
      },
      key,
      _append2Buffer(cipher, tag))
    add_log("step 3")
    // add_log(decrypted)
    add_log(new TextDecoder().decode(decrypted))
  } catch(e) {
    add_log(e)
  }
}

test()

/*
 * -----------------------------------------------------------------------
 */

// Add logs
function add_log(text) {
  let results = document.getElementById("results")
  results.innerHTML += text + "\n"
  console.log(text)
}

function _arrayBufferToBase64(buffer) {
  var binary = '';
  var bytes = new Uint8Array( buffer );
  var len = bytes.byteLength;
  for (var i = 0; i < len; i++) {
    binary += String.fromCharCode( bytes[ i ] );
  }
  return window.btoa(binary);
}

function _append2Buffer(buffer1, buffer2) {
  var tmp = new Uint8Array(buffer1.byteLength + buffer2.byteLength)
  tmp.set(new Uint8Array(buffer1), 0)
  tmp.set(new Uint8Array(buffer2), buffer1.byteLength)
  return tmp.buffer;
}
