//
//  IRCBatchCollector.swift
//  needletail-irc
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

/// A completed IRCv3 batch (`BATCH +ref type params…` … `BATCH -ref`).
public struct IRCBatch: Hashable, Sendable {
    public var reference: String
    /// The batch type, such as `chathistory` or `netsplit`.
    public var type: String
    public var parameters: [String]
    /// Tags on the opening `BATCH` line.
    public var tags: [IRCTag]
    /// The enclosing batch, for nested batches.
    public var parentReference: String?
    /// Messages tagged with this batch, in arrival order. Nested batches are reported separately.
    public var messages: [IRCRawMessage]

    public init(
        reference: String,
        type: String,
        parameters: [String] = [],
        tags: [IRCTag] = [],
        parentReference: String? = nil,
        messages: [IRCRawMessage] = []
    ) {
        self.reference = reference
        self.type = type
        self.parameters = parameters
        self.tags = tags
        self.parentReference = parentReference
        self.messages = messages
    }

    public static func == (lhs: IRCBatch, rhs: IRCBatch) -> Bool {
        lhs.reference == rhs.reference && lhs.type == rhs.type && lhs.parameters == rhs.parameters
            && lhs.parentReference == rhs.parentReference && lhs.messages == rhs.messages
            && lhs.tags.map { [$0.key, $0.value] } == rhs.tags.map { [$0.key, $0.value] }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(reference)
        hasher.combine(type)
        hasher.combine(messages)
    }
}

/// Groups messages that belong to IRCv3 batches.
public struct IRCBatchCollector: Sendable {

    /// The result of processing one message.
    public struct Output: Sendable {
        /// The message itself when it is not part of an open batch.
        public var message: IRCRawMessage?
        /// A batch that just closed.
        public var completedBatch: IRCBatch?

        /// `true` when the message was absorbed into an open batch.
        public var isEmpty: Bool { message == nil && completedBatch == nil }
    }

    private var open: [String: IRCBatch] = [:]

    public init() {}

    /// References of batches that are open.
    public var openBatchReferences: Set<String> { Set(open.keys) }

    public mutating func process(_ message: IRCRawMessage) -> Output {
        if message.command == "BATCH", let marker = message.parameters.first, marker.count > 1 {
            let reference = String(marker.dropFirst())
            if marker.hasPrefix("+") {
                open[reference] = IRCBatch(
                    reference: reference,
                    type: message.parameters.count > 1 ? message.parameters[1] : "",
                    parameters: Array(message.parameters.dropFirst(2)),
                    tags: message.tags,
                    parentReference: message.batchReference.flatMap { open[$0] == nil ? nil : $0 }
                )
                return Output()
            }
            if marker.hasPrefix("-"), let batch = open.removeValue(forKey: reference) {
                return Output(completedBatch: batch)
            }
        }

        if let reference = message.batchReference, open[reference] != nil {
            open[reference]?.messages.append(message)
            return Output()
        }
        return Output(message: message)
    }
}
