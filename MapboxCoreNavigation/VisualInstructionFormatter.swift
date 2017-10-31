import Foundation
import MapboxDirections

/**
 Formatter for creating visual instructions.
 */
@objc(MBVisualInstructionFormatter)
public class VisualInstructionFormatter: NSObject {
    
    let routeStepFormatter = RouteStepFormatter()
    
    /**
     Creates the optimal text to be displayed given a `RouteLeg` and `RouteStep`.
     */
    public func string(leg: RouteLeg?, step: RouteStep?) -> String? {
        if let currentLeg = leg, let destinationName = currentLeg.destination.name, let step = step, step.maneuverType == .arrive {
            return destinationName
        } else if let destinations = step?.destinations {
            return destinations.joined(separator: NSLocalizedString("DESTINATION_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between multiple destinations"))
        } else if let step = step, step.isNumberedMotorway, let codes = step.codes {
            return codes.joined(separator: NSLocalizedString("REF_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between route numbers in a road concurrency"))
        } else if let name = step?.names?.first {
            return name
        } else if let step = step {
            return routeStepFormatter.string(for: step)
        } else {
            return nil
        }
    }
    
    /**
     Creates the optimal text to be displayed given a `RouteLeg` and `RouteStep` divided into primary and secondary string.
     */
    public func strings(leg: RouteLeg?, step: RouteStep?) -> (String?, String?) {
        if let currentLeg = leg, let destinationName = currentLeg.destination.name, let step = step, step.maneuverType == .arrive {
            let primary = NSLocalizedString("ARRIVED_AT_DESTINATION", bundle: .mapboxCoreNavigation, value: "You have arrived", comment: "Instruction when arrived at a destination")
            return(primary, destinationName)
        } else if let step = step, let codes = step.destinationCodes {
            let primary = codes.joined(separator: NSLocalizedString("REF_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between route numbers in a road concurrency"))
            let secondary = step.destinations?.joined(separator: NSLocalizedString("DESTINATION_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between multiple destinations"))
            return (primary, secondary)
        } else if let step = step, step.isNumberedMotorway, let codes = step.codes {
            let primary = codes.joined(separator: NSLocalizedString("REF_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between route numbers in a road concurrency"))
            let secondary = step.destinations?.joined(separator: NSLocalizedString("DESTINATION_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between multiple destinations"))
            return (primary, secondary)
        } else if let destinations = step?.destinations ?? step?.names {
            let primary = destinations.first
            let secondary = destinations.suffix(from: 1).joined(separator: NSLocalizedString("DESTINATION_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between multiple destinations"))
            return (primary, secondary)
        } else {
            return (step?.instructions, nil)
        }
    }
    
    /**
     Creates the optimal instructions to be displayed given a `RouteLeg` and `RouteStep` divided into primary and secondary `Instruction`.
     */
    public func instructions(leg: RouteLeg?, step: RouteStep?) -> (Instruction?, Instruction?) {
        if let currentLeg = leg, let destinationName = currentLeg.destination.name, let step = step, step.maneuverType == .arrive {
            return (Instruction([.init(NSLocalizedString("ARRIVED_AT_DESTINATION", bundle: .mapboxCoreNavigation, value: "You have arrived", comment: "Instruction when arrived at a destination"))]),
                    Instruction([.init(destinationName)]))
        } else if let step = step, let codes = step.destinationCodes {
            let primary = codes.joined(separator: NSLocalizedString("REF_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between route numbers in a road concurrency"))
            let secondary = step.destinations?.joined(separator: NSLocalizedString("DESTINATION_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between multiple destinations"))
            let roadCode = step.codes?.first ?? step.destinationCodes?.first ?? step.destinations?.first
            return (Instruction([.init(primary, png: nil, roadCode: roadCode)]), Instruction([.init(secondary)]))
        } else if let step = step, step.isNumberedMotorway, let codes = step.codes {
            let primary = codes.joined(separator: NSLocalizedString("REF_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between route numbers in a road concurrency"))
            let secondary = step.destinations?.joined(separator: NSLocalizedString("DESTINATION_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between multiple destinations"))
            let roadCode = step.codes?.first ?? step.destinationCodes?.first ?? step.destinations?.first
            return (Instruction([.init(primary, png: nil, roadCode: roadCode)]), Instruction([.init(secondary)]))
        } else if let destinations = step?.destinations, let names = step?.names {
            let primary = names.first
            let secondary = destinations.suffix(from: 1).joined(separator: NSLocalizedString("DESTINATION_DELIMITER", bundle: .mapboxCoreNavigation, value: " / ", comment: "Delimiter between multiple destinations"))
            return (Instruction([.init(primary)]), Instruction([.init(secondary)]))
        } else if let name = step?.names?.first {
            return (Instruction([.init(name)]), nil)
        } else {
            return (Instruction([.init(step?.instructions)]), nil)
        }
    }
}
