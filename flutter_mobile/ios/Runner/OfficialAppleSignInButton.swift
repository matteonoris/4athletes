import AuthenticationServices
import Flutter
import UIKit

final class OfficialAppleSignInButtonFactory: NSObject, FlutterPlatformViewFactory {
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
    let options = args as? [String: Any]
    return OfficialAppleSignInButtonView(
      frame: frame,
      viewId: viewId,
      style: options?["style"] as? String == "white" ? .white : .black,
      messenger: messenger)
  }
}

private final class OfficialAppleSignInButtonView: NSObject, FlutterPlatformView {
  private let button: ASAuthorizationAppleIDButton
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewId: Int64,
    style: ASAuthorizationAppleIDButton.Style,
    messenger: FlutterBinaryMessenger
  ) {
    // Apple supplies the artwork, typography, localization and accessibility.
    button = ASAuthorizationAppleIDButton(type: .continue, style: style)
    channel = FlutterMethodChannel(
      name: "com.4athletes.auth/apple_button/\(viewId)", binaryMessenger: messenger)
    super.init()
    button.frame = frame
    button.cornerRadius = 16
    button.addTarget(self, action: #selector(pressed), for: .touchUpInside)
  }

  func view() -> UIView { button }

  @objc private func pressed() {
    channel.invokeMethod("pressed", arguments: nil)
  }
}
