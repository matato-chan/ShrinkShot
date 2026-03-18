import AppKit
import CoreGraphics

final class ImageCompressor {

    enum CompressionError: Error {
        case failedToLoadImage
        case failedToGetImageRep
        case failedToCreateContext
        case failedToGenerateData
        case failedToWrite
    }

    func compress(
        fileURL: URL,
        scalePercentage: Int,
        outputFormat: String,
        jpegQuality: Int
    ) throws {
        // 1. NSImage で読み込み
        guard let image = NSImage(contentsOf: fileURL) else {
            throw CompressionError.failedToLoadImage
        }

        // 2. 元サイズ取得（ピクセルサイズ）
        guard let bitmapRep = image.representations.first as? NSBitmapImageRep else {
            throw CompressionError.failedToGetImageRep
        }

        let originalWidth = bitmapRep.pixelsWide
        let originalHeight = bitmapRep.pixelsHigh

        // 3. スケーリング適用
        let scale = CGFloat(scalePercentage) / 100.0
        let newWidth = Int(CGFloat(originalWidth) * scale)
        let newHeight = Int(CGFloat(originalHeight) * scale)

        // 4. CGContext でリサイズ描画
        let colorSpace = bitmapRep.colorSpace.cgColorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        let hasAlpha = outputFormat == "png"
        let bitmapInfo: UInt32 = hasAlpha
            ? CGImageAlphaInfo.premultipliedLast.rawValue
            : CGImageAlphaInfo.noneSkipLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw CompressionError.failedToCreateContext
        }

        guard let cgImage = bitmapRep.cgImage else {
            throw CompressionError.failedToGetImageRep
        }

        context.interpolationQuality = CGInterpolationQuality.high
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
        )

        guard let resizedCGImage = context.makeImage() else {
            throw CompressionError.failedToCreateContext
        }

        // 5. フォーマットに応じて書き出し
        let resizedRep = NSBitmapImageRep(cgImage: resizedCGImage)
        let data: Data?

        if outputFormat == "jpeg" {
            let quality = CGFloat(jpegQuality) / 100.0
            data = resizedRep.representation(
                using: NSBitmapImageRep.FileType.jpeg,
                properties: [NSBitmapImageRep.PropertyKey.compressionFactor: quality]
            )
        } else {
            data = resizedRep.representation(
                using: NSBitmapImageRep.FileType.png,
                properties: [:]
            )
        }

        guard let outputData = data else {
            throw CompressionError.failedToGenerateData
        }

        // 6. 保存（元ファイル上書き or JPEG なら拡張子変更）
        let outputURL: URL
        if outputFormat == "jpeg" {
            outputURL = fileURL.deletingPathExtension().appendingPathExtension("jpg")
            // 元の .png を削除
            try? FileManager.default.removeItem(at: fileURL)
        } else {
            outputURL = fileURL
        }

        try outputData.write(to: outputURL, options: .atomic)
    }
}
