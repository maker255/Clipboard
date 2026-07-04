import Foundation
import os.log

public enum Log {
    private static let subsystem = "com.local.clipboard"

    public static let app        = Logger(subsystem: subsystem, category: "app")
    public static let database   = Logger(subsystem: subsystem, category: "database")
    public static let pasteboard = Logger(subsystem: subsystem, category: "pasteboard")
    public static let hotkey     = Logger(subsystem: subsystem, category: "hotkey")
    public static let panel      = Logger(subsystem: subsystem, category: "panel")
    public static let paste      = Logger(subsystem: subsystem, category: "paste")
    public static let cleanup    = Logger(subsystem: subsystem, category: "cleanup")
}
