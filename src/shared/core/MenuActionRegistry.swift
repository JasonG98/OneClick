struct MenuActionSnapshot: Sendable {
    let selection: SelectionContext
    let target: OpenTarget?
}

struct MenuActionRegistry {
    private let capacity: Int
    private var nextTag = 1
    private var actions: [Int: MenuActionSnapshot] = [:]
    private var insertionOrder: [Int] = []

    init(capacity: Int = 256) {
        self.capacity = max(1, capacity)
    }

    mutating func insert(selection: SelectionContext, target: OpenTarget?) -> Int {
        let tag = nextTag
        nextTag += 1

        if insertionOrder.count == capacity, let oldestTag = insertionOrder.first {
            actions.removeValue(forKey: oldestTag)
            insertionOrder.removeFirst()
        }
        actions[tag] = MenuActionSnapshot(selection: selection, target: target)
        insertionOrder.append(tag)
        return tag
    }

    func action(for tag: Int) -> MenuActionSnapshot? {
        actions[tag]
    }
}
