//
// Copyright (C) 2015 CosmicMind, Inc. <http://cosmicmind.io> and other CosmicMind contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program located at the root of the software package
// in a file called LICENSE.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import AVFoundation

public enum CaptureMode {
	case Photo
	case Video
}

@objc(CaptureViewDelegate)
public protocol CaptureViewDelegate : MaterialDelegate {
	/**
	:name:	captureViewDidStartRecordTimer
	*/
	optional func captureViewDidStartRecordTimer(captureView: CaptureView)
	
	/**
	:name:	captureViewDidUpdateRecordTimer
	*/
	optional func captureViewDidUpdateRecordTimer(captureView: CaptureView, hours: Int, minutes: Int, seconds: Int)
	
	/**
	:name:	captureViewDidStopRecordTimer
	*/
	optional func captureViewDidStopRecordTimer(captureView: CaptureView, hours: Int, minutes: Int, seconds: Int)
	
	/**
	:name:	captureViewDidTapToFocusAtPoint
	*/
	optional func captureViewDidTapToFocusAtPoint(captureView: CaptureView, point: CGPoint)
	
	/**
	:name:	captureViewDidTapToExposeAtPoint
	*/
	optional func captureViewDidTapToExposeAtPoint(captureView: CaptureView, point: CGPoint)
	
	/**
	:name:	captureViewDidTapToResetAtPoint
	*/
	optional func captureViewDidTapToResetAtPoint(captureView: CaptureView, point: CGPoint)
	
	/**
	:name:	captureViewDidPressFlashButton
	*/
	optional func captureViewDidPressFlashButton(captureView: CaptureView, button: UIButton)
	
	/**
	:name:	captureViewDidPressSwitchCamerasButton
	*/
	optional func captureViewDidPressSwitchCamerasButton(captureView: CaptureView, button: UIButton)
	
	/**
	:name:	captureViewDidPressCaptureButton
	*/
	optional func captureViewDidPressCaptureButton(captureView: CaptureView, button: UIButton)
	
	/**
	:name:	captureViewDidPressCameraButton
	*/
	optional func captureViewDidPressCameraButton(captureView: CaptureView, button: UIButton)
	
	/**
	:name:	captureViewDidPressVideoButton
	*/
	optional func captureViewDidPressVideoButton(captureView: CaptureView, button: UIButton)
}

public class CaptureView : MaterialView, UIGestureRecognizerDelegate {
	/**
	:name:	timer
	*/
	private var timer: NSTimer?
	
	/**
	:name:	tapToFocusGesture
	*/
	private var tapToFocusGesture: UITapGestureRecognizer?
	
	/**
	:name:	tapToExposeGesture
	*/
	private var tapToExposeGesture: UITapGestureRecognizer?
	
	/**
	:name:	tapToResetGesture
	*/
	private var tapToResetGesture: UITapGestureRecognizer?
	
	/**
	:name:	captureMode
	*/
	public lazy var captureMode: CaptureMode = .Video
	
	/**
	:name:	tapToFocusEnabled
	*/
	public var tapToFocusEnabled: Bool = false {
		didSet {
			if tapToFocusEnabled {
				tapToResetEnabled = true
				prepareFocusLayer()
				prepareTapGesture(&tapToFocusGesture, numberOfTapsRequired: 1, numberOfTouchesRequired: 1, selector: "handleTapToFocusGesture:")
				if let v: UITapGestureRecognizer = tapToExposeGesture {
					tapToFocusGesture!.requireGestureRecognizerToFail(v)
				}
			} else {
				removeTapGesture(&tapToFocusGesture)
				focusLayer?.removeFromSuperlayer()
				focusLayer = nil
			}
		}
	}
	
	/**
	:name:	tapToExposeEnabled
	*/
	public var tapToExposeEnabled: Bool = false {
		didSet {
			if tapToExposeEnabled {
				tapToResetEnabled = true
				prepareExposureLayer()
				prepareTapGesture(&tapToExposeGesture, numberOfTapsRequired: 2, numberOfTouchesRequired: 1, selector: "handleTapToExposeGesture:")
				if let v: UITapGestureRecognizer = tapToFocusGesture {
					v.requireGestureRecognizerToFail(tapToExposeGesture!)
				}
			} else {
				removeTapGesture(&tapToExposeGesture)
				exposureLayer?.removeFromSuperlayer()
				exposureLayer = nil
			}
		}
	}
	
