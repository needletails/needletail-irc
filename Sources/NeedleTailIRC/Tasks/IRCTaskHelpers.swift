import NeedleTailLogger

public enum AsyncMessageTask: Sendable {
    public static func parseMessageTask(
        task: String,
        messageParser: MessageParser
    ) -> IRCMessage? {
        do {
            return try messageParser.parseMessage(task)
        } catch {
            NeedleTailLogger(.init(label: "[AsyncMessageTask]")).log(level: .error, message: "\(error)")
            return nil
        }
    }
}
