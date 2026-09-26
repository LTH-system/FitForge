import Foundation
import CloudKit
import SwiftData
import CryptoKit
import UIKit

/// 記録全体（JSONスナップショット）を、利用者本人のiCloud（CloudKitのプライベートデータベース）に1件だけ保存する。
/// 機種変更やアプリの再インストールのあとに、同じApple IDでサインインしていれば戻せる。
/// プライベートデータベースの中身は利用者本人しか読めず、開発者からも見えない。
@MainActor
final class CloudBackupService: ObservableObject {
    enum AccountState: Equatable {
        case checking
        case available
        case unavailable(String)
    }

    struct BackupInfo: Equatable {
        var savedAt: Date
        var recordCount: Int
    }

    enum BackupError: LocalizedError {
        case accountUnavailable(String)
        case encodingFailed
        case noBackup
        case unreadableBackup

        var errorDescription: String? {
            switch self {
            case .accountUnavailable(let reason): return reason
            case .encodingFailed: return "バックアップするデータを作れませんでした"
            case .noBackup: return "iCloudにバックアップがありません"
            case .unreadableBackup: return "バックアップを読み込めませんでした"
            }
        }
    }

    static let containerIdentifier = "iCloud.com.fitforge.app"

    @Published private(set) var accountState: AccountState = .checking
    @Published private(set) var latestBackup: BackupInfo?
    @Published private(set) var isWorking = false
    @Published private(set) var lastErrorMessage: String?
    /// 新しい端末やアプリの再インストール後に見つかったバックアップ。値があると復元するか確認する
    @Published var pendingRestore: BackupInfo?

    @Published var isAutoBackupEnabled: Bool {
        didSet { defaults.set(isAutoBackupEnabled, forKey: Keys.autoBackupEnabled) }
    }

    private enum Keys {
        static let autoBackupEnabled = "cloudBackup.autoBackupEnabled"
        static let initialCheckDone = "cloudBackup.initialCheckDone"
        static let lastUploadedHash = "cloudBackup.lastUploadedHash"
    }

    private enum Field {
        static let payload = "payload"
        static let savedAt = "savedAt"
        static let recordCount = "recordCount"
        static let appVersion = "appVersion"
    }

    private let recordType = "Snapshot"
    private let recordID = CKRecord.ID(recordName: "latest-snapshot")
    private let defaults = UserDefaults.standard
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private lazy var container = CKContainer(identifier: Self.containerIdentifier)
    private var database: CKDatabase { container.privateCloudDatabase }

    /// 起動後にiCloudのバックアップ有無を確かめ終えたか。
    /// 再インストール直後の空のデータで、iCloudの既存バックアップを上書きしないための安全装置
    private var isInitialCheckDone: Bool {
        get { defaults.bool(forKey: Keys.initialCheckDone) }
        set { defaults.set(newValue, forKey: Keys.initialCheckDone) }
    }

    init() {
        isAutoBackupEnabled = defaults.object(forKey: Keys.autoBackupEnabled) as? Bool ?? true
    }

    // MARK: 起動時

    /// iCloudの状態と最新のバックアップを確認する。
    /// 初めての確認でバックアップが見つかったら、復元するかを利用者に聞く
    func refreshStatus() async {
        guard await refreshAccountState() else { return }
        do {
            let info = try await fetchLatestInfo()
            latestBackup = info
            lastErrorMessage = nil
            if !isInitialCheckDone {
                if let info, info.recordCount > 0 {
                    pendingRestore = info
                } else {
                    isInitialCheckDone = true
                }
            }
        } catch {
            // 通信できないときは確認済みにしない。確認できるまで自動バックアップは止めておく
            lastErrorMessage = message(for: error)
        }
    }

    /// 見つかったバックアップを使わずに、この端末の記録で始める
    func declinePendingRestore() {
        pendingRestore = nil
        isInitialCheckDone = true
    }

    // MARK: バックアップ

