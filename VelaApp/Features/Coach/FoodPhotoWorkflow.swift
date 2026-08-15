import UIKit
import SwiftData

@MainActor
final class FoodPhotoWorkflow {
    func analyzeFoodPhoto(
        _ image: UIImage,
        apiKey: String,
        dashboard: DashboardSummary,
        modelContext: ModelContext,
        journalEntries: [JournalEntryRecord],
        savedReports: [AIReportRecord],
        focus: CoachContextFocus = .general,
        services: VelaServices? = nil,
        chatVM: CoachChatVM
    ) async {
        chatVM.isAnalyzingFood = true
        chatVM.streamingContent = L10n.t("Analyzing your meal with Kimi Vision...", "正在用 Kimi 视觉模型分析你的餐食...")

        do {
            let analyzer = FoodPhotoAnalyzer(apiKey: apiKey)
            let result = try await analyzer.analyzeFoodPhoto(image)

            chatVM.streamingContent = ""
            chatVM.isAnalyzingFood = false

            let formattedResult = result.formattedMarkdown()
            let summaryText = result.plainTextSummary()

            let isChinese = AppLanguage.stored.isChinese
            let userMessage = isChinese
                ? """
                我刚拍了一张餐食照片，AI 营养分析如下：

                \(formattedResult)

                请结合我当前的健康数据、活动量、恢复状态与个人档案目标，对这顿饭给出个性化反馈。
                """
                : """
                I just took a photo of my meal. Here's the AI-powered nutritional analysis:

                \(formattedResult)

                Based on this analysis and my current health data, can you provide personalized feedback on this meal? Consider my activity level, recovery state, and health goals from my wiki profile.
                """

            await chatVM.send(
                text: userMessage,
                dashboard: dashboard,
                modelContext: modelContext,
                journalEntries: journalEntries,
                savedReports: savedReports,
                focus: focus,
                services: services
            )

            let foodLog = FoodLogRecord(
                analysis: result,
                mealName: defaultMealName(for: Date()),
                source: .photoAnalysis
            )
            modelContext.insert(foodLog)

            let entry = JournalEntryRecord(
                createdAt: Date(),
                tags: ["food", "meal"],
                note: (AppLanguage.stored.isChinese ? "[照片分析] \(summaryText)" : "[Photo Analysis] \(summaryText)"),
                value: Double(result.totalCalories),
                unit: "kcal"
            )
            modelContext.insert(entry)
            
            // Centralized Event Logging
            let eventService = VelaResolver.shared.resolve(VelaEventService.self)
            eventService.log(
                modelContext: modelContext,
                type: "food_photo_analysis",
                title: "Kimi 膳食识别分析",
                detail: "识别到餐食，摄入约 \(result.totalCalories) kcal"
            )
            
            try modelContext.save()
            VelaAppState.shared.markLocalDataChanged()
        } catch {
            chatVM.streamingContent = ""
            chatVM.isAnalyzingFood = false
            chatVM.messages.append(CoachChatVM.ChatMsg(
                role: .assistant,
                content: L10n.t(
                    "Sorry, I couldn't analyze the food photo: \(error.localizedDescription)",
                    "抱歉，无法分析食物照片：\(error.localizedDescription)"
                )
            ))
        }
    }

    private func defaultMealName(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return "Breakfast"
        case 11..<16:
            return "Lunch"
        case 16..<22:
            return "Dinner"
        default:
            return "Snack"
        }
    }
}
