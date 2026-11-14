import UIKit

/// Preserve a focused text input's selection without resigning first responder,
/// assigning its text, or interrupting an active IME composition.
@MainActor
struct TextInputSnapshot {
    private let view: UIView
    private let input: any UITextInput
    private let text: String
    private let startOffset: Int
    private let endOffset: Int

    static func capture(in view: UIView) -> TextInputSnapshot? {
        if view.isFirstResponder,
           let input = view as? any UITextInput,
           input.markedTextRange == nil,
           let selection = input.selectedTextRange,
           let document = input.textRange(from: input.beginningOfDocument, to: input.endOfDocument),
           let text = input.text(in: document) {
            return TextInputSnapshot(view: view, input: input, text: text,
                                     startOffset: input.offset(from: input.beginningOfDocument, to: selection.start),
                                     endOffset: input.offset(from: input.beginningOfDocument, to: selection.end))
        }
        for child in view.subviews {
            if let snapshot = capture(in: child) { return snapshot }
        }
        return nil
    }

    func restoreIfUnchanged() {
        guard view.isFirstResponder, input.markedTextRange == nil,
              let document = input.textRange(from: input.beginningOfDocument, to: input.endOfDocument),
              input.text(in: document) == text,
              let start = input.position(from: input.beginningOfDocument, offset: startOffset),
              let end = input.position(from: input.beginningOfDocument, offset: endOffset),
              let range = input.textRange(from: start, to: end) else { return }
        input.selectedTextRange = range
    }
}
