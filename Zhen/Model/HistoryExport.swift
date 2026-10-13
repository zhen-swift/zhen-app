import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ZhenCore

/// Everything history holds, as one JSON file a person can keep or hand to another tool.
///
/// Devices and the latest run use core's own `Codable` shapes, the ones the scan artifact
/// pins. Events do not have one — core keeps `DerivedEvent` off the wire on purpose, so a
/// change to it cannot silently become a format change — so they are written here, in a
/// shape this file owns.
nonisolated struct HistoryExport: Encodable, Sendable {
  struct Entry: Encodable, Sendable {
    /// The name shown in the app: one given here, else the winning discovered one.
    let name: String?
    let online: Bool
    let device: Device
  }

  struct Event: Encodable, Sendable {
    let at: Date
    let kind: String
    let subject: String
    let detail: String
  }

  let format = "zhen-app-history"
  let version = 1
  let exportedAt: Date
  let latestRun: ScanRun?
  let devices: [Entry]
  let events: [Event]

  init(devices: [DeviceItem], events: [DerivedEvent], latestRun: ScanRun?, at: Date = .now) {
    exportedAt = at
    self.latestRun = latestRun
    self.devices = devices.map { Entry(name: $0.name, online: $0.isOnline, device: $0.device) }
    self.events = events.map {
      Event(at: Date(timeIntervalSince1970: $0.at.timeIntervalSince1970), kind: $0.kind.rawValue, subject: $0.subject, detail: $0.detail)
    }
  }

  func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(self)
  }
}

/// An export, as `.fileExporter` writes it. Write-only: Zhen never opens one.
nonisolated struct HistoryDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.json]
  let data: Data

  init(data: Data) {
    self.data = data
  }

  init(configuration: ReadConfiguration) throws {
    throw CocoaError(.fileReadUnsupportedScheme)
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}

extension NetworkModel {
  /// History as it stands, ready for the save panel.
  func exportDocument() -> HistoryDocument? {
    let export = HistoryExport(devices: devices, events: events, latestRun: latestRun)
    return (try? export.encoded()).map(HistoryDocument.init(data:))
  }

  /// "Zhen history 2026-10-11".
  static var exportFilename: String {
    String(localized: .zhenHistory(Date.now.formatted(.iso8601.year().month().day())))
  }

  /// The history file's size in bytes; nil when this launch has none.
  var historyFileSize: Int? {
    historyURL.flatMap(HistoryWatcher.stamp(of:))?.size
  }
}
