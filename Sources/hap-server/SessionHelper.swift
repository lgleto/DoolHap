//
//  SessionHelper.swift
//  DonaHome
//
//  Created by Ricardo Abreu on 20/04/18.
//  Copyright © 2018 Ricardo Abreu. All rights reserved.
//

import Foundation

class SessionHelper {
    
    static var user: User? = nil
    static var token: String? = nil
    
    static func createSession(username: String, password: String, callback: ((_ token: String, _ error: Error?) -> ())?) {
        
        Requests.getAllUsers() { (data, error) in
            if error != nil {
                callback?(String(), error)
            } else {
                let payload = data["payload"] as! [Dictionary<String, Any>]
                for user in payload {
                    if user["name"] as! String == username {
                        self.user = User.init(user: user)
                    }
                }
                
                if self.user?.id == nil || self.user?.id == 0 {
                    let e = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not find user with that name (be aware that the username is case sensitive)"])
                    callback?(String(), e)
                    return
                }
                
                Requests.createSession(userId: (SessionHelper.user?.id)!, password: password, callback: { (data, error) in
                    if error != nil {
                        callback?(String(), error)
                    } else {
                        if (data["token"] == nil) {
                            let e = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "\(data["payload"]!)"])
                            callback?(String(), e)
                        } else {
                            callback?(data["token"] as! String, nil)
                        }
                    }
                })
            }
        }
    }
    

}
