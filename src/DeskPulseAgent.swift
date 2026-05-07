import Foundation
import CoreGraphics
import ApplicationServices
import OSLog
import Darwin


// --- Configuration ---
let defaultConfigPath = "\(NSHomeDirectory())/Library/Application Support/DeskPulse/config.json"
let defaultPermissionStatusPath = "\(NSHomeDirectory())/Library/Application Support/DeskPulse/permission-status.txt"

let logger = Logger(subsystem: "com.deskpulse.agent", category: "runtime")
let timestampFormatter = ISO8601DateFormatter()


var currentMovementIndex = 0

var lastObservedPosition = currentMouseLocation()
var lastMovementTime = Date()

var isInOffice = false {
    didSet(oldValue) {
        if oldValue != isInOffice {
            log(.info, "isInOffice changed: \(oldValue) -> \(isInOffice)")
        }
    }
}
var isWithinWorkingHours = false {
    didSet(oldValue) {
        if oldValue != isWithinWorkingHours {
            log(.info, "isWithinWorkingHours changed: \(oldValue) -> \(isWithinWorkingHours)")
        }
    }
}

enum MovementDirection {
    case up
    case down
    case left
    case right
}

let movementsPlayback: [MovementDirection] = [
    .up,
    .left,
    .down,
    .right,
    .right,
    .down,
    .left,
    .up,
    .up,
    .right,
    .down,
    .left,
    .left,
    .down,
    .right,
    .up
]


func currentMovementDirection() -> MovementDirection {
    movementsPlayback[currentMovementIndex]
}

func advanceMovementIndex() {
    currentMovementIndex = (currentMovementIndex + 1) % movementsPlayback.count
}


// Prevent App Nap / Throttling
let activity = ProcessInfo.processInfo.beginActivity(
    options: [.userInitiated, .idleSystemSleepDisabled],
    reason: "Maintain HID session activity"
)

enum LogLevel: String {
    case info = "INFO"
    case error = "ERROR"
}

// --- Logging ---
func log(_ level: LogLevel, _ message: String) {

    let timestamp = timestampFormatter.string(from: Date())
    let formatted = "[\(timestamp)] [\(level.rawValue)] \(message)"

    switch level {
    case .info:
        break//logger.log("\(formatted, privacy: .public)")
    case .error:
        logger.error("\(formatted, privacy: .public)")
    }

    if let data = (formatted + "\n").data(using: .utf8) {
        if level == .error {
            FileHandle.standardError.write(data)
        } else {
            FileHandle.standardOutput.write(data)
        }
    }
}

struct MonitorServiceConfig: Codable {
    var idleThresholdSeconds: TimeInterval
    var loopIntervalSeconds: UInt32
    var pixelOffset: Double

    var disableIfSSIDPresentEnabled: Bool
    var disableIfSSIDPresentList: [String]
    var wifiScanIntervalSeconds: UInt32

    var disableIfOutsideHoursEnabled: Bool
    var disableIfOutsideHoursRange: String

    var movementTolerancePixels: Double { pixelOffset + 10 }

    static var `default`: MonitorServiceConfig {
        MonitorServiceConfig(
            idleThresholdSeconds: 5,
            loopIntervalSeconds: 1,
            pixelOffset: 2,
            disableIfSSIDPresentEnabled: false,
            disableIfSSIDPresentList: [],
            wifiScanIntervalSeconds: 60,
            disableIfOutsideHoursEnabled: true,
            disableIfOutsideHoursRange: "8-17"
        )
    }
}

func loadConfig() -> MonitorServiceConfig {
    let environment = ProcessInfo.processInfo.environment
    let configPath = environment["DESKPULSE_CONFIG_PATH"]
        ?? environment["MONITORSERVICE_CONFIG_PATH"]
        ?? defaultConfigPath
    let configURL = URL(fileURLWithPath: configPath)

    do {
        let configData = try Data(contentsOf: configURL)
        let loadedConfig = try JSONDecoder().decode(MonitorServiceConfig.self, from: configData)
        log(.info, "Loaded config from \(configPath)")
        return loadedConfig
    } catch {
        log(.info, "Using default config (reason: \(error.localizedDescription))")
        return .default
    }
}

let config = loadConfig()

// --- Permissions ---
func isTrusted() -> Bool {
    AXIsProcessTrusted()
}