	/**
	:name:	tapToResetEnabled
	*/
	public var tapToResetEnabled: Bool = false {
		didSet {
			if tapToResetEnabled {
				prepareResetLayer()
				prepareTapGesture(&tapToResetGesture, numberOfTapsRequired: 2, numberOfTouchesRequired: 2, selector: "handleTapToResetGesture:")
				if let v: UITapGestureRecognizer = tapToFocusGesture {
					v.requireGestureRecognizerToFail(tapToResetGesture!)
				}
				if let v: UITapGestureRecognizer = tapToExposeGesture {
					v.requireGestureRecognizerToFail(tapToResetGesture!)
				}
			} else {
				removeTapGesture(&tapToResetGesture)
				resetLayer?.removeFromSuperlayer()
				resetLayer = nil
			}
		}
	}
	
	/**
	:name:	contentInsets
	*/
	public var contentInsets: MaterialEdgeInsets = .None {
		didSet {
			contentInsetsRef = MaterialEdgeInsetsToValue(contentInsets)
		}
	}
	
	/**
	:name:	contentInsetsRef
	*/
	public var contentInsetsRef: UIEdgeInsets = MaterialTheme.captureView.contentInsetsRef {
		didSet {
			reloadView()
		}
	}
	
	/**
	:name:	previewView
	*/
	public private(set) lazy var previewView: CapturePreviewView = CapturePreviewView()
	
	/**
	:name:	capture
	*/
	public private(set) lazy var captureSession: CaptureSession = CaptureSession()
	
	/**
	:name:	focusLayer
	*/
	public private(set) var focusLayer: MaterialLayer?
	
	/**
	:name:	exposureLayer
	*/
	public private(set) var exposureLayer: MaterialLayer?
	
	/**
	:name:	resetLayer
	*/
	public private(set) var resetLayer: MaterialLayer?
	
	/**
	:name:	cameraButton
	*/
	public var cameraButton: UIButton? {
		didSet {
			if let v: UIButton = cameraButton {
				v.addTarget(self, action: "handleCameraButton:", forControlEvents: .TouchUpInside)
			}
			reloadView()
		}
	}
	
	/**
	:name:	captureButton
	*/
	public var captureButton: UIButton? {
		didSet {
			if let v: UIButton = captureButton {
				v.addTarget(self, action: "handleCaptureButton:", forControlEvents: .TouchUpInside)
			}
			reloadView()
		}
	}

	
	/**
	:name:	videoButton
	*/
	public var videoButton: UIButton? {
		didSet {
			if let v: UIButton = videoButton {
				v.addTarget(self, action: "handleVideoButton:", forControlEvents: .TouchUpInside)
			}
			reloadView()
		}
	}
	
	/**
	:name:	switchCamerasButton
	*/
	public var switchCamerasButton: UIButton? {
		didSet {
			if let v: UIButton = switchCamerasButton {
				v.addTarget(self, action: "handleSwitchCamerasButton:", forControlEvents: .TouchUpInside)
			}
		}
	}
	
	/**
	:name:	flashButton
	*/
	public var flashButton: UIButton? {
		didSet {
			if let v: UIButton = flashButton {
				v.addTarget(self, action: "handleFlashButton:", forControlEvents: .TouchUpInside)
			}
		}
	}
	
	/**
	:name:	init
	*/
	public convenience init() {
		self.init(frame: CGRectNull)
	}
	
	/**
	:name:	layoutSubviews
	*/
	public override func layoutSubviews() {
		super.layoutSubviews()
		previewView.frame = bounds
		
		if let v: UIButton = cameraButton {
			v.frame.origin.y = bounds.height - contentInsetsRef.bottom - v.bounds.height
			v.frame.origin.x = contentInsetsRef.left
		}
		if let v: UIButton = captureButton {
			v.frame.origin.y = bounds.height - contentInsetsRef.bottom - v.bounds.height
			v.frame.origin.x = (bounds.width - v.bounds.width) / 2
		}
		if let v: UIButton = videoButton {
			v.frame.origin.y = bounds.height - contentInsetsRef.bottom - v.bounds.height
			v.frame.origin.x = bounds.width - v.bounds.width - contentInsetsRef.right
		}
		if let v: AVCaptureConnection = (previewView.layer as! AVCaptureVideoPreviewLayer).connection {
			v.videoOrientation = captureSession.currentVideoOrientation
		}
	}
	
