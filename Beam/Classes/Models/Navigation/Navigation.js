function decorate(obj, apiName) {
  const orig = obj[apiName];
  return function () {
    const result = orig.apply(this, arguments);
    const e = new Event(apiName);
    e.arguments = arguments;
    window.dispatchEvent(e);
    return result;
  };
}
history.pushState = decorate(history, "pushState");
history.replaceState = decorate(history, "replaceState");

function locationChanged(e) {
  const args = e.arguments[0];
  const type = e.type;
  const location = window.location;
  const href = location.href;
  const url = location.origin + args.path;
  window.webkit.messageHandlers.nav_locationChanged.postMessage({
    href,
    type,
    url,
  });
}
window.addEventListener("replaceState", locationChanged);
window.addEventListener("pushState", locationChanged);

console.log("Navigation installed");
