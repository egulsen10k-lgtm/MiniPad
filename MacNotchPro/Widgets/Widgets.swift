//
//  Widgets.swift
//  MiniPad
//

import SwiftUI
import Combine
import AppKit

// MARK: - Digital Clock View (HH:MM Top Bar)
struct DigitalClockView: View {
    let textColor: Color
    @ObservedObject var settings = AppSettings.shared
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = settings.showClockSeconds ? "HH:mm:ss" : "HH:mm"
        return f.string(from: currentTime)
    }

    var body: some View {
        Text(timeString)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(textColor)
            .onReceive(timer) { time in
                currentTime = time
            }
    }
}

// MARK: - Mini Spotify Bottom Player
struct MiniSpotifyBottomBar: View {
    @ObservedObject var musicManager: MusicManager
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color

    private func openMusicApp() {
        if let spotifyURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open(spotifyURL, configuration: config)
        } else if let musicURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open(musicURL, configuration: config)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Clickable Artwork / App Launcher
            Button(action: openMusicApp) {
                HStack(spacing: 8) {
                    ZStack {
                        if let art = musicManager.artwork {
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 30, height: 30)
                                .cornerRadius(6)
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(musicManager.sourceApp == "Spotify" ? Color.green.opacity(0.15) : accentColor.opacity(0.15))
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: musicManager.sourceApp == "Spotify" ? "music.note.house.fill" : "music.note")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(musicManager.sourceApp == "Spotify" ? Color.green : accentColor)
                        }
                    }

                    // Track & Artist Info
                    VStack(alignment: .leading, spacing: 1) {
                        Text(musicManager.hasTrack ? musicManager.title : "Open Spotify / Music")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundColor(textColor)
                            .lineLimit(1)

                        Text(musicManager.hasTrack && !musicManager.artist.isEmpty ? musicManager.artist : "Click to launch player")
                            .font(.system(size: 8.5, weight: .regular, design: .rounded))
                            .foregroundColor(textColor.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Playback Controls
            HStack(spacing: 8) {
                Button(action: { musicManager.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.8))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: { musicManager.togglePlayPause() }) {
                    Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(textColor)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(musicManager.hasTrack ? accentColor.opacity(0.3) : cardFillColor)
                                .overlay(Circle().stroke(cardStrokeColor, lineWidth: 0.8))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: { musicManager.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.8))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(musicManager.hasTrack ? accentColor.opacity(0.2) : cardStrokeColor, lineWidth: 0.6)
                )
        )
    }
}
struct ClockWidgetView: View {
    @ObservedObject var appSettings: AppSettings
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 6) {
            // Analog-style clock face
            ZStack {
                // Clock face background
                Circle()
                    .fill(cardFillColor.opacity(0.5))
                    .overlay(
                        Circle()
                            .stroke(cardStrokeColor, lineWidth: 1)
                    )
                    .frame(width: 80, height: 80)

                // Hour markers
                ForEach(0..<12) { i in
                    let angle = Angle(degrees: Double(i) * 30)
                    Rectangle()
                        .fill(textColor.opacity(i % 3 == 0 ? 0.6 : 0.3))
                        .frame(width: i % 3 == 0 ? 2 : 1, height: i % 3 == 0 ? 8 : 4)
                        .offset(y: -32)
                        .rotationEffect(angle)
                }

                // Hour hand
                let hour = Calendar.current.component(.hour, from: currentTime)
                let minute = Calendar.current.component(.minute, from: currentTime)
                Rectangle()
                    .fill(textColor.opacity(0.8))
                    .frame(width: 2.5, height: 22)
                    .offset(y: -11)
                    .rotationEffect(.degrees(Double(hour % 12) * 30 + Double(minute) * 0.5))

                // Minute hand
                Rectangle()
                    .fill(textColor.opacity(0.6))
                    .frame(width: 1.5, height: 28)
                    .offset(y: -14)
                    .rotationEffect(.degrees(Double(minute) * 6))

                // Second hand
                let second = Calendar.current.component(.second, from: currentTime)
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 0.8, height: 30)
                    .offset(y: -15)
                    .rotationEffect(.degrees(Double(second) * 6))

                // Center dot
                Circle()
                    .fill(accentColor)
                    .frame(width: 4, height: 4)
            }

            // Digital time display
            Text(currentTime, style: .time)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(textColor)
                .onReceive(timer) { time in
                    currentTime = time
                }
        }
    }
}

// MARK: - Timer Widget
struct TimerWidgetView: View {
    @ObservedObject var appSettings: AppSettings
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color

