import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var avKitPlugin: AvKitPlaybackPlugin?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        registerAvKitPlugin(engineBridge: engineBridge)
    }

    private func registerAvKitPlugin(engineBridge: FlutterImplicitEngineBridge) {
        guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AvKitPlaybackPlugin"),
              let messenger = registrar.messenger(),
              let textureRegistry = registrar.textures() else { return }

        let plugin = AvKitPlaybackPlugin(textureRegistry: textureRegistry)
        avKitPlugin = plugin

        let methodChannel = FlutterMethodChannel(
            name: AvKitPlaybackPlugin.methodChannelName,
            binaryMessenger: messenger
        )
        methodChannel.setMethodCallHandler { [weak plugin] call, result in
            plugin?.handle(call, result: result)
        }

        let eventChannel = FlutterEventChannel(
            name: AvKitPlaybackPlugin.eventChannelName,
            binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(plugin)
    }
}
