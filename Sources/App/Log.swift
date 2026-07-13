import os

/// Lightweight logging seam (mirrors the Android app's Timber usage). Unified logging is
/// off in Release by default unless the subsystem is enabled, so these are effectively
/// debug-only, matching the original's `DebugTree`-in-debug behaviour.
enum Log {
    private static let subsystem = "com.circuitstitch.toys.animals"
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let tts = Logger(subsystem: subsystem, category: "tts")
}
