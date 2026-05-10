import SwiftUI

struct HistoryPanelView: View {
    let storage: StorageManager
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var pinnedItems: [ClipboardItem] = []
    @State private var regularItems: [ClipboardItem] = []
    @State private var refreshToggle = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                SearchBar(text: $searchText)

                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("设置")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .opacity(0.2)

            // Content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 6) {
                        if pinnedItems.isEmpty && regularItems.isEmpty && !searchText.isEmpty {
                            EmptySearchView()
                        } else if pinnedItems.isEmpty && regularItems.isEmpty {
                            EmptyStateView()
                        } else {
                            // Pinned section
                            if !pinnedItems.isEmpty {
                                SectionHeader(title: "已置顶")
                                    .padding(.horizontal, 14)
                                    .padding(.top, 8)

                                ForEach(pinnedItems, id: \.id) { item in
                                    ClipboardCardView(
                                        item: item,
                                        onCopy: { storage.copyToClipboard(item) },
                                        onPin: { togglePin(item) },
                                        onDelete: { deleteItem(item) }
                                    )
                                    .padding(.horizontal, 8)
                                }
                            }

                            // Regular items
                            if !regularItems.isEmpty {
                                if !pinnedItems.isEmpty {
                                    SectionHeader(title: "历史记录")
                                        .padding(.horizontal, 14)
                                        .padding(.top, 4)
                                }

                                ForEach(regularItems, id: \.id) { item in
                                    ClipboardCardView(
                                        item: item,
                                        onCopy: { storage.copyToClipboard(item) },
                                        onPin: { togglePin(item) },
                                        onDelete: { deleteItem(item) }
                                    )
                                    .padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    .id("topAnchor")
                }
                .onChange(of: searchText) { _, _ in
                    loadItems()
                }
                .onAppear {
                    loadItems()
                    proxy.scrollTo("topAnchor", anchor: .top)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshPanel"))) { _ in
                    loadItems()
                    proxy.scrollTo("topAnchor", anchor: .top)
                }
            }
            .frame(maxHeight: 520)

            // Bottom status bar
            Divider()
                .opacity(0.2)

            HStack {
                Text("共 \(pinnedItems.count + regularItems.count) 条")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                let days = UserDefaults.standard.integer(forKey: "retentionDays")
                if days > 0 {
                    Text("保留\(days)天")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("永久保留")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 400)
    }

    private func loadItems() {
        pinnedItems = storage.fetchPinnedItems()
        regularItems = storage.fetchItems(searchText: searchText)
            .filter { !$0.isPinned }
    }

    private func togglePin(_ item: ClipboardItem) {
        storage.togglePin(item)
        loadItems()
    }

    private func deleteItem(_ item: ClipboardItem) {
        storage.deleteItem(item)
        loadItems()
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.4))
            Text("未找到匹配内容")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }
}
