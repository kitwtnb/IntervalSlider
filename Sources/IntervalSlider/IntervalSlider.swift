//
//  SplitSlider.swift
//  IntervalSlider
//
//  Created by shushutochako on 9/3/15.
//  Copyright © 2015 shushutochako. All rights reserved.
//
import UIKit

public protocol IntervalSliderDelegate {
    func confirmValue(slider: IntervalSlider, validValue: Float)
}

public class IntervalSliderSource {
    fileprivate var validValue: Float
    fileprivate var appearanceValue: Float
    fileprivate var label: UILabel?

    /**
    Initialize IntervalSliderSource

    - parameter validValue: The value set is valid
    - parameter appearanceValue: The value is used to represent the position of validValue
    - parameter label: label to be displayed at the top of the appearanceValue
    */
    public init(validValue: Float, appearanceValue: Float, label: UILabel) {
        self.validValue = validValue
        self.appearanceValue = appearanceValue
        self.label = label
    }
}

public enum IntervalSliderOption {
    case MinimumTrackTintColor(UIColor)
    case MinimumValue(Float) // can set a value greater than 0
    case MaximumValue(Float) // can set a value less than 100
    case LabelBottomPadding(CGFloat)
    case DefaultValue(Float)
    case AddMark(Bool)
    case ThumbImage(UIImage)
}

public class IntervalSlider: UIView {

