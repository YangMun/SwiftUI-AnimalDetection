import Vision
import CoreImage
import CoreML

class AnimalClassifier {
    private var model: VNCoreMLModel
    
    init() {
        do {
            let configuration = MLModelConfiguration()
            let animals = try Animals(configuration: configuration)
            model = try VNCoreMLModel(for: animals.model)
        } catch {
            fatalError("ML 모델 로드 실패: \(error)")
        }
    }
    
    func classifyAnimal(for image: CGImage, completion: @escaping (String, Double) -> Void) {
        guard let resizedImage = resizeImage(image, to: CGSize(width: 224, height: 224)),
              let pixelBuffer = resizedImage.toPixelBuffer(width: 224, height: 224) else {
            completion("알 수 없음", 0.0)
            return
        }

        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNClassificationObservation],
                  let topResult = results.first else {
                completion("알 수 없음", 0.0)
                return
            }
            let confidence = Double(topResult.confidence) * 100
            completion(topResult.identifier, confidence)
        }
        
        request.imageCropAndScaleOption = .scaleFit
        
        let handler = VNImageRequestHandler(ciImage: CIImage(cgImage: resizedImage), options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("이미지 분류 실패: \(error)")
            completion("알 수 없음", 0.0)
        }
    }
    
    private func resizeImage(_ image: CGImage, to size: CGSize) -> CGImage? {
        let context = CGContext(data: nil,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(origin: .zero, size: size))
        
        return context?.makeImage()
    }
}

extension CGImage {
    func toPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                          kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32ARGB,
                                         attributes,
                                         &pixelBuffer)
        
        guard let buffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}
