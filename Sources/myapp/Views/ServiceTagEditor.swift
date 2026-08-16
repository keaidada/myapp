import SwiftUI

/// 单个服务的标签增删窗口（点行内🏷或右键"标签…"打开）
struct ServiceTagEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceStore.self) private var store
    let service: ManagedService
    @State private var newTag = ""

    /// 实时从 store 读取该服务最新状态（添加/移除后界面立即刷新）
    private var currentService: ManagedService? {
        store.services.first { $0.id == service.id }
    }

    private var currentTags: [String] {
        currentService?.tags ?? service.tags
    }

    private var allTags: [String] {
        store.allTags
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ServiceIconView(service: currentService ?? service, size: 20)
                Text(service.name)
                    .font(.headline)
            }

            // 当前标签（点 × 移除）
            if currentTags.isEmpty {
                Text("暂无标签")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(currentTags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                            Button {
                                try? store.removeTag(tag, from: [service.id])
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(.tint)
                    }
                }
            }

            // 添加：输入 + 已有标签点选
            HStack {
                TextField("输入新标签，回车添加", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addNew() }
                Button("添加") { addNew() }
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 2)

            if !allTags.isEmpty {
                Text("点已有标签添加（可连续添加）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(allTags, id: \.self) { tag in
                        Button {
                            try? store.addTag(tag, to: [service.id])
                        } label: {
                            TagCapsule(text: tag)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentTags.contains(tag))
                        .opacity(currentTags.contains(tag) ? 0.4 : 1)
                    }
                }
            }

            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func addNew() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try? store.addTag(trimmed, to: [service.id])
        newTag = ""
    }
}
