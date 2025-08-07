import Flutter
import PolarBleSdk
import RxSwift

@objc(PolarPluginBridge)
public class PolarPluginBridge: NSObject {
    @objc public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "polar", binaryMessenger: registrar.messenger())
        let searchChannel = FlutterEventChannel(name: "polar/search", binaryMessenger: registrar.messenger())
        
        let firmwareUpdateChannel = FlutterEventChannel(name: "polar/firmware_update", binaryMessenger: registrar.messenger())
        
        let instance = SwiftPolarPlugin(
            messenger: registrar.messenger(),
            channel: channel,
            searchChannel: searchChannel,
            firmwareUpdateChannel: firmwareUpdateChannel
        )
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        searchChannel.setStreamHandler(instance.searchHandler)
        firmwareUpdateChannel.setStreamHandler(instance.firmwareUpdateHandler)
    }
}
