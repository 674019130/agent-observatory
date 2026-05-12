import AgentObservatoryCore
import SwiftUI

struct OrganizerView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var isAdvancedExpanded = false
    @State private var inspectedActionPack: OrganizerActionPack?

    private var isBusy: Bool {
        store.isPreparingOrganizerRun
            || store.isBuildingCleanupReview
            || store.isBuildingOrganizationMap
            || store.isOrganizing
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OrganizerAdvisorHeader()

                if let error = store.organizerError {
                    ManagementErrorBanner(message: error)
                }

                OrganizerRunHero(
                    run: store.organizerRun,
                    isBusy: isBusy,
                    onViewClassificationMap: {
                        isAdvancedExpanded = true
                    },
                    onReviewActionPack: { pack in
                        inspectedActionPack = pack
                    }
                )

                if let batch = store.latestManagementBatch {
                    LatestManagementOperationCard(batch: batch)
                }

                if store.organizerAdvancedContentState.isVisible {
                    OrganizerAdvancedSection(isExpanded: $isAdvancedExpanded)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(store.t(.aiOrganizer))
        .sheet(isPresented: organizerRunReviewBinding) {
            if let run = store.organizerRunReview {
                OrganizerRunReviewSheet(
                    run: run,
                    onViewDetails: {
                        isAdvancedExpanded = true
                        store.dismissOrganizerRunReview()
                    }
                )
                .environmentObject(store)
            }
        }
        .sheet(isPresented: cleanupPreviewBinding) {
            if let preview = store.cleanupExecutionPreview {
                CleanupExecutionPreviewSheet(preview: preview)
                    .environmentObject(store)
            }
        }
        .sheet(item: $inspectedActionPack) { pack in
            OrganizerActionPackReviewSheet(pack: pack)
                .environmentObject(store)
        }
    }

    private var organizerRunReviewBinding: Binding<Bool> {
        Binding(
            get: { store.organizerRunReview != nil },
            set: { isPresented in
                if !isPresented {
                    store.dismissOrganizerRunReview()
                }
            }
        )
    }

    private var cleanupPreviewBinding: Binding<Bool> {
        Binding(
            get: { store.cleanupExecutionPreview != nil },
            set: { isPresented in
                if !isPresented {
                    store.dismissCleanupExecutionPreview()
                }
            }
        )
    }
}

private struct OrganizerAdvisorHeader: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.t(.advisorTitle))
                    .font(.system(size: 28, weight: .semibold))
                Text(store.t(.advisorSubtitle))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let statusText {
                HStack(spacing: 10) {
                    if store.isPreparingOrganizerRun || store.isBuildingCleanupReview || store.isBuildingOrganizationMap || store.isOrganizing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(statusText)
                        .font(.callout)
                        .foregroundStyle(store.isPreparingOrganizerRun || store.isBuildingCleanupReview || store.isBuildingOrganizationMap || store.isOrganizing ? .primary : .secondary)
                        .lineLimit(2)
                    Spacer()
                }
            }

            if store.organizerRun.createdAt.timeIntervalSince1970 > 0 {
                Text("\(store.t(.updated)) \(store.organizerRun.createdAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var statusText: String? {
        if store.isPreparingOrganizerRun {
            return store.scanProgress.map { L10n.scanProgressMessage($0, language: store.appLanguage) }
                ?? store.t(.organizerRunScanning)
        }
        if store.isBuildingCleanupReview {
            return store.scanProgress.map { L10n.scanProgressMessage($0, language: store.appLanguage) }
                ?? store.t(.scanningForCleanupReview)
        }
        if store.isBuildingOrganizationMap {
            return store.scanProgress.map { L10n.scanProgressMessage($0, language: store.appLanguage) }
                ?? store.t(.scanningForOrganizationMap)
        }
        return store.organizerStatus
    }
}

private struct OrganizerAdvancedSection: View {
    @EnvironmentObject private var store: AssetStore
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                if store.isBuildingCleanupReview || !store.cleanupReviewSession.groups.isEmpty {
                    OrganizerAdvancedBlock(title: store.t(.cleanupGroups), systemImage: "checklist") {
                        CleanupReviewGroupsSection()
                    }
                }

                if !store.organizationPlan.recommendations.isEmpty {
                    OrganizerAdvancedBlock(title: store.t(.aiPlanNotes), systemImage: "sparkles") {
                        AIRecommendationNotesSection()
                    }
                }

                OrganizerAdvancedBlock(title: store.t(.configurationBrief), systemImage: "doc.text.magnifyingglass") {
                    AdvisorBriefSection()
                }

                OrganizerAdvancedBlock(title: store.t(.inventoryEvidence), systemImage: "map") {
                    OrganizerMapSection()
                }
            }
            .padding(.top, 12)
        } label: {
            HStack {
                Label(store.t(.advancedDetails), systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                if !store.organizerRun.actionPacks.isEmpty {
                    CountBadge(count: store.organizerRun.actionPacks.count, tint: .blue)
                } else if !store.cleanupReviewSession.groups.isEmpty {
                    CountBadge(count: store.cleanupReviewSession.groups.count, tint: .blue)
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct OrganizerAdvancedBlock<Content: View>: View {
    let title: String
    let systemImage: String
    private let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}
