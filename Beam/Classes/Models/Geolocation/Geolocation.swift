//
//  Geolocation.swift
//  Beam
//
//  Created by Sebastien Metrot on 02/07/2021.
//
// Very much inspired from https://stackoverflow.com/questions/39665367/how-to-prevent-wkwebview-to-repeatedly-ask-for-permission-to-access-location/59542677#59542677

import Foundation
import BeamCore
import WebKit
import CoreLocation

enum GeolocationMessages: String, CaseIterable {
    /**
     a media changed its playing/paused state
     */
    case geoloc_listenerAdded
    case geoloc_listenerRemoved
}

class GeolocationMessageHandler: SimpleBeamMessageHandler, CLLocationManagerDelegate {

    var locationManager = CLLocationManager()
    var listenersCount = 0
    weak var webView: WKWebView?

    init() {
        let messages = GeolocationMessages.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "Geolocation")
        locationManager.delegate = self
    }

    func locationServicesIsEnabled() -> Bool {
        return (CLLocationManager.locationServicesEnabled()) ? true : false
    }

    func authorizationStatusNeedRequest(status: CLAuthorizationStatus) -> Bool {
        return (status == .notDetermined) ? true : false
    }

    func authorizationStatusIsGranted(status: CLAuthorizationStatus) -> Bool {
        return (status == .authorizedAlways || status == .authorized) ? true : false
    }

    func authorizationStatusIsDenied(status: CLAuthorizationStatus) -> Bool {
        return (status == .restricted || status == .denied) ? true : false
    }

    func onLocationServicesIsDisabled() {
        webView?.evaluateJavaScript("navigator.geolocation.helper.error(2, 'Location services disabled');")
    }

    func onAuthorizationStatusNeedRequest() {
        locationManager.requestWhenInUseAuthorization()
    }

    func onAuthorizationStatusIsGranted() {
        locationManager.startUpdatingLocation()
    }

    func onAuthorizationStatusIsDenied() {
        webView?.evaluateJavaScript("navigator.geolocation.helper.error(1, 'App does not have location permission');")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        guard let messageKey = GeolocationMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message '\(messageName)' for Geolocation message handler", category: .web)
            return
        }

        switch messageKey {
        case .geoloc_listenerAdded:
            webView = webPage.webView
            listenersCount += 1

            if !locationServicesIsEnabled() {
                onLocationServicesIsDisabled()
            } else if authorizationStatusIsDenied(status: locationManager.authorizationStatus) {
                onAuthorizationStatusIsDenied()
            } else if authorizationStatusNeedRequest(status: locationManager.authorizationStatus) {
                onAuthorizationStatusNeedRequest()
            } else if authorizationStatusIsGranted(status: locationManager.authorizationStatus) {
                onAuthorizationStatusIsGranted()
            }
        case .geoloc_listenerRemoved:
            listenersCount -= 1

            // no listener left in web view to wait for position
            if listenersCount == 0 {
                locationManager.stopUpdatingLocation()
                webView = nil
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // didChangeAuthorization is also called at app startup, so this condition checks listeners
        // count before doing anything otherwise app will start location service without reason
        if listenersCount > 0 {
            if authorizationStatusIsDenied(status: status) {
                onAuthorizationStatusIsDenied()
            } else if authorizationStatusIsGranted(status: status) {
                onAuthorizationStatusIsGranted()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            webView?.evaluateJavaScript("navigator.geolocation.helper.success('\(location.timestamp)', \(location.coordinate.latitude), \(location.coordinate.longitude), \(location.altitude), \(location.horizontalAccuracy), \(location.verticalAccuracy), \(location.course), \(location.speed));")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        webView?.evaluateJavaScript("navigator.geolocation.helper.error(2, 'Failed to get position (\(error.localizedDescription))');")
    }

}
