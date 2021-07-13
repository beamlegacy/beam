// management for success and error listeners and its calling
navigator.geolocation.helper = {
listeners: {},
noop: function() {},
id: function() {
    var min = 1, max = 1000;
    return Math.floor(Math.random() * (max - min + 1)) + min;
},
clear: function(isError) {
    for (var id in this.listeners) {
        if (isError || this.listeners[id].onetime) {
            navigator.geolocation.clearWatch(id);
        }
    }
},
success: function(timestamp, latitude, longitude, altitude, accuracy, altitudeAccuracy, heading, speed) {
    var position = {
    timestamp: new Date(timestamp).getTime() || new Date().getTime(), // safari can not parse date format returned by swift e.g. 2019-12-27 15:46:59 +0000 (fallback used because we trust that safari will learn it in future because chrome knows that format)
    coords: {
    latitude: latitude,
    longitude: longitude,
    altitude: altitude,
    accuracy: accuracy,
    altitudeAccuracy: altitudeAccuracy,
    heading: (heading > 0) ? heading : null,
    speed: (speed > 0) ? speed : null
    }
    };
    for (var id in this.listeners) {
        this.listeners[id].success(position);
    }
    this.clear(false);
},
error: function(code, message) {
    var error = {
    PERMISSION_DENIED: 1,
    POSITION_UNAVAILABLE: 2,
    TIMEOUT: 3,
    code: code,
    message: message
    };
    for (var id in this.listeners) {
        this.listeners[id].error(error);
    }
    this.clear(true);
}
};

// @override getCurrentPosition()
navigator.geolocation.getCurrentPosition = function(success, error, options) {
    var id = this.helper.id();
    this.helper.listeners[id] = { onetime: true, success: success || this.noop, error: error || this.noop };
    window.webkit.messageHandlers.geoloc_listenerAdded.postMessage("");
};

// @override watchPosition()
navigator.geolocation.watchPosition = function(success, error, options) {
    var id = this.helper.id();
    this.helper.listeners[id] = { onetime: false, success: success || this.noop, error: error || this.noop };
    window.webkit.messageHandlers.geoloc_listenerAdded.postMessage("");
    return id;
};

// @override clearWatch()
navigator.geolocation.clearWatch = function(id) {
    var idExists = (this.helper.listeners[id]) ? true : false;
    if (idExists) {
        this.helper.listeners[id] = null;
        delete this.helper.listeners[id];
        window.webkit.messageHandlers.geoloc_listenerRemoved.postMessage("");
    }
};
