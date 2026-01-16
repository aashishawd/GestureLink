/// DebounceController implements a stability mechanism for any Equatable value.
/// It requires the same value to be received for a specified number of consecutive
/// frames before triggering an action.
class DebounceController<T: Equatable> {
    
    // MARK: - Properties
    
    private let requiredConsecutiveCount: Int
    private var consecutiveCount = 0
    private var lastValue: T?
    private var hasTriggered = false
    
    /// Callback when a value is confirmed stable
    var onStableValueDetected: ((T) -> Void)?
    
    // MARK: - Initialization
    
    init(requiredFrames: Int = 5) {
        self.requiredConsecutiveCount = requiredFrames
    }
    
    // MARK: - Processing
    
    /// Process a new value
    /// - Parameter value: The current value to debounce (e.g. current gesture)
    /// - Parameter isPositive: Whether this value counts as a "positive" detection (e.g. gesture != .None)
    func process(_ value: T, isPositive: Bool) {
        if isPositive {
            if value == lastValue {
                consecutiveCount += 1
            } else {
                consecutiveCount = 1
                lastValue = value
                hasTriggered = false
            }
            
            if consecutiveCount >= requiredConsecutiveCount && !hasTriggered {
                hasTriggered = true
                onStableValueDetected?(value)
            }
        } else {
            reset()
        }
    }
    
    func reset() {
        consecutiveCount = 0
        lastValue = nil
        hasTriggered = false
    }
    
    var progress: Float {
        Float(consecutiveCount) / Float(requiredConsecutiveCount)
    }
}

