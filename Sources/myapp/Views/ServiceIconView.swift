import SwiftUI
import ImageIO

struct ServiceIconView: View {
    let service: ManagedService
    var size: CGFloat = 24

    /// 图标缩略图缓存：原始 PNG 平均 1.7MB，SwiftUI 每次渲染都要解码+缩放（109 个 ≈ 2.7 秒，
    /// 每次列表重算 ≈ 800ms，这是搜索卡顿的根源）。这里缓存解码并缩放到 64px 的位图
    /// （约 7ms 重绘），同一图标只生成一次缩略图。
    private static let imageCache = NSCache<NSString, NSImage>()

    var body: some View {
        if let thumb = Self.thumbnail(for: service) {
            Image(nsImage: thumb)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: service.icon)
                .font(.system(size: size * 0.75))
                .foregroundStyle(.tint)
                .frame(width: size, height: size)
        }
    }

    /// 取图标缩略图：优先磁盘文件（icons/<id>.png，启动即加载），
    /// 兼容旧数据里仍内嵌在 JSON 的 appIconData（迁移后生成文件并清空）。
    private static func thumbnail(for service: ManagedService) -> NSImage? {
        let fileURL = Self.iconFileURL(for: service.id)
        if let data = try? Data(contentsOf: fileURL),
           let image = NSImage(data: data) {
            return image
        }
        if let embedded = service.appIconData,
           let thumb = makeThumbnail(embedded) {
            // 一次性迁移：写入磁盘文件，下次直接读文件
            if let png = pngData(from: thumb) {
                try? png.write(to: fileURL, options: .atomic)
            }
            return thumb
        }
        return nil
    }

    static func iconFileURL(for id: UUID) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("myapp/icons", isDirectory: true)
        return base.appendingPathComponent("\(id.uuidString).png")
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// 获取缓存的缩略图：内存 NSCache → 磁盘 PNG → 重新生成（写回磁盘）
    private static func cachedThumbnail(id: UUID, data: Data) -> NSImage? {
        let key = "\(id.uuidString)#\(data.count)" as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        // 磁盘缓存：缩略图跨启动复用，避免每次启动重新解码 109 个大图标（约 2 秒）
        if let diskImage = loadDiskThumbnail(key: key as String) {
            imageCache.setObject(diskImage, forKey: key)
            return diskImage
        }
        guard let thumb = makeThumbnail(data) else { return nil }
        imageCache.setObject(thumb, forKey: key)
        saveDiskThumbnail(thumb, key: key as String)
        return thumb
    }

    private static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("myapp/iconcache", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func diskURL(for key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).png")
    }

    private static func loadDiskThumbnail(key: String) -> NSImage? {
        let url = diskURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return NSImage(data: data)
    }

    private static func saveDiskThumbnail(_ image: NSImage, key: String) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: diskURL(for: key), options: .atomic)
    }

    /// 解码 PNG 并缩放为 64px 位图（Retina 2x 下 32pt 图标清晰）
    private static func makeThumbnail(_ data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 64,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: 32, height: 32))
    }
}
