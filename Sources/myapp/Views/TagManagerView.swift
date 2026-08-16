import SwiftUI

/// 集中的标签管理窗口：所有标签一览 + 行内重命名/删除
struct TagManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceStore.self) private var store
    @State private var renameTarget: String?
    @State private var renameText = ""
    @State private var deleteTarget: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.allTags.isEmpty {
                    ContentUnavailableView(
                        "还没有标签",
                        systemImage: "tag",
                        description: Text("多选服务后点底部「标签」按钮创建")
                    )
                } else {
                    List {
                        ForEach(store.allTags, id: \.self) { tag in
                            HStack(spacing: 10) {
                                Image(systemName: "tag")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tag)
                                    Text("\(store.count(of: tag)) 个服务")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("重命名") {
                                    renameTarget = tag
                                    renameText = tag
                                }
                                .controlSize(.small)
                                Button("删除") {
                                    deleteTarget = tag
                                }
                                .controlSize(.small)
                                .foregroundStyle(.red)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("标签管理")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .frame(width: 440, height: 500)
        .alert("重命名标签", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("新名称", text: $renameText)
            Button("确定") {
                if let old = renameTarget {
                    try? store.renameTag(old, to: renameText)
                }
                renameTarget = nil
            }
            Button("取消", role: .cancel) { renameTarget = nil }
        } message: {
            Text("所有使用该标签的服务都会同步更新")
        }
        .confirmationDialog(
            "删除标签「\(deleteTarget ?? "")」？",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let tag = deleteTarget {
                    try? store.deleteTag(tag)
                }
                deleteTarget = nil
            }
            Button("取消", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("将从所有服务上移除该标签")
        }
    }
}
