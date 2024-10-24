import Testing
import Foundation
import BSON
import NeedleTailStructures
@testable import NeedleTailIRC

final class NeedleTailIRCTests {
    let generator = IRCMessageGenerator()
    struct Base64Struct: Sendable, Codable {
        var string: String
    }
    @Test func testReadKeyBundle() async throws  {
        let base64 = try! BSONEncoder().encodeString(Base64Struct(string:TestableConstants.longMessage.rawValue))
        let messages = try await generator.createMessages(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.findUserConfig.rawValue,
                                   [base64]),
            logger: .init())
        
        for await message in messages {
            if let rebuiltMessage = try await generator.messageReassembler(ircMessage: message) {
                #expect(message == rebuiltMessage)
            }
        }
        
    }
    
    @Test func testParseMessages() async {
        for message in await createIRCMessages() {
            await #expect(throws: Never.self, performing: {
                let messageToParse = await NeedleTailIRCEncoder.encode(value: message)
                let parsed = try NeedleTailIRCParser.parseMessage(messageToParse)
            })
        }
    }
    //
    //    @Test func derivePacketsToSend() async throws {
    //        let packetDerivation = PacketDerivation()
    //        let message = IRCMessage(
    //            origin: TestableConstants.origin.rawValue,
    //            command:
    //                    .PRIVMSG(
    //                        [.nick(.init(name: "nt2", deviceId: UUID())!)],
    //                        TestableConstants.longMessage.rawValue
    //                    )
    //        )
    //        
    //        let stringValue = await NeedleTailIRCEncoder.encode(value: message)
    //        let sequence = try await packetDerivation.calculateAndDispense(ircMessage: stringValue, bufferingPolicy: .unbounded)
    ////        await #expect(sequence.consumer.deque.count == 11)
    ////        var currentId = 0
    ////        for try await result in sequence {
    ////            switch result {
    ////            case .success(let packet):
    ////                currentId += 1
    ////                #expect(packet.partNumber == currentId)
    //////                #expect(packet.totalParts == sequence.consumer.deque.count)
    ////            case .consumed:
    ////                return
    ////            }
    ////        }
    //    }
    //    
    //    @Test func decodeAndRebuildIRCMessage() async throws {
    //        let packetDerivation = PacketDerivation()
    //        let builder = PacketBuilder()
    //        let message = IRCMessage(
    //            origin: TestableConstants.origin.rawValue,
    //            command:
    //                    .PRIVMSG(
    //                        [.nick(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!)],
    //                        TestableConstants.longMessage.rawValue
    //                    )
    //        )
    //        let stringValue = await NeedleTailIRCEncoder.encode(value: message)
    //        let sequence = try await packetDerivation.calculateAndDispense(ircMessage: stringValue, bufferingPolicy: .unbounded)
    //        
    ////        for try await result in sequence {
    ////            switch result {
    ////            case .success(let packet):
    ////                let buffer = try BSONEncoder().encode(packet).makeByteBuffer()
    ////                if let ircMessageString = await builder.processPacket(buffer) {
    ////                    //Build IRCMessage from String
    ////                    let message = try NeedleTailIRCParser.parseMessage(ircMessageString)
    ////                    #expect(message.arguments?[1] != nil)
    ////                    guard let ircMessageContent = message.arguments?[1] else { return }
    ////                    #expect(ircMessageContent == TestableConstants.longMessage.rawValue)
    ////                }
    ////            case .consumed:
    ////                return
    ////            }
    ////        }
    //    }
}

