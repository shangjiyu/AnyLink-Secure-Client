import Flutter
import UIKit
import Foundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
        let vpnManager = VPNManager.shared
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let methodChannel = FlutterMethodChannel(name: "com.zeroq.demo/vpn", binaryMessenger: controller.binaryMessenger)
        methodChannel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            // This method is invoked on the UI thread.
            let callArgs = call.arguments as? [String : Any]
            switch(call.method){
            case "startVpn":
              Task(priority: .high) {
                  if (vpnManager.controller == nil) {
                      try await vpnManager.installVPNConfiguration()
                      result(false)
                      return
                  }
                  guard vpnManager.controller?.connectionStatus != .connected else { return result(true)}
                  try await vpnManager.controller?.startVPN(configMap: callArgs!)
              }
            case "stopVpn":
              Task(priority: .high) {
                  vpnManager.controller?.stopVPN()
                  result(false)
              }
            case "status":
              Task(priority: .high) {
                  let stats = try await vpnManager.controller?.status()
                  result(stats)
              }
            default:
              result(FlutterMethodNotImplemented)
            }
        })

        vpnManager.setCallback(callback: methodChannel.invokeMethod)

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
