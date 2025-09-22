//
//  Copyright © 2021 North Bronson Software
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import ARKit
import Combine
import SwiftUI

private extension ARCamera.TrackingState {
  var status: String {
    switch (self) {
    case .notAvailable:
      return "Tracking is not available."
    case .limited(let reason):
      return "Tracking is limited." + "\n" + reason.status
    case .normal:
      return "Tracking is normal."
    }
  }
}

private extension ARCamera.TrackingState.Reason {
  var status: String {
    switch (self) {
    case .initializing:
      return "The AR session has not gathered enough camera or motion data to provide tracking information."
    case .relocalizing:
      return "The AR session is attempting to resume after an interruption."
    case .excessiveMotion:
      return "The device is moving too fast for accurate image-based position tracking."
    case .insufficientFeatures:
      return "The scene visible to the camera doesn't contain enough distinguishable features for image-based position tracking."
    default:
      return ""
    }
  }
}

private extension ARGeoTrackingStatus {
  var status: String {
    return self.state.status + "\n" + self.accuracy.status + "\n" + self.stateReason.status
  }
}

private extension ARGeoTrackingStatus.Accuracy {
  var status: String {
    switch (self) {
    case .undetermined:
      return "Geo-tracking accuracy is undetermined."
    case .low:
      return "Geo-tracking accuracy is low."
    case .medium:
      return "Geo-tracking accuracy is average."
    case .high:
      return "Geo-tracking accuracy is high."
    default:
      return ""
    }
  }
}

private extension ARGeoTrackingStatus.State {
  var status: String {
    switch (self) {
    case .notAvailable:
      return "Geo-tracking is not available."
    case .initializing:
      return "Geo-tracking is being initialized."
    case .localizing:
      return "Geo-tracking is attempting to localize against a Map."
    case .localized:
      return "Geo-tracking is localized."
    default:
      return ""
    }
  }
}

private extension ARGeoTrackingStatus.StateReason {
  var status: String {
    switch (self) {
    case .none:
      return "No issues reported."
    case .notAvailableAtLocation:
      return "Geo-tracking is not available at the location."
    case .needLocationPermissions:
      return "Geo-tracking needs location permissions from the user."
    case .worldTrackingUnstable:
      return "World tracking pose is not valid yet."
    case .waitingForLocation:
      return "Waiting for a location point that meets accuracy threshold before starting geo-tracking."
    case .waitingForAvailabilityCheck:
      return "Waiting for availability check on first location point to complete."
    case .geoDataNotLoaded:
      return "Geo-tracking data hasn't been downloaded yet."
    case .devicePointedTooLow:
      return "The device is pointed at an angle too far down to use geo-tracking."
    case .visualLocalizationFailed:
      return "Visual localization failed, but no errors were found in the input."
    default:
      return ""
    }
  }
}

private extension ARCamera {
  var translation: simd_float3 {
    return SIMD3<Float>(self.transform.columns.3.x, self.transform.columns.3.y, self.transform.columns.3.z)
  }
  
  func distanceSquaredFromPoint(point: simd_float3) -> Float {
    return simd_distance_squared(self.translation, point)
  }
}

private extension ARSession {
  func getGeoLocation(completionHandler: @escaping (simd_float3, CLLocationCoordinate2D, CLLocationDistance, Error?) -> Void) {
    if let translation = self.currentFrame?.camera.translation {
      self.getGeoLocation(forPoint: translation) { coordinate, altitude, error in
        completionHandler(translation, coordinate, altitude, error)
      }
    }
  }
}

private extension CGImage {
  func copyImage() -> CGImage? {
    if let cgContext = CGContext(
      data: nil,
      width: self.width,
      height: self.height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) {
      cgContext.draw(self, in: CGRect(x: 0, y: 0, width: self.width, height: self.height))
      return cgContext.makeImage()
    }
    return nil
  }
}

private extension CGRect {
  var simdCenter: simd_float2 {
    return simd_float2(Float(self.midX), Float(self.midY))
  }
}

