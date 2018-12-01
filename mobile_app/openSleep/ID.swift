//
//  ID.swift
//  openSleep
//
//  Created by Adam Haar Horowitz on 11/30/18.
//  Copyright © 2018 Tomas Vega. All rights reserved.
//

import Foundation


public struct ID {
  var deviceID: String?
  var sessionID: String?
  
  init() {
    if UserDefaults.standard.object(forKey: "phoneUUID") == nil {
      UserDefaults.standard.set(UUID().uuidString, forKey: "phoneUUID")
    }
    self.deviceID = String(UserDefaults.standard.object(forKey: "phoneUUID") as! String)
  }
  
  mutating func newSessionId(){
    self.sessionID = UUID().uuidString;
  }
}
