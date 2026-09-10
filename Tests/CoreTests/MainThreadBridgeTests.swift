import Foundation
import Testing
@testable import OneClickCore

@Test func mainThreadBridgeMovesDetachedWorkToTheMainThread() async {
    let ranOnMainThread = await Task.detached {
        MainThreadBridge.sync {
            Thread.isMainThread
        }
    }.value

    #expect(ranOnMainThread)
}

@Test
@MainActor
func mainThreadBridgeRunsInlineWhenAlreadyOnMainActor() {
    let ranOnMainThread = MainThreadBridge.sync {
        Thread.isMainThread
    }

    #expect(ranOnMainThread)
}
