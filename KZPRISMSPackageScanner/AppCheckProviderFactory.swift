//
//  AppCheckProviderFactory.swift
//  KZPRISMSPackageScanner
//
//  Created by Kevin Zheng on 4/25/23.
//

import Foundation
import FirebaseAppCheck
import Firebase

class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    if #available(iOS 14.0, *) {
      return AppAttestProvider(app: app)
    } else {
      return DeviceCheckProvider(app: app)
    }
  }
}
