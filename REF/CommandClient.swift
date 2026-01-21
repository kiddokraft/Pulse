import Foundation
 import Pulse
 import Libbox
                                                                               
                                                                               
 public class CommandClient: ObservableObject {
     public enum ConnectionType {
         case status
         case groups
         case log
         case clashMode
         case connections
     }
                                                                               
     private let connectionType: ConnectionType
     private let logMaxLines: Int
     private var commandClient: LibboxCommandClient?
     private var connectTask: Task<Void, Error>?
     @Published public var isConnected: Bool
     @Published public var status: LibboxStatusMessage?
     @Published public var groups: [LibboxOutboundGroup]?
     @Published public var logList: [String]
     @Published public var clashModeList: [String]
     @Published public var clashMode: String
                                                                               
     @Published public var connectionStateFilter = ConnectionStateFilter.active
     @Published public var connectionSort = ConnectionSort.byDate
     @Published public var connections: [LibboxConnection]?
     public var rawConnections: LibboxConnections?
                                                                               
     // NEW: Track stored connection IDs to avoid duplicates
     private var storedConnectionIds = Set<String>()
                                                                               
     private let logQueue = DispatchQueue(label:
 "com.commandclient.logprocessing", qos: .utility)
     private var logBuffer: [String] = []
     private let logBufferLock = NSLock()
     private var logFlushTimer: Timer?
                                                                               
     public init(_ connectionType: ConnectionType, logMaxLines: Int = 300) {
         self.connectionType = connectionType
         self.logMaxLines = logMaxLines
         logList = []
         clashModeList = []
         clashMode = ""
         isConnected = false
     }
                                                                               
     public func connect() {
         if isConnected {
             return
         }
         if let connectTask {
             connectTask.cancel()
         }
         connectTask = Task {
             await connect0()
         }
     }
                                                                               
     public func disconnect() {
         if let connectTask {
             connectTask.cancel()
             self.connectTask = nil
         }
         if let commandClient {
             try? commandClient.disconnect()
             self.commandClient = nil
         }
         logFlushTimer?.invalidate()
         logFlushTimer = nil
                                                                               
         // NEW: Clear stored IDs on disconnect
         storedConnectionIds.removeAll()
     }
                                                                               
     public func filterConnectionsNow() {
         guard let message = rawConnections else {
             return
         }
         connections = filterConnections(message)
     }
                                                                               
     private func filterConnections(_ message: LibboxConnections) ->
 [LibboxConnection] {
         message.filterState(Int32(connectionStateFilter.rawValue))
         switch connectionSort {
         case .byDate:
             message.sortByDate()
         case .byTraffic:
             message.sortByTraffic()
         case .byTrafficTotal:
             message.sortByTrafficTotal()
         }
         let connectionIterator = message.iterator()!
         var connections: [LibboxConnection] = []
         while connectionIterator.hasNext() {
             connections.append(connectionIterator.next()!)
         }
         return connections
     }
                                                                               
     private func initializeConnectionFilterState() async {
         let newFilter: ConnectionStateFilter = await .init(rawValue:
 SharedPreferences.connectionStateFilter.get()) ?? .active
         let newSort: ConnectionSort = await .init(rawValue:
 SharedPreferences.connectionSort.get()) ?? .byDate
         await MainActor.run {
             connectionStateFilter = newFilter
             connectionSort = newSort
         }
     }
                                                                               
     private nonisolated func connect0() async {
         if connectionType == .connections {
             await initializeConnectionFilterState()
         }
                                                                               
         let clientOptions = LibboxCommandClientOptions()
         switch connectionType {
         case .status:
             clientOptions.command = LibboxCommandStatus
         case .groups:
             clientOptions.command = LibboxCommandGroup
         case .log:
             clientOptions.command = LibboxCommandLog
         case .clashMode:
             clientOptions.command = LibboxCommandClashMode
         case .connections:
             clientOptions.command = LibboxCommandConnections
         }
         switch connectionType {
         case .log:
             clientOptions.statusInterval = Int64(500 * NSEC_PER_MSEC)
         default:
             clientOptions.statusInterval = Int64(NSEC_PER_SEC)
         }
         let client = LibboxNewCommandClient(clientHandler(self),
 clientOptions)!
         do {
             for i in 0 ..< 10 {
                 try await Task.sleep(nanoseconds: UInt64(Double(100 + (i *
 50)) * Double(NSEC_PER_MSEC)))
                 try Task.checkCancellation()
                 do {
                     try client.connect()
                     await MainActor.run {
                         commandClient = client
                     }
                     return
                 } catch {}
                 try Task.checkCancellation()
             }
         } catch {
             try? client.disconnect()
         }
     }
                                                                               
     private func startLogFlushTimer() {
         DispatchQueue.main.async { [weak self] in
             guard let self = self else { return }
             self.logFlushTimer?.invalidate()
             self.logFlushTimer = Timer.scheduledTimer(withTimeInterval: 0.1,
 repeats: true) { [weak self] _ in
                 self?.flushLogBuffer()
             }
         }
     }
                                                                               
     private func flushLogBuffer() {
         logBufferLock.lock()
         guard !logBuffer.isEmpty else {
             logBufferLock.unlock()
             return
         }
         let logsToFlush = logBuffer
         logBuffer.removeAll(keepingCapacity: true)
         logBufferLock.unlock()
                                                                               
         var newLogList = self.logList
         newLogList.append(contentsOf: logsToFlush)
                                                                               
         if newLogList.count > logMaxLines {
             newLogList.removeFirst(newLogList.count - logMaxLines)
         }
                                                                               
         self.logList = newLogList
     }
                                                                               
     private class clientHandler: NSObject, LibboxCommandClientHandlerProtocol
 {
         private let commandClient: CommandClient
                                                                               
         init(_ commandClient: CommandClient) {
             self.commandClient = commandClient
         }
                                                                               
         func connected() {
             DispatchQueue.main.async { [self] in
                 if commandClient.connectionType == .log {
                     commandClient.logList = []
                     commandClient.startLogFlushTimer()
                 }
                 commandClient.isConnected = true
             }
         }
                                                                               
         func disconnected(_ message: String?) {
             DispatchQueue.main.async { [self] in
                 commandClient.isConnected = false
                 commandClient.logFlushTimer?.invalidate()
                 commandClient.logFlushTimer = nil
             }
             if let message {
                 NSLog("client disconnected: \(message)")
             }
         }
                                                                               
         func clearLogs() {
             commandClient.logBufferLock.lock()
             commandClient.logBuffer.removeAll()
             commandClient.logBufferLock.unlock()
                                                                               
             DispatchQueue.main.async { [self] in
                 commandClient.logList.removeAll()
             }
         }
                                                                               
         func writeLogs(_ messageList: (any LibboxStringIteratorProtocol)?) {
             guard let messageList else { return }
                                                                               
             LoggerStore.shared.storeParsedLog(from: messageList.next())
         }
                                                                               
         func writeStatus(_ message: LibboxStatusMessage?) {
             DispatchQueue.main.async { [self] in
                 commandClient.status = message
             }
         }
                                                                               
         func writeGroups(_ groups: LibboxOutboundGroupIteratorProtocol?) {
             guard let groups else {
                 return
             }
             var newGroups: [LibboxOutboundGroup] = []
             while groups.hasNext() {
                 newGroups.append(groups.next()!)
             }
             DispatchQueue.main.async { [self] in
                 commandClient.groups = newGroups
             }
         }
                                                                               
         func initializeClashMode(_ modeList: LibboxStringIteratorProtocol?,
 currentMode: String?) {
             DispatchQueue.main.async { [self] in
                 commandClient.clashModeList = modeList!.toArray()
                 commandClient.clashMode = currentMode!
             }
         }
                                                                               
         func updateClashMode(_ newMode: String?) {
             DispatchQueue.main.async { [self] in
                 commandClient.clashMode = newMode!
             }
         }
                                                                               
         // MODIFIED: Store connections to Pulse network tab
         func write(_ message: LibboxConnections?) {
             guard let message else {
                 return
             }
                                                                                       
             // FIRST: Get ALL connections before filtering (for Pulse)
             var allConnections: [LibboxConnection] = []
             if let iterator = message.iterator() {
                 while iterator.hasNext() {
                     allConnections.append(iterator.next()!)
                 }
             }
                                                                                       
             // THEN: Apply filters for UI display
             let filteredConnections = commandClient.filterConnections(message)
                                                                                       
             DispatchQueue.main.async { [self] in
                 commandClient.rawConnections = message
                 commandClient.connections = filteredConnections
                                                                                       
                 // Store closed connections to Pulse
                 for connection in allConnections {
                     if connection.closedAt > 0 &&
                        !commandClient.storedConnectionIds.contains(connection.id_) {
                         LoggerStore.shared.storeConnection(connection)
                         commandClient.storedConnectionIds.insert(connection.id_)
                     }
                 }
             }
         }
     }
 }
                                                                               
 public enum ConnectionStateFilter: Int, CaseIterable, Identifiable {
     public var id: Self {
         self
     }
                                                                               
     case all
     case active
     case closed
 }
                                                                               
 public extension ConnectionStateFilter {
     var name: String {
         switch self {
         case .all:
             return NSLocalizedString("All", comment: "")
         case .active:
             return NSLocalizedString("Active", comment: "")
         case .closed:
             return NSLocalizedString("Closed", comment: "")
         }
     }
 }
                                                                               
 public enum ConnectionSort: Int, CaseIterable, Identifiable {
     public var id: Self {
         self
     }
                                                                               
     case byDate
     case byTraffic
     case byTrafficTotal
 }
                                                                               
 public extension ConnectionSort {
     var name: String {
         switch self {
         case .byDate:
             return NSLocalizedString("Date", comment: "")
         case .byTraffic:
             return NSLocalizedString("Traffic", comment: "")
         case .byTrafficTotal:
             return NSLocalizedString("Traffic Total", comment: "")
         }
     }
 }
                                                                               
 enum LogLevel {
     case trace
     case debug
     case info
     case warning
     case error
 }
