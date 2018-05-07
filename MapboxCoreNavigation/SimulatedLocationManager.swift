import Foundation
import MapboxDirections
import Turf

fileprivate let maximumSpeed: CLLocationSpeed = 30 // ~108 kmh
fileprivate let minimumSpeed: CLLocationSpeed = 6 // ~21 kmh
fileprivate var distanceFilter: CLLocationDistance = 10
fileprivate var verticalAccuracy: CLLocationAccuracy = 10
fileprivate var horizontalAccuracy: CLLocationAccuracy = 40
// minimumSpeed will be used when a location have maximumTurnPenalty
fileprivate let maximumTurnPenalty: CLLocationDirection = 90
// maximumSpeed will be used when a location have minimumTurnPenalty
fileprivate let minimumTurnPenalty: CLLocationDirection = 0
// Go maximum speed if distance to nearest coordinate is >= `safeDistance`
fileprivate let safeDistance: CLLocationDistance = 50

fileprivate class SimulatedLocation: CLLocation {
    var turnPenalty: Double = 0
    
    override var description: String {
        return "\(super.description) \(turnPenalty)"
    }
}

/**
 The `SimulatedLocationManager` class simulates location updates along a given route.
 
 The route will be replaced upon a `RouteControllerDidReroute` notification.
 */
@objc(MBSimulatedLocationManager)
open class SimulatedLocationManager: NavigationLocationManager {
    fileprivate var currentDistance: CLLocationDistance = 0
    fileprivate var currentLocation = CLLocation()
    fileprivate var currentSpeed: CLLocationSpeed = 30
    
    fileprivate var locations: [SimulatedLocation]!
    fileprivate var routeLine = [CLLocationCoordinate2D]()
    
    /**
     Specify the multiplier to use when calculating speed based on the RouteLeg’s `expectedSegmentTravelTimes`.
     */
    @objc public var speedMultiplier: Double = 1
    
    @objc override open var location: CLLocation? {
        get {
            return currentLocation
        }
    }
    
    var route: Route? {
        didSet {
            reset()
        }
    }
    
    var routeProgress: RouteProgress?
    
    /**
     Initalizes a new `SimulatedLocationManager` with the given route.
     
     - parameter route: The initial route.
     - returns: A `SimulatedLocationManager`
     */
    @objc public init(route: Route) {
        super.init()
        initializeSimulatedLocationManager(for: route, currentDistance: 0, currentSpeed: 30)
    }

    /**
     Initalizes a new `SimulatedLocationManager` with the given routeProgress.
     
     - parameter routeProgress: The routeProgress of the current route.
     - returns: A `SimulatedLocationManager`
     */
    @objc public init(routeProgress: RouteProgress) {
        super.init()
        let currentDistance = calculateCurrentDistance(routeProgress.distanceTraveled)
        initializeSimulatedLocationManager(for: routeProgress.route, currentDistance: currentDistance, currentSpeed: 0)
    }

