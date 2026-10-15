@preconcurrency import CoreBluetooth
import Combine
import Foundation

@MainActor
final class BadgeTransferClient: ObservableObject {
    static let rxUUID = CBUUID(string: MotoBadgeCodec.rxUUID())
    static let txUUID = CBUUID(string: MotoBadgeCodec.txUUID())
    @Published private(set) var connected = false
    @Published private(set) var busy = false
    @Published private(set) var progress = 0.0
    @Published private(set) var formats: [UInt8] = [0, 0, 0, 0]
    @Published private(set) var selected: UInt8 = 255
    @Published private(set) var message = "连接支持相册功能的圆屏后即可发送。"
    private weak var peripheral: CBPeripheral?
    private var rx: CBCharacteristic?
    private var tx: CBCharacteristic?
    private var nextID = UInt32.random(in: 1 ... UInt32.max - 1)
    private var pending: (id: UInt32, operation: UInt8, slot: UInt8, continuation: CheckedContinuation<MotoBadgeReply, Error>)?
    private var timeout: Task<Void, Never>?
    private var generation: UInt64 = 0

    struct Failure: LocalizedError {
        let text: String
        var errorDescription: String? { text }
    }

    func attach(_ peripheral: CBPeripheral, rx: CBCharacteristic, tx: CBCharacteristic) {
        if self.peripheral === peripheral, self.rx === rx, self.tx === tx { return }
        detach()
        self.peripheral = peripheral; self.rx = rx; self.tx = tx
        if tx.isNotifying { notificationChanged(tx, error: nil) }
        else { peripheral.setNotifyValue(true, for: tx) }
    }

    func detach() {
        generation &+= 1
        connected = false
        formats = [0, 0, 0, 0]; selected = 255
        peripheral = nil; rx = nil; tx = nil
        timeout?.cancel(); timeout = nil
        let continuation = pending?.continuation; pending = nil
        continuation?.resume(throwing: Failure(text: "蓝牙连接已断开，请重新连接后再发送。"))
    }

    func notificationChanged(_ characteristic: CBCharacteristic, error: Error?) {
        connected = error == nil && characteristic.isNotifying
        if let error { message = error.localizedDescription }
        if connected {
            message = "已连接，可发送到 4 个保存位。"
            Task { await refresh() }
        }
    }

    func receive(_ data: Data?, error: Error?) {
        if let error { failPending(error); return }
        guard let data, let reply = MotoBadgeCodec.decodeReply(data) else { return }
        formats = reply.formats.map(\.uint8Value); selected = reply.selected
        guard let pending, pending.id == reply.requestID,
              pending.operation == reply.operation, pending.slot == reply.slot else { return }
        self.pending = nil; timeout?.cancel(); timeout = nil
        if reply.status == 0 { pending.continuation.resume(returning: reply) }
        else {
            let texts = ["", "图片参数无效。", "圆屏正在处理另一项操作。", "相册存储写入失败或空间不足。",
                         "传输顺序不一致，请重新发送。", "图片校验失败，请重新发送。",
                         "圆屏无法读取此图片，请重新选择或压缩。", "圆屏相册存储尚未就绪。"]
            pending.continuation.resume(throwing: Failure(text: texts[Int(reply.status)]))
        }
    }

    func writeCompleted(error: Error?) { if let error { failPending(error) } }

    private func failPending(_ error: Error) {
        timeout?.cancel(); timeout = nil
        let continuation = pending?.continuation; pending = nil
        continuation?.resume(throwing: error)
    }

    private func request(_ operation: UInt8, slot: UInt8 = 0, kind: UInt8 = 0,
                         offset: UInt32 = 0, payload: Data = Data()) async throws -> MotoBadgeReply {
        try Task.checkCancellation()
        guard connected, let peripheral, let rx, pending == nil else {
            throw Failure(text: "请先连接圆屏，并等待当前操作完成。")
        }
        nextID &+= 1; if nextID == 0 { nextID = 1 }
        let id = nextID
        let frame = MotoBadgeCodec.request(operation: operation, requestID: id, slot: slot,
                                          kind: kind, offset: offset, payload: payload)
        guard !frame.isEmpty, frame.count <= peripheral.maximumWriteValueLength(for: .withResponse) else {
            throw Failure(text: "蓝牙传输尺寸不匹配，请重新连接圆屏。")
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending = (id, operation, slot, continuation)
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                guard let self, self.pending?.id == id else { return }
                self.failPending(Failure(text: "圆屏响应超时；原来的图片保留，可重新发送。"))
            }
            peripheral.writeValue(frame, for: rx, type: .withResponse)
        }
    }

    func refresh() async { await perform { _ = try await self.request(1) } }
    func remove(slot: Int) async {
        guard (0..<4).contains(slot) else { return }
        await perform { _ = try await self.request(5, slot: UInt8(slot)) }
    }
    func select(slot: Int) async {
        guard (0..<4).contains(slot) else { return }
        await perform { _ = try await self.request(6, slot: UInt8(slot)) }
    }

    func upload(_ asset: BadgePreparedAsset, slot: Int) async {
        await perform {
            guard (0..<4).contains(slot), asset.data.count <= 512 * 1024,
                  let peripheral = self.peripheral else { throw Failure(text: "图片或保存位无效。") }
            let epoch = self.generation
            self.progress = 0
            self.message = "正在发送，保持手机与圆屏连接。"
            _ = try await self.request(2, slot: UInt8(slot), kind: asset.format,
                                       payload: MotoBadgeCodec.beginPayload(asset.data))
            let chunkSize = min(peripheral.maximumWriteValueLength(for: .withResponse), 182) - 16
            guard chunkSize > 0 else { throw Failure(text: "蓝牙传输空间不足。") }
            var offset = 0
            while offset < asset.data.count {
                try Task.checkCancellation()
                guard self.generation == epoch else { throw Failure(text: "连接已变化，请重新发送。") }
                let end = min(offset + chunkSize, asset.data.count)
                let reply = try await self.request(3, slot: UInt8(slot), offset: UInt32(offset),
                                                  payload: asset.data.subdata(in: offset..<end))
                guard reply.offset == UInt32(end) else { throw Failure(text: "圆屏接收进度不一致，请重新发送。") }
                offset = end; self.progress = Double(offset) / Double(asset.data.count)
            }
            _ = try await self.request(4, slot: UInt8(slot))
            self.message = "已保存到圆屏；滑到第 5 页查看，短按 BOOT 键切换图片。"
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do { try await action() } catch { message = error.localizedDescription }
    }
}
