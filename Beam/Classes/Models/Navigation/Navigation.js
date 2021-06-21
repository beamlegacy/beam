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
  const args = e.arguments;
  const stateUrl = args.length > 2 && args[2];
  if (stateUrl) {
    const location = window.location;
    const origin = window.origin;
    const href = location.href;
    const url = stateUrl.indexOf(origin) < 0 ? origin + stateUrl : stateUrl;
    const type = e.type;
    window.webkit.messageHandlers.nav_locationChanged.postMessage({
      href,
      type,
      url,
    });
  }
}

window.addEventListener("replaceState", locationChanged);
window.addEventListener("pushState", locationChanged);

console.log("Navigation installed");
