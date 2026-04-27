import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let ch = FlutterMethodChannel(
      name: "com.example.myfit/app_icon",
      binaryMessenger: messenger,
    )
    ch.setMethodCallHandler { call, result in
      if call.method == "setIcon" {
        let args = call.arguments as? [String: Any]
        let variant = (args?["variant"] as? String) ?? "light"
        let name: String? = variant == "dark" ? "AppIconDark" : nil
        if #available(iOS 10.3, *) {
          UIApplication.shared.setAlternateIconName(name) { err in
            if let err = err {
              result(FlutterError(code: "icon", message: err.localizedDescription, details: nil))
            } else {
              result(nil)
            }
          }
        } else {
          result(nil)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
