import UIKit
import CoreMotion
import CoreML


public class RTClassifier: NSObject {
    //meta parameters
    var motionManager = CMMotionManager()
    var data: Dictionary<String, Participant> = Dictionary<String, Participant>()
    let knn: KNNDTW_3D = KNNDTW_3D()
    
    var accX = Array<Float>()
    var accY = Array<Float>()
    var accZ = Array<Float>()
    var gyrX = Array<Float>()
    var gyrY = Array<Float>()
    var gyrZ = Array<Float>()
    
    struct ModelConstants {
        static let numOfFeatures = 6
        static let predictionWindowSize = 50
        static let sensorsUpdateInterval = 1.0 / 20.0
        static let hiddenInLength = 200
        static let hiddenCellInLength = 200
    }
    //internal data structures
    
    func configure() {
        self.data = Helper.createDataDict(path: "data_csv")
        let participants = ["P5", "P1", "P12", "P11", "P7", "P6", "P2", "P8", "P4", "P3", "P9", "P10"]
        var training_samples: [knn_curve_label_pair_3d] = [knn_curve_label_pair_3d]()
        
        // add training data
        for participantString in participants {
            let participant = data[participantString]
            
            var sampleMap = [String : Array<Sample>]()
            sampleMap["left"] = participant!.leftSamples
            sampleMap["right"] = participant!.rightSamples
            sampleMap["front"] = participant!.frontSamples
            
            for (label, samples) in sampleMap {
                for sample in samples {
                    if sample.number <= 8 {
                        training_samples.append(knn_curve_label_pair_3d(curveAccX: sample.accX, curveAccY: sample.accY, curveAccZ: sample.accZ , curveGyrX: sample.gyrX,curveGyrY: sample.gyrY, curveGyrZ: sample.gyrZ, label: label))
                    }
                }
            }
        }
        
        self.knn.configure(neighbors: 3, max_warp: 0) //max_warp isn't implemented yet
        self.knn.train(data_sets: training_samples)
    }
    
    public func run() {
        var currentIndexInPredictionWindow = 0
//        let predictionWindowDataArray = try? MLMultiArray(shape: [1 , ModelConstants.predictionWindowSize , ModelConstants.numOfFeatures] as [NSNumber], dataType: MLMultiArrayDataType.double)
        
        if motionManager.isAccelerometerAvailable && motionManager.isGyroAvailable {
            print("ALL GOOD")
        } else {
            print("Something wrong")
        }
        
        motionManager.accelerometerUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        motionManager.gyroUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        
        motionManager.startAccelerometerUpdates(to: OperationQueue.main) { accelerometerData, error in
            guard let accelerometerData = accelerometerData else { return }
            // Add the current data sample to the data array
            addAccelSampleToDataArray(accelSample: accelerometerData)
        }
        
        motionManager.startGyroUpdates(to: OperationQueue.main) { gyroscopeData, error in
            guard let gyroscopeData = gyroscopeData else { return }
            // Add the current data sample to the data array
            addGyroSampleToDataArray(gyroSample: gyroscopeData)
        }
        
        func addGyroSampleToDataArray (gyroSample: CMGyroData) {
            // Add the current gyro reading to the data array
            gyrX.append(Float(gyroSample.rotationRate.x))
            gyrY.append(Float(gyroSample.rotationRate.y))
            gyrZ.append(Float(gyroSample.rotationRate.z))
        }
        
        
        func addAccelSampleToDataArray (accelSample: CMAccelerometerData) {
            // Add the current accelerometer reading to the data array
            accX.append(Float(accelSample.acceleration.x))
            accY.append(Float(accelSample.acceleration.y))
            accZ.append(Float(accelSample.acceleration.z))
            
            // Update the index in the prediction window data array
            currentIndexInPredictionWindow += 1
            
            // If the data array is full, call the prediction method to get a new model prediction.
            // We assume here for simplicity that the Gyro data was added to the data array as well.
            if (currentIndexInPredictionWindow == ModelConstants.predictionWindowSize) {
                let predictedActivity = performModelPrediction() ?? "N/A"
                
                // Use the predicted activity here
                print(predictedActivity)
                
                // Start a new prediction window
                currentIndexInPredictionWindow = 0
                accX = Array<Float>()
                accY = Array<Float>()
                accZ = Array<Float>()
                gyrX = Array<Float>()
                gyrY = Array<Float>()
                gyrZ = Array<Float>()

            }
        }
        
        func performModelPrediction () -> String? {
            // Perform model prediction
            let prediction: knn_certainty_label_pair_3d = knn.predict(curveToTestAccX: accX, curveToTestAccY: accY, curveToTestAccZ: accZ, curveToTestGyrX: gyrX, curveToTestGyrY: gyrY, curveToTestGyrZ: gyrZ)
            print("predicted " + prediction.label, "with ", prediction.probability*100,"% certainty")
            return prediction.label
        }
    }
}
