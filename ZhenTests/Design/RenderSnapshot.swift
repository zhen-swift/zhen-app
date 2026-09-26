#if DEBUG
import AppKit
import SwiftUI
import Testing
@testable import Zhen
// Not a test. A way to get the pixels onto disk so a person can look at the thing
// rather than at an assertion about it — which is how the misplaced chip was found and
// how this one was checked.
@Suite("Snapshots, written only when asked", .disabled(if: ProcessInfo.processInfo.environment["ZHEN_SNAPSHOT"] == nil))
@MainActor
struct RenderSnapshot {
    private func write(_ view: some View, width: CGFloat, to name: String) {
        let host = NSHostingView(rootView: AnyView(view.environment(\.colorScheme, .dark)))
        host.appearance = NSAppearance(named: .darkAqua)
        let height = host.fittingSize.height
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ZHEN_SNAPSHOT"]!)
        try? data.write(to: out.appendingPathComponent(name))
    }

    @Test("Write the device list at the minimum width and at a comfortable one")
    func deviceList() {
        let rows = VStack(spacing: 0) {
            DeviceTableHeader()
            Divider().overlay(Palette.separator)
            ForEach(DeviceRowModel.sampleNetwork.prefix(4)) { device in
                DeviceRow(device)
                Divider().overlay(Palette.separator)
            }
        }
        .background(Palette.surface)
        write(rows, width: Metrics.windowMinWidth, to: "list-at-window-minimum.png")
        write(rows, width: 1400, to: "list-1400.png")

        // The same long subtitle WITHOUT the chip, to see whether the chip's line is
        // what makes it truncate at the minimum width or whether it always did.
        var noChip = DeviceRowModel.reassignedSample
        noChip = DeviceRowModel(
            id: noChip.id, name: noChip.name, subtitle: noChip.subtitle,
            presence: noChip.presence, identification: noChip.identification,
            ip: noChip.ip, addressState: .lastKnown, mac: noChip.mac,
            isPrivateMAC: noChip.isPrivateMAC, lastSeen: noChip.lastSeen
        )
        let pair = VStack(spacing: 0) {
            DeviceRow(.reassignedSample)
            Divider().overlay(Palette.separator)
            DeviceRow(noChip)
        }
        .background(Palette.surface)
        write(pair, width: Metrics.windowMinWidth, to: "chip-vs-nochip-at-window-minimum.png")
    }
}
#endif
