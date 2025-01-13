import Flutter
import UIKit
import MapboxMaps
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize MapBox
    if let token = Bundle.main.object(forInfoDictionaryKey: "MGLMapboxAccessToken") as? String {
        MapboxOptions.accessToken = token
    }
    
    GMSServices.provideAPIKey("AIzaSyC228_kFDkb_z3PetipFzvjeDueyZKAzgA")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
