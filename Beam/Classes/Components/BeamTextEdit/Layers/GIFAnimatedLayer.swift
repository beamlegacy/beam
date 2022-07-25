//
//  GIFAnimatedLayer.swift
//  Beam
//
//  Created by Thomas on 22/07/2022.
//

import Foundation
import ImageIO

final class GIFAnimatedLayer: CALayer {
    private var imageSource: CGImageSource? = nil
    private var frameDurations: [TimeInterval] = []
    private var totalDuration = 0.0
    private var numberOfFrames = 0
    private var loopCount = 0
    @objc private var currentGIFFrameIndex = -1

    init?(data: Data) {
        let options: [AnyHashable: Any] = [kCGImageSourceShouldCache: false]

        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary),
              CGImageSourceGetCount(source) > 1 else {
            return nil
        }

        imageSource = source

        super.init()

        prepareImage()
    }

    override init(layer: Any) {
        if let layer = layer as? GIFAnimatedLayer {
            frameDurations = layer.frameDurations
            totalDuration = layer.totalDuration
            numberOfFrames = layer.numberOfFrames
            loopCount = layer.loopCount
            currentGIFFrameIndex = layer.currentGIFFrameIndex
        }
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override class func needsDisplay(forKey key: String) -> Bool {
        return key == "currentGIFFrameIndex"
    }

    override func display() {
        let index = presentation()?.currentGIFFrameIndex ?? 0
        guard index != -1 else { return }

        CATransaction.disableAnimations {
            contents = image(at: index)
        }
    }

    func startAnimating() {
        guard numberOfFrames > 0 else { return }

        stopAnimating()

        let animation = CAKeyframeAnimation(keyPath: "currentGIFFrameIndex")
        animation.calculationMode = .discrete
        animation.autoreverses = false
        animation.repeatCount = loopCount > 0 ? Float(loopCount) : Float.infinity

        var values: [Int] = []
        var keyTimes: [Double] = []

        values.reserveCapacity(numberOfFrames)
        keyTimes.reserveCapacity(numberOfFrames)

        values.append(0)
        keyTimes.append(0)

        for i in 1..<numberOfFrames {
            let duration = keyTimes[i-1] + frameDurations[i] / totalDuration
            values.append(i)
            keyTimes.append(duration)
        }

        animation.values = values
        animation.keyTimes = keyTimes.map { $0 as NSNumber }
        animation.duration = totalDuration

        add(animation, forKey: "GIFAnimation")
    }

    func stopAnimating() {
        removeAnimation(forKey: "GIFAnimation")
    }

    private func image(at index: Int) -> CGImage? {
        guard let imageSource = imageSource, index < numberOfFrames else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(imageSource, index, nil)
    }

    private func prepareImage() {
        guard let imageSource = imageSource else {
            return
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
        let size = size(from: properties)

        numberOfFrames = CGImageSourceGetCount(imageSource)
        loopCount = loopCount(from: properties)
        frame = CGRect(origin: .zero, size: size)

        frameDurations.reserveCapacity(numberOfFrames)

        for i in 0..<numberOfFrames {
            let delay = frameDelay(for: imageSource, at: i)
            frameDurations.append(delay)
            totalDuration += delay
        }

        CATransaction.disableAnimations {
            isOpaque = !hasAlpha(from: properties)
        }

        currentGIFFrameIndex = 0
        display()
    }

    private func size(from properties: CFDictionary?) -> CGSize {
        guard let properties = properties as NSDictionary?,
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return .zero
        }

        return CGSize(width: width.doubleValue, height: height.doubleValue).rounded()
    }

    private func loopCount(from properties: CFDictionary?) -> Int {
        guard let properties = properties as NSDictionary?,
              let loopCount = properties[kCGImagePropertyGIFLoopCount] as? NSNumber else {
            return 0
        }

        return loopCount.intValue
    }

    private func hasAlpha(from properties: CFDictionary?) -> Bool {
        guard let properties = properties as NSDictionary?,
              let hasAlpha = properties[kCGImagePropertyHasAlpha] as? NSNumber else {
            return false
        }

        return hasAlpha.boolValue
    }

    private func frameDelay(for imageSource: CGImageSource, at index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as NSDictionary?,
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? NSDictionary,
              let delayTime = gifProperties[kCGImagePropertyGIFDelayTime] as? NSNumber else {
            return 0.0
        }

        return delayTime.doubleValue
    }
}
