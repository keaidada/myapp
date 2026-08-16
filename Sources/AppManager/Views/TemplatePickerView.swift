import SwiftUI

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onUse: (ServiceTemplate) -> Void

    private var groups: [(String, [ServiceTemplate])] {
        ServiceTemplates.categories.map { category in
            (category, ServiceTemplates.templates(in: category))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.0) { category, templates in
                    Section(category) {
                        ForEach(templates) { template in
                            HStack(spacing: 10) {
                                Image(systemName: template.icon)
                                    .foregroundStyle(.tint)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .fontWeight(.medium)
                                    Text(template.description ?? template.kind.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Button("使用") {
                                    onUse(template)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("从模板添加服务")
        }
        .frame(width: 560, height: 480)
    }
}
