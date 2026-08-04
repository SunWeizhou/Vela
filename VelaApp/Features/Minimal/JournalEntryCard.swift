import SwiftUI
import SwiftData

struct JournalEntryCard: View {
    @Environment(\.colorScheme) private var cs
    let entry: JournalEntryRecord
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.uiIcon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(entry.uiColor))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.uiDisplayTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    
                    Text(entry.createdAt.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }
                
                if !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(entry.note)
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.muted)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(VelaTheme.systemGroupedBackground))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除手记：\(entry.uiDisplayTitle)")
            .accessibilityHint("删除前会要求确认")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(VelaTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
    }
}

extension JournalEntryRecord {
    var uiIcon: String {
        if tags.contains("低碳水化合物") { return "fork.knife" }
        if tags.contains("添加糖") { return "birthday.cake.fill" }
        if tags.contains("生酮饮食") { return "leaf.fill" }
        if tags.contains("在床上使用设备") { return "iphone" }
        if tags.contains("caffeine") || tags.contains("咖啡因") { return "cup.and.saucer.fill" }
        if tags.contains("hydration") || tags.contains("补水") { return "drop.fill" }
        if tags.contains("mood") || tags.contains("每日心情") { return "face.smiling.fill" }
        if tags.contains("alcohol") || tags.contains("酒") { return "wineglass.fill" }
        return "text.bubble.fill"
    }

    var uiColor: Color {
        if tags.contains("低碳水化合物") { return Color.orange }
        if tags.contains("添加糖") { return Color.purple }
        if tags.contains("生酮饮食") { return Color.green }
        if tags.contains("在床上使用设备") { return Color.blue }
        if tags.contains("caffeine") || tags.contains("咖啡因") { return Color(hex: "#8B5A2B") }
        if tags.contains("hydration") || tags.contains("补水") { return VelaTheme.accent }
        if tags.contains("mood") || tags.contains("每日心情") { return VelaTheme.systemYellow }
        if tags.contains("alcohol") || tags.contains("酒") { return VelaTheme.stressColor }
        return VelaTheme.accent
    }

    var uiDisplayTitle: String {
        if tags.contains("低碳水化合物") { return "低碳水化合物" }
        if tags.contains("添加糖") { return "添加糖" }
        if tags.contains("生酮饮食") { return "生酮饮食" }
        if tags.contains("在床上使用设备") { return "在床上使用设备" }
        if tags.contains("caffeine") || tags.contains("咖啡因") {
            if let val = value {
                return "咖啡因: \(Int(val)) mg"
            }
            return "咖啡因"
        }
        if tags.contains("hydration") || tags.contains("补水") {
            if let val = value {
                return "饮水: \(Int(val)) ml"
            }
            return "补水"
        }
        if tags.contains("mood") || tags.contains("每日心情") {
            return "每日心情"
        }
        if tags.contains("alcohol") || tags.contains("酒") {
            if let val = value {
                return "饮酒: \(val) 杯"
            }
            return "饮酒"
        }
        return tags.first(where: { $0 != "behavior_signal" && !$0.hasPrefix("behavior:") && !$0.hasPrefix("intensity:") && !$0.hasPrefix("timing:") }) ?? "手记"
    }
}