func createIRCMessages() async -> [IRCMessage] {
    var messages = [IRCMessage]()
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.pass.rawValue, ["123", "456"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .nick(.init(name: TestableConstants.origin.rawValue, deviceId: UUID())!),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .nick(.init(name: TestableConstants.origin.rawValue, deviceId: UUID())!),
            tags: [.init(key: "tempRegistration", value: "123456hgfdsa")])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .nick(.init(name: TestableConstants.origin.rawValue, deviceId: UUID())!),
            arguments: ["hop_count_0"],
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .user(.init(username: "guest", hostname: "needletail-client", servername: "needletail-server", realname: "No ones business")),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .user(.init(username: "guest", realname: "No ones business")),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .isOn([.init(name: TestableConstants.origin.rawValue, deviceId: UUID())!]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .isOn([.init(name: TestableConstants.origin.rawValue, deviceId: UUID())!, .init(name: TestableConstants.target.rawValue, deviceId: UUID())!]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .quit("See ya!"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .ping(server: TestableConstants.serverOne.rawValue, server2: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .ping(server: TestableConstants.serverOne.rawValue, server2: TestableConstants.serverTwo.rawValue),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .pong(server: TestableConstants.serverOne.rawValue, server2: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .pong(server: TestableConstants.serverOne.rawValue, server2: TestableConstants.serverTwo.rawValue),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .join(channels: [.init(TestableConstants.channelOne.rawValue)!], keys: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .join(channels: [.init(TestableConstants.channelOne.rawValue)!], keys: [TestableConstants.channelOneKey.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .join(channels: [.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], keys: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .join(channels: [.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], keys: [TestableConstants.channelOneKey.rawValue, TestableConstants.channelTwoKey.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .join0,
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .part(channels: [.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: [.init(TestableConstants.channelOne.rawValue)!], target: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: [.init(TestableConstants.channelOne.rawValue)!], target: TestableConstants.target.rawValue),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: [.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], target: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: [.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], target: TestableConstants.target.rawValue),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: nil, target: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: nil, target: TestableConstants.target.rawValue),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .privMsg([.all], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .privMsg([.channel(.init(TestableConstants.channelOne.rawValue)!)], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .privMsg([.nick(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!)], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .notice([.all], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .notice([.channel(.init(TestableConstants.channelOne.rawValue)!)], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .notice([.nick(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!)], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .mode(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!, add: .away, remove: .blockUnidentified),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .modeGet(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: .inviteOnly, addParameters: [], removeMode: nil, removeParameters: []),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: .banMask, addParameters: ["baduser1!*@*","baduser2!*@*"], removeMode: nil, removeParameters: []),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: .userLimit, addParameters: ["10"], removeMode: nil, removeParameters: []),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: nil, addParameters: [], removeMode: .inviteOnly, removeParameters: []),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: nil, addParameters: [], removeMode: .banMask, removeParameters: ["baduser2!*@*","baduser3!*@*"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: .banMask, addParameters: ["baduser1!*@*","baduser2!*@*"], removeMode: .banMask, removeParameters: ["baduser1!*@*","baduser2!*@*"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelModeGet(.init(TestableConstants.channelOne.rawValue)!),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: .banMask, addParameters: [], removeMode: nil, removeParameters: []),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelModeGetBanMask(.init(TestableConstants.channelOne.rawValue)!),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .whois(server: TestableConstants.serverOne.rawValue, usermasks: [TestableConstants.usermaskOne.rawValue, TestableConstants.usermaskTwo.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .who(usermask: TestableConstants.usermaskOne.rawValue, onlyOperators: false),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .who(usermask: TestableConstants.usermaskOne.rawValue, onlyOperators: true),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .kick([.init(TestableConstants.channelOne.rawValue)!], [.init(name: TestableConstants.target.rawValue, deviceId: UUID())!], ["GO AWAY"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .kick([.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], [.init(name: TestableConstants.target.rawValue, deviceId: UUID())!], ["GO AWAY", "YOU GOT KICKED"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .kick([.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], [.init(name: TestableConstants.target.rawValue, deviceId: UUID())!, .init(name: TestableConstants.origin.rawValue, deviceId: UUID())!], ["GO AWAY", "YOU GOT KICKED", "SEE YA!"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .kill(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!, "KILLED IT"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .kill(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!, "KILLED IT"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.ack, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.end, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.list, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.ls, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.nak, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.req, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.registryRequest.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.newDevice.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.findUserConfig.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.offlineMessages.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.deleteOfflineMessage.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.publishBlob.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.readPublishedBlob.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.badgeUpdate.rawValue, ["1"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.multipartMediaDownload.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.multipartMediaUpload.rawValue, [
                "id",
                "1",
                "20",
                TestableConstants.longMessage.rawValue
            ]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.requestMediaDeletion.rawValue, ["contactId", "mediaId"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.destoryUser.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.listBucket.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .numeric(.replyWelcome, ["Welcome", "To", "Your", "IRC Server"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .numeric(.replyISON, ["userOne", "userTwo", "userThree", "userFour"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .numeric(.replyMotDStart, ["- Message of the Day -"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .numeric(.replyMotD, ["I think therefore I am"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .numeric(.replyEndOfMotD, ["End of /MOTD command."]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .otherNumeric(999, ["uknown", "message"]),
            tags: [])
    )
    return messages
}

enum TestableConstants: String, Sendable {
    case origin = "nt1"
    case target = "nt2"
    case serverOne = "server-one"
    case serverTwo = "server-two"
    case channelOne = "#channel-one"
    case channelTwo = "#channel-two"
    case channelOneKey = "channel-one-key"
    case channelTwoKey = "channel-two-key"
    case usermaskOne = "usermask-one"
    case usermaskTwo = "usermask-two"
    case longMessage =
            "nibh tortor id aliquet lectus proin nibh nisl condimentum id venenatis a condimentum vitae sapien pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas sed tempus urna et pharetra pharetra massa massa ultricies mi quis hendrerit dolor magna eget est lorem ipsum dolor sit amet consectetur adipiscing elit pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas integer eget aliquet nibh praesent tristique magna sit amet purus gravida quis blandit turpis cursus in hac habitasse platea dictumst quisque sagittis purus sit amet volutpat consequat mauris nunc congue nisi vitae suscipit tellus mauris a diam maecenas sed enim ut sem viverra aliquet eget sit amet tellus cras adipiscing enim eu turpis egestas pretium aenean pharetra magna ac placerat vestibulum lectus mauris ultrices eros in cursus turpis massa tincidunt dui ut ornare lectus sit amet est placerat in egestas erat imperdiet sed euismod nisi porta lorem mollis aliquam ut porttitor leo a diam sollicitudin tempor id eu nisl nunc mi ipsum faucibus vitae aliquet nec ullamcorper sit amet risus nullam eget felis eget nunc lobortis mattis aliquam faucibus purus in massa tempor nec feugiat nisl pretium fusce id velit ut tortor pretium viverra suspendisse potenti nullam ac tortor vitae purus faucibus ornare suspendisse sed nisi lacus sed viverra tellus in hac habitasse platea dictumst vestibulum rhoncus est pellentesque elit ullamcorper dignissim cras tincidunt lobortis feugiat vivamus at augue eget arcu dictum varius duis at consectetur lorem donec massa sapien faucibus et molestie ac feugiat sed lectus vestibulum mattis ullamcorper velit sed ullamcorper morbi tincidunt ornare massa eget egestas purus viverra accumsan in nisl nisi scelerisque eu ultrices vitae auctor eu augue ut lectus arcu bibendum at varius vel pharetra vel turpis nunc eget lorem dolor sed viverra ipsum nunc aliquet bibendum enim facilisis gravida neque convallis a cras semper auctor neque vitae tempus quam pellentesque nec nam aliquam sem et tortor consequat id porta nibh venenatis cras sed felis eget velit aliquet sagittis id consectetur purus ut faucibus pulvinar elementum integer enim neque volutpat ac tincidunt vitae semper quis lectus nulla at volutpat diam ut venenatis tellus in metus vulputate eu scelerisque felis imperdiet proin fermentum leo vel orci porta non pulvinar neque laoreet suspendisse interdum consectetur libero id faucibus nisl tincidunt eget nullam non nisi est sit amet facilisis magna etiam tempor orci eu lobortis elementum nibh tellus molestie nunc non blandit massa enim nec dui nunc mattis enim ut tellus elementum sagittis vitae et leo duis ut diam quam nulla porttitor massa id neque aliquam vestibulum morbi blandit cursus risus at ultrices mi tempus imperdiet nulla malesuada pellentesque elit eget gravida cum sociis natoque penatibus et magnis dis parturient montes nascetur ridiculus mus mauris vitae ultricies leo integer malesuada nunc vel risus commodo viverra maecenas accumsan lacus vel facilisis volutpat est velit egestas dui id ornare arcu odio ut sem nulla pharetra diam sit amet nisl suscipit adipiscing bibendum est ultricies integer quis auctor elit sed vulputate mi sit amet mauris commodo quis imperdiet massa tincidunt nunc pulvinar sapien et ligula ullamcorper malesuada proin libero nunc consequat interdum varius sit amet mattis vulputate enim nulla aliquet porttitor lacus luctus accumsan tortor posuere ac ut consequat semper viverra nam libero justo laoreet sit amet cursus sit amet dictum sit amet justo donec enim diam vulputate ut pharetra sit amet aliquam id diam maecenas ultricies mi eget mauris pharetra et ultrices neque ornare aenean euismod elementum nisi quis eleifend quam adipiscing vitae proin sagittis nisl rhoncus mattis rhoncus urna neque viverra justo nec ultrices dui sapien eget mi proin sed libero enim sed faucibus turpis in eu mi bibendum neque egestas congue quisque egestas diam in arcu cursus euismod quis viverra nibh cras pulvinar mattis nunc sed blandit libero volutpat sed cras ornare arcu dui vivamus arcu felis bibendum ut tristique et egestas quis ipsum suspendisse ultrices gravida dictum fusce ut placerat orci nulla pellentesque dignissim enim sit amet venenatis urna cursus eget nunc scelerisque viverra mauris in aliquam sem fringilla ut morbi tincidunt augue interdum velit euismod in pellentesque massa placerat duis ultricies lacus sed turpis tincidunt id aliquet risus feugiat in ante metus dictum at tempor commodo ullamcorper a lacus vestibulum sed arcu non odio euismod lacinia at quis risus sed vulputate odio ut enim blandit volutpat maecenas volutpat blandit aliquam etiam erat velit scelerisque in dictum non consectetur a erat nam at lectus urna duis convallis convallis tellus id interdum velit laoreet id donec ultrices tincidunt arcu non sodales neque sodales ut etiam sit amet nisl purus in mollis nunc sed id semper risus in hendrerit gravida rutrum quisque non tellus orci ac auctor augue mauris augue neque gravida in fermentum et sollicitudin ac orci phasellus egestas tellus rutrum tellus pellentesque eu tincidunt tortor aliquam nulla facilisi cras fermentum odio eu"
}