func permissionStatusPath() -> String {
    let environment = ProcessInfo.processInfo.environment
    return environment["DESKPULSE_PERMISSION_STATUS_PATH"] ?? defaultPermissionStatusPath
}

func writePermissionStatus(_ trusted: Bool, note: String) {
    let path = permissionStatusPath()
    let url = URL(fileURLWithPath: path)
    let directoryURL = url.deletingLastPathComponent()
    let value = trusted ? "true\n" : "false\n"

    do {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        try value.write(to: url, atomically: true, encoding: .utf8)
        //log(.info, "Wrote permission status (trusted=\(trusted), note=\(note))")
    } catch {
        log(.error, "Failed to write permission status: \(error.localizedDescription)")
    }
}

func isScreenOpen() -> Bool {
    guard let sessionDict = CGSessionCopyCurrentDictionary() as? [String: Any] else {
        return false
    }

    let isLoggedIn = (sessionDict["kCGSessionLoginDoneKey"] as? Bool) ?? false
    let isScreenLocked = (sessionDict["CGSSessionScreenIsLocked"] as? Bool) ?? false
    let isDisplayActive = CGDisplayIsActive(CGMainDisplayID()) != 0
    // log(.info, "isLoggedIn: \(isLoggedIn)")
    // log(.info, "isScreenLocked: \(isScreenLocked)")
    // log(.info, "isDisplayActive: \(isDisplayActive)")
    return isLoggedIn && !isScreenLocked && isDisplayActive
}

// --- Mouse Logic ---
func currentMouseLocation() -> CGPoint {
    guard let source = CGEventSource(stateID: .combinedSessionState) else {
        log(.error, "Failed to create source. Session might be stale.")
        return .zero
    }
    guard let event = CGEvent(source: source) else {
        return .zero
    }
    return CGPoint(x: event.location.x, y: event.location.y)
}

func performMove(to point: CGPoint) {
    guard let source = CGEventSource(stateID: .combinedSessionState) else {
        log(.error, "Failed to create source. Session might be stale.")
        return
    }

    guard let event = CGEvent(
        mouseEventSource: source,
        mouseType: .mouseMoved,
        mouseCursorPosition: point,
        mouseButton: .left
    ) else {
        log(.error, "Failed to create CGEvent for mouse move to: \(point)")
        return
    }
    event.post(tap: .cgSessionEventTap)
    // log(.info, "Moved mouse to: \(point)")
}

func moveMouse() {
    let currentPosition = currentMouseLocation()
    let direction = currentMovementDirection()
    let pixelOffset = CGFloat(config.pixelOffset)
    let nudgePosition: CGPoint

    switch direction {
    case .up:
        nudgePosition = CGPoint(x: currentPosition.x, y: currentPosition.y - pixelOffset)
    case .down:
        nudgePosition = CGPoint(x: currentPosition.x, y: currentPosition.y + pixelOffset)
    case .left:
        nudgePosition = CGPoint(x: currentPosition.x - pixelOffset, y: currentPosition.y)
    case .right:
        nudgePosition = CGPoint(x: currentPosition.x + pixelOffset, y: currentPosition.y)
    }

    performMove(to: nudgePosition)
    lastObservedPosition = nudgePosition
    lastMovementTime = Date()
    advanceMovementIndex()
}

// --- Wi-Fi Logic (connected network name via shell) ---
func connectedWiFiNetworkNameViaShell() throws -> [String] {
    let script = #"en="$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}')"; ipconfig getsummary "$en" | grep -Fxq "  Active : FALSE" || networksetup -listpreferredwirelessnetworks "$en" | sed -n '2s/^\t//p'"#

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    task.arguments = ["-c", script]

    let outPipe = Pipe()
    task.standardOutput = outPipe

    try task.run()
    task.waitUntilExit()

    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let raw = String(data: outData, encoding: .utf8) ?? ""
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    // log(.info, "wifi shell output: \(trimmed) [line \(#line)]")
    if trimmed.isEmpty {
        return []
    }
    return [trimmed.lowercased()]
}

