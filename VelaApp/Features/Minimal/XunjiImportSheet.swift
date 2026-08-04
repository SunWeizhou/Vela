import SwiftUI

struct XunjiImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var apiKey: String
    @Binding var selectedDate: Date
    @Binding var includeFullData: Bool
    var isImporting: Bool
    var message: String?
    var onImport: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("训记训练导入", systemImage: "tray.and.arrow.down.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("读取指定日期的训记训练，并合并到 Vela 的力量训练、统一训练记录和训练负荷中。")
                            .font(.system(size: 13))
                            .foregroundStyle(VelaTheme.muted)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))

                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker("训练日期", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        SecureField("训记密钥", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        Toggle("读取完整组数据", isOn: $includeFullData)
                            .font(.system(size: 13, weight: .semibold))
                        Text("完整模式会保留未完成组、RPE、备注、超级组和动作摘要。短时间重复导入同一天训练时，会直接复用刚读取的数据，减少等待。")
                            .font(.system(size: 11))
                            .foregroundStyle(VelaTheme.muted)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))

                    if let message {
                        Text(message)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VelaTheme.fg)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous).fill(VelaTheme.cardBg))
                    }

                    Button {
                        onImport()
                    } label: {
                        HStack {
                            if isImporting {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text(isImporting ? "正在导入" : "导入并合并训练")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color.white)
                        .background(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous).fill(VelaTheme.fg))
                    }
                    .disabled(isImporting)
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(VelaTheme.systemGroupedBackground)
            .navigationTitle("导入训记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
