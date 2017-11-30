import UIKit
import Solar

protocol StyleManagerDelegate: class {
    func locationFor(styleManager: StyleManager) -> CLLocation
    func styleManager(_ styleManager: StyleManager, didApply style: Style)
    func styleManagerDidRefreshAppearance(_ styleManager: StyleManager)
}

class StyleManager: NSObject {
    
    weak var delegate: StyleManagerDelegate!
    
    var currentStyleType: StyleType?
    var styles = [Style]() { didSet { applyStyle() } }
    var automaticallyAdjustsStyleForTimeOfDay = true {
        didSet {
            resumeNotifications()
        }
    }
    
    required init(_ delegate: StyleManagerDelegate) {
        self.delegate = delegate
        super.init()
        resumeNotifications()
    }
    
    deinit {
        suspendNotifications()
    }
    
    func resumeNotifications() {
        suspendNotifications()
        
        guard automaticallyAdjustsStyleForTimeOfDay else { return }
        
        let location = delegate.locationFor(styleManager: self)
        guard let solar = Solar(coordinate: location.coordinate),
            let sunrise = solar.sunrise,
            let sunset = solar.sunset else {
                return
        }
        
        guard let interval = solar.date.intervalUntilTimeOfDayChanges(sunrise: sunrise, sunset: sunset) else {
            print("Unable to get sunrise or sunset. Automatic style switching has been disabled.")
            return
        }
        
        perform(#selector(timeOfDayChanged), with: nil, afterDelay: interval+1)
    }
    
    func suspendNotifications() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(timeOfDayChanged), object: nil)
    }
    
    @objc func timeOfDayChanged() {
        applyStyle()
        resumeNotifications()
    }
    
    func applyStyle() {
        let location = delegate.locationFor(styleManager: self)
        let styleTypeForTimeOfDay = styleType(for: location)
        
        for style in styles {
            if style.styleType == styleTypeForTimeOfDay {
                style.apply()
                currentStyleType = style.styleType
                delegate.styleManager(self, didApply: style)
            }
        }
    }
    
    func styleType(for location: CLLocation) -> StyleType {
        guard let solar = Solar(coordinate: location.coordinate),
            let sunrise = solar.sunrise,
            let sunset = solar.sunset else {
                return .dayStyle
        }
        
        return solar.date.isNighttime(sunrise: sunrise, sunset: sunset) ? .nightStyle : .dayStyle
    }
    
    func forceRefreshAppearanceIfNeeded() {
        let location = delegate.locationFor(styleManager: self)
        
        guard currentStyleType != styleType(for: location) else {
            return
        }
        
        applyStyle()
        
        for window in UIApplication.shared.windows {
            for view in window.subviews {
                view.removeFromSuperview()
                window.addSubview(view)
            }
        }
        
        delegate.styleManagerDidRefreshAppearance(self)
    }
}

extension Date {
    func intervalUntilTimeOfDayChanges(sunrise: Date, sunset: Date) -> TimeInterval? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: self)
        guard let date = calendar.date(from: components) else {
            return nil
        }
        
        if isNighttime(sunrise: sunrise, sunset: sunset) {
            let sunriseComponents = calendar.dateComponents([.hour, .minute, .second], from: sunrise)
            guard let sunriseDate = calendar.date(from: sunriseComponents) else {
                return nil
            }
            return sunriseDate.timeIntervalSince(date)
        } else {
            let sunsetComponents = calendar.dateComponents([.hour, .minute, .second], from: sunset)
            guard let sunsetDate = calendar.date(from: sunsetComponents) else {
                return nil
            }
            return sunsetDate.timeIntervalSince(date)
        }
    }
    
    fileprivate func isNighttime(sunrise: Date, sunset: Date) -> Bool {
        let calendar = Calendar.current
        let currentMinutesFromMidnight = calendar.component(.hour, from: self) * 60 + calendar.component(.minute, from: self)
        let sunriseMinutesFromMidnight = calendar.component(.hour, from: sunrise) * 60 + calendar.component(.minute, from: sunrise)
        let sunsetMinutesFromMidnight = calendar.component(.hour, from: sunset) * 60 + calendar.component(.minute, from: sunset)
        return currentMinutesFromMidnight < sunriseMinutesFromMidnight || currentMinutesFromMidnight > sunsetMinutesFromMidnight
    }
}
