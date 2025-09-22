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

import Combine
import CoreLocation
import SwiftUI

public protocol NBARPhotosViewAnchor {
  var id: Foundation.UUID { get }
  var altitude: CoreLocation.CLLocationDistance? { get }
  var coordinate: CoreLocation.CLLocationCoordinate2D { get }
  var course: CoreLocation.CLLocationDirection { get }
  var pixelHeight: Swift.Int? { get }
  var pixelWidth: Swift.Int? { get }
}

public protocol NBARPhotosViewDataModel : Combine.ObservableObject {
  var anchors: Swift.Array<NBARPhotosViewAnchor> { get }
  
  func cancelImageRequest(for id: Foundation.UUID)
  func placeholder(for anchor: NBARPhotosViewAnchor) -> UIKit.UIImage?
  func requestImage(for anchor: NBARPhotosViewAnchor, resultHandler: @escaping (UIKit.UIImage?, Swift.Error?) -> Swift.Void) -> Foundation.UUID?
}

public struct NBARPhotosView<DataModel> : SwiftUI.View where DataModel: NBARPhotosViewDataModel {
  private struct Control : SwiftUI.View {
    private struct Label : SwiftUI.View {
      private let text: Swift.String
      
      var body: some SwiftUI.View {
        SwiftUI.HStack {
          SwiftUI.Text(self.text)
          SwiftUI.Spacer()
        }
      }
      
      init(text: Swift.String) {
        self.text = text
      }
    }
    
    private struct Slider : SwiftUI.View {
      private let label: Swift.String
      private let value: SwiftUI.Binding<Swift.Double>
      
      var body: some SwiftUI.View {
        SwiftUI.VStack {
          SwiftUI.Slider(
            value: self.value,
            in: 0...100,
            step: 0.1
          )
          SwiftUI.HStack {
            SwiftUI.Text(
              self.label
            )
            SwiftUI.Spacer()
            SwiftUI.Text(
              Swift.String(format: "%.1f", self.value.wrappedValue)
            )
          }.foregroundColor(
            .accentColor
          )
        }
      }
      
      init(label: Swift.String, value: SwiftUI.Binding<Swift.Double>) {
        self.label = label
        self.value = value
      }
    }
    
    private let status: Swift.String
    private let transparency: SwiftUI.Binding<Swift.Double>
    private let height: SwiftUI.Binding<Swift.Double>
    private let altitude: SwiftUI.Binding<Swift.Double>
    
    var body: some SwiftUI.View {
      Group {
        SwiftUI.VStack {
          Self.Label(
            text: self.status
          )
          Self.Slider(
            label: "Transparency",
            value: self.transparency
          )
          Self.Slider(
            label: "Height",
            value: self.height
          )
          Self.Slider(
            label: "Altitude",
            value: self.altitude
          )
        }.padding()
      }.background(
        SwiftUI.Color(.systemBackground)
      ).opacity(
        0.75
      )
    }
    
    init(status: Swift.String, transparency: SwiftUI.Binding<Swift.Double>, height: SwiftUI.Binding<Swift.Double>, altitude: SwiftUI.Binding<Swift.Double>) {
      self.status = status
      self.transparency = transparency
      self.height = height
      self.altitude = altitude
    }
  }
  
  @SwiftUI.ObservedObject private var model: DataModel
  
  private let isEditing: Swift.Bool
  
  @SwiftUI.State private var status = ""
  @SwiftUI.State private var transparency = 50.0
  @SwiftUI.State private var height = 50.0
  @SwiftUI.State private var altitude = 50.0
  
  public var body: some SwiftUI.View {
    //  TODO: [2] ARCOACHINGOVERLAYVIEW
    SwiftUI.ZStack {
      NBARPhotosViewContainer(
        model: self.model,
        status: self.$status,
        transparency: self.$transparency,
        height: self.$height,
        altitude: self.$altitude
      )
      if self.isEditing {
        SwiftUI.VStack {
          SwiftUI.Spacer()
          Self.Control(
            status: self.status,
            transparency: self.$transparency,
            height: self.$height,
            altitude: self.$altitude
          )
        }
      }
    }
  }
  
  public init(model: DataModel, isEditing: Swift.Bool) {
    self.model = model
    self.isEditing = isEditing
  }
}
