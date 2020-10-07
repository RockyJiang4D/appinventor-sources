// -*- mode: swift; swift-mode:basic-offset: 2; -*-
// Copyright © 2016-2019 Massachusetts Institute of Technology, All rights reserved.

import Foundation
import SchemeKit

open class ReplForm: Form {
  @objc internal static weak var topform: ReplForm?
  fileprivate static var _httpdServer: AppInvHTTPD?
  fileprivate var _assetsLoaded = false
  fileprivate var _isScreenClosed = false
  
  public override init(nibName nibNameOrNil: String?, bundle bundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: bundleOrNil)
    if ReplForm.topform == nil {
      makeTopForm()
    }
  }
  
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    if ReplForm.topform == nil {
      makeTopForm()
    }
  }

  public override init(application: Application) {
    super.init(application: application)
    if ReplForm.topform == nil {
      makeTopForm()
    }
  }

  open func makeTopForm() {
    ReplForm.topform = self
    formName = "Screen1"
  }

  open override func dispatchEvent(of component: Component, called componentName: String, with eventName: String, having args: [AnyObject]) -> Bool {
    defer {
      _componentWithActiveEvent = nil
    }
    _componentWithActiveEvent = component
    let interpreter = SCMInterpreter.shared
    let result = interpreter.invokeMethod("dispatchEvent", withArgArray: [component, componentName, eventName, args])
    if (interpreter.exception != nil) {
      NSLog("Exception occurred in YAIL: \((interpreter.exception?.name.rawValue)!) (irritants: \((interpreter.exception)!))");
      return false
    }
    if (result is Bool) {
      return result as! Bool
    } else if (result is NSNumber) {
      return (result as! NSNumber).boolValue
    } else {
      return false
    }
  }

  open override func dispatchGenericEvent(of component: Component, eventName: String, unhandled: Bool, arguments: [AnyObject]) {
    _componentWithActiveEvent = component
    if let interpreter = ReplForm._httpdServer?.interpreter {
      interpreter.invokeMethod("dispatchGenericEvent", withArgArray: [component, eventName, unhandled, arguments])
      if (interpreter.exception != nil) {
        NSLog("Exception occurred in YAIL: \((interpreter.exception?.name.rawValue)!) (irritants: \((interpreter.exception)!))");
      }
    }
    _componentWithActiveEvent = nil
  }

  @objc open func startHTTPD(_ secure: Bool) {
    if ReplForm._httpdServer == nil {
      ReplForm._httpdServer = AppInvHTTPD(port: 8001, rootDirectory: "", secure: secure, for: self)
    }
  }

  @objc open func stopHTTPD() {
    if let server = ReplForm._httpdServer {
      server.stop()
      ReplForm._httpdServer = nil
    }
  }
  
  @objc open var interpreter: SCMInterpreter {
    get {
      return SCMInterpreter.shared
    }
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    interpreter.setCurrentForm(self)
  }

  open override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if self.isMovingFromParent {
      if _isScreenClosed == false {
        Application.current?.popScreen(with: "")
      }
    }
  }

  open override func doSwitchForm(to formName: String, startValue: AnyObject?) {
    Application.current?.pushScreen(named: formName, with: startValue as? NSObject)
  }

  @objc open var activeForm: ReplForm? {
    get {
      if let form = Form.activeForm {
        if form is ReplForm {
          return form as? ReplForm
        }
      }
      return self
    }
  }

  @objc open var assetsLoaded: Bool {
    @objc(isAssetsLoaded)
    get {
      return _assetsLoaded;
    }
  }
  
  @objc open func setAssetsLoaded() {
    _assetsLoaded = true
  }

  override func doCloseScreen(withValue value: AnyObject? = nil) {
    super.doCloseScreen(withValue: value)
    _isScreenClosed = true
    do {
      Application.current?.popScreen(with: try getJsonRepresentation(value))
    } catch {
      Application.current?.popScreen(with: "")
    }
  }

  override func doCloseScreen(withPlainText text: String) {
    super.doCloseScreen(withPlainText: text)
    _isScreenClosed = true
    Application.current?.popScreen(with: text)
  }

  override open func doCloseApplication() {
    view.makeToast("Closing the application is not allowed in live development mode.")
  }

  override open var isRepl: Bool {
    return true
  }
}
