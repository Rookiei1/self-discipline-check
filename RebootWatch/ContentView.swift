import SwiftUI
import WatchKit

/// Three pages, swiped with the Digital Crown: today, history, reset.
struct ContentView: View {
    @StateObject private var store = LogStore()

    var body: some View {
        TimelineView(.everyMinute) { context in
            TabView {
                TodayPage(log: store.log, today: context.date)
                HistoryPage(log: store.log, today: context.date)
                ResetPage(store: store, today: context.date)
            }
            .tabViewStyle(.verticalPage)
        }
    }
}

// MARK: - Today

private struct TodayPage: View {
    let log: DisciplineLog
    let today: Date
    @State private var breathing = false

    var body: some View {
        let streak = log.streak(today: today)
        let goal = DisciplineLog.progress(streak: streak)
        let resetToday = log.isReset(today, .current)

        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: goal.fraction)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(streak)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(streak == 1 ? "day" : "days")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: .infinity)

            Text(resetToday ? "Day 1 starts tomorrow" : "Next goal: \(goal.next) days")
                .font(.footnote)
                .foregroundStyle(resetToday ? Color.orange : Color.secondary)

            Button {
                breathing = true
                WKInterfaceDevice.current().play(.start)
            } label: {
                Label("Breathe 60s", systemImage: "wind")
            }
            .tint(.orange)
        }
        .sheet(isPresented: $breathing) { BreatheView() }
    }
}

// MARK: - History

private struct HistoryPage: View {
    let log: DisciplineLog
    let today: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            Text("Last 28 days")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(0..<28, id: \.self) { index in
                    dot(daysAgo: 27 - index)
                }
            }
            HStack {
                stat(log.bestStreak(today: today), "Best")
                stat(log.cleanDays(today: today), "Clean")
                stat(log.resetCount(), "Resets")
            }
        }
    }

    private func dot(daysAgo: Int) -> some View {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return Circle()
            .fill(color(log.status(of: day, today: today)))
            .overlay {
                if daysAgo == 0 { Circle().stroke(Color.white, lineWidth: 1.5) }
            }
            .aspectRatio(1, contentMode: .fit)
    }

    private func color(_ status: DisciplineLog.DayStatus) -> Color {
        switch status {
        case .clean: return .green
        case .reset: return .red
        case .untracked, .future: return Color.gray.opacity(0.3)
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text("\(value)")
                .font(.headline)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reset

private struct ResetPage: View {
    @ObservedObject var store: LogStore
    let today: Date
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 10) {
            if store.log.isReset(today, .current) {
                Text("Reset today. Tomorrow is a new day 1.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Button("Undo Today's Reset") {
                    store.undoReset()
                    WKInterfaceDevice.current().play(.click)
                }
            } else {
                Text("Slipped? Start again. Your earlier days stay counted.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Button("Reset", role: .destructive) { confirming = true }
            }
        }
        .alert("Reset your streak?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.reset()
                WKInterfaceDevice.current().play(.failure)
            }
        } message: {
            Text("Today won't count. You can undo this until midnight.")
        }
    }
}

// MARK: - Breathe

/// One minute of guided breathing. Time comes from the clock, so it stays right
/// even if the screen sleeps when the wrist drops.
private struct BreatheView: View {
    private static let length: TimeInterval = 60
    private static let breath: TimeInterval = 4

    @Environment(\.dismiss) private var dismiss
    @State private var start = Date()
    @State private var lastPhase = -1
    @State private var finished = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            let phase = Int(elapsed / BreatheView.breath)
            VStack(spacing: 8) {
                if finished {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.green)
                    Text("You made it.")
                        .font(.headline)
                    Button("Done") { dismiss() }
                } else {
                    Circle()
                        .fill(Color.orange.opacity(0.75))
                        .scaleEffect(scale(elapsed: elapsed))
                        .frame(maxHeight: .infinity)
                    Text(phase % 2 == 0 ? "Breathe in" : "Breathe out")
                        .font(.headline)
                    Text("\(max(0, Int((BreatheView.length - elapsed).rounded(.up))))s")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: phase) { _, newPhase in
                guard !finished else { return }
                if elapsed >= BreatheView.length {
                    finished = true
                    WKInterfaceDevice.current().play(.success)
                } else if newPhase != lastPhase {
                    lastPhase = newPhase
                    WKInterfaceDevice.current().play(.click)
                }
            }
        }
    }

    private func scale(elapsed: TimeInterval) -> CGFloat {
        let cycle = elapsed.truncatingRemainder(dividingBy: BreatheView.breath * 2) / (BreatheView.breath * 2)
        let wave = (1 - cos(cycle * 2 * .pi)) / 2   // 0 → 1 → 0 over one in-and-out
        return 0.45 + 0.55 * CGFloat(wave)
    }
}

#Preview {
    ContentView()
}
