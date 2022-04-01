// Before a window or frame is removed clear the window.beam object from memory
window.onunload = function(){
  window.beam = null
}