import SwiftUI

/// Available without a connection, so permission and storage information can
/// still be read when the gateway or the accessory is unavailable.
struct DataUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("位置与路线") {
                    Text("地点搜索、规划和重新规划路线时，搜索内容、起终点及所需位置会发送给配置的导航服务。使用高德服务时，网关会再将所需信息发送给高德。在线周边地图请求也会透露所查看的区域。")
                    Text("打开 App 后，定位用于显示 GPS 实时速度并同步圆屏，不需要先开始导航。导航期间同时更新路线与指引；结束导航后仍保留速度定位。允许相应后台权限时，锁屏或切换应用后可继续。纯速度显示不向导航网关请求路线，可在系统设置中调整定位权限。")
                    Text("如需后台和锁屏持续测速，并隐藏时间旁的蓝色定位提示，请在 iPhone 设置 → 隐私与安全性 → 定位服务 → Qian GPS 中选择“始终”，并开启“精确位置”。仅允许“使用 App 期间”时，iOS 仍会显示蓝色提示；定位箭头和系统隐私提醒由 iOS 管理。")
                }
                Section("蓝牙与音乐") {
                    Text("连接圆屏后，导航、速度及周边地图通过蓝牙同步。允许媒体资料库权限后，Apple Music 的曲名、歌手和播放状态也会同步到圆屏，圆屏可控制上一首、播放或暂停、下一首。")
                    Text("音乐信息不发送到 Qian GPS 的导航服务器。拒绝音乐权限不影响地点搜索和导航。")
                    Text("配套圆屏固件也可直接接收 iPhone 蓝牙媒体服务提供的歌曲文字；部分播放器开启蓝牙歌词后会通过这些文字字段输出歌词。此路径不经导航服务器，是否输出取决于播放器和系统。")
                }
                Section("存储与清理") {
                    Text("最近地点、已连接设备标识、累计骑行公里数和下载地图保存在手机上。累计公里数从此版本起按有效的真实导航定位计算，模拟数据不计入。首页可清空最近搜索；地图与离线下载页面可删除下载包、清理临时缓存。删除 App 可移除它的本地数据；系统备份可能包含部分本地数据。")
                    Text("服务器访问日志可能保留 IP、请求时间、搜索词、位置参数及地图区域。记录范围、轮转和保留期限由部署方的实际配置及隐私政策说明；这不等于数据只在手机上保存。")
                }
                Section {
                    Link("高德隐私政策", destination: URL(string: "https://lbs.amap.com/home/privacy/")!)
                    Link("Apple 隐私政策", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                    Link("OpenStreetMap 数据与许可", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    Link("Protomaps 地图数据", destination: URL(string: "https://protomaps.com")!)
                } header: {
                    Text("第三方服务")
                } footer: {
                    Text("手机路线预览由 Apple 地图提供；内置深圳道路与建筑来自 OpenStreetMap / Geofabrik，在线底图可使用 Protomaps 数据。")
                }
            }
            .listStyle(.insetGrouped)
            .modifier(QianInstrumentSurface())
            .navigationTitle("隐私与数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .accessibilityIdentifier("privacy-data-done")
                }
            }
        }
    }
}