private extension CGSize {
  var aspectRatio: CGFloat {
    return (self.width / self.height)
  }
}

private extension SCNMaterialProperty {
  var image: UIImage? {
    get {
      return self.contents as? UIImage
    }
    set(image) {
      self.contents = image
    }
  }
}

private extension SCNNode {
  var plane: SCNPlane? {
    get {
      return self.geometry as? SCNPlane
    }
    set(plane) {
      self.geometry = plane
    }
  }
}

private extension SCNSceneRenderer {
  func nodesInsidePointOfView() -> Array<SCNNode> {
    if let pointOfView = self.pointOfView {
      return self.nodesInsideFrustum(of: pointOfView)
    }
    return []
  }
}

private extension UIImage {
  var aspectRatio: CGFloat {
    return self.size.aspectRatio
  }
  
  func copyImage() -> UIImage? {
    if let cgImage = self.cgImage?.copyImage() {
      return UIImage(cgImage: cgImage)
    }
    return nil
  }
}

final private class NBARDictionary<Key, Value> where Key : Hashable {
  private var privateDictionary = Dictionary<Key, Value>()
  private let privateQueue: DispatchQueue
  
  var dictionary: Dictionary<Key, Value> {
    get {
      self.privateQueue.sync {
        return self.privateDictionary
      }
    }
    set(dictionary) {
      self.privateQueue.async(flags: [.barrier]) { [weak self] in
        self?.privateDictionary = dictionary
      }
    }
  }
  
  func object(forKey aKey: Key) -> Value? {
    self.privateQueue.sync { [weak self] in
      return self?.privateDictionary[aKey]
    }
  }
  
  func setObject(_ anObject: Value, forKey aKey: Key) {
    self.privateQueue.async(flags: [.barrier]) { [weak self] in
      self?.privateDictionary[aKey] = anObject
    }
  }
  
  func removeObject(forKey aKey: Key) {
    self.privateQueue.async(flags: [.barrier]) { [weak self] in
      self?.privateDictionary[aKey] = nil
    }
  }
  
  init(label: String) {
    self.privateQueue = DispatchQueue(label: label, attributes: [.concurrent])
  }
}

private struct NBARFocus {
  let id: UUID
  let timestamp: TimeInterval
}

private struct NBARFocusResult {
  //  TODO: [3] COMPARISON OPERATORS
  let distance: Float
  let dotProduct: Float
  let id: UUID
  let projectedPoint: SCNVector3
}

struct NBARPhotosViewContainer<DataModel> : UIViewRepresentable where DataModel: NBARPhotosViewDataModel {
  @ObservedObject private var model: DataModel
  
  private var status: Binding<String>
  private var transparency: Binding<Double>
  private var height: Binding<Double>
  private var altitude: Binding<Double>
  
  func makeCoordinator() -> Self.Coordinator {
    Self.Coordinator(self)
  }
  
  func makeUIView(context: Context) -> ARSCNView {
    
    let sceneView = ARSCNView(frame: .zero)
    
    context.coordinator.sceneView = sceneView
    
    sceneView.delegate = context.coordinator
    
    sceneView.session.delegate = context.coordinator
    
    if context.environment.scenePhase == .active {
      DispatchQueue.main.async {
        context.coordinator.run(sceneView)
      }
    }
    
    return sceneView
  }
  
  func updateUIView(_ sceneView: ARSCNView, context: Context) {
    switch (context.environment.scenePhase) {
    case .background:
      DispatchQueue.main.async {
        context.coordinator.pause(sceneView)
      }
      break
    case .inactive:
      DispatchQueue.main.async {
        context.coordinator.pause(sceneView)
      }
      break
    case .active:
      DispatchQueue.main.async {
        context.coordinator.run(sceneView)
      }
      break
    default:
      break
    }
    DispatchQueue.main.async {
      context.coordinator.updateUIView(sceneView)
    }
  }
  
  init(model: DataModel, status: Binding<Swift.String>, transparency: Binding<Swift.Double>, height: Binding<Swift.Double>, altitude: Binding<Swift.Double>) {
    self.model = model
    self.status = status
    self.transparency = transparency
    self.height = height
    self.altitude = altitude
  }
  
