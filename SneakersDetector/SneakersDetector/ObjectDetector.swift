//
//  ObjectDetector.swift
//  SneakersDetector
//
//  Created by Andre Montenegro on 06/04/2018.
//

import Foundation
import Vision
import UIKit

//We could have a model outputting Float values instead. Hence the usage of these typealias.

///Confidence is a fractional value between 0 and 1.
typealias Confidence = Double
///BoxCoordinate can be the value for x, y, width or height.
typealias BoxCoordinate = Double

protocol ObjectDetectorDelegate: class {

    func didReceive(predictions: [ObjectDetector.Prediction])
    func didFailPrediction(withError error: Error)
}

// MARK:- Exercise Tips
//1. Search for "Mark:- Step". You should find 9 steps to complete. None of these steps should be skipped.
//2. Make sure it compiles every time you finish a step.
//3. The comments in the code and Apple's documentation are a great help to understand the needed concepts
//4. The app works in 3 different modes that can be selected in the ```AppDelegate.swift```. Use the staticImages mode at first and then, once your app starts to present correct bounding boxes, try the liveCamera with a real device ;)

enum ObjectDetectorError: Error {

    case generic

    var localizedDescription: String {

        switch self {
        case .generic:
            return "Generic Error"
        }
    }
}

class ObjectDetector {

    struct Prediction {

        let classIndex: Int
        let confidence: Confidence
        let boundingBox: CGRect //normalized rect (all coordinates in [0,1])
    }

    weak var delegate: ObjectDetectorDelegate?

    var confidenceThreshold: Confidence = 0.2
    var maxNumberOfPredictions = 10

    var detectionRequest: VNCoreMLRequest?

    var predictionQueue = DispatchQueue(label: "prediction.queue", qos: .userInitiated)

    let model: MLModel
    let throttler = Throttler()

    init(model: MLModel) {

        self.model = model

        setupDetectionRequest()
    }

    func setupDetectionRequest() {

        do {

            // VNCoreMLModel is the Vision object that wraps a CoreML model.
            let visionModel = try VNCoreMLModel(for: model)

            // MARK:- Step 2 - Vision API - Detection request
            // Create the detection request by passing the visionModel and self.handleDetection as arguments. self.handleDetection is already implemented below, so you just need to pass it as an argument.
            // Note: The detection request should be a VNCoreMLRequest. Vision has other types of requests used for built-in features such as detections of faces, barcodes, etc. However, VNCoreMLRequest is the one to be used when we want to perform predictions in CoreML models. The results are passed to the completionHandler passed in the initialization.

            //detectionRequest = <#initialize here#>
            detectionRequest?.imageCropAndScaleOption = .scaleFill

        } catch {

            print("did fail creating detection request: \(error)")
        }
    }

    func predict(cgImage: CGImage) {

        predictionQueue.async {

            self.predict(requestHandler: VNImageRequestHandler(cgImage: cgImage))
        }
    }

    ///Executes the request to predict for the given pixelBuffer. A throttlingInterval might be passed to avoid unneeded calls to the model.
    func predict(pixelBuffer: CVPixelBuffer, throttlingInterval: TimeInterval?) {

        if let throttlingInterval = throttlingInterval {

            throttler.async(to: predictionQueue, interval: throttlingInterval) {

                self.predict(requestHandler: VNImageRequestHandler(cvPixelBuffer: pixelBuffer))
            }

        } else {

            predictionQueue.async {

                self.predict(requestHandler: VNImageRequestHandler(cvPixelBuffer: pixelBuffer))
            }
        }
    }
}

