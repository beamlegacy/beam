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
    case Geolocation_listenerAdded
    case Geolocation_listenerRemoved
}

class GeolocationMessageHandler: SimpleBeamMessageHandler, CLLocationManagerDelegate {

    var locationManager = CLLocationManager()
    var listenersCount = 0

    private weak var localWebPage: WebPage?
    private let JSObjectName = "Geolocation"

    init() {
        let messages = GeolocationMessages.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "Geolocation_prod")
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

    func onLocationServicesIsDisabled(webPage: WebPage?) {
        sendError(code: 2, message: "Location services disabled", in: webPage)
    }

    func onAuthorizationStatusNeedRequest() {
        locationManager.requestWhenInUseAuthorization()
    }

    func onAuthorizationStatusIsGranted(webPage: WebPage?) {
        locationManager.startUpdatingLocation()
    }

    func onAuthorizationStatusIsDenied(webPage: WebPage?) {
        sendError(code: 1, message: "App does not have location permission", in: webPage)
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        guard let messageKey = GeolocationMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message '\(messageName)' for Geolocation message handler", category: .web)
            return
        }

        switch messageKey {
        case .Geolocation_listenerAdded:
            listenersCount += 1
            localWebPage = webPage
            if !locationServicesIsEnabled() {
                onLocationServicesIsDisabled(webPage: webPage)
            } else if authorizationStatusIsDenied(status: locationManager.authorizationStatus) {
                onAuthorizationStatusIsDenied(webPage: webPage)
            } else if authorizationStatusNeedRequest(status: locationManager.authorizationStatus) {
                onAuthorizationStatusNeedRequest()
            } else if authorizationStatusIsGranted(status: locationManager.authorizationStatus) {
                onAuthorizationStatusIsGranted(webPage: webPage)
            }
        case .Geolocation_listenerRemoved:
            listenersCount -= 1

            // no listener left in web view to wait for position
            if listenersCount == 0 {
                locationManager.stopUpdatingLocation()
                localWebPage = nil
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // didChangeAuthorization is also called at app startup, so this condition checks listeners
        // count before doing anything otherwise app will start location service without reason
        if listenersCount > 0 {
            if authorizationStatusIsDenied(status: status) {
                onAuthorizationStatusIsDenied(webPage: localWebPage)
            } else if authorizationStatusIsGranted(status: status) {
                onAuthorizationStatusIsGranted(webPage: localWebPage)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            sendLocation(location, in: localWebPage)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        sendError(code: 2, message: "Failed to get position (\(error.localizedDescription))", in: localWebPage)
    }

}

// MARK: Send to JS

private extension GeolocationMessageHandler {

    func sendLocation(_ location: CLLocation, in webPage: WebPage?) {
        webPage?.executeJS("success('\(location.timestamp)', \(location.coordinate.latitude), \(location.coordinate.longitude), \(location.altitude), \(location.horizontalAccuracy), \(location.verticalAccuracy), \(location.course), \(location.speed));",
                           objectName: JSObjectName, frameInfo: nil, successLogCategory: .javascript, nil)
    }

    func sendError(code: Int, message: String, in webPage: WebPage?) {
        webPage?.executeJS("error(\(code), '\(message)');",
                           objectName: JSObjectName, frameInfo: nil, successLogCategory: .javascript, nil)
    }
}