  final class Coordinator : NSObject, ARSCNViewDelegate, ARSessionDelegate {
    private static var FocusTime: Double {
      return 2.0    //  SECONDS
    }
    
    private static var Radius: Double {
      return 100.0  //  METERS
    }
    
    private let parent: NBARPhotosViewContainer
    
    weak var sceneView: ARSCNView?
    
    private var transparency: Double {
      return (self.parent.transparency.wrappedValue * 0.01)
    }
    
    private var height: Double {
      return (self.parent.height.wrappedValue * 0.10)
    }
    
    private var altitude: Double {
      return ((self.parent.altitude.wrappedValue - 50.0) * 0.10)
    }
    
    private var isCheckingAvailability = false
    private var isGettingGeoLocation = false
    private var isSessionRunning = false
    
    private var center: simd_float2?
    
    private var currentFocus: NBARFocus?
    private var nextFocus: NBARFocus?
    
    private var anchorsToPhotosAnchors = NBARDictionary<UUID, NBARPhotosViewAnchor>(label: "anchorsToPhotosAnchors")
    private var photosAnchorsToAnchors = Dictionary<UUID, ARAnchor>()
    private var photosAnchorsToImageRequests = Dictionary<UUID, UUID>()
    private var photosAnchorsToNodes = Dictionary<UUID, SCNNode>()
    private var photosAnchorsToOnscreenNodes = Dictionary<UUID, SCNNode>()
    
    private var subscriber: AnyCancellable?
    private var modelWillChange = false
    
    private var lastGeoLocationPoint: simd_float3?
    private var modelNeedsUpdate = false
    
    init(_ parent: NBARPhotosViewContainer) {
      self.parent = parent
    }
    
    func run(_ sceneView: ARSCNView) {
      if self.isSessionRunning == false {
        if ARGeoTrackingConfiguration.isSupported {
          if self.isCheckingAvailability == false {
            self.isCheckingAvailability = true
            //  TODO: [3] CONFIRM THIS ALL WORKS AFTER PAUSING
            ARGeoTrackingConfiguration.checkAvailability { [weak self] (available, error) in
              DispatchQueue.main.async { [weak self] in
                if let self = self {
                  self.isCheckingAvailability = false
                  if available {
                    self.isSessionRunning = true
                    
                    let configuration = ARGeoTrackingConfiguration()
                    if ARGeoTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
                      configuration.frameSemantics.insert(.personSegmentationWithDepth)
                    }
                    sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                    self.modelNeedsUpdate = true
                    self.updateModel()
                    
                    self.parent.status.wrappedValue = "Running new AR session."
                  } else {
                    self.parent.status.wrappedValue = "Geo-tracking Unavailable." + "\n" + "\(error?.localizedDescription ?? "")" + "\n" + "Please try again in an area where geo-tracking is supported."
                  }
                }
              }
            }
          }
        }
        else {
          self.parent.status.wrappedValue = "Unsupported Device." + "\n" + "Geo-tracking requires a device with A12 Bionic chip or later, and cellular (GPS) capability."
        }
      }
    }
    
    func pause(_ sceneView: ARSCNView) {
      if self.isSessionRunning == true {
        self.isSessionRunning = false
        
        self.lastGeoLocationPoint = nil
        
        self.currentFocus = nil
        self.nextFocus = nil
        
        for (id, anchor) in self.photosAnchorsToAnchors {
          if let request = self.photosAnchorsToImageRequests[id] {
            self.photosAnchorsToImageRequests[id] = nil
            self.parent.model.cancelImageRequest(for: request)
          }
          
          self.photosAnchorsToNodes[id] = nil
          self.photosAnchorsToOnscreenNodes[id] = nil
          
          self.anchorsToPhotosAnchors.removeObject(forKey: anchor.identifier)
          self.photosAnchorsToAnchors[id] = nil
          
          sceneView.session.remove(anchor: anchor)
        }
        
        sceneView.session.pause()
      }
    }
    
