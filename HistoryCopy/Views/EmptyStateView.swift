import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.on.square")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))
            Text("暂无复制记录")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("使用 Cmd+C 复制内容后会自动显示")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }
}
