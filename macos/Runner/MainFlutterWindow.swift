import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
 
      let vpnManager = VPNManager.shared
      let methodChannel = FlutterMethodChannel(name: "com.zeroq.demo/vpn", binaryMessenger: flutterViewController.engine.binaryMessenger)
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
                let status = try await vpnManager.controller?.status()
                result(status)
            }
          default:
            result(FlutterMethodNotImplemented)
          }
      })
      
      vpnManager.setCallback(callback: methodChannel.invokeMethod)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