    @State private var timerValue: TimeInterval = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var laps: [TimeInterval] = []
    @State private var lapCount = 0

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int(time * 100) % 100
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }

    private func toggleTimer() {
        if isRunning {
            timer?.invalidate()
            timer = nil
            isRunning = false
        } else {
            isRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
                timerValue += 0.02
            }
        }
    }

    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        if timerValue > 0 {
            laps.insert(timerValue, at: 0)
            lapCount += 1
            if laps.count > 5 {
                laps.removeLast()
            }
        }
        timerValue = 0
    }

    var body: some View {
        VStack(spacing: 8) {
            // Timer display
            Text(formatTime(timerValue))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(textColor)

            // Control buttons
            HStack(spacing: 12) {
                Button(action: resetTimer) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(cardFillColor)
                                .overlay(Circle().stroke(cardStrokeColor, lineWidth: 0.8))
                        )
                }
                .buttonStyle(.plain)

                Button(action: toggleTimer) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.95))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(isRunning ? Color.orange.opacity(0.3) : accentColor.opacity(0.3))
                                .overlay(Circle().stroke(cardStrokeColor, lineWidth: 0.8))
                        )
                }
                .buttonStyle(.plain)
            }

            // Lap times
            if !laps.isEmpty {
                VStack(spacing: 2) {
                    ForEach(laps.prefix(3), id: \.self) { lap in
                        Text(formatTime(lap))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(textColor.opacity(0.5))
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Alarm Widget
struct AlarmWidgetView: View {
    @ObservedObject var appSettings: AppSettings
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color

    @State private var alarms: [(hour: Int, minute: Int, label: String, isEnabled: Bool)] = [
        (hour: 8, minute: 0, label: "Morning", isEnabled: true),
        (hour: 12, minute: 30, label: "Lunch", isEnabled: false),
        (hour: 18, minute: 0, label: "Evening", isEnabled: true)
    ]

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private func timeString(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("Alarms")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textColor.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(alarms.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeString(hour: alarms[index].hour, minute: alarms[index].minute))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(textColor)
                        Text(alarms[index].label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(textColor.opacity(0.5))
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { alarms[index].isEnabled },
                        set: { newValue in alarms[index].isEnabled = newValue }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(cardFillColor)
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(cardStrokeColor, lineWidth: 0.6))
                )
            }
        }
    }
}

// MARK: - Calendar Widget
struct CalendarWidgetView: View {
    @ObservedObject var appSettings: AppSettings
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color

