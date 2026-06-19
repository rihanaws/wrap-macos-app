import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
final class ImageAttachmentManager: ObservableObject {
    @Published var attachments: [ImageAttachment] = []
    @Published var lastError: String?

    func pickImages(maxCount: Int, visionSupported: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .gif]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            add(urls: Array(panel.urls.prefix(maxCount)), visionSupported: visionSupported)
        }
    }

    func add(urls: [URL], visionSupported: Bool) {
        for url in urls {
            do {
                attachments.append(try makeAttachment(url: url, visionSupported: visionSupported))
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func addFromPasteboard(visionSupported: Bool) {
        let pasteboard = NSPasteboard.general
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !fileURLs.isEmpty {
            add(urls: fileURLs, visionSupported: visionSupported)
            return
        }
        guard let image = NSImage(pasteboard: pasteboard),
              let data = jpegData(for: image, maxDimension: 2048),
              let thumbnail = jpegData(for: image, maxDimension: 120)
        else { return }
        attachments.append(
            ImageAttachment(
                fileName: "Clipboard.jpg",
                mimeType: "image/jpeg",
                data: data,
                thumbnailData: thumbnail,
                detectedVisionCompatible: visionSupported
            )
        )
    }

    func remove(_ id: UUID) {
        attachments.removeAll { $0.id == id }
    }

    private func makeAttachment(url: URL, visionSupported: Bool) throws -> ImageAttachment {
        guard let image = NSImage(contentsOf: url) else {
            throw NSError(domain: "WarpClone.ImageAttachment", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported image \(url.lastPathComponent)."])
        }
        guard let data = jpegData(for: image, maxDimension: 2048),
              let thumbnail = jpegData(for: image, maxDimension: 120)
        else {
            throw NSError(domain: "WarpClone.ImageAttachment", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode image \(url.lastPathComponent)."])
        }
        return ImageAttachment(
            fileName: url.lastPathComponent,
            mimeType: "image/jpeg",
            data: data,
            thumbnailData: thumbnail,
            detectedVisionCompatible: visionSupported
        )
    }

    private func jpegData(for image: NSImage, maxDimension: CGFloat) -> Data? {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let targetSize = NSSize(width: size.width * scale, height: size.height * scale)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        resized.unlockFocus()
        guard
            let tiff = resized.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}