    private class TapSlider: UISlider {
        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            return true
        }
    }

    public var delegate: IntervalSliderDelegate?
    private var slider: TapSlider!
    private var sources = [IntervalSliderSource]()
    private var labels = [UILabel]()
    private var marks = [UIView]()

    // options
    private var minimumValue: Float = 0 {
        willSet {
            if newValue < 0 || newValue > 100 { fatalError("MinimumValue must be between 0 and 100") }
        }
    }
    private var maximumValue: Float = 100 {
        willSet {
            if newValue < 0 || newValue > 100 { fatalError("MaximumValue must be between 0 and 100") }
        }
    }
    private var minimumTrackTintColor = UIColor.blue
    private var labelBottomPadding: CGFloat = 5
    private var defaultValue: Float = 0
    private var isAddMark: Bool = false
    private var thumbImage: UIImage?
    private var defaultThumbImage: UIImage? {
        let thumbView = UIView(frame: .init(x: 0, y: 0 , width: 20, height: 20))
        thumbView.backgroundColor = UIColor.white
        thumbView.layer.cornerRadius = thumbView.bounds.width * 0.5
        thumbView.clipsToBounds = true
        return self.imageFromViewWithCornerRadius(view: thumbView)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init(frame: CGRect, sources: [IntervalSliderSource], options: [IntervalSliderOption]? = nil) {
        super.init(frame: frame)
        self.sources = sources
        self.build(options: options)
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.layout()
    }

    private func build(options: [IntervalSliderOption]?) {
        if let options = options {
            for option in options {
                switch option {
                case let .MinimumTrackTintColor(value):
                    self.minimumTrackTintColor = value
                case let .MinimumValue(value):
                    self.minimumValue = value
                case let .MaximumValue(value):
                    self.maximumValue = value
                case let .LabelBottomPadding(value):
                    self.labelBottomPadding = value
                case let .DefaultValue(value):
                    self.defaultValue = value
                case let .AddMark(value):
                    self.isAddMark = value
                case let .ThumbImage(value):
                    self.thumbImage = value
                }
            }
        }
        let rect = CGRect(x: 0, y:self.frame.height / 2, width: self.frame.width, height: self.frame.height / 2)
        self.slider = TapSlider(frame: rect)
        self.slider.setThumbImage(self.thumbImage ?? self.defaultThumbImage, for: .normal)
        self.addSubview(self.slider)
        self.slider.minimumValue = self.minimumValue
        self.slider.maximumValue = self.maximumValue
        self.slider.minimumTrackTintColor = self.minimumTrackTintColor
        self.slider.addTarget(self, action: #selector(endDrag(slider:)), for: .touchUpInside)
        self.slider.addTarget(self, action: #selector(endDrag(slider:)), for: .touchUpOutside)

        for source in self.sources {
            if let label = source.label {
                label.frame = .init(x: 0, y: 0, width: label.bounds.size.width, height: label.bounds.size.height)
                self.labels.append(label)
                self.addSubview(label)
            }
            if self.isAddMark {
                let mark = UIView(frame: .init(x: 0, y: 0, width: 1, height: 8))
                mark.backgroundColor = UIColor.lightGray
                self.marks.append(mark)
                self.insertSubview(mark, belowSubview:self.slider)
            }
        }
        self.seek(value: self.adjustSliderValue(baseValue: self.defaultValue))
    }

    private func layout(){
        self.slider.frame = .init(x: 0, y: self.frame.height / 2, width: self.frame.width, height: self.frame.height / 2)
        var index: Int = 0
        for source in self.sources {
            let label = self.labels[index]
            let center = self.thumbCenter(value: source.appearanceValue)
            label.frame = .init(x: 0,
                                y: self.slider.frame.origin.y - (label.bounds.size.height + self.labelBottomPadding),
                                width: label.bounds.size.width,
                                height: label.bounds.size.height)
            label.center = CGPoint(x: center.x, y: label.center.y)
            if self.isAddMark {
                let mark = marks[index]
                mark.center = CGPoint(x: center.x, y: center.y)
            }
            index += 1
        }
    }

    @objc public func endDrag(slider: UISlider) {
        let adjustValue: Float = self.adjustSliderValue(baseValue: self.slider.value)
        self.seek(value: adjustValue)
        self.delegate?.confirmValue(slider: self, validValue: self.getValue())
    }

    /**
    Return a current validValue

    */
    public func getValue() -> Float {
        return self.findValidValue(appearanceValue: self.slider.value)
    }

    /**
    Set valid value
    If you specify a value not included in the valideValues,
    the value is adjusted to the nearest validValue

    - parameter value:   validValue
    */
    public func setValue(value: Float) {
        self.seek(value: self.findAppearanceValue(validValue: value))
    }

    private func findValidValue(appearanceValue: Float) -> Float {
        let sources = self.sources.filter({
            $0.appearanceValue == appearanceValue
        })
        return sources[0].validValue
    }

    private func findAppearanceValue(validValue: Float) -> Float {
        let sources = self.sources.filter({
            $0.validValue == validValue
        })
        return sources[0].appearanceValue
    }

    private func thumbCenter(value: Float) -> (x: CGFloat, y: CGFloat) {
        let originValue = self.slider.value
        self.seek(value: value)
        let trackRect = self.slider.trackRect(forBounds: self.slider.bounds)
        let thumbRect = self.slider.thumbRect(forBounds: self.slider.bounds, trackRect: trackRect, value: self.slider.value)
        self.seek(value: originValue)
        return (thumbRect.origin.x + (self.slider.currentThumbImage!.size.width / 2),
            self.slider.frame.origin.y + thumbRect.origin.y + (self.slider.currentThumbImage!.size.height / 2))
    }

    private func adjustSliderValue(baseValue: Float) -> Float {
        var selectValue = self.sources.first?.appearanceValue
        var leastDifference: Float?
        for sources in self.sources {
            let value = sources.appearanceValue
            let difference = abs(value - baseValue)
            if let comparison = leastDifference {
                if difference < comparison {
                    leastDifference = difference
                    selectValue = value
                }
            } else {
                leastDifference = difference
            }
        }
        return selectValue!
    }

    private func seek(value: Float) {
        UIView.animate(withDuration: 0.6, delay: 0,
            usingSpringWithDamping: 0.4,
            initialSpringVelocity: 0,
            options: .curveEaseInOut,
            animations: {
                self.slider.setValue(value, animated: true)
            },
            completion: nil)
    }

    private func imageFromViewWithCornerRadius(view: UIView) -> UIImage? {
        // maskImage
        let imageBounds = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: view.bounds.size.height)
        let path = UIBezierPath(roundedRect: imageBounds, cornerRadius: view.bounds.size.width * 0.5)
        UIGraphicsBeginImageContextWithOptions(path.bounds.size, false, 0)
        view.backgroundColor?.setFill()
        path.fill()
        let maskImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // drawImge
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0.0)
        if let context = UIGraphicsGetCurrentContext(), let maskImage = maskImage?.cgImage {
            context.clip(to: imageBounds, mask: maskImage)
        }
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image;
    }

    public func setThumbImage(_ image: UIImage?, for state: UIControl.State) {
        slider.setThumbImage(image, for: state)
    }
}
