(()=>{"use strict";var t,e={327:(t,e)=>{e.R=void 0;e.R=class{constructor(t){this.win=t,this.registerEventListeners()}registerEventListeners(){this.win.addEventListener("click",this.onClick.bind(this),!0)}onClick(){const t=this.win.location.href;this.win.webkit.messageHandlers.nav_clickEvent.postMessage({href:t})}linkWithoutListeners(t){const e=document.createElement("a");t.rel&&(e.rel=t.rel),e.href=t.href,e.target=t.target;for(const s in t.dataset)e.dataset[s]=t.dataset[s];const s=e.getAttribute("draggable");s&&e.setAttribute("draggable",s);const n=t.className;n&&(e.className=n);const i=t.getAttribute("style");return i&&e.setAttribute("style",i),e.innerHTML=t.innerHTML,e.dataset.beam="yes",e}decorate(t,e){const s=t[e],n=this;return function(){const t=s.apply(this,arguments),i=new Event(e);return i.arguments=arguments,n.win.dispatchEvent(i),t}}locationChanged(t){const e=t.arguments,s=null==e?void 0:e[2];if(s){let e=this.win.location.href;"about:blank"==e&&(e=s);const n=t.type;this.win.webkit.messageHandlers.nav_locationChanged.postMessage({href:e,type:n})}}locationChangedBackwards(t){const e=this.win.location.href,s=t.type;this.win.webkit.messageHandlers.nav_locationChanged.postMessage({href:e,type:s})}startHistoryHandling(){history.pushState=this.decorate(history,"pushState"),history.replaceState=this.decorate(history,"replaceState"),this.win.addEventListener("replaceState",this.locationChanged.bind(this)),this.win.addEventListener("pushState",this.locationChanged.bind(this)),this.win.addEventListener("popstate",this.locationChangedBackwards.bind(this))}}}},s={};function n(t){var i=s[t];if(void 0!==i)return i.exports;var a=s[t]={exports:{}};return e[t](a,a.exports,n),a.exports}t=n(327),window.beam||(window.beam={}),window.beam.__ID__Nav=new t.R(window),window.beam.__ID__Nav.startHistoryHandling()})();