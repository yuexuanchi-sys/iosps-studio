import AppKit
import BirthdayCore
import Foundation
import MediaIO
import SwiftUI

struct PhotoMemoryTimelineView: View {
    let session: PhotoMemorySession
    let largeText: Bool
    let onGoToEditor: () -> Void
    let onContinueEditing: (PhotoProjectReference) -> Void
    let onMakeMovie: (ImportedMedia, String) -> Void

    @FocusState private var focusedMemoryID: ProjectID?

    private var flatIndexByID: [ProjectID: Int] {
        Dictionary(uniqueKeysWithValues: session.items.enumerated().map { ($0.element.id, $0.offset) })
    }

    var body: some View {
        Group {
            if let detail = session.selectedMemory {
                detailView(for: detail)
            } else {
                listView
            }
        }
        .font(.system(size: largeText ? 18 : 14))
        .controlSize(largeText ? .large : .regular)
        .frame(minWidth: 740, minHeight: 480)
        .task {
            await session.reload()
            restoreListFocus()
        }
        .onChange(of: session.selectedMemoryID) { oldValue, newValue in
            if oldValue != nil, newValue == nil {
                restoreListFocus()
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            listHeader
            Divider()
            if session.hasPendingRetries || session.errorMessage != nil {
                errorBanner
                Divider()
            }
            if session.items.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(session.daySections) { section in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(verbatim: section.title)
                                        .font(.system(size: largeText ? 21 : 15, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .accessibilityAddTraits(.isHeader)
                                    ForEach(section.items) { item in
                                        let index = flatIndexByID[item.id] ?? 0
                                        memoryRow(item, index: index)
                                            .id(item.id)
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                    .onAppear {
                        if let anchor = session.lastOpenedMemoryID {
                            proxy.scrollTo(anchor, anchor: .center)
                        }
                    }
                    .onChange(of: session.selectedMemoryID) { oldValue, newValue in
                        if oldValue != nil, newValue == nil, let anchor = session.lastOpenedMemoryID {
                            proxy.scrollTo(anchor, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var listHeader: some View {
        HStack(spacing: 10) {
            Text("回忆")
                .font(.system(size: largeText ? 28 : 22, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("memories-title")
            if !session.items.isEmpty {
                Text("共 \(session.items.count) 件作品")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("memories-count")
            }
            Spacer()
            Button("去修图", action: onGoToEditor)
                .accessibilityIdentifier("memories-header-edit")
            Button("刷新") { Task { await session.reload() } }
                .disabled(session.isBusy)
                .accessibilityIdentifier("memories-refresh")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var errorBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(verbatim: session.errorMessage ?? String(localized: "有待重试的回忆更新。"))
                .lineLimit(2)
                .accessibilityIdentifier("memories-error-banner")
            Spacer()
            if session.hasPendingRetries {
                Button("重试更新索引") {
                    Task { _ = await session.retryPendingPublications() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("memories-retry-index")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有已保存的修图作品", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("保存修图工程后，作品会按最近编辑时间自动出现在这里。")
        } actions: {
            Button("去修图", action: onGoToEditor)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("memories-go-edit")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func memoryRow(_ item: ResolvedPhotoMemory, index: Int) -> some View {
        HStack(spacing: 14) {
            Button {
                session.openDetail(id: item.id)
            } label: {
                HStack(spacing: 14) {
                    thumbnailView(for: item)
                        .frame(width: largeText ? 112 : 92, height: largeText ? 84 : 68)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: item.entry.title)
                            .font(.system(size: largeText ? 20 : 15, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("\(item.entry.pixelWidth) × \(item.entry.pixelHeight) 像素 · \(formattedTime(item.entry.savedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        if let notice = healthNotice(for: item.health) {
                            Label(notice, systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($focusedMemoryID, equals: item.id)
            .accessibilityLabel(Text("\(item.entry.title)，\(item.entry.pixelWidth) × \(item.entry.pixelHeight) 像素"))
            .accessibilityIdentifier("memory-card-\(index)")

            HStack(spacing: 8) {
                if item.canReopenProject {
                    Button("继续编辑") {
                        onContinueEditing(PhotoProjectReference(projectID: item.id, fileURL: item.projectURL))
                    }
                    .accessibilityIdentifier("memory-row-edit-\(index)")
                } else {
                    Button("重新检查") {
                        Task { await session.reload() }
                    }
                    .accessibilityIdentifier("memory-row-recheck-\(index)")
                }
            }
        }
        .padding(12)
        .background(
            focusedMemoryID == item.id ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(focusedMemoryID == item.id ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
        }
    }

    private func detailView(for item: ResolvedPhotoMemory) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button("返回回忆", systemImage: "chevron.left") {
                    session.closeDetail()
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("memories-back")

                Button("上一张") { session.selectAdjacentDetail(offset: -1) }
                    .disabled(!session.canSelectAdjacentDetail(offset: -1))
                    .accessibilityIdentifier("memories-prev")

                Button("下一张") { session.selectAdjacentDetail(offset: 1) }
                    .disabled(!session.canSelectAdjacentDetail(offset: 1))
                    .accessibilityIdentifier("memories-next")

                Spacer()

                Button("做短片", systemImage: "film.stack") {
                    if let media = item.movieMedia {
                        onMakeMovie(media, item.entry.title)
                    }
                }
                .disabled(item.movieMedia == nil)
                .accessibilityIdentifier("memories-make-movie")

                Button("继续编辑", systemImage: "slider.horizontal.3") {
                    onContinueEditing(PhotoProjectReference(projectID: item.id, fileURL: item.projectURL))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!item.canReopenProject)
                .accessibilityIdentifier("memories-continue-edit")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            VStack(spacing: 12) {
                if let url = item.previewImageURL, let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel(Text("\(item.entry.title) 预览"))
                        .accessibilityIdentifier("memories-detail-image")
                } else {
                    ContentUnavailableView {
                        Label("预览缩略图暂时不可读", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(healthNotice(for: item.health) ?? String(localized: "可重新打开原工程并再次保存以修复预览。"))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: item.entry.title)
                            .font(.headline)
                            .accessibilityIdentifier("memories-detail-title")
                        Text("\(item.entry.pixelWidth) × \(item.entry.pixelHeight) 像素 · 保存于 \(formattedDateTime(item.entry.savedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .accessibilityIdentifier("memories-detail-meta")
                    }
                    Spacer()
                    if let notice = healthNotice(for: item.health) {
                        Text(verbatim: notice)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("memories-detail-notice")
                    }
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func thumbnailView(for item: ResolvedPhotoMemory) -> some View {
        if let url = item.previewThumbnailURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.secondary.opacity(0.15)
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func healthNotice(for health: PhotoMemoryEntryHealth) -> String? {
        switch health {
        case .ready:
            nil
        case .missingProject:
            String(localized: "原照片工程文件已丢失，其余回忆已保留；恢复文件后可点击「重新检查」。")
        case .unreadableProject:
            String(localized: "原照片工程暂无法读取（可能权限已撤回），请恢复权限后重试。")
        case .damagedPreview:
            String(localized: "预览缩略图已损坏，点击「继续编辑」重开工程并重新保存即可修复。")
        }
    }

    private func restoreListFocus() {
        guard session.selectedMemoryID == nil else { return }
        if let last = session.lastOpenedMemoryID, session.items.contains(where: { $0.id == last }) {
            focusedMemoryID = last
        } else {
            focusedMemoryID = session.items.first?.id
        }
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }

    private func formattedDateTime(_ date: Date) -> String {
        date.formatted(date: .numeric, time: .standard)
    }
}
