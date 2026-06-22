import SwiftUI
import NabtoEdgeClient

struct ContentView: View {
    @State private var status: String = "Client SDK Version: " + Client.versionString()
    @State private var inFlight = false

    var body: some View {
        VStack(spacing: 24) {
            Text(status)
                .multilineTextAlignment(.center)
                .padding()
            if inFlight {
                ProgressView()
            }
            Button("Send CoAP /hello-world") {
                Task { await callHelloWorld() }
            }
            .disabled(inFlight)
        }
        .padding()
    }

    @MainActor
    private func callHelloWorld() async {
        inFlight = true
        defer { inFlight = false }
        do {
            let result = try await Task.detached(priority: .userInitiated) { () -> String in
                let client = Client()
                client.enableNsLogLogging()
                try client.setLogLevel(level: "info")
                let connection = try client.createConnection()
                let privateKey = try client.createPrivateKey()
                try connection.setPrivateKey(key: privateKey)
                try connection.setProductId(id: "pr-fatqcwj9")
                try connection.setDeviceId(id: "de-avmqjaje")
                try connection.setServerKey(key: "sk-72c860c244a6014248e64d5273e3e0ec")
                try connection.connect()
                let coap = try connection.createCoapRequest(method: "GET", path: "/hello-world")
                let response = try coap.execute()
                let body = response.status == 205
                    ? String(decoding: response.payload, as: UTF8.self)
                    : "(no payload)"
                return "\(response.status): \(body)"
            }.value
            status = result
        } catch {
            status = "ERROR: \(error)"
        }
    }
}