    private func initializeSimulatedLocationManager(for route: Route, currentDistance: CLLocationDistance, currentSpeed: CLLocationSpeed) {
        
        self.currentSpeed = currentSpeed
        self.currentDistance = currentDistance
        self.route = route
        
        NotificationCenter.default.addObserver(self, selector: #selector(didReroute(_:)), name: .routeControllerDidReroute, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .routeControllerProgressDidChange, object: nil)
    }
    
    private func reset() {
        if let coordinates = route?.coordinates {
            routeLine = coordinates
            locations = coordinates.simulatedLocationsWithTurnPenalties()
        }
    }
    
    private func calculateCurrentDistance(_ distance: CLLocationDistance) -> CLLocationDistance {
        return distance + (currentSpeed * speedMultiplier)
    }
    
    @objc private func progressDidChange(_ notification: Notification) {
        routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress
    }
    
    @objc private func didReroute(_ notification: Notification) {
        guard let routeController = notification.object as? RouteController else {
            return
        }
        
        route = routeController.routeProgress.route
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidReroute, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
    }
    
    override open func startUpdatingLocation() {
        DispatchQueue.main.async(execute: tick)
    }
    
    override open func stopUpdatingLocation() {
        DispatchQueue.main.async {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.tick), object: nil)
        }
    }
    
    @objc fileprivate func tick() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(tick), object: nil)
        
        let polyline = Polyline(routeLine)
        
        guard let newCoordinate = polyline.coordinateFromStart(distance: currentDistance) else {
            return
        }
        
        // Closest coordinate ahead
        guard let lookAheadCoordinate = polyline.coordinateFromStart(distance: currentDistance + 10) else { return }
        guard let closestCoordinate = polyline.closestCoordinate(to: newCoordinate) else { return }
        
        let closestLocation = locations[closestCoordinate.index]
        let distanceToClosest = closestLocation.distance(from: CLLocation(newCoordinate))
        
        let distance = min(max(distanceToClosest, 10), safeDistance)
        let coordinatesNearby = polyline.trimmed(from: newCoordinate, distance: 100).coordinates
        
        currentSpeed = CLLocationSpeed(NSNotFound)
        
        // Simulate speed based on expected segment travel time
        if let expectedSegmentTravelTimes = routeProgress?.currentLeg.expectedSegmentTravelTimes,
            let coordinates = routeProgress?.route.coordinates,
            let closestCoordinateOnRoute = Polyline(routeProgress!.route.coordinates!).closestCoordinate(to: newCoordinate),
            let time = expectedSegmentTravelTimes.optional[closestCoordinateOnRoute.index] {
            
            let closestCoordinateOnRouteIndex = closestCoordinateIndex(from: closestCoordinateOnRoute.index,
                                                                coordinates: coordinates)
            
            if let nextCoordinateOnRoute = coordinates.after(element: coordinates[closestCoordinateOnRouteIndex]) {
                let distance = coordinates[closestCoordinateOnRouteIndex].distance(to: nextCoordinateOnRoute)
                currentSpeed = distance / time
            }
        }
        
        if currentSpeed == CLLocationSpeed(NSNotFound) {
            currentSpeed = calculateCurrentSpeed(distance: distance, coordinatesNearby: coordinatesNearby, closestLocation: closestLocation)
        }
        
        let location = CLLocation(coordinate: newCoordinate,
                                  altitude: 0,
                                  horizontalAccuracy: horizontalAccuracy,
                                  verticalAccuracy: verticalAccuracy,
                                  course: newCoordinate.direction(to: lookAheadCoordinate).wrap(min: 0, max: 360),
                                  speed: currentSpeed,
                                  timestamp: Date())
        currentLocation = location
        lastKnownLocation = location
        
        delegate?.locationManager?(self, didUpdateLocations: [currentLocation])
        currentDistance = calculateCurrentDistance(currentDistance)
        perform(#selector(tick), with: nil, afterDelay: 1)
    }
    
    private func closestCoordinateIndex(from startIndex: Int, coordinates: [CLLocationCoordinate2D]) -> Int {
        let endIndex = coordinates.endIndex - 1

        guard startIndex < endIndex else {
            return endIndex
        }
        
        // In case current coordinate and successive coordinate have identical latitude and longitude,
        // Advance to the next coordinate with an unidentical coordinate to the current coordinate.
        for i in startIndex...endIndex {
            let currentCoordinate = coordinates[i]
            let nextCoordinate = coordinates.after(element: coordinates[i])
            if let nextCoordinate = nextCoordinate, nextCoordinate != currentCoordinate {
                return i
            }
        }

        return endIndex
    }
    
    private func calculateCurrentSpeed(distance: CLLocationDistance, coordinatesNearby: [CLLocationCoordinate2D]? = nil, closestLocation: SimulatedLocation? = nil) -> CLLocationSpeed {

        // More than 10 nearby coordinates indicates that we are in a roundabout or similar complex shape.
        if let coordinatesNearby = coordinatesNearby, coordinatesNearby.count >= 10 {
            return minimumSpeed
        }
        // Maximum speed if we are a safe distance from the closest coordinate
        else if distance >= safeDistance {
            return maximumSpeed
        }
        // Base speed on previous or upcoming turn penalty
        else if let closestLocation = closestLocation {
            let reversedTurnPenalty = maximumTurnPenalty - closestLocation.turnPenalty
            return reversedTurnPenalty.scale(minimumIn: minimumTurnPenalty, maximumIn: maximumTurnPenalty, minimumOut: minimumSpeed, maximumOut: maximumSpeed)
        }
        
        // default speed
        return 0.0
    }
}

extension Double {
    fileprivate func scale(minimumIn: Double, maximumIn: Double, minimumOut: Double, maximumOut: Double) -> Double {
        return ((maximumOut - minimumOut) * (self - minimumIn) / (maximumIn - minimumIn)) + minimumOut
    }
}

extension CLLocation {
    fileprivate convenience init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

extension Array where Element : Hashable {
    fileprivate struct OptionalSubscript {
        var elements: [Element]
        subscript (index: Int) -> Element? {
            return index < elements.count ? elements[index] : nil
        }
    }
    
    fileprivate var optional: OptionalSubscript {
        get { return OptionalSubscript(elements: self) }
    }
}

extension Array where Element : Equatable {
    fileprivate func after(element: Element) -> Element? {
        if let index = self.index(of: element), index + 1 <= self.count {
            return index + 1 == self.count ? self[0] : self[index + 1]
        }
        return nil
    }
}

extension Array where Element == CLLocationCoordinate2D {
    
    // Calculate turn penalty for each coordinate.
    fileprivate func simulatedLocationsWithTurnPenalties() -> [SimulatedLocation] {
        var locations = [SimulatedLocation]()
        
        for (coordinate, nextCoordinate) in zip(prefix(upTo: endIndex - 1), suffix(from: 1)) {
            let currentCoordinate = locations.isEmpty ? first! : coordinate
            let course = coordinate.direction(to: nextCoordinate).wrap(min: 0, max: 360)
            let turnPenalty = currentCoordinate.direction(to: coordinate).difference(from: coordinate.direction(to: nextCoordinate))
            let location = SimulatedLocation(coordinate: coordinate,
                                             altitude: 0,
                                             horizontalAccuracy: horizontalAccuracy,
                                             verticalAccuracy: verticalAccuracy,
                                             course: course,
                                             speed: minimumSpeed,
                                             timestamp: Date())
            location.turnPenalty = Swift.max(Swift.min(turnPenalty, maximumTurnPenalty), minimumTurnPenalty)
            locations.append(location)
        }
        
        locations.append(SimulatedLocation(coordinate: last!,
                                           altitude: 0,
                                           horizontalAccuracy: horizontalAccuracy,
                                           verticalAccuracy: verticalAccuracy,
                                           course: locations.last!.course,
                                           speed: minimumSpeed,
                                           timestamp: Date()))
        
        return locations
    }
}
