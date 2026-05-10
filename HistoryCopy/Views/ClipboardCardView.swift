import SwiftUI
import AppKit

struct ClipboardCardView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    @State private var showActions = false
    @State private var justCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Content area
            Button(action: {
                onCopy()
                justCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    justCopied = false
                }
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    switch item.type {
                    case .text:
                        Text(item.textContent ?? "")
                            .lineLimit(3)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .image:
                        if let url = item.imageFileURL, let image = NSImage(contentsOf: url) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    HStack(spacing: 8) {
                        Text(item.timestamp.relativeDisplay)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        if let bundleId = item.sourceAppBundleId,
                           let appName = bundleIdToAppName(bundleId) {
                            Text("from \(appName)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        if justCopied {
                            Text("已复制")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            // Action buttons (visible on hover)
            if showActions {
                HStack(spacing: 8) {
                    Button(action: onPin) {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 12))
                            .foregroundColor(item.isPinned ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "取消置顶" : "置顶")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("删除")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(showActions ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(showActions ? Color.primary.opacity(0.1) : Color.clear, lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .help("点击复制到剪贴板")
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
            withAnimation(.easeInOut(duration: 0.18)) {
                showActions = hovering
            }
        }
    }

    private func bundleIdToAppName(_ bundleId: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }
}
