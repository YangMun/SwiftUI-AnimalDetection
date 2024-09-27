import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            CameraView(cameraManager: cameraManager)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                if cameraManager.isRecognizing, let (animal, confidence) = cameraManager.matchedAnimal {
                    Text("당신과 닮은 동물: \(animal)")
                        .padding()
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    
                    Text("닮은 정도: \(String(format: "%.1f", confidence))%")
                        .padding()
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 10)
                }
                
                Text(cameraManager.isRecognizing ? "얼굴 인식 중: \(cameraManager.detectedFacesCount)명" : "얼굴을 찾는 중...")
                    .padding()
                    .background(cameraManager.isRecognizing ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}