fileprivate extension ObjectDetector {

    func predict(requestHandler: VNImageRequestHandler) {

        guard let detectionRequest = self.detectionRequest else {

            self.delegate?.didFailPrediction(withError: ObjectDetectorError.generic)
            return
        }

        do {

            try requestHandler.perform([detectionRequest])

        } catch {

            self.delegate?.didFailPrediction(withError: ObjectDetectorError.generic)
        }
    }

    func handleDetection(for request: VNRequest, error: Error?) {

        if let predictionError = error {

            print("did fail prediction with error \(predictionError.localizedDescription)")
            self.delegate?.didFailPrediction(withError: predictionError)
        }

        // MARK:- Step 3 - Send results to delegate
        // Get the results from the request object. They should be casted to VNCoreMLFeatureValueObservation.
        // Create the predictions using self.predictions(from:confidenceThreshold:maxCount:) and send them to the ObjectDetectorDelegate.
    }

    func predictions(from features: [VNCoreMLFeatureValueObservation],
                     confidenceThreshold: Confidence,
                     maxCount: Int) -> [Prediction]? {

        guard let boxesArray = features[0].featureValue.multiArrayValue,
            let confidencesArray = features[1].featureValue.multiArrayValue else {

                return nil
        }

        print("Boxes Array: " + String(describing: boxesArray))
        print("Confidences Array: " + String(describing: confidencesArray))

        var unorderedPredictions = [Prediction]()

        let confidencesCount = confidencesArray.shape[0].intValue
        let classesCount = confidencesArray.shape[1].intValue
        let confidencesPointer = confidencesArray.dataPointer.bindMemory(to: Confidence.self, capacity: confidencesCount)

        // MARK:- Step 4 - Understanding MLMultiArray - shape
        // Use shape property to get the number of boxes outputted by or model. You can check the example of the confidencesCount definition. After implementing boxesCount you can uncomment the definition of the boxesPointer
        let boxesCount = 0 //<#implement here#>

        let boxesPointer = boxesArray.dataPointer.bindMemory(to: BoxCoordinate.self, capacity: boxesCount)

        // MARK:- Step 5 - Understanding MLMultiArray - stride
        // Use stride property to properly infer the number of elements that compose the box.
        let boxesStride = 0 // <#implement here#>

        for boxIdx in 0..<boxesCount {

            //get the class with the highest confidence. In our case there is only one so bestClassIdx will always be the same
            var bestConfidence = 0.0
            var bestClassIdx = 0
            for classIdx in 0..<classesCount {

                let confidence = confidencesPointer[boxIdx * classesCount + classIdx]

                if confidence > bestConfidence {

                    bestConfidence = confidence
                    bestClassIdx = classIdx
                }
            }

            //we will only return a prediction if its confidence is > confidenceThreshold
            if bestConfidence > confidenceThreshold {

                // MARK:- Step 6 - Understanding bounding box
                // After Step 5 you can uncomment the code related to bounding box creation.
                // Take a time to understand how the bounding box properties are being accessed with the pointer. Also uncomment the boundingBox definition.

                //create the bounding box
                //            let x = boxesPointer[boxIdx * boxesStride]
                //            let y = boxesPointer[boxIdx * boxesStride + 1]
                //            let width = boxesPointer[boxIdx * boxesStride + 2]
                //            let height = boxesPointer[boxIdx * boxesStride + 3]

                //create the normalized rect with its origin
                //            let boundingBox = ObjectDetector.rectFromBoxCoordinates(x: x, y: y, width: width, height: height)


                // MARK:- Step 7 - Create and append prediction to be returned
                // Create the prediction and add it to unorderedPredictions. After this step, you should be able to see green bounding boxes on top of the images.
            }
        }

        // MARK:- Step 8 - Sort results
        // We should sort the unorderedPredictions by confidence before returning.

        // MARK:- Step 9 - Return results capped to maximum number
        // Return the ordered predictions capped to the maxCount given as argument. Currently we are returning unorderedPredictions. But we should instead return orderedPredictions

        // MARK:- Bonus Step (or Homework) - Implement NMS algorithm
        // You can try to apply Non-maximum suppression to return just the boxes with the highest confidence for each object. Implement predictionsAfterNMS(threshold:) in NonMaximumSuppresion.swift

        return unorderedPredictions
    }
}

fileprivate extension ObjectDetector {

    ///Transforms the given bounding box coordinates to a CGRect. From the given x and y that correspond to the center of the box, we create a CGRect with the actual origin point of the box.
    static func rectFromBoxCoordinates(x: BoxCoordinate,
                                       y: BoxCoordinate,
                                       width: BoxCoordinate,
                                       height: BoxCoordinate) -> CGRect {

        let origin = CGPoint(x: CGFloat(x - width / 2), y: CGFloat(y - height / 2))
        let size = CGSize(width: CGFloat(width), height: CGFloat(height))

        return CGRect(origin: origin, size: size)
    }
}
