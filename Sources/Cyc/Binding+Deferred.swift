import SwiftUI

extension Binding {
    /// The same binding, but writes land a moment later, on the next turn of
    /// the main run loop.
    ///
    /// Some macOS controls (segmented pickers, pop-up pickers, color wells)
    /// write their value back while SwiftUI is still drawing the window. When
    /// that value lives in an `ObservableObject`, the write publishes a change
    /// mid-draw and Xcode logs "Publishing changes from within view updates is
    /// not allowed". Deferring the write moves it after the draw.
    func deferredWrites() -> Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                DispatchQueue.main.async { wrappedValue = newValue }
            })
    }
}
