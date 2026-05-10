import Foundation

extension Date {
    var relativeDisplay: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        switch interval {
        case ..<60:
            return "刚刚"
        case ..<3600:
            return "\(Int(interval / 60))分钟前"
        case ..<86400:
            return "\(Int(interval / 3600))小时前"
        case ..<604800:
            return "\(Int(interval / 86400))天前"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: self)
        }
    }
}
