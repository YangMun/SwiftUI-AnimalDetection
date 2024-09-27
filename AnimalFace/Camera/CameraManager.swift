import AVFoundation
import Vision
import UIKit
import VideoToolbox  // 이 줄을 추가합니다.

class CameraManager: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isRecognizing: Bool = false
    @Published var detectedFacesCount: Int = 0
    @Published var matchedAnimal: (String, Double)?
    
    let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    
    private var detectionRequest: VNDetectFaceRectanglesRequest?
    private var detectionSequenceHandler = VNSequenceRequestHandler()
    private let animalClassifier = AnimalClassifier()
    
    private var classificationResults: [(String, Double)] = []
    private let classificationThreshold = 10
    
    override init() {
        super.init()
        setupCaptureSession()
        setupVision()
    }
    
    private func setupVision() {
        detectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation] else { return }
            DispatchQueue.main.async {
                self?.detectedFacesCount = results.count
                self?.isRecognizing = results.count > 0
            }
        }
    }
    
    private func setupCaptureSession() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("전면 카메라를 찾을 수 없습니다.")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
        } catch {
            print("카메라 설정 중 오류 발생: \(error.localizedDescription)")
        }
    }
    
    func startSession() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        captureSession.stopRunning()
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func detectFaces(in image: CVPixelBuffer) {
        guard let request = detectionRequest else { return }
        do {
            try detectionSequenceHandler.perform([request], on: image, orientation: .right)
            
            if let results = request.results as? [VNFaceObservation], !results.isEmpty {
                if let cgImage = CGImage.create(from: image) {
                    // 얼굴 영역만 추출
                    if let faceImage = cropFaceImage(cgImage, observation: results[0]) {
                        classifyAnimal(for: faceImage)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.matchedAnimal = nil
                    self.classificationResults.removeAll()
                }
            }
        } catch {
            print("얼굴 감지 실패: \(error.localizedDescription)")
        }
    }
    
    private func cropFaceImage(_ image: CGImage, observation: VNFaceObservation) -> CGImage? {
        let faceRect = VNImageRectForNormalizedRect(observation.boundingBox, image.width, image.height)
        return image.cropping(to: faceRect)
    }
    
    private func classifyAnimal(for image: CGImage) {
        animalClassifier.classifyAnimal(for: image) { [weak self] animal, confidence in
            guard let self = self else { return }
            self.classificationResults.append((animal, confidence))
            
            if self.classificationResults.count >= self.classificationThreshold {
                let mostFrequentAnimal = self.getMostFrequentAnimal()
                DispatchQueue.main.async {
                    self.matchedAnimal = mostFrequentAnimal
                    self.classificationResults.removeAll()
                }
            }
        }
    }
    
    private func getMostFrequentAnimal() -> (String, Double) {
        let groupedResults = Dictionary(grouping: classificationResults, by: { $0.0 })
        let sortedResults = groupedResults.sorted { $0.value.count > $1.value.count }
        
        if let topResult = sortedResults.first {
            let averageConfidence = topResult.value.reduce(0.0) { $0 + $1.1 } / Double(topResult.value.count)
            return (topResult.key, averageConfidence)
        }
        
        return ("알 수 없음", 0.0)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("이미지 처리 중 오류 발생")
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}

extension CGImage {
    static func create(from cvPixelBuffer: CVPixelBuffer) -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(cvPixelBuffer, options: nil, imageOut: &cgImage)
        return cgImage
    }
}
