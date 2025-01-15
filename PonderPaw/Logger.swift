import SwiftyBeaver

// Configure SwiftyBeaver logger as a global instance
let log: SwiftyBeaver.Type = {
    let log = SwiftyBeaver.self

    // Configure console destination
    let console = ConsoleDestination()
    console.asynchronously = true
    console.minLevel = .verbose

    // Add destinations
    log.addDestination(console)

    return log
}()
