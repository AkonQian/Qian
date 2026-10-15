import PhotosUI
import SwiftUI
import UIKit

struct BadgeGalleryView: View {
    @ObservedObject var client: BadgeTransferClient
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotosPickerItem?
    @State private var asset: BadgePreparedAsset?
    @State private var preview: UIImage?
    @State private var preparing = false
    @State private var preparationError: String?
    @State private var target = 0
    @State private var deleteSlot: Int?

    var body: some View {
        NavigationStack {
            Form {
                imageSection
                albumSection
                statusSection
            }
            .navigationTitle("电子吧唧")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .task { await client.refresh() }
            .task(id: selection) { await prepareSelection() }
            .confirmationDialog("删除这个保存位的图片？", isPresented: Binding(
                get: { deleteSlot != nil }, set: { if !$0 { deleteSlot = nil } })) {
                Button("删除图片", role: .destructive) {
                    if let slot = deleteSlot { Task { await client.remove(slot: slot) } }
                    deleteSlot = nil
                }
            }
        }
    }

    private var imageSection: some View {
        Section {
        PhotosPicker(selection: $selection, matching: .images, preferredItemEncoding: .current) {
            Label("选择图片或 GIF", systemImage: "photo.on.rectangle.angled")
        }
        .disabled(client.busy || preparing)
        if preparing { ProgressView("正在处理图片…") }
        if let preview {
            Image(uiImage: preview).resizable().scaledToFill()
                .frame(width: 220, height: 220).clipShape(Circle())
                .frame(maxWidth: .infinity)
        }
        if let asset {
            Text(asset.detail).font(.footnote)
            if asset.format == 2 { Text("此处预览首帧，发送后在圆屏循环播放。 ").font(.caption).foregroundStyle(.secondary) }
            slotPicker
            Button(client.formats[target] == 0 ? "发送到圆屏" : "替换此保存位") {
                Task { await client.upload(asset, slot: target) }
            }
            .disabled(!client.connected || client.busy || preparing)
        }
        if let preparationError { Text(preparationError).foregroundStyle(.red) }
    } footer: {
        Text("图片按中心裁切适配圆屏。最多保存 4 张；GIF 最长 15 秒、最高 10 帧/秒。图片只经蓝牙发送到你的圆屏。")
    }
    }

    private var slotPicker: some View {
        Picker("保存到", selection: $target) {
            Text("保存位 1").tag(0)
            Text("保存位 2").tag(1)
            Text("保存位 3").tag(2)
            Text("保存位 4").tag(3)
        }
    }

    private var albumSection: some View {
        Section {
        ForEach(0..<4, id: \.self) { index in
            albumRow(index)
        }
        Button("刷新相册状态") { Task { await client.refresh() } }
            .disabled(!client.connected || client.busy)
    } header: {
        Text("圆屏相册")
    } footer: {
        Text("在圆屏上左右滑到第 5 页，短按 BOOT 键切换下一张。PWR 键用于电源。图片保存在圆屏，重启后保留。")
    }
    }

    private func albumRow(_ index: Int) -> some View {
        HStack {
                VStack(alignment: .leading) {
                    Text("保存位 \(index + 1)")
                    Text(kind(client.formats[index])).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if client.selected == UInt8(index) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                if client.formats[index] != 0 {
                    Button("展示") { Task { await client.select(slot: index) } }
                        .buttonStyle(.borderless)
                    Button(role: .destructive) { deleteSlot = index } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
        }.disabled(!client.connected || client.busy)
    }

    private var statusSection: some View {
        Section {
        if client.busy { ProgressView(value: client.progress) }
        Text(client.message).font(.footnote)
    }
    }

    private func kind(_ value: UInt8) -> String {
        value == 2 ? "GIF 动图" : value == 1 ? "静态图片" : "空"
    }

    @MainActor private func prepareSelection() async {
        guard let selection else { return }
        preparing = true; preparationError = nil; asset = nil; preview = nil
        defer { preparing = false }
        do {
            guard let data = try await selection.loadTransferable(type: Data.self) else { return }
            let prepared = try await Task.detached(priority: .userInitiated) {
                try BadgeAssetEncoder.prepare(data)
            }.value
            try Task.checkCancellation()
            asset = prepared; preview = UIImage(data: prepared.data)
        } catch is CancellationError { }
        catch { preparationError = error.localizedDescription }
    }
}
