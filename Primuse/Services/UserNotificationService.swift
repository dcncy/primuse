import Foundation
import UserNotifications

/// 本地通知统一入口。
///
/// 设计选择: 用户在设置页打开"完成时通知我"开关时, 才会调 `requestAuthorization()`
/// 主动弹系统权限对话框。开关关掉的话所有 post 都 noop, 不发送任何通知。
/// 这样不需要 APNs / Capabilities 等远程推送基建, 仅本地通知 ── 审核 0 摩擦。
enum UserNotificationService {
    /// UserDefaults key: 用户是否打开了"读取标签完成时通知我"开关。
    static let backfillCompleteNotificationKey = "primuse.notify.backfillComplete"

    /// 用户已打开开关 + 已授权时发本地通知。否则静默 noop。
    /// 同时检查 UserDefaults 开关 (即便系统授权了, 用户在 app 内关掉也不发)。
    static func postIfEnabled(
        userDefaultsKey: String,
        title: String,
        body: String,
        identifier: String = UUID().uuidString
    ) async {
        guard UserDefaults.standard.bool(forKey: userDefaultsKey) else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        guard authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // trigger=nil 立即送达。app 在前台时默认不弹横幅 (用户已经看到 UI 进度)。
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await center.add(request)
    }

    /// 主动请求系统权限 ── 用户在设置页打开开关时调用。返回授权结果。
    /// 系统的 `requestAuthorization` 第一次会弹对话框, 后续被 deny 后再调
    /// 不会再弹 ── 用户得去系统 Settings 手动允许。
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// 查询当前权限状态 ── 设置页 toggle 加载时用, 已经 deny 的情况要在 UI
    /// 提示用户去系统 Settings 开。
    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
