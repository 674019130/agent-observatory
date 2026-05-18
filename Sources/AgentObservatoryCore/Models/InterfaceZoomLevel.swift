import Foundation

public enum InterfaceZoomLevel: Int, CaseIterable, Codable, Sendable {
    case smallest = -2
    case smaller = -1
    case standard = 0
    case larger = 1
    case largest = 2
    case accessibility = 3

    public static let defaultLevel: InterfaceZoomLevel = .standard

    public static func stored(rawValue: Int?) -> InterfaceZoomLevel {
        guard let rawValue else { return defaultLevel }
        return InterfaceZoomLevel(rawValue: rawValue) ?? defaultLevel
    }

    public var canZoomIn: Bool {
        self != Self.allCases.max(by: { $0.rawValue < $1.rawValue })
    }

    public var canZoomOut: Bool {
        self != Self.allCases.min(by: { $0.rawValue < $1.rawValue })
    }

    public var scale: Double {
        switch self {
        case .smallest:
            return 0.80
        case .smaller:
            return 0.90
        case .standard:
            return 1.00
        case .larger:
            return 1.12
        case .largest:
            return 1.25
        case .accessibility:
            return 1.40
        }
    }

    public var zoomedIn: InterfaceZoomLevel {
        guard canZoomIn else { return self }
        return Self.stored(rawValue: rawValue + 1)
    }

    public var zoomedOut: InterfaceZoomLevel {
        guard canZoomOut else { return self }
        return Self.stored(rawValue: rawValue - 1)
    }
}
