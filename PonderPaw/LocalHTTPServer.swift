import Foundation
import PerfectHTTP
import PerfectHTTPServer

public class LocalHTTPServer {
    private var server: HTTPServer
    private(set) var port: UInt16 = 0
    
    public init() {
        server = HTTPServer()
    }
    
    public func startServer(folderPath: String, preferredPort: UInt16 = 8888) -> String? {
        port = findAvailablePort(startingAt: preferredPort)
        
        do {
            // Configure the server to serve static files from the specified folder
            var routes = Routes()
            routes.add(method: .get, uri: "/**",
                       handler: StaticFileHandler(documentRoot: folderPath, allowResponseFilters: true).handleRequest)
            
            server.serverName = "localhost"
            server.serverPort = UInt16(port)
            server.addRoutes(routes)
            
            // Run the server asynchronously
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                do {
                    try self.server.start()
                    print("Server has started and is running")
                } catch {
                    print("Error starting server: \(error)")
                }
            }
            
            let serverURL = "http://localhost:\(port)"
            
            print("Server has started at \(serverURL)")
            return serverURL
        } catch {
            print("Error starting server: \(error)")
            return nil
        }
    }
    
    public func stopServer() {
        server.stop()
        print("Server has stopped.")
    }
    
    private func isPortAvailable(_ port: UInt16) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD > 0 else { return false }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian
        
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        close(socketFD)
        return bindResult == 0
    }
    
    private func findAvailablePort(startingAt basePort: UInt16) -> UInt16 {
        var currentPort = basePort
        while !isPortAvailable(currentPort) {
            currentPort += 1
            if currentPort > 65535 {
                fatalError("No available ports found.")
            }
        }
        return currentPort
    }
}