/// Updates `isInOffice`: true when Wi‑Fi name filtering is enabled and the **connected** network name matches a configured substring (nudging is then suppressed).
func checkIsInOffice() {
    if !config.disableIfSSIDPresentEnabled {
        isInOffice = false
        // log(.info, "isInOffice: false (disableIfSSIDPresentEnabled is false) [line \(#line)]")
        return
    }

    let nameSubstrings = config.disableIfSSIDPresentList.map { $0.lowercased() }

    do {
        let connectedNames = try connectedWiFiNetworkNameViaShell()
        // log(.info, "connected Wi-Fi name(s) from shell: \(connectedNames) [line \(#line)]")
        let match = connectedNames.contains { name in
            nameSubstrings.contains { substring in name.contains(substring) }
        }
        // log(.info, "connected Wi-Fi name matches filter: \(match) [line \(#line)]")
        if match {
            // log(.info, "isInOffice: true (connected network matched filter) [line \(#line)]")
            isInOffice = true
            return
        } else {
            // log(.info, "isInOffice: false (no substring match on connected name) [line \(#line)]")
            isInOffice = false
            return
        }
    } catch {
        // log(.error, "Wi-Fi name check failed: \(error.localizedDescription)")
    }

    isInOffice = false
    return
}

func checkIsWithinWorkingHours() {
    if !config.disableIfOutsideHoursEnabled {
        isWithinWorkingHours = true
        return
    }

    let parts = config.disableIfOutsideHoursRange.split(separator: "-", maxSplits: 1).map(String.init)
    guard parts.count == 2, let startHour = Int(parts[0]), let endHour = Int(parts[1]),
          (0...23).contains(startHour), (0...23).contains(endHour) else {
        log(.error, "Invalid disableIfOutsideHoursRange: \(config.disableIfOutsideHoursRange)")
        isWithinWorkingHours = false
        return
    }

    let calendar = Calendar.current
    let components = calendar.dateComponents([.weekday, .hour], from: Date())
    guard let weekday = components.weekday, let hour = components.hour else {
        isWithinWorkingHours = false
        return
    }
    let isWeekday = (2...6).contains(weekday)
    let isWithinHourRange: Bool
    if startHour <= endHour {
        isWithinHourRange = (startHour..<endHour).contains(hour)
    } else {
        isWithinHourRange = hour >= startHour || hour < endHour
    }
    isWithinWorkingHours = isWeekday && isWithinHourRange
    return
}

var hasMouseMoved = false

func checkHasMouseMoved() {
    let currentPosition = currentMouseLocation()
    let deltaX = currentPosition.x - lastObservedPosition.x
    let deltaY = currentPosition.y - lastObservedPosition.y
    let movedDistance = hypot(deltaX, deltaY)
    let movementTolerance = CGFloat(config.movementTolerancePixels)

    if movedDistance > movementTolerance {
        lastObservedPosition = currentPosition
        lastMovementTime = Date()
        currentMovementIndex = 0
        hasMouseMoved = true
    } else {
        hasMouseMoved = false
    }
}

func hasIddlingThresholdReached() -> Bool {
    let idleSeconds = Date().timeIntervalSince(lastMovementTime)
    return idleSeconds > config.idleThresholdSeconds
}


func checkPermission() -> Bool {
    let trusted = isTrusted()
    writePermissionStatus(trusted, note: trusted ? "loop-check" : "trust-lost")
    return trusted
}

var isNudging = false {
    didSet(oldValue) {
        if oldValue != isNudging {
            log(.info, "isNudging changed: \(oldValue) -> \(isNudging)")
        }
    }
}

// --- Main Loop ---
log(.info, "---------------------------------------------------")
log(.info, "DeskPulse started")
log(.info, "isNudging: \(isNudging)")
log(.info, "isInOffice: \(isInOffice)")
log(.info, "isWithinWorkingHours: \(isWithinWorkingHours)")
log(.info, "---------------------------------------------------")
writePermissionStatus(isTrusted(), note: "startup-check")


DispatchQueue.global(qos: .utility).async {
    while true {
        checkIsInOffice()
        sleep(config.wifiScanIntervalSeconds)
    }
}

func mainRunLoop() {
    while true {

        sleep(config.loopIntervalSeconds)
        guard checkPermission() else {
            continue
        }

        checkIsWithinWorkingHours()
        let shouldConsiderNudging = isWithinWorkingHours && !isInOffice && isScreenOpen()

        if shouldConsiderNudging {
            checkHasMouseMoved()
            if hasIddlingThresholdReached() && !hasMouseMoved {
                moveMouse()
                // log(.info, "Nudging mouse")
                isNudging = true
            } else if hasMouseMoved {
                isNudging = false

                // log(.info, "Has moved")
            } else {
                // log(.info, "Not nudging mouse")
            }
        } else {
            isNudging = false
        }
    }
}

mainRunLoop()