    func updateModel() {
      if self.modelWillChange == true || self.modelNeedsUpdate == true {
        if let geoTrackingStatus = self.sceneView?.session.currentFrame?.geoTrackingStatus,
           geoTrackingStatus.state == .localized,
           self.isGettingGeoLocation == false {
          self.isGettingGeoLocation = true
          
          let modelAnchors = self.parent.model.anchors
          
          var photosAnchorsToAdd = self.anchorsToPhotosAnchors.dictionary
          var anchorsToAdd = Dictionary<UUID, ARAnchor>()
          var anchorsToRemove = self.photosAnchorsToAnchors
          
          self.sceneView?.session.getGeoLocation { [weak self] point, coordinate, altitude, error in
            DispatchQueue.global().async { [weak self] in
              if CLLocationCoordinate2DIsValid(coordinate) {
                //  SUCCESS
                
                //  TODO: [3] WHAT ABOUT ALTITUDE?
                let cameraLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                
                for photosAnchor in modelAnchors {
                  let photosAnchorLocation = CLLocation(latitude: photosAnchor.coordinate.latitude, longitude: photosAnchor.coordinate.longitude)
                  if photosAnchorLocation.distance(from: cameraLocation) < Self.Radius {
                    //  NEAR ANCHORS
                    if anchorsToRemove[photosAnchor.id] == nil {
                      let anchor = ARGeoAnchor(coordinate: photosAnchor.coordinate, altitude: photosAnchor.altitude)
                      photosAnchorsToAdd[anchor.identifier] = photosAnchor
                      anchorsToAdd[photosAnchor.id] = anchor
                    } else {
                      anchorsToRemove[photosAnchor.id] = nil
                    }
                  }
                }
                
                DispatchQueue.main.async { [weak self] in
                  if let self = self {
                    self.modelWillChange = false
                    self.modelNeedsUpdate = false
                    self.isGettingGeoLocation = false
                    
                    self.lastGeoLocationPoint = point
                    
                    self.anchorsToPhotosAnchors.dictionary = photosAnchorsToAdd
                    
                    for (id, anchor) in anchorsToAdd {
                      //  NEW ANCHORS
                      self.photosAnchorsToAnchors[id] = anchor
                      self.sceneView?.session.add(anchor: anchor)
                    }
                    
                    for (_, anchor) in anchorsToRemove {
                      //  FAR ANCHORS
                      self.sceneView?.session.remove(anchor: anchor)
                    }
                  }
                }
              } else {
                //  FAILURE
                self?.isGettingGeoLocation = false
              }
            }
          }
        }
      }
    }
    
