import Foundation
import func Evergreen.getLogger
import HAP

fileprivate let logger = getLogger("demo")

#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Dispatch
    import Glibc
#endif

import Kitura
import SwiftyGPIO

let officeLightbulb = Accessory.Lightbulb(info: Service.Info(name: "Escritório", serialNumber: "00001"))
let kitchenLightbulb = Accessory.Lightbulb(info: Service.Info(name: "Cozinha", serialNumber: "00002"))
let livingRoomLightbulb = Accessory.Lightbulb(info: Service.Info(name: "Sala", serialNumber: "00003"))
let bedRoomLightbulb = Accessory.Lightbulb(info: Service.Info(name: "Quarto", serialNumber: "00004"))

// Get the Pin where the LED will be attached to
let gpios = SwiftyGPIO.GPIOs(for: .RaspberryPiPlusZero)
guard let ledGPIO3 = gpios[.P4 ] else { fatalError("LED GPIO pin 3") }
guard let ledGPIO5 = gpios[.P17] else { fatalError("LED GPIO pin 5") }
guard let ledGPIO7 = gpios[.P27] else { fatalError("LED GPIO pin 7") }
guard let ledGPIO8 = gpios[.P22] else { fatalError("LED GPIO pin 8") }

guard let ledGPIO6  = gpios[.P6 ] else { fatalError("LED GPIO pin 8") }
guard let ledGPIO13 = gpios[.P13] else { fatalError("LED GPIO pin 8") }
guard let ledGPIO19 = gpios[.P19] else { fatalError("LED GPIO pin 8") }
guard let ledGPIO26 = gpios[.P26] else { fatalError("LED GPIO pin 8") }

// Set the GPIO to output


let pinsOUTS = [ledGPIO3, ledGPIO5, ledGPIO7, ledGPIO8]
let pinsINS  = [ledGPIO6, ledGPIO13, ledGPIO19, ledGPIO26]


for  p in pinsOUTS {
    p.direction = .OUT
}
for  p in pinsINS {
    p.direction = .IN
}

ledGPIO3.value = 0
ledGPIO5.value = 0
ledGPIO7.value = 0
ledGPIO8.value = 0

var prev06 = 0

ledGPIO6.onFalling(){
    (input)  in
    print("on ledGPIO6 :\(input .value)")
    ledGPIO7.value = ledGPIO7.value == 0 ? 1 : 0
    livingRoomLightbulb.lightbulb.powerState.value = ledGPIO7.value == 1
}

ledGPIO13.onFalling(){
    (input)  in
    print("on ledGPI13 :\(input .value)")
    
    ledGPIO8.value = ledGPIO8.value == 0 ? 1 : 0
    bedRoomLightbulb.lightbulb.powerState.value = ledGPIO8.value == 1
}

ledGPIO19.onFalling(){
    (input)  in
    print("on ledGPI19 :\(input .value)")
    ledGPIO5.value = ledGPIO5.value == 0 ? 1 : 0
    kitchenLightbulb.lightbulb.powerState.value = ledGPIO5.value == 1
}

ledGPIO26.onFalling(){
    (input)  in
    print("on ledGPI26 :\(input .value)")
    ledGPIO3.value = ledGPIO3.value == 0 ? 1 : 0
    officeLightbulb.lightbulb.powerState.value = ledGPIO3.value == 1
}


class  House : Decodable{
    var output1 = 0
    var output2 = 0
    var output3 = 0
    var output4 = 0
}

let router = Router()

func dict2json(dict : Dictionary<String, Any?>) -> String {
    let invalidJson = "Not a valid JSON"
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        return String(bytes: jsonData, encoding: String.Encoding.utf8) ?? invalidJson
    } catch {
        return invalidJson
    }
    return invalidJson
}

func dict2json(dict : [String: Any]?) -> String {
    let invalidJson = "Not a valid JSON"
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        return String(bytes: jsonData, encoding: String.Encoding.utf8) ?? invalidJson
    } catch {
        return invalidJson
    }
    return invalidJson
}

router.get("/api/status") { request, response, next in
    print (request)
    
    let objectDict : Dictionary<String, Any?> = [
        "output1"          : ledGPIO3.value,
        "output2"          : ledGPIO5.value,
        "output3"          : ledGPIO7.value,
        "output4"          : ledGPIO8.value,
    ]
    
    response.send(dict2json(dict:objectDict))
    next()
}

router.post("/api") { request, response, next in
    do {
        let h = try request.read(as: House.self)
        ledGPIO3.value = h.output1
        ledGPIO5.value = h.output2
        ledGPIO7.value = h.output3
        ledGPIO8.value = h.output4
        
        let objectDict : Dictionary<String, Any?> = [
            "status"          : "ok"
        ]
        response.send(dict2json(dict:objectDict))
        
    } catch {
        let _ = response.send(status: .badRequest)
    }
    next()
}

