import SwiftUI

struct QuickLaunchView: View {
    @Bindable var controller: QuickLaunchController
    @FocusState private var searchFocused: Bool

    private var results: [ManagedService] {
        controller.results
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索并启动服务…（Cmd+Shift+M 呼出）", text: $controller.query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($searchFocused)
                    .onSubmit {
                        controller.launchSelected()
                    }
            }
            .padding(12)

            Divider()

            if results.isEmpty {
                Text("无匹配结果")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, service in
                            QuickLaunchRow(
                                service: service,
                                isSelected: index == controller.selectedIndex
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                controller.launch(service)
                            }
                        }
                    }
                }
                .frame(minHeight: 120, maxHeight: 260)
            }
        }
        .frame(width: 480)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator, lineWidth: 1)
        )
        .onChange(of: controller.query) { _, _ in
            controller.selectedIndex = 0
        }
        .onAppear {
            searchFocused = true
        }
    }
}

struct QuickLaunchRow: View {
    let service: ManagedService
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ServiceIconView(service: service, size: 22)
            Text(service.name)
                .lineLimit(1)
            Spacer()
            if !service.tags.isEmpty {
                Text(service.tags.prefix(2).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .animation(.easeOut(duration: 0.1), value: isSelected)
    }
}
