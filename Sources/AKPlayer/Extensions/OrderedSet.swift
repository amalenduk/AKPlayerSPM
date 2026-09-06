//
//  OrderedSet.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

// MARK: - OrderedSet

/// An ordered collection of unique elements maintaining insertion sequence.
public struct OrderedSet<Element: Hashable>: Sequence {
    
    // MARK: - Properties
    
    /// The backing array preserving ordered sequence.
    private var elements: [Element]
    
    /// The backing set enforcing element uniqueness and $O(1)$ existence lookups.
    private var set: Set<Element>
    
    /// The last element in the ordered set, if any.
    public var last: Element? {
        return elements.last
    }
    
    /// The first element in the ordered set, if any.
    public var first: Element? {
        return elements.first
    }
    
    /// The total number of unique elements stored in the set.
    public var count: Int {
        return elements.count
    }
    
    /// A Boolean value indicating whether the set contains no elements.
    public var isEmpty: Bool {
        return elements.isEmpty
    }
    
    // MARK: - Initialization
    
    /// Initializes an empty ordered set collection.
    public init() {
        self.elements = []
        self.set = Set()
    }
    
    // MARK: - Insertion & Lookup
    
    /// Inserts the specified element into the ordered set if it is not already present.
    /// - Parameter element: The element to append to the end of the collection.
    public mutating func insert(_ element: Element) {
        if set.insert(element).inserted {
            elements.append(element)
        }
    }
    
    /// Returns a Boolean value indicating whether the set contains the given element.
    /// - Parameter element: The element to search for in the collection.
    /// - Returns: `true` if the element exists; otherwise, `false`.
    public func contains(_ element: Element) -> Bool {
        return set.contains(element)
    }
    
    // MARK: - Sequence Protocol
    
    /// Returns an iterator over the ordered elements of the collection.
    public func makeIterator() -> IndexingIterator<[Element]> {
        return elements.makeIterator()
    }
    
    // MARK: - Removal Operations
    
    /// Removes and discards the first element from the ordered set.
    public mutating func removeFirst() {
        guard !elements.isEmpty else { return }
        let removedElement = elements.removeFirst()
        set.remove(removedElement)
    }
    
    /// Removes and discards the last element from the ordered set.
    public mutating func removeLast() {
        guard !elements.isEmpty else { return }
        let removedElement = elements.removeLast()
        set.remove(removedElement)
    }
    
    /// Removes all elements from the ordered set.
    public mutating func removeAll() {
        elements.removeAll()
        set.removeAll()
    }
    
    /// Removes the specified element from the set if present.
    /// - Parameter element: The element to remove.
    public mutating func remove(_ element: Element) {
        guard set.contains(element) else { return }
        elements.removeAll(where: { $0 == element })
        set.remove(element)
    }
}
