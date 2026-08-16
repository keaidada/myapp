import SwiftUI

struct BatchTagView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedCount: Int
    let existingTags: [String]
    let onApply: (String) -> Void
    var onRemove: ((String) -> Void)? = nil
    @State private var tagInput = ""
    @State private var mode: Mode = .add

    enum Mode: String, CaseIterable, Identifiable {
        case add = "添加标签"
        case remove = "移除标签"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("为选中的 \(selectedCount) 个服务")
                .font(.headline)
            Picker("操作", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            if mode == .add {
                TextField("输入新标签，回车添加", text: $tagInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { apply(tagInput) }
            }

            if !existingTags.isEmpty {
                Text(mode == .add ? "点标签快速添加（可连续添加）" : "点标签从选中服务移除")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(existingTags, id: \.self) { tag in
                        Button {
                            if mode == .add {
                                apply(tag)
                            } else {
                                onRemove?(tag)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if mode == .remove {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                TagCapsule(text: tag, tint: mode == .remove ? .red : .accentColor)
                            }
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
        .frame(width: 380)
    }

    private func apply(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onApply(trimmed)
        tagInput = ""
    }
}
