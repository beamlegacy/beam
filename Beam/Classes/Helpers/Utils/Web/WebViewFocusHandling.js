if (!window.beam) {
    window.beam = {};
}
window.beam.__ID__FocusHandling = {

    lastFocusedElement: undefined,

    focusDidChange: function (e) {
        this.lastFocusedElement = document.activeElement;
    },

    refocusLastElement: function () {
        let element = this.lastFocusedElement;
        if (element) {
            element.focus();
        }
    }
};

window.addEventListener("focus", window.beam.__ID__FocusHandling.focusDidChange);
