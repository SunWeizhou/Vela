import SwiftUI
import SwiftData

// MARK: - CoachHistoryDrawer

struct CoachHistoryDrawer: View {
    let width: CGFloat
    @ObservedObject var vm: CoachChatVM
    let modelContext: ModelContext
    @Binding var showHistoryDrawer: Bool
    @Binding var renamingSession: CoachSessionRecord?
    @Binding var renameText: String
    @Binding var isRenamingSession: Bool
    @Binding var sessionPendingDeletion: CoachSessionRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drawer Header
            HStack {
                Text("历史对话")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showHistoryDrawer = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundStyle(VelaTheme.accent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)
            .padding(.bottom, 16)
            
            // New Chat Button
            Button {
                vm.createNewSession(modelContext: modelContext)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showHistoryDrawer = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("新建对话")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.accent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            Divider().padding(.horizontal, 20).padding(.bottom, 12)
            
            // Sessions Scroll List
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(vm.sessions) { session in
                        HStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(vm.currentSession?.id == session.id ? VelaTheme.accent : VelaTheme.muted)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title.isEmpty ? "新对话" : session.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(VelaTheme.fg)
                                    .lineLimit(1)
                                
                                Text(session.updatedAt.formatted(.dateTime.month().day().hour().minute()))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(VelaTheme.muted)
                            }
                            
                            Spacer()
                            
                            if vm.currentSession?.id == session.id {
                                Button {
                                    renamingSession = session
                                    renameText = session.title
                                    isRenamingSession = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12))
                                        .foregroundStyle(VelaTheme.accent)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    sessionPendingDeletion = session
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(VelaTheme.danger)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(vm.currentSession?.id == session.id ? VelaTheme.cardBg : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(vm.currentSession?.id == session.id ? VelaTheme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 14)
                        .onTapGesture {
                            vm.selectSession(session, modelContext: modelContext)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showHistoryDrawer = false
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Drawer Footer
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(VelaTheme.accent)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("本机健康资料")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("本机优先存储")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 48)
            .background(VelaTheme.surface)
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(VelaTheme.systemGroupedBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(VelaTheme.separatorSoft)
                .frame(width: 0.5)
        }
    }
}
