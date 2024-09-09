import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    let vpnManager = VPNManager.shared
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
      
    override func applicationWillTerminate(_ notification: Notification) {
        vpnManager.controller?.stopVPN()
        vpnManager.controller?.disableVPN()
    }
}
