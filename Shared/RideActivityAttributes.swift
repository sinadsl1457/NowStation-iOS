import ActivityKit
import Foundation

/** 잠금화면·다이나믹 아일랜드에 띄우는 탑승. 앱과 위젯이 같이 쓴다(문구는 앱이 만들어 넣는다). */
struct RideActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var detail: String
        /** 아일랜드처럼 좁은 곳에 넣을 짧은 글자(이번 역). 모르면 nil. */
        var chip: String?
        var line: String?
        var prepareToAlight: Bool
        var online: Bool
    }

    var origin: String
    var destination: String?
}
