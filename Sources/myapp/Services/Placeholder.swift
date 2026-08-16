import Foundation

enum Placeholder {
    /// 将 {key} 形式的占位符替换为 values 中的值；未提供的保留原样
    static func substitute(_ template: String, values: [String: String]) -> String {
        values.reduce(template) { partial, kv in
            partial.replacingOccurrences(of: "{\(kv.key)}", with: kv.value)
        }
    }
}
