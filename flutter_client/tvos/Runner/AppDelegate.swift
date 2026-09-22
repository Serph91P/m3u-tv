import AVFoundation
import Flutter
import UIKit

// Opts the Siri Remote into raw indirect-touch reporting (delivered to Dart
// over the `flutter/gamepadtouchevent` channel that AppleTvRemoteSwipeGovernor
// listens on) instead of the system's own swipe-to-UIPress translation, which
// has no app-level sensitivity control and is what made navigation feel
// over-sensitive with no acceleration on a held swipe.
class M3uTvFlutterViewController: FlutterViewController {
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        resignFirstResponder()
        super.viewWillDisappear(animated)
    }
}

@main
class AppDelegate: FlutterAppDelegate {
    private var avKitPlugin: AvKitPlaybackPlugin?
    private var mpvPlugin: MpvPlayerPlugin?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let flutterVC = M3uTvFlutterViewController(project: nil, nibName: nil, bundle: nil)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = flutterVC
        window.makeKeyAndVisible()
        self.window = window

        // Register all plugins against the FlutterViewController's engine so
        // Dart platform-channel calls (path_provider, secure_storage, etc.)
        // reach the same engine that is actually running the Dart code.
        GeneratedPluginRegistrant.register(with: flutterVC.pluginRegistry())
        registerAvKitPlugin(with: flutterVC)
        registerMpvPlugin(with: flutterVC)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func registerAvKitPlugin(with controller: FlutterViewController) {
        guard let registrar = controller.pluginRegistry().registrar(forPlugin: "AvKitPlaybackPlugin") else { return }
        let plugin = AvKitPlaybackPlugin(textureRegistry: registrar.textures())
        avKitPlugin = plugin

        FlutterMethodChannel(
            name: AvKitPlaybackPlugin.methodChannelName,
            binaryMessenger: registrar.messenger()
        ).setMethodCallHandler { [weak plugin] call, result in
            plugin?.handle(call, result: result)
        }

        FlutterEventChannel(
            name: AvKitPlaybackPlugin.eventChannelName,
            binaryMessenger: registrar.messenger()
        ).setStreamHandler(plugin)
    }

    private func registerMpvPlugin(with controller: FlutterViewController) {
        guard let registrar = controller.pluginRegistry().registrar(forPlugin: "MpvPlayerPlugin") else { return }
        let plugin = MpvPlayerPlugin()
        mpvPlugin = plugin

        FlutterMethodChannel(
            name: MpvPlayerPlugin.methodChannelName,
            binaryMessenger: registrar.messenger()
        ).setMethodCallHandler { [weak plugin] call, result in
            plugin?.handle(call, result: result)
        }

        FlutterEventChannel(
            name: MpvPlayerPlugin.eventChannelName,
            binaryMessenger: registrar.messenger()
        ).setStreamHandler(plugin)

        registrar.register(
            MpvPlayerPlatformViewFactory(plugin: plugin),
            withId: "m3u_tv/apple_mpv_view"
        )
    }
}
