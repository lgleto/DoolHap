//
//  User.swift
//  DonaHome
//
//  Created by Ricardo Abreu on 20/04/18.
//  Copyright © 2018 Ricardo Abreu. All rights reserved.
//

import Foundation

class User: NSObject {
    
    var id: Int? = nil
    var role: Int? = nil
    var hidden: Bool? = nil
    var photoUri: String? = nil
    var name: String? = nil
    var remoteAccessible: Bool? = nil
    var house: Int? = nil
    var enabled: Bool? = nil
    
    init(id: Int, role: Int, hidden: Bool, photoUri: String, name: String, remoteAccessible: Bool, house: Int, enabled: Bool) {
        self.id = id
        self.role = role
        self.hidden = hidden
        self.photoUri = photoUri
        self.name = name
        self.remoteAccessible = remoteAccessible
        self.house = house
        self.enabled = enabled
    }
    
    init?(user: Dictionary<String, Any>) {
        self.id = user["id"] as? Int
        self.role = user["role"] as? Int
        self.hidden = user["hidden"] as? Bool
        self.photoUri = user["photoUri"] as? String
        self.name = user["name"] as? String
        self.remoteAccessible = user["remoteAccessible"] as? Bool
        self.house = user["house"] as? Int
        self.enabled = user["enabled"] as? Bool
    }
}
