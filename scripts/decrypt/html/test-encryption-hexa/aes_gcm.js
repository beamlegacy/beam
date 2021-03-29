
let data = 
  {
    encrypted: '8784d54e7bc60fe0da09',
    KEY: 'cd0158b7f46bf9e6c8f6d200756d19f20b59e1c51222c93a8c9ae7612ac8acbf',
    IV: '2d17f6f9e2af079af3ce97936d0cf4c7',
    TAG: '8a62f031a6dd3466525a0f632a098c23'
  }

decrypt(data)

function decrypt(data) {
  let KEY = hexStringToArrayBuffer(data.KEY);
  let IV = hexStringToArrayBuffer(data.IV);
  let encrypted = hexStringToArrayBuffer(data.encrypted + data.TAG);

  window.crypto.subtle.importKey('raw', KEY, 'AES-GCM', true, ['decrypt']).then((importedKey)=>{
    console.log('importedKey: ', importedKey);
    window.crypto.subtle.decrypt(
      {
        name: "AES-GCM",
        iv: IV,
      },
      importedKey,
      encrypted
    ).then((decodedBuffer)=>{
      let plaintext = new TextDecoder('utf8').decode(decodedBuffer);
      console.log('plainText: ', plaintext);
    })
 })
}

function hexStringToArrayBuffer(hexString) {
  hexString = hexString.replace(/^0x/, '');
  if (hexString.length % 2 != 0) {
    console.log('WARNING: expecting an even number of characters in the hexString');
  }
  var bad = hexString.match(/[G-Z\s]/i);
  if (bad) {
      console.log('WARNING: found non-hex characters', bad);
  }
  var pairs = hexString.match(/[\dA-F]{2}/gi);
  var integers = pairs.map(function(s) {
      return parseInt(s, 16);
  });
  var array = new Uint8Array(integers);
  return array.buffer;
}
