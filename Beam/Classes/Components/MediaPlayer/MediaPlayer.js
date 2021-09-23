if (!window.beam) {
    window.beam = {};
}

window.beam.__ID__MDPLR = {

    media_isPageMuted: false,

    media_htmlMediaTags: function () {
        return document.querySelectorAll("video,audio");
    },

    media_observe: function () {
        let tags = this.media_htmlMediaTags();
        for (let i = 0; i < tags.length; i++) {
            let tag = tags[i];
            if (tag.addEventListener) {
                tag.addEventListener('playing', this.media_onPlaying.bind(this));
                tag.addEventListener('pause', this.media_onStopPlaying.bind(this));
                tag.addEventListener('ended', this.media_onStopPlaying.bind(this));
            }
        }
    },

    media_isAnyMediaPlaying: function () {
        let tags = this.media_htmlMediaTags();
        for (let i = 0; i < tags.length; i++) {
            let tag = tags[i];
            let isMutedByDefault = tag.muted && !this.media_isPageMuted
            if (!tag.paused && !isMutedByDefault) {
                return true;
            }
        }
        return false
    },

    media_toggleMute: function () {
        this.media_isPageMuted = !this.media_isPageMuted;
        let tags = this.media_htmlMediaTags();
        for (let i = 0; i < tags.length; i++) {
            let tag = tags[i];
            tag.muted = this.media_isPageMuted
        }
    },

    media_elemenSupportsPictureInPicture: function (element) {
        return element.webkitSupportsPresentationMode !== undefined && typeof element.webkitSetPresentationMode === "function"
    },

    media_elemenIsInPictureInPicture: function (element) {
        return this.media_elemenSupportsPictureInPicture(element) && element.webkitPresentationMode === "picture-in-picture"
    },

    media_togglePictureInPicture: function () {
        let tags = this.media_htmlMediaTags();
        if (tags.length == 0) { return; }
        for (let i = 0; i < tags.length; i++) {
            let tag = tags[i];
            if (this.media_elemenSupportsPictureInPicture(tag)) {
                const isInPip = this.media_elemenIsInPictureInPicture(tag);
                tag.webkitSetPresentationMode(isInPip ? "inline" : "picture-in-picture");
                return;
            }
        }
    },

    media_onPlaying: function (e) {
        if (this.media_isPageMuted && e.target.muted == false) {
            // mute any appearing playing element if we muted.
            e.target.muted = this.media_isPageMuted
        }
        const playing = this.media_isAnyMediaPlaying();
        this.media_sendPlayStateChanged(playing, e.target)
    },

    media_onStopPlaying: function (e) {
        const playing = this.media_isAnyMediaPlaying();
        this.media_sendPlayStateChanged(playing, e.target)
    },

    media_sendPlayStateChanged: function (playing, element) {
        window.webkit.messageHandlers.media_playing_changed.postMessage({
            "playing": playing,
            "muted": this.media_isPageMuted,
            "pipSupported": this.media_elemenSupportsPictureInPicture(element),
            "isInPip": this.media_elemenIsInPictureInPicture(element)
        });
    }
};

window.addEventListener("load", window.beam.__ID__MDPLR.media_observe.bind(window.beam.__ID__MDPLR));
window.addEventListener("beam_historyLoad", window.beam.__ID__MDPLR.media_onPlaying.bind(window.beam.__ID__MDPLR));
