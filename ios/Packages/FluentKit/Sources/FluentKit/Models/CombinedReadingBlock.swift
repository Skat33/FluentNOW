import Foundation

/// The questions of one reading inside a combined session (they always come as one block of
/// consecutive tasks, see `CombinedSessionBuilder.orderTasks`). Used for the read-first flow:
/// the passage is shown alone before the first question of the block and again, with the
/// evidence, after the last one (FEEDBACK-2 G1).
public struct CombinedReadingBlock: Sendable, Hashable {
    public var readingID: String
    /// Task indices of the block, in session order.
    public var taskIndices: [Int]
    /// Position of the inspected task within `taskIndices`.
    public var position: Int

    public init(readingID: String, taskIndices: [Int], position: Int) {
        self.readingID = readingID
        self.taskIndices = taskIndices
        self.position = position
    }

    /// The inspected task is the first question of the passage.
    public var opensBlock: Bool { position == 0 }
    /// The inspected task is the last question of the passage.
    public var closesBlock: Bool { position == taskIndices.count - 1 }

    /// The reading block containing task `index`, or `nil` when it is not a reading question.
    public static func block(in session: CombinedSession, at index: Int) -> CombinedReadingBlock? {
        guard let id = readingID(session.tasks[safe: index]) else { return nil }
        var start = index
        while start > 0, readingID(session.tasks[safe: start - 1]) == id {
            start -= 1
        }
        var end = index
        while end + 1 < session.tasks.count, readingID(session.tasks[safe: end + 1]) == id {
            end += 1
        }
        return CombinedReadingBlock(readingID: id, taskIndices: Array(start...end), position: index - start)
    }

    private static func readingID(_ task: CombinedTask?) -> String? {
        task?.questionTask?.reading?.id
    }
}
