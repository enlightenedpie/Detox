import XCTest
import Network

final class CommandServer {

    private let listener: NWListener
    private let app: XCUIApplication

    init(port: UInt16, app: XCUIApplication) throws {
        self.app = app
        listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
    }

    func run() {
        listener.newConnectionHandler = { connection in
            connection.start(queue: .main)
            self.receive(on: connection)
        }

        listener.start(queue: .main)
        print("Command server running on port \(listener.port!)")
        RunLoop.current.run()
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
            guard let data = data, let json = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            if let response = self.handleCommand(json: json) {
                let responseData = response.data(using: .utf8)!
                connection.send(content: responseData, completion: .contentProcessed({ _ in }))
            }

            if !isComplete {
                self.receive(on: connection)
            } else {
                connection.cancel()
            }
        }
    }

    private func handleCommand(json: String) -> String? {
        // Very simple parsing for Phase 0
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = dict["action"] as? String
        else { return nil }

        switch action {
        case "tap":
            if let by = dict["by"] as? [String: Any],
               let type = by["type"] as? String,
               let value = by["value"] as? String {

                if type == "id" {
                    let element = app.descendants(matching: .any)[value]
                    if element.exists {
                        element.tap()
                        return "{\"status\":\"ok\"}"
                    } else {
                        return "{\"status\":\"error\",\"message\":\"Element not found\"}"
                    }
                }
            }
            return "{\"status\":\"error\",\"message\":\"Invalid selector\"}"
        default:
            return "{\"status\":\"error\",\"message\":\"Unknown action\"}"
        }
    }
}
