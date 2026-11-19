//  FaceTheme.swift
//  The two shipped looks from the v5 designs: Amethyst (purple and gold)
//  and Chalk (white, sport). Long-press the dial to switch between them.

import SwiftUI

extension Color {
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255)
    }
}

struct FaceTheme {
    enum NumeralMode { case all, quarters }

    var id: String
    var bg, dialIn, dialOut, track, track2, minTick, index, numeral: Color
    var hand, lume, accent, dateBg, dateText, label, text, nowFill, nowStroke: Color
    var heart, ring1, ring2, ring3, battery, free: Color
    /// Event colours, assigned to calendars in the order they appear.
    var events: [Color]
    /// Text colour to use on top of each event colour (for the arc label).
    var onEvents: [Color]
    var indexWidth: CGFloat
    var numeralMode: NumeralMode
    var numeralFont: Font
    var numeralRadius: CGFloat
    var slimHands: Bool
    var dullOpacity: Double
    var pastOpacity: Double

    static let amethyst = FaceTheme(
        id: "amethyst",
        bg: Color(rgb: 0x120E26), dialIn: Color(rgb: 0x2E2766), dialOut: Color(rgb: 0x120E26),
        track: Color(rgb: 0x262052), track2: Color(rgb: 0x1D1840), minTick: Color(rgb: 0x5F58A8),
        index: Color(rgb: 0xE9C46A), numeral: Color(rgb: 0xE9C46A),
        hand: Color(rgb: 0xF0CF7A), lume: Color(rgb: 0x999FFF), accent: Color(rgb: 0x999FFF),
        dateBg: Color(rgb: 0x262052), dateText: Color(rgb: 0xE9C46A),
        label: Color(rgb: 0xB8B5F0), text: Color(rgb: 0xF5F3FF),
        nowFill: Color(rgb: 0xE9C46A), nowStroke: Color(rgb: 0x120E26),
        heart: Color(rgb: 0xF29E5B), ring1: Color(rgb: 0x999FFF), ring2: Color(rgb: 0xE9C46A),
        ring3: Color(rgb: 0xD3B4FF), battery: Color(rgb: 0x999FFF), free: Color(rgb: 0x999FFF),
        events: [Color(rgb: 0x999FFF), Color(rgb: 0xE9C46A), Color(rgb: 0xD3B4FF), Color(rgb: 0xF29E5B), Color(rgb: 0x6B74F5)],
        onEvents: [Color(rgb: 0x120E26), Color(rgb: 0x120E26), Color(rgb: 0x120E26), Color(rgb: 0x120E26), Color.white],
        indexWidth: 4,
        numeralMode: .all,
        numeralFont: .system(size: 26, weight: .medium, design: .rounded),
        numeralRadius: 112,
        slimHands: true,
        dullOpacity: 0.5,
        pastOpacity: 0.3)

    static let chalk = FaceTheme(
        id: "chalk",
        bg: Color.white, dialIn: Color.white, dialOut: Color(rgb: 0xF1F2F4),
        track: Color(rgb: 0xECEEF1), track2: Color(rgb: 0xF3F4F6), minTick: Color(rgb: 0xC2C6CC),
        index: Color(rgb: 0x111316), numeral: Color(rgb: 0x111316),
        hand: Color(rgb: 0x111316), lume: Color(rgb: 0xFF5A1F), accent: Color(rgb: 0xFF5A1F),
        dateBg: Color(rgb: 0x111316), dateText: Color.white,
        label: Color(rgb: 0x5B616B), text: Color(rgb: 0x111316),
        nowFill: Color(rgb: 0xFF5A1F), nowStroke: Color.white,
        heart: Color(rgb: 0xF43F7A), ring1: Color(rgb: 0xF43F7A), ring2: Color(rgb: 0x12B76A),
        ring3: Color(rgb: 0x1F6FEB), battery: Color(rgb: 0x12B76A), free: Color(rgb: 0x1F6FEB),
        events: [Color(rgb: 0x1F6FEB), Color(rgb: 0xFF8A00), Color(rgb: 0x8B5CF6), Color(rgb: 0x12B76A), Color(rgb: 0xF43F7A)],
        onEvents: [Color.white, Color(rgb: 0x111316), Color.white, Color(rgb: 0x111316), Color.white],
        indexWidth: 5,
        numeralMode: .quarters,
        numeralFont: .system(size: 46, weight: .bold),
        numeralRadius: 106,
        slimHands: false,
        dullOpacity: 0.5,
        pastOpacity: 0.3)

    static let all = [amethyst, chalk]

    static func named(_ id: String) -> FaceTheme {
        all.first { $0.id == id } ?? amethyst
    }

    /// The low-power look used when the wrist is down (Always On): a pure
    /// black screen, which costs almost nothing on the watch's OLED display,
    /// with everything else drawn dim. Chalk's dark ink turns light grey so it
    /// stays visible on black.
    func lowPower() -> FaceTheme {
        var t = self
        let ink = id == "chalk" ? Color(rgb: 0xB9BEC6) : numeral
        t.bg = .black; t.dialIn = .black; t.dialOut = .black
        t.track = Color.white.opacity(0.07); t.track2 = Color.white.opacity(0.05)
        t.minTick = .clear
        t.index = ink.opacity(0.55); t.numeral = ink.opacity(0.55)
        t.hand = ink.opacity(0.8); t.lume = lume.opacity(0.5)
        t.accent = accent.opacity(0.5)
        t.dateBg = .clear; t.dateText = ink.opacity(0.55)
        t.label = Color.white.opacity(0.35); t.text = Color.white.opacity(0.6)
        t.nowFill = ink.opacity(0.7); t.nowStroke = .black
        t.heart = heart.opacity(0.5); t.battery = battery.opacity(0.5); t.free = free.opacity(0.5)
        t.events = events.map { $0.opacity(0.5) }
        t.onEvents = events.map { _ in Color.white.opacity(0.85) }
        return t
    }

    var next: FaceTheme {
        let i = Self.all.firstIndex { $0.id == id } ?? 0
        return Self.all[(i + 1) % Self.all.count]
    }
}
