//
//  Requests.swift
//  DonaHome
//
//  Created by Ricardo Abreu on 20/04/18.
//  Copyright © 2018 Ricardo Abreu. All rights reserved.
//

import Foundation

enum RequestsCallback {
    case onSuccess(data: Dictionary<String, Any>)
    case onError(e: Error)
}

class Requests {
    
    static func getAllUsers(callback: @escaping (_ data: Dictionary<String, Any>, _ error: Error?) -> ()) {
    
        SocketService2.sendRequest(request: "{\"verb\": \"read\",\"subject\": \"user\"}") { (data, error) in
            if error != nil {
                callback(Dictionary(), error)
            } else {
                callback(data, nil)
            }
        }
    }
    
    static func createSession(userId: Int, password: String, callback: @escaping (_ data: Dictionary<String, Any>, _ error: Error?) -> ()){
        
        let objectDict : Dictionary<String, Any?> = [
            "userId"           : userId         ,
            "password"         : password.md5() ,
            "forever"          : true           ,
            ]
        
        
        let dictionaryRequest  : Dictionary<String, Any?> = [
            "verb"             : "create"       ,
            "subject"          : "session"      ,
            "options"          : objectDict     ,
            ]
        
        SocketService2.sendRequest(request: dictionaryRequest.dict2json()) { (data, error) in
            if error != nil {
                callback(Dictionary(), error)
            } else {
                callback(data, nil)
            }
        }
    }
    
    static func recoverSession(token: String?, callback: @escaping (_ data: Dictionary<String, Any>, _ error: Error?) -> ()) {
        if (token == nil) {
            let e = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No token found in user defaults"])
            callback(Dictionary(), e)
        } else {
            SocketService2.sendRequest(request: "{\"verb\": \"action\",\"subject\": \"session\",\"options\": {\"token\": \"\(token ?? "")\"}}") { (data, error) in
                if error != nil {
                    callback(Dictionary(), error)
                } else {
                    callback(data, nil)
                }
            }
        }
    }
    
    static func deleteSession() {
        SocketService2.sendRequest(request: "{\"verb\": \"delete\",\"subject\": \"session\"}") { (_, _) in }
    }
    
    static func getAlarms(callback: @escaping (_ data: Dictionary<String, Any>, _ error: Error?) -> ()) {
        SocketService2.sendRequest(request: "{\"verb\": \"read\",\"subject\": \"alarm\"}") { (data, error) in
            if error != nil {
                callback(Dictionary(), error)
            } else {
                callback(data, nil)
            }
        }
    }
  
}
extension Dictionary {
    
    var json: String {
        let invalidJson = "Not a valid JSON"
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            return String(bytes: jsonData, encoding: String.Encoding.utf8) ?? invalidJson
        } catch {
            return invalidJson
        }
    }
    
    func dict2json() -> String {
        return json
    }
}































