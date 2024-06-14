import NIOSSL
import NIOExtras
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix
#if canImport(Network)
import Network
import NIOTransportServices
#endif
import NeedleTailLogger

/// `EventLoopGroupManager` can be used to manage an `EventLoopGroup`, either by creating or by sharing an existing one.
///
/// When making network client libraries with SwiftNIO that are supposed to work well on both Apple platforms (macOS,
/// iOS, tvOS, ...) as well as Linux, users often find it tedious to select the right combination of:
///
/// - an `EventLoopGroup`
/// - a bootstrap
/// - a TLS implementation
///
/// The choices to the above need to be compatible, or else the program won't work.
///
/// What makes the task even harder is that as a client library, you often want to share the `EventLoopGroup` with other
/// components. That raises the question of how to choose a bootstrap and a matching TLS implementation without even
/// knowing the concrete `EventLoopGroup` type (it may be `SelectableEventLoop` which is an internal `NIO` types).
/// `EventLoopGroupManager` should support all those use cases with a simple API.
public final class EventLoopGroupManager: @unchecked Sendable {
    private let provider: Provider
    private let lock = NIOLock()
    private let logger = NeedleTailLogger(.init(label: "[EventLoopGroupManager]"))
    public let groupWrapper: GroupWrapper
    fileprivate var asyncChannel: NIOAsyncChannel<ByteBuffer, ByteBuffer>?
    
    public struct GroupWrapper: Sendable {
        public var group: EventLoopGroup
    }
    
    public enum Provider: Sendable {
        case createNew
        case shared(EventLoopGroup)
    }
    
    /// Initialize the `EventLoopGroupManager` with a `Provder` of `EventLoopGroup`s.
    ///
    /// The `Provider` lets you choose whether to use a `.shared(group)` or to `.createNew`.
    public init(provider: Provider, usingNetwork: Bool = false) {
        self.provider = provider
        switch self.provider {
        case .shared(let group):
            lock.lock()
            self.groupWrapper = GroupWrapper(group: group)
            lock.unlock()
        case .createNew:
            lock.lock()
            if usingNetwork {
#if canImport(Network)
                self.groupWrapper = GroupWrapper(group: NIOTSEventLoopGroup())
#else
                self.groupWrapper = GroupWrapper(group: MultiThreadedEventLoopGroup(numberOfThreads: 1))
#endif
            } else {
                self.groupWrapper = GroupWrapper(group: MultiThreadedEventLoopGroup(numberOfThreads: 1))
            }
            lock.unlock()
        }
    }
    
    deinit {
        //        assert(self.group == nil, "Please call EventLoopGroupManager.shutdown .")
    }
    
    @Sendable private func setChannel(_ asyncChannel: NIOAsyncChannel<ByteBuffer, ByteBuffer>?) {
        self.asyncChannel = asyncChannel
    }
}

// - MARK: Public API
extension EventLoopGroupManager {
    /// Create a "universal bootstrap" for the given host.
    /// Shutdown the `EventLoopGroupManager`.
    ///
    /// This will release all resources associated with the `EventLoopGroupManager` such as the threads that the
    /// `EventLoopGroup` runs on.
    ///
    /// This method _must_ be called when you're done with this `EventLoopGroupManager`.
    public func shutdown() async {
        switch self.provider {
        case .createNew:
            ()
        case .shared:
            logger.log(level: .debug, message: "Shutdown Shared Group \(String(describing: groupWrapper.group))")
        }
    }
}

// - MARK: Error types
extension EventLoopGroupManager {
    /// The provided `EventLoopGroup` is not compatible with this client.
    public struct UnsupportedEventLoopGroupError: Swift.Error {
        var eventLoopGroup: EventLoopGroup
    }
}
enum ELGMErrors: Swift.Error {
    case nilEventLoopGroup
}

// - MARK: Internal functions
extension EventLoopGroupManager {
    
    
    public func makeAsyncChannel(
        host: String,
        port: Int,
        enableTLS: Bool = true,
        group: EventLoopGroup
    ) async throws -> NIOAsyncChannel<ByteBuffer, ByteBuffer> {
        func socketChannelCreator() async throws -> NIOAsyncChannel<ByteBuffer, ByteBuffer> {
            let sslContext = try NIOSSLContext(configuration: TLSConfiguration.makeClientConfiguration())
            let client = ClientBootstrap(group: group)
            let channel: NIOAsyncChannel<ByteBuffer, ByteBuffer> = try await client
                .connectTimeout(.minutes(1))
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET),SO_REUSEADDR), value: 1)
                .connect(host: host, port: port) { channel in
                    return createHandlers(channel)
                }
            
            let bootstrap = try NIOClientTCPBootstrap(
                client,
                tls: NIOSSLClientTLSProvider(
                    context: sslContext,
                    serverHostname: host
                )
            )
            if enableTLS {
                bootstrap.enableTLS()
            }
            return channel
        }
        
        
#if canImport(Network)
        if #available(macOS 10.14, iOS 12, tvOS 12, watchOS 3, *) {
            //             We run on a new-enough Darwin so we can use Network.framework
            var bootstrap = NIOTSConnectionBootstrap(group: group)
            let tcpOptions = NWProtocolTCP.Options()
            bootstrap = bootstrap.tcpOptions(tcpOptions)
            if enableTLS {
                let tlsOptions = NWProtocolTLS.Options()
                bootstrap = bootstrap.tlsOptions(tlsOptions)
            }
            
            let connection = bootstrap
                .connectTimeout(.minutes(1))
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET),SO_REUSEADDR), value: 1)
            do {
                return try await connection.connect(
                    host: host,
                    port: port
                ) { channel in
                    return createHandlers(channel)
                }
            } catch {
                try await asyncChannel?.executeThenClose({ inbound, outbound in
                    outbound.finish()
                })
                throw error
            }
        } else {
            // We're on Darwin but not new enough for Network.framework, so we fall back on NIO on BSD sockets.
            return try await socketChannelCreator()
        }
#else
        // We are on a non-Darwin platform, so we'll use BSD sockets.
        return try await socketChannelCreator()
#endif
        
        @Sendable func createHandlers(_ channel: Channel) -> EventLoopFuture<NIOAsyncChannel<ByteBuffer, ByteBuffer>> {
            channel.eventLoop.makeCompletedFuture {
                try channel.pipeline.syncOperations.addHandlers([
                    ByteToMessageHandler(
                        LineBasedFrameDecoder()
                    )
                ], position: .first)
                let asyncChannel = try NIOAsyncChannel<ByteBuffer, ByteBuffer>(
                    wrappingChannelSynchronously: channel,
                    configuration: .init()
                )
                setChannel(asyncChannel)
                return asyncChannel
            }
        }
    }
}


//TODO: We need to test that thesers network events are being fired from NIOTS on our NIOAsyncChannel Inbound/Outbound Handlers
//func betterPathHandler(available: Bool) {
//if available {
//    self.pipeline.fireUserInboundEventTriggered(NIOTSNetworkEvents.BetterPathAvailable())
//} else {
//    self.pipeline.fireUserInboundEventTriggered(NIOTSNetworkEvents.BetterPathUnavailable())
//}

//func pathChangedHandler(newPath path: NWPath) {
//self.pipeline.fireUserInboundEventTriggered(NIOTSNetworkEvents.PathChanged(newPath: path))

//case .failed(let err):
//self.close0(error: err, mode: .all, promise: nil)

//case .waiting(let err):
//self.pipeline.fireUserInboundEventTriggered(NIOTSNetworkEvents.WaitingForConnectivity(transientError: err))
