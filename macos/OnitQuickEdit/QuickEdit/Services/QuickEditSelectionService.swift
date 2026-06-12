//
//  QuickEditSelectionService.swift
//  Onit
//
//  Created by Kévin Naudin on 12/08/2025.
//

import Foundation
import AppKit
import Combine

enum SegmentVersionSource: Equatable {
    case initial
    case retry
    case aiEdit(instruction: String)
}

struct SegmentVersion: Identifiable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    let source: SegmentVersionSource

    init(id: UUID = UUID(), text: String, source: SegmentVersionSource) {
        self.id = id
        self.text = text
        self.createdAt = Date()
        self.source = source
    }
}

struct TextSegment: Identifiable, Equatable {
    let id: UUID
    var range: NSRange
    var isFrozen: Bool
    var versions: [SegmentVersion]
    var currentVersionIndex: Int

    var currentVersion: SegmentVersion? {
        guard currentVersionIndex >= 0, currentVersionIndex < versions.count else { return nil }
        return versions[currentVersionIndex]
    }

    var currentText: String {
        currentVersion?.text ?? ""
    }

    var hasMultipleVersions: Bool {
        versions.count > 1
    }

    init(id: UUID = UUID(), range: NSRange, text: String, isFrozen: Bool = false) {
        self.id = id
        self.range = range
        self.isFrozen = isFrozen
        self.versions = [SegmentVersion(text: text, source: .initial)]
        self.currentVersionIndex = 0
    }

    mutating func addVersion(text: String, source: SegmentVersionSource) {
        let newVersion = SegmentVersion(text: text, source: source)
        versions.append(newVersion)
        currentVersionIndex = versions.count - 1
    }

    mutating func navigateToVersion(_ index: Int) -> Bool {
        guard index >= 0, index < versions.count else { return false }
        currentVersionIndex = index
        return true
    }
}

struct TextSnapshot: Identifiable, Equatable, Codable {
    let id: UUID
    let fullText: String
    let instruction: String?
    let segments: [TextSegment]
    let frozenRanges: [NSRange]
    let createdAt: Date

    init(id: UUID = UUID(), fullText: String, instruction: String?, segments: [TextSegment], frozenRanges: [NSRange]) {
        self.id = id
        self.fullText = fullText
        self.instruction = instruction
        self.segments = segments
        self.frozenRanges = frozenRanges
        self.createdAt = Date()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, fullText, instruction, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fullText = try container.decode(String.self, forKey: .fullText)
        instruction = try container.decodeIfPresent(String.self, forKey: .instruction)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        segments = []
        frozenRanges = []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullText, forKey: .fullText)
        try container.encodeIfPresent(instruction, forKey: .instruction)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - QuickEditSelectionService

@MainActor
class QuickEditSelectionService: ObservableObject {

    static let shared = QuickEditSelectionService()

    // MARK: - Published State

    @Published private(set) var fullText: String = ""
    @Published private(set) var segments: [TextSegment] = []
    @Published private(set) var frozenRanges: [NSRange] = []
    @Published private(set) var globalHistory: [TextSnapshot] = []
    @Published private(set) var globalHistoryIndex: Int = -1
    @Published var selectedRanges: [NSRange] = []
    @Published private(set) var isRegenerating: Bool = false
    @Published private(set) var regeneratingRanges: [NSRange] = []
    @Published private(set) var isUpdatingFromOperation: Bool = false

    // MARK: - Computed Properties

    var hasFrozenText: Bool { !frozenRanges.isEmpty }
    var frozenSegmentCount: Int { frozenRanges.count }
    var modifiedRanges: [NSRange] { segments.filter { $0.hasMultipleVersions }.map { $0.range } }
    var globalHistoryPosition: (current: Int, total: Int) { (globalHistoryIndex + 1, globalHistory.count) }
    var canNavigateGlobalBack: Bool { globalHistoryIndex > 0 }
    var canNavigateGlobalForward: Bool { globalHistoryIndex < globalHistory.count - 1 }

    private init() {}

    // MARK: - Initialization

    func initialize(with text: String) {
        reset()
        fullText = text
        createInitialSnapshot()
    }

