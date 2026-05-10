#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard = "Dashboard"
    case guests = "Gästeliste"
    case tags = "Beziehungen"
    case tables = "Sitzplan"
    case assistant = "KI-Assistent"
    case export = "Export"
    case settings = "Einstellungen"

    static var sidebarVisible: [AppSection] {
        [.dashboard, .guests, .tags, .tables, .export, .settings]
    }

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "house"
        case .guests: "person.2"
        case .tags: "heart"
        case .tables: "square.grid.3x3"
        case .assistant: "sparkles"
        case .export: "square.and.arrow.up"
        case .settings: "gearshape"
        }
    }

    enum Group: String, CaseIterable {
        case overview = "Übersicht"
        case planning = "Planung"
        case app = "App"
    }

    var group: Group {
        switch self {
        case .dashboard, .guests, .tags: .overview
        case .tables, .assistant, .export: .planning
        case .settings: .app
        }
    }
}

struct AppSidebar: View {
    @Binding var selection: AppSection?
    @Query private var events: [Event]
    @Query private var guests: [Guest]
    @AppStorage("lmStudioEndpoint") private var lmStudioEndpoint = "http://localhost:1234"
    @State private var connectionState: KIConnectionState = .unknown

    enum KIConnectionState {
        case unknown, connected, offline
    }

    private var event: Event? { events.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Event-Header
            if let event {
                VStack(alignment: .leading, spacing: 3) {
                    Text(eventCoupleHeader(event))
                        .font(Tokens.Typography.display(size: 17))
                        .foregroundStyle(Tokens.Colors.ink)
                        .lineLimit(1)
                    if let date = event.date {
                        Text(eventSubline(date: date, venue: event.venue))
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .lineLimit(1)
                    } else if !event.venue.isEmpty {
                        Text(event.venue)
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }

            // Nav-Gruppen
            ForEach(AppSection.Group.allCases, id: \.self) { group in
                let items = AppSection.sidebarVisible.filter { $0.group == group }
                if !items.isEmpty {
                    sidebarGroup(label: group.rawValue, items: items)
                        .padding(.bottom, 14)
                }
            }

            Spacer(minLength: 0)

            // KI-Status footer
            kiStatusFooter
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .padding(.top, 18)
        .frame(maxHeight: .infinity)
        .background(liquidGlassBackground)
        .task {
            // Initial-Check sofort, dann alle 20s nachfragen damit ein Sidebar-Status-
            // Wechsel von grün → orange auch bemerkt wird, wenn LM Studio zwischendurch
            // ausgeht (oder erst angeworfen wird).
            await checkConnection()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                await checkConnection()
            }
        }
    }

    private var liquidGlassBackground: some View {
        ZStack {
            Tokens.Colors.bg2
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.6)
            LinearGradient(
                colors: [
                    Color(red: 0.82, green: 0.88, blue: 0.96).opacity(0.18),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func sidebarGroup(label: String, items: [AppSection]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.6)
                .padding(.horizontal, 22)
                .padding(.bottom, 6)
            ForEach(items) { section in
                sidebarItem(section: section)
            }
        }
    }

    private func sidebarItem(section: AppSection) -> some View {
        let isActive = selection == section
        let count = sidebarCount(for: section)

        return Button {
            selection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isActive ? Tokens.Colors.accent : Tokens.Colors.ink3)
                    .frame(width: 16)
                Text(section.rawValue)
                    .font(.system(size: 13, weight: isActive ? .medium : .regular, design: .rounded))
                    .foregroundStyle(isActive ? Tokens.Colors.ink : Tokens.Colors.ink2)
                Spacer(minLength: 0)
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isActive {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Tokens.Colors.accentSoft)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 10)
            .padding(.vertical, 1)
        }
        .buttonStyle(.plain)
    }

    private func sidebarCount(for section: AppSection) -> Int? {
        switch section {
        case .guests: guests.isEmpty ? nil : guests.count
        default: nil
        }
    }

    private var kiStatusFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(kiDotColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(kiTitle)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                Text("LM Studio · lokal")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Tokens.Colors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var kiDotColor: Color {
        switch connectionState {
        case .unknown: Tokens.Colors.ink4
        case .connected: Tokens.Colors.sage
        case .offline: Tokens.Colors.warn
        }
    }

    private var kiTitle: String {
        switch connectionState {
        case .unknown: "Verbindung wird geprüft…"
        case .connected: "KI verbunden"
        case .offline: "KI offline"
        }
    }

    private func eventCoupleHeader(_ event: Event) -> String {
        let p1 = event.partnerDisplayName1
        let p2 = event.partnerDisplayName2
        return "\(p1) & \(p2)"
    }

    private func eventSubline(date: Date, venue: String) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.locale = Locale(identifier: "de_DE")
        if !venue.isEmpty {
            return "\(fmt.string(from: date)) · \(venue)"
        }
        return fmt.string(from: date)
    }

    @MainActor
    private func checkConnection() async {
        let client = LMStudioClient(endpoint: lmStudioEndpoint)
        do {
            _ = try await client.checkConnection()
            connectionState = .connected
        } catch {
            connectionState = .offline
        }
    }
}
#endif
