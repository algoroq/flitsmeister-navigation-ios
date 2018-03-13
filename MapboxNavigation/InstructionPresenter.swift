import UIKit
import MapboxDirections

class InstructionPresenter {
    private let instruction: [VisualInstructionComponent]
    private weak var label: InstructionLabel?

    required init(_ instruction: [VisualInstructionComponent], label: InstructionLabel) {
        self.instruction = instruction
        self.label = label
    }

    typealias ShieldDownloadCompletion = (NSAttributedString) -> ()
    var onShieldDownload: ShieldDownloadCompletion?

    private let imageRepository = ImageRepository.shared
    
    func attributedText() -> NSAttributedString {
        let string = NSMutableAttributedString()
        fittedAttributedComponents().forEach { string.append($0) }
        return string
    }
    
    func fittedAttributedComponents() -> [NSAttributedString] {
        guard let label = self.label else { return [] }
        var attributedComponents = self.attributedComponents()
        let availableBounds = label.availableBounds()
        let totalWidth = attributedComponents.map { $0.size() }.reduce(.zero, +).width
        let stringFits = totalWidth <= availableBounds.width
        
        guard !stringFits else { return attributedComponents }
        
        let indexedComponents = instruction.enumerated().map { IndexedVisualInstructionComponent(component: $1, index: $0) }
        let filtered = indexedComponents.filter { $0.component.abbreviation != nil }
        let sorted = filtered.sorted { $0.component.abbreviationPriority < $1.component.abbreviationPriority }
        for component in sorted {
            let isFirst = component.index == 0
            let joinChar = isFirst ? "" : " "
            guard component.component.type == .text else { continue }
            guard let abbreviation = component.component.abbreviation else { continue }
            
            attributedComponents[component.index] = NSAttributedString(string: joinChar + abbreviation, attributes: attributesForLabel(label))
            let newWidth = attributedComponents.map { $0.size() }.reduce(.zero, +).width
            
            if newWidth <= availableBounds.width {
                break
            }
        }
        
        return attributedComponents
    }
    
    func attributedComponents() -> [NSAttributedString] {
        guard let label = self.label else { return [NSAttributedString()] }
        var strings = [NSAttributedString]()
        let components = instruction
        
        for component in components {
            let isFirst = component == instruction.first
            let joinChar = isFirst ? "" : " "
            
            if let shieldKey = component.shieldKey() {
                if let cachedImage = imageRepository.cachedImageForKey(shieldKey) {
                    strings.append(attributedString(withFont: label.font, shieldImage: cachedImage))
                } else {
                    // Display road code while shield is downloaded
                    if let text = component.text {
                        strings.append(NSAttributedString(string: joinChar + text, attributes: attributesForLabel(label)))
                    }
                    shieldImageForComponent(component, height: label.shieldHeight, completion: { [weak self] (image) in
                        guard image != nil else {
                            return
                        }
                        if let strongSelf = self, let completion = strongSelf.onShieldDownload {
                            completion(strongSelf.attributedText())
                        }
                    })
                }
            } else if let text = component.text {
                if component.type == .delimiter && instructionHasDownloadedAllShields() {
                    continue
                }
                strings.append(NSAttributedString(string: (joinChar + text), attributes: attributesForLabel(label)))
            }
        }
        
        return strings
    }

    private func shieldImageForComponent(_ component: VisualInstructionComponent, height: CGFloat, completion: @escaping (UIImage?) -> Void) {
        guard let imageURL = component.imageURL, let shieldKey = component.shieldKey() else {
            return
        }

        imageRepository.imageWithURL(imageURL, cacheKey: shieldKey, completion: { (image) in
            completion(image)
        })
    }

    private func instructionHasDownloadedAllShields() -> Bool {
        for component in instruction {
            guard let key = component.shieldKey() else {
                continue
            }

            if imageRepository.cachedImageForKey(key) == nil {
                return false
            }
        }
        return true
    }

    private func attributesForLabel(_ label: UILabel) -> [NSAttributedStringKey: Any] {
        return [.font: label.font, .foregroundColor: label.textColor]
    }

    private func attributedString(withFont font: UIFont, shieldImage: UIImage) -> NSAttributedString {
        let attachment = ShieldAttachment()
        attachment.font = font
        attachment.image = shieldImage
        return NSAttributedString(attachment: attachment)
    }

}

class ShieldAttachment: NSTextAttachment {

    var font: UIFont = UIFont.systemFont(ofSize: 17)

    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        guard let image = image else {
            return super.attachmentBounds(for: textContainer, proposedLineFragment: lineFrag, glyphPosition: position, characterIndex: charIndex)
        }
        let mid = font.descender + font.capHeight
        return CGRect(x: 0, y: font.descender - image.size.height / 2 + mid + 2, width: image.size.width, height: image.size.height).integral
    }
}

extension CGSize {
    fileprivate static var greatestFiniteSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    
    fileprivate static func +(lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width + rhs.width, height: lhs.height +  rhs.height)
    }
}


fileprivate struct IndexedVisualInstructionComponent {
    let component: Array<VisualInstructionComponent>.Element
    let index: Array<VisualInstructionComponent>.Index
}
