import Foundation

struct FixedSizeRingBuffer<Element> {
    let capacity: Int

    private var storage: ContiguousArray<Element?>
    private var writeIndex = 0
    private(set) var count = 0

    init(capacity: Int) {
        precondition(capacity > 0, "Capacity must be greater than zero.")
        self.capacity = capacity
        storage = ContiguousArray(repeating: nil, count: capacity)
    }

    var isEmpty: Bool {
        count == 0
    }

    var latest: Element? {
        guard count > 0 else {
            return nil
        }

        let latestIndex = (writeIndex - 1 + capacity) % capacity
        return storage[latestIndex]
    }

    mutating func append(_ element: Element) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    mutating func removeAll(keepingCapacity keepCapacity: Bool = true) {
        if keepCapacity {
            storage = ContiguousArray(repeating: nil, count: capacity)
        } else {
            storage.removeAll(keepingCapacity: false)
            storage = ContiguousArray(repeating: nil, count: capacity)
        }

        writeIndex = 0
        count = 0
    }

    func values() -> [Element] {
        guard count > 0 else {
            return []
        }

        let startIndex = count == capacity ? writeIndex : 0
        var result: [Element] = []
        result.reserveCapacity(count)

        for offset in 0..<count {
            let index = (startIndex + offset) % capacity
            if let value = storage[index] {
                result.append(value)
            }
        }

        return result
    }
}

extension FixedSizeRingBuffer: Sendable where Element: Sendable {}
