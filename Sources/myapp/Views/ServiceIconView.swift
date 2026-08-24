import SwiftUI

struct ServiceIconView: View {
    let service: ManagedService
    var size: CGFloat = 24

    /// 解码缓存：图标 PNG 平均 1.7MB，每次 body 重算都 NSImage(data:) 解码是列表卡顿的根源。
    /// 按「服务 id + 数据长度」做 key，同一图标只解码一次。
    private static let imageCache = NSCache<NSString, NSImage>()

    var body: some View {
        if let data = service.appIconData,
           let nsImage = Self.cachedImage(id: service.id, data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: service.icon)
                .font(.system(size: size * 0.75))
                .foregroundStyle(.tint)
                .frame(width: size, height: size)
        }
    }

    private static func cachedImage(id: UUID, data: Data) -> NSImage? {
        let key = "\(id.uuidString)#\(data.count)" as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(data: data) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }
}
