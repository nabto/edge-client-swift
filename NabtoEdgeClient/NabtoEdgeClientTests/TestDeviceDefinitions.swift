//
// Created by Ulrik Gammelby on 01/03/2022.
//

import Foundation

struct TestDevice {
    var productId: String
    var deviceId: String
    var url: String
    var key: String
    var fp: String?
    var sct: String?
    var local: Bool
    var password: String!

    init(productId: String, deviceId: String, url: String, key: String, fp: String?=nil, sct: String?=nil, local: Bool=false, password: String?=nil) {
        self.productId = productId
        self.deviceId = deviceId
        self.url = url
        self.key = key
        self.fp = fp
        self.sct = sct
        self.local = local
        self.password = password
    }

    func asJson() -> String {
        let sctElement = sct != nil ? "\"ServerConnectToken\": \"\(sct!)\",\n" : ""
        return """
               {\n
               \"Local\": \(self.local),\n
               \"ProductId\": \"\(self.productId)\",\n
               \"DeviceId\": \"\(self.deviceId)\",\n
               \"ServerUrl\": \"\(self.url)\",\n
               \(sctElement)
               \"ServerKey\": \"\(self.key)\"\n}
               """
    }
}

struct TestDevices {
    let coapDevice = TestDevice(
            productId: "pr-fatqcwj9",
            deviceId: "de-avmqjaje",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce",
            fp: "fcb78f8d53c67dbc4f72c36ca6cd2d5fc5592d584222059f0d76bdb514a9340c"
    )

    let streamDevice = TestDevice(
            productId: "pr-fatqcwj9",
            deviceId: "de-bdsotcgm",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce"
    )

    let tunnelDevice = TestDevice(
            productId: "pr-fatqcwj9",
            deviceId: "de-ijrdq47i",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-9c826d2ebb4343a789b280fe22b98305",
            sct: "WzwjoTabnvux"
    )

    let forbiddenDevice = TestDevice(
            productId: "pr-t4qwmuba",
            deviceId: "de-fociuotx",
            url: "https://pr-t4qwmuba.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce", // product only configured with tunnel app with sk-9c826d2ebb4343a789b280fe22b98305
            sct: "WzwjoTabnvux"
    )

    let passwordProtectedDevice = TestDevice(
            productId: "pr-fatqcwj9",
            deviceId: "de-ijrdq47i",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-9c826d2ebb4343a789b280fe22b98305",
            sct: "WzwjoTabnvux",
            password: "open-password"
    )

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // local integration test devices that needs to be manually started
    //
    // build a device for local tests
    //
    // $ git clone --recursive git@github.com:nabto/nabto-embedded-sdk.git
    // $ cd nabto-embedded-sdk
    // $ mkdir _build
    // $ cd _build
    // $ cmake -j ..

    // password open pairing not enabled in config
    let localPasswordPairingDisabledConfig = TestDevice(
            productId: "pr-fatqcwj9",
            deviceId: "de-y3qyrjsn",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-9c826d2ebb4343a789b280fe22b98305",
            sct: "",
            local: true,
            password: "pff3wUnbs7V7"
    )

    // local password protected device
    let localPairPasswordOpen = TestDevice(
            productId: "pr-fatqcwj9",
            deviceId: "de-aiywxrjr",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-9c826d2ebb4343a789b280fe22b98305",
            sct: "RTLRgFXLwCsk",
            local: true,
            password: "pUhkiHnLhaoo"
    )

    // local open enabled device
    let localPairLocalOpen = TestDevice(
            productId: "pr-fatqcwj9",
            deviceId: "de-ysymtcbh",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-9c826d2ebb4343a789b280fe22b98305",
            sct: "",
            local: true,
            password: ""
    )

    // local initial enabled device
    let localPairLocalInitial = TestDevice(
            productId: "pr-fatqcwj9",
            deviceId: "de-i9dqsmif",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-9c826d2ebb4343a789b280fe22b98305",
            sct: "",
            local: true,
            password: ""
    )

    let localPasswordInvite = TestDevice(
            productId: "pr-fatqcwj9",
            deviceId: "de-vma9qrox",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-9c826d2ebb4343a789b280fe22b98305",
            local: true,
            password: "buKVmisdxETM"
    )


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // local mDNS test device
    //
    // run as follows:
    // $ cd _build
    // $ ./examples/simple_mdns/simple_mdns_device pr-mdns de-mdns swift-test-subtype swift-txt-key swift-txt-val
    static let mdnsProductId = "pr-mdns"
    static let mdnsDeviceId = "de-mdns"
    let mdnsSubtype = "swift-test-subtype"
    let mdnsTxtKey = "swift-txt-key"
    let mdnsTxtVal = "swift-txt-val"
    let localMdnsDevice = TestDevice(
            productId: "pr-mdns",
            deviceId: mdnsDeviceId,
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "none",
            sct: "none",
            local: true
    )

}