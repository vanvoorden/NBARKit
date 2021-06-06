# NBARKit 0.1

The `NBARPhotosView` can be used to display any photos with location metadata (latitude, longitude, and heading) in an AR space.

Clone the [NBARPhotos](https://github.com/vanvoorden/NBARPhotos) and [NBARRuscha](https://github.com/vanvoorden/NBARRuscha) projects to see sample implementations.

## Requirements

This framework requires Xcode 12.5 or later. The following device requirements apply:

* ARKit
* arm64
* GPS
* A12 Bionic and Later Chips
* Location Services
* iOS 14.0 or later

This framework requests location and camera access. Your app `Info.plist` must include the `NSLocationWhenInUseUsageDescription` and `NSCameraUsageDescription` keys. 

## Known Issues

* Launching the app, loading photos in AR, backgrounding the app for a long period of time, and activating the app back to the foreground can cause the previously loaded photos to disappear. Reloading the photos from the photo picker should place them back in AR space correctly.
