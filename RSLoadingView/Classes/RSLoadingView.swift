import UIKit
import QuartzCore
import SceneKit

protocol RSLoadingViewEffect {
  func setup(main: RSLoadingView)
  func prepareForResize(main: RSLoadingView)
  func update(at time: TimeInterval)
}

public class RSLoadingView: UIView, SCNSceneRendererDelegate {
  
  @IBInspectable public var speedFactor: CGFloat = 1.0
  @IBInspectable public var mainColor: UIColor = UIColor.white
  @IBInspectable public var colorVariation: CGFloat = 0.0
  @IBInspectable public var sizeFactor: CGFloat = 1.0
  @IBInspectable public var spreadingFactor: CGFloat = 1.0
  @IBInspectable public var lifeSpanFactor: CGFloat = 1.0
  @IBInspectable public var variantKey: String = ""
  
  fileprivate var effect: RSLoadingViewEffect = RSLoadingSpinAlone()
  let logger = RSLogger(tag: "RSLoadingView")
  var scnView: SCNView!
  let scene = SCNScene()
  let cameraNode = SCNNode()
  var bundleResourcePath: String = ""
  var pixelPerUnit: Float = 0
  var widthInUnit: Float = 0
  var heightInUnit: Float = 0
  var topLeftPoint: SCNVector3 = SCNVector3Zero
  var topRightPoint: SCNVector3 = SCNVector3Zero
  var bottomLeftPoint: SCNVector3 = SCNVector3Zero
  var bottomRightPoint: SCNVector3 = SCNVector3Zero
  var isResized = true
  
  var containerView: RSLoadingContainerView?
  public var shouldDimBackground = true
  public var dimBackgroundColor = UIColor.black.withAlphaComponent(0.6)
  public var isBlocking = true
  public var shouldTapToDismiss = false
  public var sizeInContainer: CGSize = CGSize(width: 180, height: 180)
  
  init(effect: RSLoadingViewEffect? = nil) {
    super.init(frame: CGRect.zero)
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  override open func awakeFromNib() {
    super.awakeFromNib()
    setup()
  }
  
  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  open func setup() {
    scnView = SCNView(frame: CGRect.zero, options: [SCNView.Option.preferredRenderingAPI.rawValue: NSNumber(value: 1)])
    scnView.delegate = self
    addSubview(scnView)
    scnView.scene = scene
    scnView.allowsCameraControl = false
    scnView.backgroundColor = backgroundColor
    cameraNode.camera = SCNCamera()
    scene.rootNode.addChildNode(cameraNode)
    cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
    bundleResourcePath = "/Frameworks/RSLoadingView.framework/RSLoadingView.bundle/"
    effect.setup(main: self)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    scnView.frame = bounds
    isResized = true
  }
  
  open func prepareForResize() {
    logger.logDebug("prepareForResize Size: \(bounds.size)")
    let pointZero = scnView.projectPoint(SCNVector3Zero)
    let pointOne = scnView.projectPoint(SCNVector3Make(1, 0, 0))
    pixelPerUnit = pointOne.x - pointZero.x
    topLeftPoint = scnView.unprojectPoint(SCNVector3Make(0, 0, pointZero.z))
    topRightPoint = scnView.unprojectPoint(SCNVector3Make(bounds.size.width.asFloat, 0, pointZero.z))
    bottomLeftPoint = scnView.unprojectPoint(SCNVector3Make(0, bounds.size.height.asFloat, pointZero.z))
    bottomRightPoint = scnView.unprojectPoint(SCNVector3Make(bounds.size.width.asFloat, bounds.size.height.asFloat, pointZero.z))
    widthInUnit = topRightPoint.x * 2
    heightInUnit = topRightPoint.y * 2
    logger.logDebug("pixelPerUnit \(pixelPerUnit)")
    logger.logDebug("topLeftPoint \(topLeftPoint)")
    logger.logDebug("topRightPoint \(topRightPoint)")
    logger.logDebug("bottomLeftPoint \(bottomLeftPoint)")
    logger.logDebug("bottomRightPoint \(bottomRightPoint)")
    logger.logDebug("sizeInUnit \(widthInUnit) x \(heightInUnit)")
    effect.prepareForResize(main: self)
  }
  
  
  public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    //logger.logDebug("updateAtTime \(time)")
    if isResized {
      prepareForResize()
      isResized = false
    } else {
      effect.update(at: time)
    }
  }
  
  func loadParticleSystem(name: String) -> SCNParticleSystem? {
    if let particleSystem = SCNParticleSystem(named: name, inDirectory: bundleResourcePath) {
      return particleSystem
    } else {
      logger.logDebug("Can't load particleSystem \(name) at \(bundleResourcePath)")
      return nil
    }
  }
  
  func loadParticleImage(name: String) -> UIImage? {
    let frameworkBundle = Bundle(for: RSLoadingView.self)
    let bundleURL = frameworkBundle.url(forResource: "RSLoadingView", withExtension: "bundle")!
    let resourceBundle = Bundle(url: bundleURL)!
    if let image = UIImage(named: name, in: resourceBundle, compatibleWith: nil) {
      return image
    } else {
      logger.logDebug("Can't load particleImage \(name) at \(resourceBundle.bundlePath)")
      return nil
    }
  }
  
  public func showOnKeyWindow() {
    show(on: UIApplication.shared.keyWindow!)
  }
  
  public func show(on view: UIView) {
    // Remove existing container views
    let containerViews = view.subviews.filter { (view) -> Bool in
      return view is RSLoadingContainerView
    }
    containerViews.forEach { (view) in
      view.removeFromSuperview()
    }
    
    backgroundColor = UIColor.clear
    scnView.backgroundColor = backgroundColor
    containerView = RSLoadingContainerView(loadingView: self)
    if let containerView = containerView {
      view.addSubview(containerView)
      containerView.translatesAutoresizingMaskIntoConstraints = false
      containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
      containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
      containerView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
      containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
      containerView.isHidden = true
      
      if shouldTapToDismiss {
        containerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hide)))
      }
      showContainerView()
    }
  }
  
  static public func hideFromKeyWindow() {
    hide(from: UIApplication.shared.keyWindow!)
  }
  
  static public func hide(from view: UIView) {
    let containerViews = view.subviews.filter { (view) -> Bool in
      return view is RSLoadingContainerView
    }
    containerViews.forEach { (view) in
      if let containerView = view as? RSLoadingContainerView {
        containerView.loadingView.hide()
      }
    }
  }
  
  open func hide() {
    hideContainerView()
  }
  
  fileprivate func showContainerView() {
    if let containerView = containerView {
      containerView.isHidden = false
      containerView.alpha = 0.0
      UIView.animate(withDuration: 0.3) {
        containerView.alpha = 1.0
      }
    }
  }
  
  fileprivate func hideContainerView() {
    if let containerView = containerView {
      UIView.animate(withDuration: 0.3, animations: { 
        containerView.alpha = 0.0
      }, completion: { _ in
        containerView.removeFromSuperview()
      })
    }
  }
}
