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
import Atomics
import Foundation

public protocol ConnectionDelegate: Sendable {
#if canImport(Network)
    func handleError(_ stream: AsyncStream<NWError>)
    func handleNetworkEvents(_ stream: AsyncStream<NetworkEventMonitor.NetworkEvent>)
#endif
}


public class ConnectionManager: @unchecked Sendable {
    
    public var delegate: ConnectionDelegate?
    fileprivate var asyncChannel: NIOAsyncChannel<ByteBuffer, ByteBuffer>?
    private let lock = NIOLock()
    private let group: EventLoopGroup
    
    
    public struct NTConnection: Sendable {
        let id = UUID()
        var group: EventLoopGroup
        var childChannel: NIOAsyncChannel<ByteBuffer, ByteBuffer>
    }
    
    internal var connections = [NTConnection]()
    
    public init() {
#if canImport(Network)
        if #available(macOS 10.14, iOS 12, tvOS 12, watchOS 3, *) {
            self.group = NIOTSEventLoopGroup.singleton
        } else {
            self.group = MultiThreadedEventLoopGroup.singleton
        }
#else
        self.group = MultiThreadedEventLoopGroup.singleton
#endif
    }
    
    public func createConnection(
        host: String,
        port: Int,
        enableTLS: Bool = true
    ) async throws -> NIOAsyncChannel<ByteBuffer, ByteBuffer> {
        
        if !connections.isEmpty {
            if let currentConnection = connections.last {
                try await shutdown(connection: currentConnection)   
            }
        }
        
        func createBootstrap() throws -> NIOTSConnectionBootstrap {
            var bootstrap = NIOTSConnectionBootstrap(group: group)
            let tcpOptions = NWProtocolTCP.Options()
            bootstrap = bootstrap.tcpOptions(tcpOptions)
            
            if enableTLS {
                let tlsOptions = NWProtocolTLS.Options()
                bootstrap = bootstrap.tlsOptions(tlsOptions)
            }
            
            return bootstrap
        }
        
        func socketChannelCreator() async throws -> NIOAsyncChannel<ByteBuffer, ByteBuffer> {
            let sslContext = try NIOSSLContext(configuration: TLSConfiguration.makeClientConfiguration())
            let client = ClientBootstrap(group: group)
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
            
            return try await client
                .connectTimeout(.minutes(1))
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .connect(host: host, port: port) { channel in
                    return createHandlers(channel)
                }
        }
        
#if canImport(Network)
        if #available(macOS 10.14, iOS 12, tvOS 12, watchOS 3, *) {
            let bootstrap = try createBootstrap()
            let connection = bootstrap
                .connectTimeout(.minutes(1))
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            
            do {
                return try await connection.connect(host: host, port: port) { channel in
                    return createHandlers(channel)
                }
            } catch {
                try await asyncChannel?.executeThenClose { inbound, outbound in
                    outbound.finish()
                }
                throw error
            }
        } else {
            return try await socketChannelCreator()
        }
#else
        return try await socketChannelCreator()
#endif
        
        @Sendable func createHandlers(_ channel: Channel) -> EventLoopFuture<NIOAsyncChannel<ByteBuffer, ByteBuffer>> {
            let monitor = NetworkEventMonitor()
            return channel.eventLoop.makeCompletedFuture {
                try channel.pipeline.syncOperations.addHandlers([
                    monitor,
                    LengthFieldPrepender(lengthFieldBitLength: .threeBytes),
                    ByteToMessageHandler(
                        LengthFieldBasedFrameDecoder(lengthFieldBitLength: .threeBytes),
                        maximumBufferSize: 16777216
                    ),
                ])
                let childChannel = try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                setChannel(asyncChannel)
                if let errorStream = monitor.errorStream {
                    delegate?.handleError(errorStream)
                }
                if let eventStream = monitor.eventStream {
                    delegate?.handleNetworkEvents(eventStream)
                }
                connections.append(.init(group: self.group, childChannel: childChannel))
                return childChannel
            }
        }
    }
    
    @Sendable private func setChannel(_ asyncChannel: NIOAsyncChannel<ByteBuffer, ByteBuffer>?) {
        lock.lock()
        defer { lock.unlock() }
        self.asyncChannel = asyncChannel
    }
    
    
    public func shutdown(connection: NTConnection? = nil) async {
        // Use the provided connection or the first one in the list if none is provided
        let connectionToShutdown = connection ?? connections.first
        
        // Ensure there is a connection to shut down
        guard let connection = connectionToShutdown else { return }
        do {
            // Shut down the connection gracefully and remove it from the list
            try await connection.group.shutdownGracefully()
        } catch {
            print("Error shutting down connection group Error:", error)
        }
        connections.removeAll(where: { $0.id == connection.id })
    }
}

public final class NetworkEventMonitor: ChannelInboundHandler, @unchecked Sendable {
    public typealias InboundIn = ByteBuffer
    
    private let didSetError = ManagedAtomic(false)
    var errorStream: AsyncStream<NWError>?
    private var errorContinuation: AsyncStream<NWError>.Continuation?
    var eventStream: AsyncStream<NetworkEvent>?
    private var eventContinuation: AsyncStream<NetworkEvent>.Continuation?
    
    init () {
#if canImport(Network)
        errorStream = AsyncStream<NWError>(bufferingPolicy: .unbounded) { continuation in
            self.errorContinuation = continuation
        }
        
        eventStream = AsyncStream<NetworkEvent>(bufferingPolicy: .unbounded) { continuation in
            self.eventContinuation = continuation
        }
#endif
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: any Error) {
        context.fireErrorCaught(error)
#if canImport(Network)
        let nwError = error as? NWError
        if nwError == .posix(.ENETDOWN) || nwError == .posix(.ENOTCONN), !didSetError.load(ordering: .acquiring) {
            didSetError.store(true, ordering: .relaxed)
            if let nwError = nwError {
                errorContinuation?.yield(nwError)
            }
        }
#endif
    }
    
#if canImport(Network)
    public enum NetworkEvent: Sendable {
        case betterPathAvailable(NIOTSNetworkEvents.BetterPathAvailable)
        case betterPathUnavailable
        case connectToNWEndpoint(NIOTSNetworkEvents.ConnectToNWEndpoint)
        case bindToNWEndpoint(NIOTSNetworkEvents.BindToNWEndpoint)
        case waitingForConnectivity(NIOTSNetworkEvents.WaitingForConnectivity)
        case pathChanged(NIOTSNetworkEvents.PathChanged)
    }
#endif
    
    public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        context.fireUserInboundEventTriggered(event)
#if canImport(Network)
        guard let networkEvent = event as? any NIOTSNetworkEvent else {
            return
        }
        
        let eventType: NetworkEvent?
        
        switch networkEvent {
        case let event as NIOTSNetworkEvents.BetterPathAvailable:
            eventType = .betterPathAvailable(event)
        case is NIOTSNetworkEvents.BetterPathUnavailable:
            eventType = .betterPathUnavailable
        case let event as NIOTSNetworkEvents.ConnectToNWEndpoint:
            eventType = .connectToNWEndpoint(event)
        case let event as NIOTSNetworkEvents.BindToNWEndpoint:
            eventType = .bindToNWEndpoint(event)
        case let event as NIOTSNetworkEvents.WaitingForConnectivity:
            eventType = .waitingForConnectivity(event)
        case let event as NIOTSNetworkEvents.PathChanged:
            eventType = .pathChanged(event)
        default:
            eventType = nil
        }
        if let eventType = eventType {
            eventContinuation?.yield(eventType)
        }
        
#endif
    }
}
