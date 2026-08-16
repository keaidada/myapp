import SwiftUI

struct BatchTagView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedCount: Int
    let existingTags: [String]
    let onApply: (String) -> Void
    @State private var tagInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("为选中的 \(selectedCount) 个服务添加标签")
                .font(.headline)
            TextField("输入新标签，回车添加", text: $tagInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit { apply(tagInput) }
            if !existingTags.isEmpty {
                Divider()
                Text("点已有标签快速添加（可连续添加多个）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(existingTags, id: \.self) { tag in
                        Button {
                            apply(tag)
                        } label: {
                            TagCapsule(text: tag)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Spacer()
                Button("完成") { dismiss() }
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func apply(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onApply(trimmed)
        tagInput = ""
    }
}
