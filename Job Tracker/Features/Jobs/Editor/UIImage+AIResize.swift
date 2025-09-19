import UIKit

extension UIImage {
    /// Returns an image whose orientation is normalized and whose longest side does not exceed the given pixel cap.
    /// - Parameter maxDimension: The maximum length, in pixels, allowed for the longest side of the image.
    func aiFixingOrientationAndResizingIfNeeded(maxDimension: CGFloat = 2048) -> UIImage? {
        guard size.width > 0, size.height > 0, maxDimension > 0 else {
            return nil
        }

        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        let longestSide = max(pixelWidth, pixelHeight)
        let resizeRatio = longestSide > maxDimension ? maxDimension / longestSide : 1
        let needsOrientationNormalization = imageOrientation != .up

        if resizeRatio == 1 && !needsOrientationNormalization {
            return self
        }

        let targetSize = CGSize(width: size.width * resizeRatio, height: size.height * resizeRatio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(1, scale)
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
