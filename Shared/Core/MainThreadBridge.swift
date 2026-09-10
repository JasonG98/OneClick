import Dispatch
import Foundation

enum MainThreadBridge {
    nonisolated static func sync<Value: Sendable>(
        _ operation: @escaping @MainActor @Sendable () -> Value
    ) -> Value {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                operation()
            }
        }

        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                operation()
            }
        }
    }
}