router.get("/api") { request, response, next in
    print (request)
    response.send("Hello world")
    next()
}

print ("Server started on port 8080")

Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

getLogger("hap").logLevel = .debug
getLogger("hap.encryption").logLevel = .warning

let storage = FileStorage(filename: "configuration.json")
if CommandLine.arguments.contains("--recreate") {
    logger.info("Dropping all pairings, keys")
    try storage.write(Data())
}





let device = Device(
    bridgeInfo: Service.Info(name: "Bridge", serialNumber: "00001"),
    setupCode: "123-44-321",
    storage: storage,
    accessories: [
        officeLightbulb,
        kitchenLightbulb,
        livingRoomLightbulb,
        bedRoomLightbulb
    ])

class MyDeviceDelegate: DeviceDelegate {
    func didRequestIdentificationOf(_ accessory: Accessory) {
        logger.info("Requested identification "
            + "of accessory \(String(describing: accessory.info.name.value ?? ""))")
    }

    func characteristic<T>(_ characteristic: GenericCharacteristic<T>,
                           ofService service: Service,
                           ofAccessory accessory: Accessory,
                           didChangeValue newValue: T?) {
        logger.info("Characteristic \(characteristic) "
            + "in service \(service.type) "
            + "of accessory \(accessory.info.name.value ?? "") "
            + "did change: \(String(describing: newValue))")
        /*
        let objectDict : Dictionary<String, Any?> = [
            "output1"          : ledGPIO3.value,officeLightbulb
            "output2"          : ledGPIO5.value,kitchenLightbulb
            "output3"          : ledGPIO7.value,livingRoomLightbulb
            "output4"          : ledGPIO8.value,bedRoomLightbulb
        ]
         let officeLightbulb = Accessory.Lightbulb(info: Service.Info(name: "Escritório", serialNumber: "00001"))
         let kitchenLightbulb = Accessory.Lightbulb(info: Service.Info(name: "Cozinha", serialNumber: "00002"))
         let livingRoomLightbulb = Accessory.Lightbulb(info: Service.Info(name: "Sala", serialNumber: "00003"))
         let bedRoomLightbulb = Accessory.Lightbulb(info: Service.Info(name: "Quarto", serialNumber: "00004"))
        */
        switch accessory.info.name.value {
        case "Escritório":
            ledGPIO3.value = (String(describing: newValue) == "true") ? 1 : 0
        case "Cozinha":
            ledGPIO5.value = (String(describing: newValue) == "true") ? 1 : 0
        case "Sala":
            ledGPIO5.value = (String(describing: newValue) == "true") ? 1 : 0
        case "Quarto":
            ledGPIO8.value = (String(describing: newValue) == "true") ? 1 : 0
        default:
            print("no case ")
        }
    }

    func characteristicListenerDidSubscribe(_ accessory: Accessory,
                                            service: Service,
                                            characteristic: AnyCharacteristic) {
        logger.info("Characteristic \(characteristic) "
            + "in service \(service.type) "
            + "of accessory \(accessory.info.name.value ?? "") "
            + "got a subscriber")
    }

    func characteristicListenerDidUnsubscribe(_ accessory: Accessory,
                                              service: Service,
                                              characteristic: AnyCharacteristic) {
        logger.info("Characteristic \(characteristic) "
            + "in service \(service.type) "
            + "of accessory \(accessory.info.name.value ?? "") "
            + "lost a subscriber")
    }
}

var delegate = MyDeviceDelegate()
device.delegate = delegate
let server = try Server(device: device, listenPort: 8000)

// Stop server on interrupt.
var keepRunning = true
func stop() {
    DispatchQueue.main.async {
        logger.info("Shutting down...")
        keepRunning = false
    }
}
signal(SIGINT) { _ in stop() }
signal(SIGTERM) { _ in stop() }

print("Initializing the server...")

// Switch the lights every 5 seconds.
/*
let timer = DispatchSource.makeTimerSource()
timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(5))
timer.setEventHandler(handler: {
    livingRoomLightbulb.lightbulb.powerState.value = !(livingRoomLightbulb.lightbulb.powerState.value ?? false)
})
timer.resume()
*/
print()
print("Scan the following QR code using your iPhone to pair this device:")
print()
print(device.setupQRCode.asText)
print()

withExtendedLifetime([delegate]) {
    if CommandLine.arguments.contains("--test") {
        print("Running runloop for 10 seconds...")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))
    } else {
        while keepRunning {
            RunLoop.current.run(mode: .default, before: Date.distantFuture)
        }
    }
}

try server.stop()
logger.info("Stopped")
