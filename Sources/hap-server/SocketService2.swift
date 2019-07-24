//
//  SocketService2.swift
//  DonaHome3
//
//  Created by Ricardo Abreu on 03/07/18.
//  Copyright © 2018 WinWel Electronics, Lda. All rights reserved.
//

import Foundation
import Starscream
import CommonCrypto

class SocketService2: WebSocketDelegate {
    
    private static var ws: WebSocket? = nil

    private static var currentCallbackId = 0
    private static var callbacks = Dictionary<Int, (_ data: Dictionary<String, Any>, _ error: Error?) -> ()>()
    private var socketCallback: ((_ error: Error?) -> ())? = nil
    
    static var masterLogListeners = [(subject: String, params: Dictionary<String, Any>, objId: Int) -> ()]()
    static var deviceListeners   = [(objId: Int, value: Double) -> ()]()
    
    static var isConnected = false
    
    func websocketDidConnect(socket: WebSocketClient) {
        print("Socket: connected")
        SocketService2.isConnected = true
        socketCallback?(nil)
        sendPing(socket: socket)
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("Socket: disconnected")
        SocketService2.isConnected = false
        if error != nil {
            socketCallback?(error)
        }
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        if (text.contains("key")) {
            //generate cipher resp key with the key that comes from the server
            return
        }
        
        if (text.range(of: "pong") != nil) {
            sendPing(socket: socket)
            //print("pong")
            return
        }
         //print(text)
        do {
            guard let data = try JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: .allowFragments) as? Dictionary<String, Any> else { return }
           
            if data["request"] != nil {
                let subject = (data["request"] as! Dictionary<String, Any>)["subject"] as! String
                //print(subject)
                
                if (    subject == "counter"  ||
                        subject == "analog"   ||
                        subject == "shutter"  ||
                        subject == "binaryIn" ||
                        subject == "binaryOut" ){
                    let obj = ((data["request"] as! Dictionary<String, Any>)["options"] as! Dictionary<String, Any>)["object"] as! Dictionary<String, Any>
                    let objId = obj["id"] as! Int
                    var objValue = 0.0
                    switch subject {
                    case "counter"  :
                        objValue = obj["value"] as! Double
                    case "analog"   :
                        objValue = obj["value"] as! Double
                    case "shutter"  :
                        objValue = obj["percentage"] as! Double
                    case "binaryIn" :
                        objValue = obj["status"] as! Double
                    case "binaryOut":
                        objValue = obj["status"] as! Double
                    default:
                        objValue = obj["value"] as! Double
                    }
                    
                    for listener in SocketService2.deviceListeners {
                        listener(objId, objValue)
                    }
                    return
                }
                else if subject == "masterLog" {
                    let obj = ((data["request"] as! Dictionary<String, Any>)["options"] as! Dictionary<String, Any>)["object"] as! Dictionary<String, Any>
                    let objId = obj["objectId"] as! Int
                    let objSubject = obj["subject"] as! String
                    guard let params = try JSONSerialization.jsonObject(with: (obj["params"] as! String).data(using: .utf8)!, options: []) as? Dictionary<String, Any> else {return}
                    print(objSubject)
                    if  (objSubject == "binaryOut"  && params["#status"]        != nil) ||
                        (objSubject == "binaryIn"   && params["#event"]         != nil) ||
                        (objSubject == "shutter"    && params["#percentage"]    != nil) ||
                        (objSubject == "ambience"   && params["#name"]          != nil) || //&& (objType == 3 || objType == 4)) ||
                        (objSubject == "pulse"      && params["#status"]        != nil) ||
                        (objSubject == "dimmer"     && params["#percentage"]    != nil) {
                        for listener in SocketService2.masterLogListeners {
                            listener(objSubject, params, objId)
                        }
                    }
                    if  (objSubject == "alarm"  && params["#wasArmedPreviosly"]    != nil) {
                        for listener in SocketService2.masterLogListeners {
                            listener(objSubject, params, objId)
                        }
                    }
                    return
                }
            }
    
            if data["code"] != nil {
                let code = data["code"] as! Int
                
                if code == 401 {
                    let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "The session expired. \(data)"])
                    SocketService2.callbacks[data["callback_id"] as! Int]?(Dictionary(), error)
                    return
                }
                if code == 403 {
                    let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed request, code 403. \(data)"])
                    SocketService2.callbacks[data["callback_id"] as! Int]?(Dictionary(), error)
                    return
                }
                if code == 404 {
                    let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed request, code 404. \(data)"])
                    SocketService2.callbacks[data["callback_id"] as! Int]?(Dictionary(), error)
                    return
                }
            }
            
            let callbackId = data["callback_id"] as? Int
            if callbackId != nil {
                print("Socket: Received response (for callback \(callbackId!)): \(text)")
                SocketService2.callbacks[callbackId!]?(data, nil)
            }
            
        } catch let error {
            print(error)
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {}
    
    static var counterTries = 0
    
    static func sendRequest(request: String, callback: @escaping (_ data: Dictionary<String, Any>, _ error: Error?) -> ()) {

        let callbackId = getCallbackId()
        callbacks[callbackId] = callback
        
        do {
            if var requestDict = try JSONSerialization.jsonObject(with: request.data(using: .utf8)!, options : JSONSerialization.ReadingOptions.allowFragments) as? Dictionary<String, Any>
            {
                if (SessionHelper.token != nil) {
                    requestDict["token"] = SessionHelper.token!
                }
                requestDict["callback_id"] = callbackId
                
                let json = try! String(data: JSONSerialization.data(withJSONObject: requestDict), encoding: String.Encoding.utf8)!
                print("SENDING (callback id: \(callbackId)): \(json)")
                ws?.write(string: json)
                
            } else {
                print("bad json in send request")
            }
        } catch let error {
            callback(Dictionary(), error)
            
            
        }
    }
    
    private static var ss2: SocketService2? = nil
    static func connect(dnsOrIp: String, secureConnection: Bool, callback: @escaping (_ error: Error?) -> ()) {
        
        ws?.delegate = nil
        ws = nil
        if secureConnection {
            
            ws = WebSocket(url: URL(string: "wss://\(dnsOrIp)/ws/")!, protocols: ["domotalk","ping-pong"])
        } else {
            ws = WebSocket(url: URL(string: "ws://\(dnsOrIp)/ws/")!, protocols: ["domotalk","ping-pong"])
        }
        
        ss2 = SocketService2()
        ss2?.socketCallback = callback
        ws?.delegate = ss2
        ws?.connect()
       
    }
    
    static func disconnect() {
        ws?.disconnect()
        ws?.delegate = nil
        ws = nil
    }
    
    private static func getCallbackId() -> Int {
        currentCallbackId += 1
        if currentCallbackId > 10000 {currentCallbackId = 0}
        return currentCallbackId
    }
    
    public func sendPing(socket: WebSocketClient) {

        if #available(OSX 10.12, *) {
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { (timer) in
                socket.write(string: "ping", completion: nil)
            }
        } else {
            // Fallback on earlier versions
        }
    }
}

extension String {
    func md5() -> String {
        
        
        let messageData = self.data(using:.utf8)!
        var digestData = Data(count: Int(CC_MD5_DIGEST_LENGTH))
        
        _ = digestData.withUnsafeMutableBytes {digestBytes in
            messageData.withUnsafeBytes {messageBytes in
                CC_MD5(messageBytes, CC_LONG(messageData.count), digestBytes)
            }
        }
        return digestData.map { String(format: "%02hhx", $0) }.joined()
    }
    
    func isIp() -> Bool {
        let validIP = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
        if ((self.count == 0) || (self.range(of: validIP, options: .regularExpression) == nil)) {
            return false
        }
        return true
    }
}



