    @State private var selectedDate = Date()
    @State private var currentMonth = Date()

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private func openCalendar() {
        if let calendarURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open(calendarURL, configuration: config)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        }
    }

    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }

        var days: [Date?] = []
        var current = monthFirstWeek.start

        // Fill leading blanks
        let leadingBlanks = calendar.component(.weekday, from: monthInterval.start) - calendar.firstWeekday
        for _ in 0..<max(0, leadingBlanks) {
            days.append(nil)
        }

        // Fill actual days
        while current < monthInterval.end {
            if calendar.isDate(current, equalTo: monthInterval.start, toGranularity: .month) {
                days.append(current)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        // Fill trailing blanks
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    var body: some View {
        VStack(spacing: 3) {
            // Month header
            HStack {
                Button(action: {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.6))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(dateFormatter.string(from: currentMonth))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(textColor)

                Spacer()

                Button(action: {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)

            // Day headers
            HStack(spacing: 0) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day.prefix(1))
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 1) {
                ForEach(days.indices, id: \.self) { index in
                    if let day = days[index] {
                        let isToday = calendar.isDateInToday(day)
                        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)

                        Text(dayFormatter.string(from: day))
                            .font(.system(size: 8, weight: isToday ? .bold : .regular))
                            .foregroundColor(isToday ? .white : (isSelected ? accentColor : textColor))
                            .frame(width: 13, height: 13)
                            .background(
                                Circle()
                                    .fill(isToday ? accentColor : (isSelected ? accentColor.opacity(0.2) : Color.clear))
                            )
                            .onTapGesture {
                                selectedDate = day
                            }
                    } else {
                        Color.clear.frame(width: 13, height: 13)
                    }
                }
            }

            // Open Calendar button
            Button(action: openCalendar) {
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Open Calendar")
                        .font(.system(size: 8, weight: .medium))
                }
                .foregroundColor(accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    Capsule()
                        .fill(accentColor.opacity(0.1))
                        .overlay(Capsule().stroke(accentColor.opacity(0.3), lineWidth: 0.6))
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxHeight: 104, alignment: .center)
    }
}

// MARK: - Compact Music Widget (Spotify-style)
struct SpotifyWidgetView: View {
    @ObservedObject var musicManager: MusicManager
    @ObservedObject var appSettings: AppSettings
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color

    var body: some View {
        VStack(spacing: 6) {
            // Album art placeholder with waveform animation
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cardFillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(cardStrokeColor, lineWidth: 0.8)
                    )
                    .frame(height: 60)

                if musicManager.hasTrack {
                    // Animated waveform bars
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(musicManager.sourceApp == "Spotify" ? Color.green : Color.pink)
                                .frame(width: 3, height: musicManager.isPlaying ? CGFloat.random(in: 10...35) : 8)
                                .animation(.easeInOut(duration: 0.4).repeatForever(), value: musicManager.isPlaying)
                        }
                    }
                    .opacity(musicManager.isPlaying ? 1 : 0.4)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(textColor.opacity(0.3))
                }
            }

            // Track info
            VStack(spacing: 1) {
                Text(musicManager.hasTrack ? musicManager.title : "Not Playing")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                if musicManager.hasTrack && !musicManager.artist.isEmpty {
                    Text(musicManager.artist)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundColor(textColor.opacity(0.5))
                        .lineLimit(1)
                }
            }

            // Transport controls
            HStack(spacing: 16) {
                Button(action: { musicManager.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.7))
                }
                .buttonStyle(.plain)

                Button(action: { musicManager.togglePlayPause() }) {
                    Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.95))
                }
                .buttonStyle(.plain)

                Button(action: { musicManager.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Phone-Style Swipeable Widget Stack
struct WidgetsStackView: View {
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var musicManager: MusicManager
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color

    @State private var currentPage: Int = 0
    private let pages = [0, 1, 2, 3] // 0=Clock/Timer, 1=Alarm, 2=Calendar, 3=Spotify

    var body: some View {
        VStack(spacing: 6) {
            // Widget Card
            ZStack {
                ForEach(pages, id: \.self) { page in
                    if currentPage == page {
                        widgetCard(for: page)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            .gesture(
                                DragGesture()
                                    .onEnded { value in
                                        if value.translation.width < -30 && currentPage < pages.count - 1 {
                                            withAnimation(.spring()) { currentPage += 1 }
                                        } else if value.translation.width > 30 && currentPage > 0 {
                                            withAnimation(.spring()) { currentPage -= 1 }
                                        }
                                    }
                            )
                    }
                }
            }
            .frame(height: 120)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)

            // Page dots indicator
            HStack(spacing: 5) {
                ForEach(pages, id: \.self) { i in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentPage = i
                        }
                    }) {
                        Circle()
                            .fill(i == currentPage ? accentColor : cardStrokeColor.opacity(0.6))
                            .frame(width: i == currentPage ? 6 : 4, height: i == currentPage ? 6 : 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 145)
        .onHover { isHovered in
            AppDiscoveryManager.shared.isModalOrPopupActive = isHovered
        }
    }

    @ViewBuilder
    private func widgetCard(for page: Int) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(cardFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(cardStrokeColor.opacity(0.6), lineWidth: 0.8)
            )
            .overlay(
                pageContent(for: page)
                    .padding(8)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func pageContent(for page: Int) -> some View {
        switch page {
        case 0:
            HStack(spacing: 8) {
                ClockWidgetView(appSettings: appSettings, textColor: textColor, accentColor: accentColor, cardFillColor: cardFillColor, cardStrokeColor: cardStrokeColor).frame(width: 60)
                Divider().background(textColor.opacity(0.15))
                TimerWidgetView(appSettings: appSettings, textColor: textColor, accentColor: accentColor, cardFillColor: cardFillColor, cardStrokeColor: cardStrokeColor).frame(width: 60)
            }
        case 1:
            AlarmWidgetView(appSettings: appSettings, textColor: textColor, accentColor: accentColor, cardFillColor: cardFillColor, cardStrokeColor: cardStrokeColor)
        case 2:
            CalendarWidgetView(appSettings: appSettings, textColor: textColor, accentColor: accentColor, cardFillColor: cardFillColor, cardStrokeColor: cardStrokeColor)
        case 3:
            SpotifyWidgetView(musicManager: musicManager, appSettings: appSettings, textColor: textColor, accentColor: accentColor, cardFillColor: cardFillColor, cardStrokeColor: cardStrokeColor)
        default:
            EmptyView()
        }
    }
}
