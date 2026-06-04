import AgentObservatoryCore
import SwiftUI

struct ContextOverviewMergedView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var showsNavigator = false

    var body: some View {
        VStack(spacing: 0) {
            navigatorControlBar

            Divider()

            HStack(spacing: 0) {
                if showsNavigator {
                    ContextOverviewView()
                        .environmentObject(store)
                        .frame(width: 390)
                        .frame(maxHeight: .infinity)
                        .background(.regularMaterial)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    Divider()
                }

                overviewDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .animation(.easeOut(duration: 0.18), value: showsNavigator)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var navigatorControlBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    showsNavigator.toggle()
                }
            } label: {
                Label(
                    showsNavigator
                        ? overviewText("Hide context tree", "收起上下文树", language: store.appLanguage)
                        : overviewText("Show context tree", "展开上下文树", language: store.appLanguage),
                    systemImage: showsNavigator ? "sidebar.left" : "list.bullet.indent"
                )
                .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(overviewText(
                "Show or hide the context browser without leaving this canvas.",
                "在当前画布内显示或隐藏上下文浏览器。",
                language: store.appLanguage
            ))

            if showsNavigator {
                Text(overviewText(
                    "Selecting a tree item updates the detail pane on the right.",
                    "选择树节点后，右侧详情会同步更新。",
                    language: store.appLanguage
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var overviewDetail: some View {
        if let contextGroup = store.selectedContextTreeGroup {
            ContextGroupInspectorView(node: contextGroup)
        } else if store.selectedAssetID == nil {
            ContextOverviewInspectorView()
        } else {
            InspectorView()
        }
    }
}

private func overviewText(_ english: String, _ simplifiedChinese: String, language: AppLanguage) -> String {
    switch language {
    case .english:
        english
    case .simplifiedChinese:
        simplifiedChinese
    }
}
