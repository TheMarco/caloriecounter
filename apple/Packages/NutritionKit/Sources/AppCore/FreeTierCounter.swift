//
//  FreeTierCounter.swift
//  The "first N food entries are free" tally. Stored in iCloud key-value storage
//  so it survives delete + reinstall and follows the user's Apple ID across their
//  devices — all WITHOUT an account. Mirrored to UserDefaults as a local cache /
//  offline fallback, and we always trust the HIGHER of the two so the count can't
//  be quietly undercut.
//
//  Monotonic: it only ever increments on a genuinely new, user-initiated food
//  entry — deleting entries does not refund free slots.
//

import Foundation
import Observation

@Observable
@MainActor
public final class FreeTierCounter {
    /// Lifetime count of user-logged food entries that counted toward the free tier.
    public private(set) var count: Int

    private let kvs = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private static let storageKey = "freeFoodEntriesLogged"
    private var externalChange: (any NSObjectProtocol)?

    public init() {
        kvs.synchronize()
        count = Self.merged(kvs: kvs, defaults: defaults)
        // Dev: `-gate` starts the free allowance spent (in-memory only; not persisted).
        if ProcessInfo.processInfo.arguments.contains("-gate") {
            count = max(count, 9999)
        }

        // Adopt a higher count pushed from another device (reinstall / second device).
        externalChange = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.count = max(self.count, Self.merged(kvs: self.kvs, defaults: self.defaults))
            }
        }
    }

    public func increment() {
        count += 1
        persist(count)
    }

    // Dev/testing helpers.
    public func reset() { count = 0; persist(0) }
    public func set(_ value: Int) { count = max(0, value); persist(count) }

    private func persist(_ value: Int) {
        kvs.set(Int64(value), forKey: Self.storageKey)
        kvs.synchronize()
        defaults.set(value, forKey: Self.storageKey)
    }

    private static func merged(kvs: NSUbiquitousKeyValueStore, defaults: UserDefaults) -> Int {
        max(Int(kvs.longLong(forKey: storageKey)), defaults.integer(forKey: storageKey))
    }
}