    func updateUIView(_ sceneView: ARSCNView) {
      self.center = sceneView.bounds.simdCenter
      
      if self.subscriber == nil {
        self.modelWillChange = true
        self.subscriber = self.parent.model.objectWillChange.sink { [weak self] _ in
          self?.modelWillChange = true
        }
      }
      
      self.updateModel()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
      if let photosAnchor = self.anchorsToPhotosAnchors.object(forKey: anchor.identifier) {
        let plane = SCNPlane(width: 0, height: 0)
        plane.firstMaterial?.lightingModel = .constant
        plane.firstMaterial?.transparency = 0
        let childNode = SCNNode(geometry: plane)
        //  CORE LOCATION MEASURES CLOCKWISE
        //  WE WANT COUNTER CLOCKWISE
        let radians = (((photosAnchor.course / 180.0) * Double.pi) * -1.0)
        childNode.eulerAngles = SCNVector3(0, radians, 0)
        childNode.position = SCNVector3(0, Float(0), 0)
        node.addChildNode(childNode)
        
        DispatchQueue.main.async { [weak self] in
          self?.photosAnchorsToNodes[photosAnchor.id] = childNode
        }
      }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
      if let photosAnchor = self.anchorsToPhotosAnchors.object(forKey: anchor.identifier) {
        DispatchQueue.main.async { [weak self] in
          if let self = self {
            if let request = self.photosAnchorsToImageRequests[photosAnchor.id] {
              self.photosAnchorsToImageRequests[photosAnchor.id] = nil
              self.parent.model.cancelImageRequest(for: request)
            }
            
            self.photosAnchorsToNodes[photosAnchor.id] = nil
            self.photosAnchorsToOnscreenNodes[photosAnchor.id] = nil
            
            if let currentFocus = self.currentFocus,
               currentFocus.id == photosAnchor.id {
              self.currentFocus = nil
              self.nextFocus = nil
            }
          }
        }
      }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
      let anchorsToPhotosAnchors = self.anchorsToPhotosAnchors.dictionary
      var photosAnchorsToPreviousOnscreenNodes = self.photosAnchorsToOnscreenNodes
      var photosAnchorsToCurrentOnscreenNodes = Dictionary<UUID, SCNNode>()
      var photosAnchors = Dictionary<UUID, NBARPhotosViewAnchor>()
      
      func findOnscreenNodes() {
        for node in self.sceneView?.nodesInsidePointOfView() ?? [] {
          if let anchor = self.sceneView?.anchor(for: node),
             let photosAnchor = anchorsToPhotosAnchors[anchor.identifier] {
            if let childNode = photosAnchorsToPreviousOnscreenNodes[photosAnchor.id] {
              //  PREVIOUSLY VISIBLE
              photosAnchorsToPreviousOnscreenNodes[photosAnchor.id] = nil
              photosAnchorsToCurrentOnscreenNodes[photosAnchor.id] = childNode
              photosAnchors[photosAnchor.id] = photosAnchor
            } else {
              if let childNode = self.photosAnchorsToNodes[photosAnchor.id] {
                //  NOT PREVIOUSLY VISIBLE
                photosAnchorsToCurrentOnscreenNodes[photosAnchor.id] = childNode
                photosAnchors[photosAnchor.id] = photosAnchor
              }
            }
          }
        }
      }
      
      func updateOffscreenNodes() {
        for (id, childNode) in photosAnchorsToPreviousOnscreenNodes {
          if let request = self.photosAnchorsToImageRequests[id] {
            self.photosAnchorsToImageRequests[id] = nil
            self.parent.model.cancelImageRequest(for: request)
          }
          
          childNode.plane?.firstMaterial?.diffuse.image = nil
          childNode.plane?.width = 0
          childNode.plane?.height = 0
          
          if let currentFocus = self.currentFocus,
             currentFocus.id == id {
            self.currentFocus = nil
            self.nextFocus = nil
          }
        }
      }
      
      func replaceOnscreenNodes() {
        self.photosAnchorsToOnscreenNodes = photosAnchorsToCurrentOnscreenNodes
      }
      
      func updateFocus() {
        if photosAnchorsToCurrentOnscreenNodes.count != 0 {
          if photosAnchorsToCurrentOnscreenNodes.count != 1 {
            //  TODO: [3] KEEP IMPROVING
            var closestDistanceToCenterOfView: NBARFocusResult?
            var largestDotProductFromPointOfView: NBARFocusResult?
            var closestDistanceToCameraNearPlane: NBARFocusResult?
            for (id, childNode) in photosAnchorsToCurrentOnscreenNodes {
              if let projectedPoint = self.sceneView?.projectPoint(childNode.worldPosition),
                 let center = self.center {
                let point = simd_float2(projectedPoint.x, projectedPoint.y)
                let distance = simd_distance_squared(center, point)
                if let pointOfView = self.sceneView?.pointOfView {
                  let dotProduct = simd_dot(pointOfView.simdWorldFront, childNode.simdWorldFront)
                  //  LOOK FOR CLOSEST DISTANCE TO CENTER OF VIEW
                  if closestDistanceToCenterOfView == nil || distance < closestDistanceToCenterOfView!.distance {
                    closestDistanceToCenterOfView = NBARFocusResult(distance: distance, dotProduct: dotProduct, id: id, projectedPoint: projectedPoint)
                  }
                  //  LOOK FOR LARGEST DOT PRODUCT FROM POINT OF VIEW
                  if largestDotProductFromPointOfView == nil || largestDotProductFromPointOfView!.dotProduct < dotProduct {
                    largestDotProductFromPointOfView = NBARFocusResult(distance: distance, dotProduct: dotProduct, id: id, projectedPoint: projectedPoint)
                  }
                  //  LOOK FOR CLOSEST DISTANCE TO CAMERA NEAR PLANE
                  if closestDistanceToCameraNearPlane == nil || projectedPoint.z < closestDistanceToCameraNearPlane!.projectedPoint.z {
                    closestDistanceToCameraNearPlane = NBARFocusResult(distance: distance, dotProduct: dotProduct, id: id, projectedPoint: projectedPoint)
                  }
                }
              }
            }
            
            var focusID: UUID?
            if let closestDistanceToCenterOfView = closestDistanceToCenterOfView,
               let largestDotProductFromPointOfView = largestDotProductFromPointOfView,
               let closestDistanceToCameraNearPlane = closestDistanceToCameraNearPlane {
              if closestDistanceToCenterOfView.id == largestDotProductFromPointOfView.id,
                 largestDotProductFromPointOfView.id == closestDistanceToCameraNearPlane.id {
                focusID = largestDotProductFromPointOfView.id
              } else {
                if closestDistanceToCenterOfView.id == largestDotProductFromPointOfView.id {
                  focusID = largestDotProductFromPointOfView.id
                } else {
                  if largestDotProductFromPointOfView.id == closestDistanceToCameraNearPlane.id {
                    focusID = largestDotProductFromPointOfView.id
                  } else {
                    if closestDistanceToCenterOfView.id == closestDistanceToCameraNearPlane.id {
                      if closestDistanceToCenterOfView.dotProduct + 0.5 < largestDotProductFromPointOfView.dotProduct {
                        focusID = largestDotProductFromPointOfView.id
                      } else {
                        focusID = closestDistanceToCenterOfView.id
                      }
                    } else {
                      if closestDistanceToCenterOfView.dotProduct + 0.5 < largestDotProductFromPointOfView.dotProduct,
                         closestDistanceToCameraNearPlane.dotProduct + 0.5 < largestDotProductFromPointOfView.dotProduct {
                        focusID = largestDotProductFromPointOfView.id
                      } else {
                        if closestDistanceToCenterOfView.dotProduct + 0.5 < largestDotProductFromPointOfView.dotProduct {
                          focusID = closestDistanceToCameraNearPlane.id
                        } else {
                          if closestDistanceToCameraNearPlane.dotProduct + 0.5 < largestDotProductFromPointOfView.dotProduct {
                            focusID = closestDistanceToCenterOfView.id
                          } else {
                            focusID = largestDotProductFromPointOfView.id
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            
            if let focusID = focusID {
              if self.currentFocus == nil {
                self.currentFocus = NBARFocus(id: focusID, timestamp: frame.timestamp)
                self.nextFocus = nil
              } else {
                if self.currentFocus!.id == focusID {
                  self.currentFocus = NBARFocus(id: focusID, timestamp: frame.timestamp)
                  self.nextFocus = nil
                } else {
                  if self.nextFocus == nil {
                    self.nextFocus = NBARFocus(id: focusID, timestamp: frame.timestamp)
                  } else {
                    if self.nextFocus!.id == focusID {
                      if self.nextFocus!.timestamp + Self.FocusTime < frame.timestamp {
                        self.currentFocus = NBARFocus(id: focusID, timestamp: frame.timestamp)
                        self.nextFocus = nil
                      }
                    } else {
                      self.nextFocus = NBARFocus(id: focusID, timestamp: frame.timestamp)
                    }
                  }
                }
              }
            }
          } else {
            for (id, _) in photosAnchorsToCurrentOnscreenNodes {
              self.currentFocus = NBARFocus(id: id, timestamp: frame.timestamp)
              self.nextFocus = nil
            }
          }
        }
      }
      
      func updateOnscreenNodes() {
        for (id, childNode) in photosAnchorsToCurrentOnscreenNodes {
          if let currentFocus = self.currentFocus,
             currentFocus.id == id {
            //  FOCUSED
            childNode.plane?.firstMaterial?.transparency = CGFloat(self.transparency)
            
            childNode.position = SCNVector3(0, Float(self.altitude), 0)
            
            //  TODO: [3] SOMETHING MORE ROBUST THAN DIFFUSE IMAGE
            if let image = childNode.plane?.firstMaterial?.diffuse.image {
              childNode.plane?.width = CGFloat(self.height) * image.aspectRatio
              childNode.plane?.height = CGFloat(self.height)
            } else {
              if let photosAnchor = photosAnchors[id] {
                if let placeholder = self.parent.model.placeholder(for: photosAnchor) {
                  childNode.plane?.firstMaterial?.diffuse.image = placeholder.copyImage()
                  childNode.plane?.width = CGFloat(self.height) * placeholder.aspectRatio
                  childNode.plane?.height = CGFloat(self.height)
                } else {
                  if let pixelWidth = photosAnchor.pixelWidth,
                     let pixelHeight = photosAnchor.pixelHeight {
                    childNode.plane?.width = CGFloat(self.height) * (CGFloat(pixelWidth) / CGFloat(pixelHeight))
                    childNode.plane?.height = CGFloat(self.height)
                  }
                }
                
                if self.photosAnchorsToImageRequests[id] == nil {
                  self.photosAnchorsToImageRequests[id] = self.parent.model.requestImage(for: photosAnchor) { [weak self] result, info in
                    if let image = result {
                      if let self = self {
                        self.photosAnchorsToImageRequests[id] = nil
                        if let childNode = self.photosAnchorsToOnscreenNodes[id] {
                          childNode.plane?.firstMaterial?.diffuse.image = image.copyImage()
                          childNode.plane?.width = CGFloat(self.height) * image.aspectRatio
                          childNode.plane?.height = CGFloat(self.height)
                        }
                      }
                    } else {
                      //  TODO: [3] WHAT ABOUT A MISSING IMAGE?
                    }
                  }
                }
              }
            }
          } else {
            //  NOT FOCUSED
            childNode.plane?.firstMaterial?.transparency = CGFloat(0)
          }
        }
      }
      
      func updateGeoLocation() {
        if let lastGeoLocationPoint = self.lastGeoLocationPoint {
          let threshold = (Float(Self.Radius * 0.5) * Float(Self.Radius * 0.5))
          if threshold < frame.camera.distanceSquaredFromPoint(point: lastGeoLocationPoint) {
            self.modelNeedsUpdate = true
            self.updateModel()
          }
        }
      }
      
      findOnscreenNodes()
      updateOffscreenNodes()
      replaceOnscreenNodes()
      updateFocus()
      updateOnscreenNodes()
      updateGeoLocation()
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
      
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
      
    }
    
    func session(_ session: ARSession, didRemove anchors: Array<ARAnchor>) {
      for anchor in anchors {
        if let photosAnchor = self.anchorsToPhotosAnchors.object(forKey: anchor.identifier) {
          self.anchorsToPhotosAnchors.removeObject(forKey: anchor.identifier)
          self.photosAnchorsToAnchors[photosAnchor.id] = nil
        }
      }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
      if let error = error as NSError? {
        let messages = [
          "The AR session failed.",
          error.localizedDescription,
          error.localizedFailureReason,
          error.localizedRecoverySuggestion
        ]
        self.parent.status.wrappedValue = messages.compactMap({ $0 }).joined(separator: "\n")
      } else {
        self.parent.status.wrappedValue = "The AR session failed."
      }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
      self.parent.status.wrappedValue = camera.trackingState.status
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
      
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
      
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
      return false
    }
    
    func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
      
    }
    
    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData) {
      
    }
    
    func session(_ session: ARSession, didChange geoTrackingStatus: ARGeoTrackingStatus) {
      self.parent.status.wrappedValue = geoTrackingStatus.status
      self.updateModel()
    }
  }
}