    /// アプリがバックグラウンドに入ったときに呼ぶ。前回から内容が変わっていればアップロードする
    func backupInBackground(_ snapshot: AppSnapshot) {
        guard isAutoBackupEnabled, isInitialCheckDone, pendingRestore == nil else { return }
        guard backgroundTaskID == .invalid else { return }
        // 記録が空になった内容で、記録のあるバックアップを自動で上書きしない（誤って全削除したときの逃げ道を残す）
        let count = Self.recordCount(of: snapshot)
        if count == 0, (latestBackup?.recordCount ?? 0) > 0 { return }
        guard let data = PersistenceService.encode(snapshot) else { return }
        let hash = Self.hash(of: data)
        guard hash != defaults.string(forKey: Keys.lastUploadedHash) else { return }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "FitForgeBackup") { [weak self] in
            MainActor.assumeIsolated { self?.endBackgroundTask() }
        }
        Task {
            try? await upload(data, hash: hash, recordCount: count)
            endBackgroundTask()
        }
    }

    /// 設定画面の「今すぐバックアップ」
    func backupNow(_ snapshot: AppSnapshot) async {
        guard let data = PersistenceService.encode(snapshot) else {
            lastErrorMessage = BackupError.encodingFailed.errorDescription
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await upload(data, hash: Self.hash(of: data), recordCount: Self.recordCount(of: snapshot))
            // 利用者が明示的に保存したので、以後の自動バックアップも有効にしてよい
            isInitialCheckDone = true
            pendingRestore = nil
        } catch {
            lastErrorMessage = message(for: error)
        }
    }

    private func upload(_ data: Data, hash: String, recordCount: Int) async throws {
        guard await refreshAccountState() else {
            if case .unavailable(let reason) = accountState { throw BackupError.accountUnavailable(reason) }
            return
        }

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("fitforge_backup_upload.json")
        try data.write(to: fileURL, options: [.atomic])
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let savedAt = Date.now
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record[Field.payload] = CKAsset(fileURL: fileURL)
        record[Field.savedAt] = savedAt as CKRecordValue
        record[Field.recordCount] = recordCount as CKRecordValue
        record[Field.appVersion] = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") as CKRecordValue

        // 常に1件だけを最新の内容で上書きする
        let (results, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: true)
        if let result = results[recordID] {
            _ = try result.get()
        }

        defaults.set(hash, forKey: Keys.lastUploadedHash)
        latestBackup = BackupInfo(savedAt: savedAt, recordCount: recordCount)
        lastErrorMessage = nil
    }

    // MARK: 復元

    /// iCloudの最新バックアップを読み込む。端末への反映は呼び出し側（AppStore.restore）で行う
    private func downloadLatest() async throws -> AppSnapshot {
        guard await refreshAccountState() else {
            if case .unavailable(let reason) = accountState { throw BackupError.accountUnavailable(reason) }
            throw BackupError.noBackup
        }
        isWorking = true
        defer { isWorking = false }

        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            throw BackupError.noBackup
        }

        guard let asset = record[Field.payload] as? CKAsset,
              let fileURL = asset.fileURL,
              let data = try? Data(contentsOf: fileURL),
              let snapshot = PersistenceService.decode(data) else {
            throw BackupError.unreadableBackup
        }

        // 戻した内容と同じものを再アップロードしないように覚えておく
        defaults.set(Self.hash(of: data), forKey: Keys.lastUploadedHash)
        isInitialCheckDone = true
        pendingRestore = nil
        latestBackup = Self.info(from: record)
        lastErrorMessage = nil
        return snapshot
    }

    /// 最新のバックアップを読み込み、記録（JSON）とSwiftDataの両方をその内容に置き換える
    func restoreLatest(into store: AppStore, context: ModelContext) async throws {
        let snapshot = try await downloadLatest()
        store.restore(from: snapshot)
        SwiftDataBridge.resetAndSeed(from: store, context: context)
        NotificationService.apply(store.preferences.notificationSettings)
    }

    func reportRestoreFailure(_ error: Error) {
        lastErrorMessage = message(for: error)
    }

    // MARK: 内部

    @discardableResult
    private func refreshAccountState() async -> Bool {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                accountState = .available
            case .noAccount:
                accountState = .unavailable("iCloudにサインインしていません。設定アプリでApple IDにサインインするとバックアップできます")
            case .restricted:
                accountState = .unavailable("この端末ではiCloudの利用が制限されています")
            case .temporarilyUnavailable:
                accountState = .unavailable("iCloudに一時的に接続できません。しばらくしてからお試しください")
            case .couldNotDetermine:
                accountState = .unavailable("iCloudの状態を確認できませんでした")
            @unknown default:
                accountState = .unavailable("iCloudの状態を確認できませんでした")
            }
        } catch {
            accountState = .unavailable("iCloudの状態を確認できませんでした")
        }
        return accountState == .available
    }

    private func fetchLatestInfo() async throws -> BackupInfo? {
        do {
            let record = try await database.record(for: recordID)
            return Self.info(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func message(for error: Error) -> String {
        if let backupError = error as? BackupError {
            return backupError.errorDescription ?? "iCloudとの通信に失敗しました"
        }
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return "通信できませんでした。電波の良い場所でもう一度お試しください"
            case .quotaExceeded:
                return "iCloudの空き容量が足りません"
            case .notAuthenticated:
                return "iCloudにサインインしていません"
            default:
                break
            }
        }
        return "iCloudとの通信に失敗しました"
    }

    private static func info(from record: CKRecord) -> BackupInfo {
        BackupInfo(
            savedAt: record[Field.savedAt] as? Date ?? record.modificationDate ?? .now,
            recordCount: record[Field.recordCount] as? Int ?? 0
        )
    }

    private static func recordCount(of snapshot: AppSnapshot) -> Int {
        snapshot.meals.count + snapshot.strengthSets.count + snapshot.cardioSessions.count
            + snapshot.bodyMetrics.count + snapshot.checkIns.count
    }

    private static func hash(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
