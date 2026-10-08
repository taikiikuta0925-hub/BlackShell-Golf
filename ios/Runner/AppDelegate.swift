import Flutter
import UIKit

private let liquidGlassViewType = "blackshell/liquid_glass"
private let liquidTabBarViewType = "blackshell/liquid_tab_bar"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var watchRoundBridge: WatchRoundBridge?
  private var liveActivityBridge: AnyObject?
  private var healthKitBridge: HealthKitBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "BlackShellAppleSync"
    ) {
      watchRoundBridge = WatchRoundBridge(messenger: registrar.messenger())
      if #available(iOS 16.1, *) {
        liveActivityBridge = GolfLiveActivityBridge(messenger: registrar.messenger())
      }
      healthKitBridge = HealthKitBridge(messenger: registrar.messenger())
    }

    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "BlackShellLiquidGlass"
    ) {
      registrar.register(
        LiquidGlassViewFactory(messenger: registrar.messenger()),
        withId: liquidGlassViewType
      )
      registrar.register(
        LiquidTabBarViewFactory(messenger: registrar.messenger()),
        withId: liquidTabBarViewType
      )
    }
  }
}

private final class LiquidTabBarViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    LiquidTabBarPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

private final class LiquidTabBarPlatformView: NSObject, FlutterPlatformView,
    UITabBarDelegate {
  private struct ItemDescriptor: Equatable {
    let label: String
    let symbolName: String
    let accessibilityIdentifier: String

    init(configuration: [String: Any]) {
      label = configuration["label"] as? String ?? ""
      symbolName = configuration["symbol"] as? String ?? "circle"
      if let identifier = configuration["accessibilityIdentifier"] as? String,
         !identifier.isEmpty {
        accessibilityIdentifier = identifier
      } else {
        accessibilityIdentifier = "main-tab-\(symbolName)"
      }
    }
  }

  private let containerView: UIView
  private let tabBar: UITabBar
  private let channel: FlutterMethodChannel
  private var configuration: [String: Any] = [:]
  private var renderedItemDescriptors: [ItemDescriptor] = []

  init(
    frame: CGRect,
    viewId: Int64,
    arguments args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    containerView = UIView(frame: frame)
    tabBar = UITabBar(frame: frame)
    channel = FlutterMethodChannel(
      name: "blackshell/liquid_tab_bar/\(viewId)",
      binaryMessenger: messenger
    )
    super.init()

    containerView.backgroundColor = .clear
    containerView.isOpaque = false
    tabBar.translatesAutoresizingMaskIntoConstraints = false
    tabBar.delegate = self
    tabBar.accessibilityIdentifier = "main-liquid-tab-bar"
    containerView.addSubview(tabBar)
    NSLayoutConstraint.activate([
      tabBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      tabBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      tabBar.topAnchor.constraint(equalTo: containerView.topAnchor),
      tabBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])

    if let arguments = args as? [String: Any] {
      configuration = arguments
    }
    applyConfiguration()

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update",
            let arguments = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.configuration = arguments
      self?.applyConfiguration()
      result(nil)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView {
    containerView
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    guard let index = tabBar.items?.firstIndex(of: item) else { return }
    channel.invokeMethod("selectionChanged", arguments: index)
  }

  private func applyConfiguration() {
    let interfaceStyle: UIUserInterfaceStyle =
      configuration["brightness"] as? String == "dark" ? .dark : .light
    containerView.overrideUserInterfaceStyle = interfaceStyle
    tabBar.overrideUserInterfaceStyle = interfaceStyle

    let itemConfigurations = configuration["items"] as? [[String: Any]] ?? []
    let itemDescriptors = itemConfigurations.map {
      ItemDescriptor(configuration: $0)
    }
    if itemDescriptors != renderedItemDescriptors {
      let items = itemDescriptors.enumerated().map { index, descriptor in
        makeTabBarItem(from: descriptor, index: index)
      }
      tabBar.setItems(items, animated: false)
      renderedItemDescriptors = itemDescriptors
    }

    let selectedIndex = (configuration["selectedIndex"] as? NSNumber)?.intValue ?? 0
    if let items = tabBar.items, !items.isEmpty {
      let safeIndex = min(max(selectedIndex, 0), items.count - 1)
      if tabBar.selectedItem !== items[safeIndex] {
        tabBar.selectedItem = items[safeIndex]
      }
    }

    if let tint = configuration["accentColor"] as? NSNumber {
      tabBar.tintColor = color(from: tint)
    }
  }

  private func makeTabBarItem(
    from descriptor: ItemDescriptor,
    index: Int
  ) -> UITabBarItem {
    let image = UIImage(systemName: descriptor.symbolName)
      ?? UIImage(systemName: "circle")
    let item = UITabBarItem(title: descriptor.label, image: image, tag: index)
    item.accessibilityLabel = descriptor.label
    item.accessibilityIdentifier = descriptor.accessibilityIdentifier
    return item
  }

  private func color(from value: NSNumber) -> UIColor {
    let argb = value.uint32Value
    return UIColor(
      red: CGFloat((argb >> 16) & 0xff) / 255,
      green: CGFloat((argb >> 8) & 0xff) / 255,
      blue: CGFloat(argb & 0xff) / 255,
      alpha: CGFloat((argb >> 24) & 0xff) / 255
    )
  }
}

private final class LiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    LiquidGlassPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

private final class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
  private let containerView: UIView
  private let effectView: UIVisualEffectView
  private let channel: FlutterMethodChannel
  private var configuration: [String: Any] = [:]

  init(
    frame: CGRect,
    viewId: Int64,
    arguments: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    containerView = UIView(frame: frame)
    effectView = UIVisualEffectView(effect: nil)
    channel = FlutterMethodChannel(
      name: "blackshell/liquid_glass/\(viewId)",
      binaryMessenger: messenger
    )
    super.init()

    containerView.backgroundColor = .clear
    containerView.isOpaque = false
    effectView.frame = containerView.bounds
    effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    effectView.isUserInteractionEnabled = false
    containerView.addSubview(effectView)

    if let arguments = arguments as? [String: Any] {
      configuration = arguments
    }
    applyConfiguration()

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update",
            let arguments = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.configuration = arguments
      self?.applyConfiguration()
      result(nil)
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(accessibilityAppearanceDidChange),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(accessibilityAppearanceDidChange),
      name: UIAccessibility.reduceMotionStatusDidChangeNotification,
      object: nil
    )
  }

  deinit {
    channel.setMethodCallHandler(nil)
    NotificationCenter.default.removeObserver(self)
  }

  func view() -> UIView {
    containerView
  }

  @objc private func accessibilityAppearanceDidChange() {
    applyConfiguration()
  }

  private func applyConfiguration() {
    let interfaceStyle: UIUserInterfaceStyle =
      configuration["brightness"] as? String == "dark" ? .dark : .light
    containerView.overrideUserInterfaceStyle = interfaceStyle
    effectView.overrideUserInterfaceStyle = interfaceStyle

    let cornerRadius = (configuration["cornerRadius"] as? NSNumber)?.doubleValue ?? 24
    if #available(iOS 26.0, *) {
      effectView.cornerConfiguration = .uniformCorners(radius: .fixed(cornerRadius))
    } else {
      effectView.layer.cornerRadius = cornerRadius
      effectView.layer.cornerCurve = .continuous
      effectView.clipsToBounds = true
    }

    let fallbackColor = color(from: configuration["fallbackColor"] as? NSNumber)
      ?? UIColor.secondarySystemBackground.withAlphaComponent(0.92)

    if UIAccessibility.isReduceTransparencyEnabled {
      effectView.effect = nil
      effectView.backgroundColor = fallbackColor
      return
    }

    effectView.backgroundColor = .clear

    if #available(iOS 26.0, *) {
      let isClear = configuration["style"] as? String == "clear"
      let effect = UIGlassEffect(style: isClear ? .clear : .regular)
      effect.isInteractive =
        (configuration["interactive"] as? Bool ?? false)
        && !UIAccessibility.isReduceMotionEnabled
      effect.tintColor = color(from: configuration["tintColor"] as? NSNumber)
      effectView.effect = effect
    } else {
      effectView.effect = UIBlurEffect(style: .systemMaterial)
    }
  }

  private func color(from value: NSNumber?) -> UIColor? {
    guard let value else { return nil }

    let argb = value.uint32Value
    return UIColor(
      red: CGFloat((argb >> 16) & 0xff) / 255,
      green: CGFloat((argb >> 8) & 0xff) / 255,
      blue: CGFloat(argb & 0xff) / 255,
      alpha: CGFloat((argb >> 24) & 0xff) / 255
    )
  }
}
