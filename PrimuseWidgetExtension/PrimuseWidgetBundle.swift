import WidgetKit
import SwiftUI

@main
struct PrimuseWidgetBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
        QuickAccessWidget()
        // iOS 18+ 控制中心 / 锁屏 Action Button 入口
        if #available(iOS 18.0, *) {
            PrimusePlayPauseControl()
            PrimuseShuffleControl()
            PrimuseNextControl()
            PrimusePreviousControl()
        }
    }
}
