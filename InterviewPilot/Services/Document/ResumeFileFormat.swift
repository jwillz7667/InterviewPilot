import Foundation
import UniformTypeIdentifiers

enum ResumeFileFormat: String, Sendable {
    case pdf
    case rtf
    case plainText
    case markdown

    nonisolated static var allowedContentTypes: [UTType] {
        var types: [UTType] = [.pdf, .rtf, .plainText]
        if let md = UTType("net.daringfireball.markdown") {
            types.append(md)
        }
        types.append(.text)
        return types
    }

    nonisolated static func detect(filename: String?, data: Data) -> ResumeFileFormat? {
        if let ext = filename?.split(separator: ".").last.map(String.init)?.lowercased() {
            switch ext {
            case "pdf": return .pdf
            case "rtf": return .rtf
            case "md", "markdown": return .markdown
            case "txt", "text": return .plainText
            default: break
            }
        }
        return sniff(data: data)
    }

    nonisolated private static func sniff(data: Data) -> ResumeFileFormat? {
        let head = data.prefix(8)
        if head.starts(with: [0x25, 0x50, 0x44, 0x46]) {  // "%PDF"
            return .pdf
        }
        if head.starts(with: [0x7B, 0x5C, 0x72, 0x74, 0x66]) {  // "{\\rtf"
            return .rtf
        }
        if String(data: data.prefix(4096), encoding: .utf8) != nil {
            return .plainText
        }
        return nil
    }
}