	/**
	:name:	prepareView
	*/
	public override func prepareView() {
		super.prepareView()
		userInteractionEnabled = MaterialTheme.captureView.userInteractionEnabled
		backgroundColor = MaterialTheme.captureView.backgroundColor
		
		contentsRect = MaterialTheme.captureView.contentsRect
		contentsCenter = MaterialTheme.captureView.contentsCenter
		contentsScale = MaterialTheme.captureView.contentsScale
		contentsGravity = MaterialTheme.captureView.contentsGravity
		shadowDepth = MaterialTheme.captureView.shadowDepth
		shadowColor = MaterialTheme.captureView.shadowColor
		zPosition = MaterialTheme.captureView.zPosition
		borderWidth = MaterialTheme.captureView.borderWidth
		borderColor = MaterialTheme.captureView.bordercolor
		
		preparePreviewView()
	}
	
	/**
	:name:	reloadView
	*/
	public func reloadView() {
		// clear constraints so new ones do not conflict
		removeConstraints(constraints)
		for v in subviews {
			v.removeFromSuperview()
		}
		
		insertSubview(previewView, atIndex: 0)
		
		if let v: UIButton = captureButton {
			insertSubview(v, atIndex: 1)
		}
		
		if let v: UIButton = cameraButton {
			insertSubview(v, atIndex: 2)
		}
		
		if let v: UIButton = videoButton {
			insertSubview(v, atIndex: 3)
		}
	}
	
	/**
	:name:	startTimer
	*/
	internal func startTimer() {
		timer?.invalidate()
		timer = NSTimer(timeInterval: 0.5, target: self, selector: "updateTimer", userInfo: nil, repeats: true)
		NSRunLoop.mainRunLoop().addTimer(timer!, forMode: NSRunLoopCommonModes)
		(delegate as? CaptureViewDelegate)?.captureViewDidStartRecordTimer?(self)
	}
	
	/**
	:name:	updateTimer
	*/
	internal func updateTimer() {
		let duration: CMTime = captureSession.recordedDuration
		let time: Double = CMTimeGetSeconds(duration)
		let hours: Int = Int(time / 3600)
		let minutes: Int = Int((time / 60) % 60)
		let seconds: Int = Int(time % 60)
		(delegate as? CaptureViewDelegate)?.captureViewDidUpdateRecordTimer?(self, hours: hours, minutes: minutes, seconds: seconds)
	}
	
	/**
	:name:	stopTimer
	*/
	internal func stopTimer() {
		let duration: CMTime = captureSession.recordedDuration
		let time: Double = CMTimeGetSeconds(duration)
		let hours: Int = Int(time / 3600)
		let minutes: Int = Int((time / 60) % 60)
		let seconds: Int = Int(time % 60)
		timer?.invalidate()
		timer = nil
		(delegate as? CaptureViewDelegate)?.captureViewDidStopRecordTimer?(self, hours: hours, minutes: minutes, seconds: seconds)
	}
	
	/**
	:name:	handleFlashButton
	*/
	internal func handleFlashButton(button: UIButton) {
		(delegate as? CaptureViewDelegate)?.captureViewDidPressFlashButton?(self, button: button)
	}
	
	/**
	:name:	handleSwitchCamerasButton
	*/
	internal func handleSwitchCamerasButton(button: UIButton) {
		captureSession.switchCameras()
		(delegate as? CaptureViewDelegate)?.captureViewDidPressSwitchCamerasButton?(self, button: button)
	}
	
	/**
	:name:	handleCaptureButton
	*/
	internal func handleCaptureButton(button: UIButton) {
		if .Photo == captureMode {
			captureSession.captureStillImage()
		} else if .Video == captureMode {
			if captureSession.isRecording {
				captureSession.stopRecording()
				stopTimer()
			} else {
				captureSession.startRecording()
				startTimer()
			}
		}
		(delegate as? CaptureViewDelegate)?.captureViewDidPressCaptureButton?(self, button: button)
	}
	
	/**
	:name:	handleCameraButton
	*/
	internal func handleCameraButton(button: UIButton) {
		captureMode = .Photo
		(delegate as? CaptureViewDelegate)?.captureViewDidPressCameraButton?(self, button: button)
	}
	
	/**
	:name:	handleVideoButton
	*/
	internal func handleVideoButton(button: UIButton) {
		captureMode = .Video
		(delegate as? CaptureViewDelegate)?.captureViewDidPressVideoButton?(self, button: button)
	}
	
