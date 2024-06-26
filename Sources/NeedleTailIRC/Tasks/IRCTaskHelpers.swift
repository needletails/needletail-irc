import NeedleTailLogger

public enum AsyncMessageTask: Sendable {
    public static func parseMessageTask(task: String) -> IRCMessage? {
        do {
            return try NeedleTailIRCParser.parseMessage(task)
        } catch {
            NeedleTailLogger(.init(label: "[AsyncMessageTask]")).log(level: .error, message: "\(error)")
            return nil
        }
    }
}