    func reset() {
        fullText = ""
        segments = []
        frozenRanges = []
        globalHistory = []
        globalHistoryIndex = -1
        selectedRanges = []
        isRegenerating = false
        regeneratingRanges = []
    }

    func restoreSnapshots(from snapshots: [TextSnapshot]) {
        guard !snapshots.isEmpty else { return }

        /// Restore global history snapshots.
        globalHistory = snapshots
        /// Point to the most recent snapshot (last entry).
        globalHistoryIndex = snapshots.count - 1

        /// Restore current state from latest snapshot.
        let mostRecentSnapshot = snapshots[globalHistoryIndex]
        fullText = mostRecentSnapshot.fullText
        segments = []
        frozenRanges = []
        selectedRanges = []
        isRegenerating = false
        regeneratingRanges = []
    }

    func updateText(_ newText: String) {
        fullText = newText
        adjustSegmentRanges()
    }

    // MARK: - Selection

    func updateSelection(_ ranges: [NSRange]) {
        DispatchQueue.main.async { [weak self] in
            self?.selectedRanges = ranges
        }
    }

    /// Returns the context around a specific range (text before, selected text, text after)
    func getContextForRange(_ range: NSRange) -> (before: String, selected: String, after: String)? {
        guard range.location + range.length <= fullText.count else { return nil }

        let nsString = fullText as NSString
        let before = nsString.substring(to: range.location)
        let selected = nsString.substring(with: range)
        let after = nsString.substring(from: range.location + range.length)

        return (before, selected, after)
    }

    func isEntireTextSelected() -> Bool {
        guard selectedRanges.count == 1, let range = selectedRanges.first else { return false }
        return range.location == 0 && range.length == fullText.count
    }

    // MARK: - Segments

    func getSegmentVersionInfo(for range: NSRange) -> (current: Int, total: Int)? {
        guard let segment = segments.first(where: { $0.range == range }),
              segment.hasMultipleVersions else {
            return nil
        }
        return (segment.currentVersionIndex + 1, segment.versions.count)
    }

    func navigateSegmentVersion(for range: NSRange, to index: Int) -> TextSegment? {
        guard let segmentIndex = segments.firstIndex(where: { $0.range == range }) else {
            return nil
        }

        let success = segments[segmentIndex].navigateToVersion(index)
        if success {
            isUpdatingFromOperation = true
            updateFullTextFromSegment(segmentIndex)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.isUpdatingFromOperation = false
            }
            return segments[segmentIndex]
        }
        return nil
    }

