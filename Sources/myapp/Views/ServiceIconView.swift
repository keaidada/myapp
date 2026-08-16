import SwiftUI

struct ServiceIconView: View {
    let service: ManagedService
    var size: CGFloat = 24

    var body: some View {
        if let data = service.appIconData, let nsImage = NSImage(data: data) {
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
}
