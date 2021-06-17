function beam_media_htmlMediaTags() {
    return document.querySelectorAll("video,audio");
}

function beam_media_observe() {
    let tags = beam_media_htmlMediaTags();
    for (let i = 0; i < tags.length; i++) {
        let tag = tags[i];
        if (tag.addEventListener) {
            tag.addEventListener('playing', beam_media_onPlaying);
            tag.addEventListener('pause', beam_media_onStopPlaying);
            tag.addEventListener('ended', beam_media_onStopPlaying);
        }
    }
}

function beam_media_isAnyMediaPlaying() {
    let tags = beam_media_htmlMediaTags();
    for (let i = 0; i < tags.length; i++) {
        let tag = tags[i];
        if (!tag.paused) {
            return true;
        }
    }
    return false
}

let beam_media_isPageMuted = false;
function beam_media_toggleMute() {
    beam_media_isPageMuted = !beam_media_isPageMuted;
    let tags = beam_media_htmlMediaTags();
    for (let i = 0; i < tags.length; i++) {
        let tag = tags[i];
        tag.muted = beam_media_isPageMuted
    }
}

function beam_media_elemenSupportsPictureInPicture(element) {
    return element.webkitSupportsPresentationMode && typeof element.webkitSetPresentationMode === "function"
}

function beam_media_elemenIsInPictureInPicture(element) {
    return beam_media_elemenSupportsPictureInPicture(element) && element.webkitPresentationMode === "picture-in-picture"
}

function beam_media_togglePictureInPicture() {
    let tags = beam_media_htmlMediaTags();
    if (tags.length == 0) { return; }
    for (let i = 0; i < tags.length; i++) {
        let tag = tags[i];
        if (beam_media_elemenSupportsPictureInPicture(tag)) {
            const isInPip = beam_media_elemenIsInPictureInPicture(tag);
            tag.webkitSetPresentationMode(isInPip ? "inline" : "picture-in-picture");
            return;
        }
    }
}

function beam_media_onPlaying(e) {
    if (beam_media_isPageMuted && e.target.muted == false) {
        // mute any appearing playing element if we muted.
        e.target.muted = beam_media_isPageMuted
    }
    const playing = beam_media_isAnyMediaPlaying();
    beam_media_sendPlayStateChanged(playing, e.target)
}

function beam_media_onStopPlaying(e) {
    const playing = beam_media_isAnyMediaPlaying();
    beam_media_sendPlayStateChanged(playing, e.target)
}

function beam_media_sendPlayStateChanged(playing, element) {
    window.webkit.messageHandlers.media_playing_changed.postMessage({
        "playing": playing,
        "muted": beam_media_isPageMuted,
        "pipSupported": beam_media_elemenSupportsPictureInPicture(element),
        "isInPip": beam_media_elemenIsInPictureInPicture(element)
    });
}

console.log("MediaPlayer installed");
window.addEventListener("load", beam_media_observe);