    func setUpdatingFromOperation(_ value: Bool) {
        isUpdatingFromOperation = value
        if value {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isUpdatingFromOperation = false
            }
        }
    }

    // MARK: - Freeze

    func selectionContainsFrozenText() -> Bool {
        guard !selectedRanges.isEmpty else { return false }

        for selectedRange in selectedRanges {
            for frozenRange in frozenRanges {
                if NSIntersectionRange(selectedRange, frozenRange).length > 0 {
                    return true
                }
            }
        }
        return false
    }

    func freezeSelection() -> Bool {
        guard !selectedRanges.isEmpty, !isEntireTextSelected() else { return false }

        for range in selectedRanges {
            clearSegmentHistory(for: range)

            if let existingIndex = frozenRanges.firstIndex(where: { NSIntersectionRange($0, range).length > 0 }) {
                let existing = frozenRanges[existingIndex]
                let newLocation = min(existing.location, range.location)
                let newEnd = max(NSMaxRange(existing), NSMaxRange(range))
                frozenRanges[existingIndex] = NSRange(location: newLocation, length: newEnd - newLocation)
            } else {
                frozenRanges.append(range)
            }
        }

        mergeFrozenRanges()
        return true
    }

    func unfreeze(range: NSRange) {
        frozenRanges.removeAll { $0 == range }
    }

    /// Unfreezes any frozen range that contains the given location
    func unfreezeContaining(location: Int) {
        frozenRanges.removeAll { NSLocationInRange(location, $0) }
    }

    /// Adjusts all frozen and modified ranges after an edit at the given location
    /// - Parameters:
    ///   - editLocation: The location where the edit occurred
    ///   - lengthDelta: The change in length (positive for insertion, negative for deletion)
    func adjustRangesAfterEdit(editLocation: Int, lengthDelta: Int) {
        guard lengthDelta != 0 else { return }

        // Adjust frozen ranges
        frozenRanges = frozenRanges.compactMap { range in
            adjustRange(range, editLocation: editLocation, lengthDelta: lengthDelta)
        }

        // Adjust segment ranges (which affects modifiedRanges)
        segments = segments.compactMap { segment in
            guard let newRange = adjustRange(segment.range, editLocation: editLocation, lengthDelta: lengthDelta) else {
                return nil
            }
            var updatedSegment = segment
            updatedSegment.range = newRange
            return updatedSegment
        }
    }

    /// Helper to adjust a single range based on an edit
    private func adjustRange(_ range: NSRange, editLocation: Int, lengthDelta: Int) -> NSRange? {
        if range.location > editLocation {
            // Range is after the edit - shift it
            let newLocation = range.location + lengthDelta
            guard newLocation >= 0 else { return nil }
            return NSRange(location: newLocation, length: range.length)
        } else if range.location + range.length > editLocation {
            // Edit is inside the range - adjust the length
            let newLength = range.length + lengthDelta
            guard newLength > 0 else { return nil }
            return NSRange(location: range.location, length: newLength)
        }
        // Range is before the edit - no change
        return range
    }

    func unfreezeAll() {
        frozenRanges.removeAll()
    }

    // MARK: - Regeneration

    func startRegeneration(for range: NSRange? = nil) {
        isRegenerating = true
        if let range = range {
            regeneratingRanges = [range]
        } else if let firstSelected = selectedRanges.first {
            regeneratingRanges = [firstSelected]
        } else {
            regeneratingRanges = []
        }
    }

    func endRegeneration() {
        isRegenerating = false
        regeneratingRanges = []
    }

    func getFrozenTexts() -> [String] {
        frozenRanges.map { (fullText as NSString).substring(with: $0) }
    }

    func updateSegmentWithNewVersion(range: NSRange, newText: String, source: SegmentVersionSource, instruction: String?) -> TextSegment? {
        let updatedSegment = updateSegmentWithNewVersionInternal(range: range, newText: newText, source: source)
        createGlobalSnapshot(instruction: instruction)
        return updatedSegment
    }

    func updateAfterGlobalRegeneration(newText: String, previousFrozenTexts: [String], instruction: String?) {
        fullText = newText
        updateFrozenRangesAfterRegeneration(frozenTexts: previousFrozenTexts, newText: newText)
        clearNonFrozenSegmentHistory()
        createGlobalSnapshot(instruction: instruction)
    }

    private func updateFrozenRangesAfterRegeneration(frozenTexts: [String], newText: String) {
        let nsString = newText as NSString
        frozenRanges = frozenTexts.compactMap { frozenText in
            let range = nsString.range(of: frozenText)
            return range.location != NSNotFound ? range : nil
        }
    }

    // MARK: - Global Regeneration

    func startGlobalRegeneration() {
        isRegenerating = true
        regeneratingRanges = getNonFrozenRanges()
    }

    func endGlobalRegeneration() {
        isRegenerating = false
        regeneratingRanges = []
    }

    func createGlobalSnapshotPublic(instruction: String?) {
        createGlobalSnapshot(instruction: instruction)
    }

    // MARK: - Global History

    var currentSnapshot: TextSnapshot? {
        guard globalHistoryIndex >= 0,
              globalHistoryIndex < globalHistory.count
        else {
            return nil
        }
        
        return globalHistory[globalHistoryIndex]
    }

    func navigateGlobalHistory(to index: Int) -> Bool {
        guard index >= 0, index < globalHistory.count else { return false }

        let snapshot = globalHistory[index]
        fullText = snapshot.fullText
        segments = snapshot.segments
        frozenRanges = snapshot.frozenRanges
        globalHistoryIndex = index

        return true
    }

    func navigateGlobalBack() -> Bool {
        navigateGlobalHistory(to: globalHistoryIndex - 1)
    }

    func navigateGlobalForward() -> Bool {
        navigateGlobalHistory(to: globalHistoryIndex + 1)
    }

    // MARK: - Private

    private func createInitialSnapshot() {
        let snapshot = TextSnapshot(
            fullText: fullText,
            instruction: nil,
            segments: segments,
            frozenRanges: frozenRanges
        )
        globalHistory = [snapshot]
        globalHistoryIndex = 0
    }

    private func createGlobalSnapshot(instruction: String?) {
        // Remove any snapshots after current index (branching)
        if globalHistoryIndex < globalHistory.count - 1 {
            globalHistory.removeSubrange((globalHistoryIndex + 1)...)
        }

        let snapshot = TextSnapshot(
            fullText: fullText,
            instruction: instruction,
            segments: segments,
            frozenRanges: frozenRanges
        )
        globalHistory.append(snapshot)
        globalHistoryIndex = globalHistory.count - 1
    }

    private func mergeFrozenRanges() {
        guard frozenRanges.count > 1 else { return }
        frozenRanges.sort { $0.location < $1.location }

        var merged: [NSRange] = []
        var current = frozenRanges[0]

        for i in 1..<frozenRanges.count {
            let next = frozenRanges[i]
            if NSMaxRange(current) >= next.location {
                let newEnd = max(NSMaxRange(current), NSMaxRange(next))
                current = NSRange(location: current.location, length: newEnd - current.location)
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)
        frozenRanges = merged
    }

    private func clearSegmentHistory(for range: NSRange) {
        segments.removeAll { NSIntersectionRange($0.range, range).length > 0 }
    }

    /// Clears any segment that contains the given location - used when user manually edits
    func clearSegmentContaining(location: Int) {
        segments.removeAll { NSLocationInRange(location, $0.range) }
    }

    private func clearNonFrozenSegmentHistory() {
        segments.removeAll { segment in
            !frozenRanges.contains { NSIntersectionRange(segment.range, $0).length > 0 }
        }
    }

    private func adjustSegmentRanges() {
        segments.removeAll()
    }

    private func updateFullTextFromSegment(_ segmentIndex: Int) {
        guard segmentIndex >= 0, segmentIndex < segments.count else { return }

        let segment = segments[segmentIndex]
        let nsString = fullText as NSString
        guard segment.range.location + segment.range.length <= nsString.length else { return }

        fullText = nsString.replacingCharacters(in: segment.range, with: segment.currentText)

        let lengthDiff = segment.currentText.count - segment.range.length
        guard lengthDiff != 0 else { return }

        segments[segmentIndex].range = NSRange(location: segment.range.location, length: segment.currentText.count)

        for i in (segmentIndex + 1)..<segments.count {
            segments[i].range = NSRange(location: segments[i].range.location + lengthDiff, length: segments[i].range.length)
        }

        for i in 0..<frozenRanges.count where frozenRanges[i].location > segment.range.location {
            frozenRanges[i] = NSRange(location: frozenRanges[i].location + lengthDiff, length: frozenRanges[i].length)
        }
    }

    private func updateSegmentWithNewVersionInternal(range: NSRange, newText: String, source: SegmentVersionSource) -> TextSegment? {
        if let index = segments.firstIndex(where: { $0.range == range }) {
            segments[index].addVersion(text: newText, source: source)
            updateFullTextFromSegment(index)
            return segments[index]
        } else {
            var segment = TextSegment(range: range, text: (fullText as NSString).substring(with: range))
            segment.addVersion(text: newText, source: source)
            segments.append(segment)
            updateFullTextFromSegment(segments.count - 1)
            return segments.last
        }
    }

    private func getNonFrozenRanges() -> [NSRange] {
        guard !frozenRanges.isEmpty else {
            return [NSRange(location: 0, length: fullText.count)]
        }

        var nonFrozen: [NSRange] = []
        var currentLocation = 0
        let sortedFrozen = frozenRanges.sorted { $0.location < $1.location }

        for frozen in sortedFrozen {
            if currentLocation < frozen.location {
                nonFrozen.append(NSRange(location: currentLocation, length: frozen.location - currentLocation))
            }
            currentLocation = NSMaxRange(frozen)
        }

        if currentLocation < fullText.count {
            nonFrozen.append(NSRange(location: currentLocation, length: fullText.count - currentLocation))
        }

        return nonFrozen
    }
}