	/**
	:name:	handleTapToFocusGesture
	*/
	internal func handleTapToFocusGesture(recognizer: UITapGestureRecognizer) {
		if tapToFocusEnabled && captureSession.cameraSupportsTapToFocus {
			let point: CGPoint = recognizer.locationInView(self)
			captureSession.focusAtPoint(previewView.captureDevicePointOfInterestForPoint(point))
			animateTapLayer(layer: focusLayer!, point: point)
			(delegate as? CaptureViewDelegate)?.captureViewDidTapToFocusAtPoint?(self, point: point)
		}
	}
	
	/**
	:name:	handleTapToExposeGesture
	*/
	internal func handleTapToExposeGesture(recognizer: UITapGestureRecognizer) {
		if tapToExposeEnabled && captureSession.cameraSupportsTapToExpose {
			let point: CGPoint = recognizer.locationInView(self)
			captureSession.exposeAtPoint(previewView.captureDevicePointOfInterestForPoint(point))
			animateTapLayer(layer: exposureLayer!, point: point)
			(delegate as? CaptureViewDelegate)?.captureViewDidTapToExposeAtPoint?(self, point: point)
		}
	}
	
	/**
	:name:	handleTapToResetGesture
	*/
	internal func handleTapToResetGesture(recognizer: UITapGestureRecognizer) {
		if tapToResetEnabled {
			captureSession.resetFocusAndExposureModes()
			let point: CGPoint = previewView.pointForCaptureDevicePointOfInterest(CGPointMake(0.5, 0.5))
			animateTapLayer(layer: resetLayer!, point: point)
			(delegate as? CaptureViewDelegate)?.captureViewDidTapToResetAtPoint?(self, point: point)
		}
	}
	
	/**
	:name:	prepareTapGesture
	*/
	private func prepareTapGesture(inout gesture: UITapGestureRecognizer?, numberOfTapsRequired: Int, numberOfTouchesRequired: Int, selector: Selector) {
		removeTapGesture(&gesture)
		gesture = UITapGestureRecognizer(target: self, action: selector)
		gesture!.delegate = self
		gesture!.numberOfTapsRequired = numberOfTapsRequired
		gesture!.numberOfTouchesRequired = numberOfTouchesRequired
		addGestureRecognizer(gesture!)
	}
	
	/**
	:name:	removeTapToFocusGesture
	*/
	private func removeTapGesture(inout gesture: UITapGestureRecognizer?) {
		if let v: UIGestureRecognizer = gesture {
			removeGestureRecognizer(v)
			gesture = nil
		}
	}
	
	/**
	:name:	preparePreviewView
	*/
	private func preparePreviewView() {
		(previewView.layer as! AVCaptureVideoPreviewLayer).session = captureSession.session
		captureSession.startSession()
	}
	
	/**
	:name:	prepareFocusLayer
	*/
	private func prepareFocusLayer() {
		if nil == focusLayer {
			focusLayer = MaterialLayer(frame: CGRectMake(0, 0, 150, 150))
			focusLayer!.hidden = true
			focusLayer!.borderWidth = 2
			focusLayer!.borderColor = MaterialColor.white.CGColor
			previewView.layer.addSublayer(focusLayer!)
		}
	}
	
	/**
	:name:	prepareExposureLayer
	*/
	private func prepareExposureLayer() {
		if nil == exposureLayer {
			exposureLayer = MaterialLayer(frame: CGRectMake(0, 0, 150, 150))
			exposureLayer!.hidden = true
			exposureLayer!.borderWidth = 2
			exposureLayer!.borderColor = MaterialColor.yellow.darken1.CGColor
			previewView.layer.addSublayer(exposureLayer!)
		}
	}
	
	/**
	:name:	prepareResetLayer
	*/
	private func prepareResetLayer() {
		if nil == resetLayer {
			resetLayer = MaterialLayer(frame: CGRectMake(0, 0, 150, 150))
			resetLayer!.hidden = true
			resetLayer!.borderWidth = 2
			resetLayer!.borderColor = MaterialColor.red.accent1.CGColor
			previewView.layer.addSublayer(resetLayer!)
		}
	}
	
	/**
	:name:	animateTapLayer
	*/
	private func animateTapLayer(layer v: MaterialLayer, point: CGPoint) {
		MaterialAnimation.animationDisabled {
			v.transform = CATransform3DIdentity
			v.position = point
			v.hidden = false
		}
		MaterialAnimation.animateWithDuration(0.25, animations: {
			v.transform = CATransform3DMakeScale(0.5, 0.5, 1)
		}) {
			MaterialAnimation.delay(0.4) {
				MaterialAnimation.animationDisabled {
					v.hidden = true
				}
			}
		}
	}
}