# NBARKit 1.0

The `NBARPhotosView` can be used to display any photos with location metadata (latitude, longitude, and heading) in an AR space.

Clone the [NBARPhotos](https://github.com/vanvoorden/NBARPhotos) and [NBARRuscha](https://github.com/vanvoorden/NBARRuscha) projects to see sample implementations.

## Requirements

This framework requires Xcode 15.4 or later. The following device requirements apply:

* ARKit
* arm64
* GPS
* A12 Bionic and Later Chips
* Location Services
* iOS 14.0 or later

This framework requests location and camera access. Your app `Info.plist` must include the `NSLocationWhenInUseUsageDescription` and `NSCameraUsageDescription` keys.

The location data required to place photos is limited to specific areas supported by Apple. Reference the [ARGeoTrackingConfiguration](https://developer.apple.com/documentation/arkit/argeotrackingconfiguration) documentation before implemeting the `NBARPhotosView` in your location.    

## Known Issues

* Launching the app, loading photos in AR, backgrounding the app for a long period of time, and activating the app back to the foreground can cause the previously loaded photos to disappear. Reloading the `NBARPhotosViewDataModel.anchors` property should place them back in AR space correctly.

## License

Copyright 2021 North Bronson Software

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
