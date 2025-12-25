//
//  OrderedSetSortedInsert.swift
//  Mousecape
//
//  Swift replacement for NSOrderedSet+AZSortedInsert
//  Provides binary search insertion for maintaining sorted collections
//

import Foundation

// MARK: - Swift Array Extension (Preferred)

extension Array where Element: Comparable {

    /// Find the index where an element should be inserted to maintain sort order
    /// Uses binary search for O(log n) performance
    /// - Parameter element: The element to insert
    /// - Returns: The index where the element should be inserted
    func sortedInsertionIndex(for element: Element) -> Int {
        var low = 0
        var high = count

        while low < high {
            let mid = (low + high) / 2
            if self[mid] < element {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return low
    }

    /// Insert an element while maintaining sort order
    /// - Parameter element: The element to insert
    mutating func insertSorted(_ element: Element) {
        let index = sortedInsertionIndex(for: element)
        insert(element, at: index)
    }
}

extension Array {

    /// Find the index where an element should be inserted to maintain sort order
    /// Uses binary search for O(log n) performance
    /// - Parameters:
    ///   - element: The element to insert
    ///   - areInIncreasingOrder: A comparison closure
    /// - Returns: The index where the element should be inserted
    func sortedInsertionIndex(for element: Element, by areInIncreasingOrder: (Element, Element) -> Bool) -> Int {
        var low = 0
        var high = count

        while low < high {
            let mid = (low + high) / 2
            if areInIncreasingOrder(self[mid], element) {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return low
    }

    /// Insert an element while maintaining sort order
    /// - Parameters:
    ///   - element: The element to insert
    ///   - areInIncreasingOrder: A comparison closure
    mutating func insertSorted(_ element: Element, by areInIncreasingOrder: (Element, Element) -> Bool) {
        let index = sortedInsertionIndex(for: element, by: areInIncreasingOrder)
        insert(element, at: index)
    }
}

// MARK: - NSOrderedSet Extension (For ObjC compatibility)

extension NSOrderedSet {

    /// Find the index where an object should be inserted to maintain sort order
    /// - Parameters:
    ///   - object: The object to insert
    ///   - comparator: A comparator closure
    /// - Returns: The index where the object should be inserted
    func indexForInsertingObject(_ object: Any, using comparator: (Any, Any) -> ComparisonResult) -> Int {
        var low = 0
        var high = count

        while low < high {
            let mid = (low + high) / 2
            let testObject = self.object(at: mid)
            if comparator(object, testObject) == .orderedDescending {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return low
    }

    /// Find the index where an object should be inserted using sort descriptors
    /// - Parameters:
    ///   - object: The object to insert
    ///   - descriptors: Array of sort descriptors
    /// - Returns: The index where the object should be inserted
    func indexForInsertingObject(_ object: Any, using descriptors: [NSSortDescriptor]) -> Int {
        return indexForInsertingObject(object) { a, b in
            for descriptor in descriptors {
                let result = descriptor.compare(a, to: b)
                if result != .orderedSame {
                    return result
                }
            }
            return .orderedSame
        }
    }
}

extension NSMutableOrderedSet {

    /// Insert an object while maintaining sort order
    /// - Parameters:
    ///   - object: The object to insert
    ///   - comparator: A comparator closure
    func insertSorted(_ object: Any, using comparator: (Any, Any) -> ComparisonResult) {
        let index = indexForInsertingObject(object, using: comparator)
        insert(object, at: index)
    }

    /// Insert an object while maintaining sort order using sort descriptors
    /// - Parameters:
    ///   - object: The object to insert
    ///   - descriptors: Array of sort descriptors
    func insertSorted(_ object: Any, using descriptors: [NSSortDescriptor]) {
        let index = indexForInsertingObject(object, using: descriptors)
        insert(object, at: index)
    }
}
