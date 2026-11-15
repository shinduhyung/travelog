import AdServices
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
    registerAdServicesChannel(engineBridge.pluginRegistry)
  }

  /// Apple Search Ads attribution (AdServices). Used by
  /// lib/services/adservices_attribution.dart. Never throws to Dart:
  /// any failure returns nil.
  private func registerAdServicesChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "TravelogAdServices") else { return }
    let channel = FlutterMethodChannel(
      name: "travelog/adservices",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getAttributionToken":
        if #available(iOS 14.3, *) {
          DispatchQueue.global(qos: .utility).async {
            let token = try? AAAttribution.attributionToken()
            DispatchQueue.main.async { result(token) }
          }
        } else {
          result(nil)
        }
      case "getAppVersion":
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        result(build.isEmpty ? version : "\(version)+\(build)")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
