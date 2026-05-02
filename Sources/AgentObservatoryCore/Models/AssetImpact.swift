import Foundation

public struct AssetImpact: Equatable, Sendable {
    public let assetPath: String
    public let outgoingReferences: [AssetDependencyLink]
    public let incomingReferences: [AssetDependencyLink]

    public init(
        assetPath: String,
        outgoingReferences: [AssetDependencyLink],
        incomingReferences: [AssetDependencyLink]
    ) {
        self.assetPath = assetPath
        self.outgoingReferences = outgoingReferences
        self.incomingReferences = incomingReferences
    }

    public var missingReferenceCount: Int {
        outgoingReferences.filter(\.isMissing).count
    }

    public var staleReferenceCount: Int {
        (outgoingReferences + incomingReferences).filter(\.isStaleReference).count
    }
}

public struct AssetDependencyLink: Identifiable, Equatable, Sendable {
    public var id: String { "\(sourcePath)->\(reference)" }
    public let sourcePath: String
    public let sourceTitle: String
    public let reference: String
    public let targetPath: String?
    public let targetTitle: String?
    public let isMissing: Bool
    public let isStaleReference: Bool

    public init(
        sourcePath: String,
        sourceTitle: String,
        reference: String,
        targetPath: String?,
        targetTitle: String?,
        isMissing: Bool,
        isStaleReference: Bool
    ) {
        self.sourcePath = sourcePath
        self.sourceTitle = sourceTitle
        self.reference = reference
        self.targetPath = targetPath
        self.targetTitle = targetTitle
        self.isMissing = isMissing
        self.isStaleReference = isStaleReference
    }
}
