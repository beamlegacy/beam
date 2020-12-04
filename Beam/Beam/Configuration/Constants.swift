//
//  Constant.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 04/12/2020.
//

import Foundation

enum Constants {

  static var runningOnBigSur: Bool = {
      let version = ProcessInfo.processInfo.operatingSystemVersion
      return version.majorVersion >= 11 || (version.majorVersion == 10 && version.minorVersion >= 16)
  }()

}
