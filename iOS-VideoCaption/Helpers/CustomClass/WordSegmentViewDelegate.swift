import UIKit
import CoreData

protocol WordSegmentViewDelegate: AnyObject {
    func wordSegmentView(_ view: WordSegmentView, didResizeTo start: Double, duration: Double)
    func wordSegmentViewDidEndResizing(_ view: WordSegmentView)
}

class WordSegmentView: UIView {
    
    // Data
    var segment: WordSegment
    weak var delegate: WordSegmentViewDelegate?
    
    // UI Elements
    private let lbl_title = UILabel()
    private let view_leftHandle = UIView()
    private let view_rightHandle = UIView()
    
    // Internal Constants
    private let handleWidth: CGFloat = 12.0
    private var pointsPerSecond: CGFloat
    
    init(segment: WordSegment, pointsPerSecond: CGFloat) {
        self.segment = segment
        self.pointsPerSecond = pointsPerSecond
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init") }
    
    private func setupUI() {
        self.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.4)
        self.layer.cornerRadius = 6
        self.layer.borderWidth = 1.5
        self.layer.borderColor = UIColor.systemBlue.cgColor
        self.clipsToBounds = false // Allow handles to slightly overflow if needed
        
        lbl_title.text = segment.text
        lbl_title.font = .systemFont(ofSize: 11, weight: .semibold)
        lbl_title.textColor = .white
        lbl_title.textAlignment = .center
        addSubview(lbl_title)
        
        // Setup Handles
        configureHandle(view_leftHandle, isLeft: true)
        configureHandle(view_rightHandle, isLeft: false)
    }
    
    private func configureHandle(_ handle: UIView, isLeft: Bool) {
        handle.backgroundColor = .white
        handle.layer.cornerRadius = 2
        addSubview(handle)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleHandlePan(_:)))
        handle.addGestureRecognizer(pan)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        lbl_title.frame = bounds
        view_leftHandle.frame = CGRect(x: -2, y: 4, width: 4, height: bounds.height - 8)
        view_rightHandle.frame = CGRect(x: bounds.width - 2, y: 4, width: 4, height: bounds.height - 8)
    }
    
    @objc private func handleHandlePan(_ gesture: UIPanGestureRecognizer) {
        let isLeft = (gesture.view == view_leftHandle)
        let translation = gesture.translation(in: self.superview)
        let deltaSeconds = Double(translation.x / pointsPerSecond)
        
        switch gesture.state {
        case .changed:
            var newStart = segment.start
            var newDuration = segment.duration
            
            if isLeft {
                newStart += deltaSeconds
                newDuration -= deltaSeconds
            } else {
                newDuration += deltaSeconds
            }
            
            delegate?.wordSegmentView(self, didResizeTo: newStart, duration: newDuration)
            gesture.setTranslation(.zero, in: self.superview)
            
        case .ended, .cancelled:
            delegate?.wordSegmentViewDidEndResizing(self)
            
        default: break
        }
    }
}