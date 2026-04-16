import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case globalPresets = "Global Caches"
    case systemCaches = "System Caches"
    case localProjects = "Local Projects"
    case history = "History"
    case settings = "Settings"
    case about = "About"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .overview: return "internaldrive"
        case .globalPresets: return "archivebox"
        case .systemCaches: return "memorychip"
        case .localProjects: return "hammer"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    
    var body: some View {
        List(selection: $selection) {
            Section("Workspace") {
                SidebarLabel(item: .overview)
                SidebarLabel(item: .globalPresets)
                SidebarLabel(item: .systemCaches)
                SidebarLabel(item: .localProjects)
            }
            
            Section("Activity") {
                SidebarLabel(item: .history)
            }

            Section("Preferences") {
                SidebarLabel(item: .settings)
            }

            Section("App") {
                SidebarLabel(item: .about)
            }
        }
        .listStyle(.sidebar)
        .safeAreaPadding(.top, 16)
        .navigationTitle("DevReclaim")
    }
}

struct SidebarLabel: View {
    let item: SidebarItem
    
    var body: some View {
        NavigationLink(value: item) {
            Label(item.rawValue, systemImage: item.icon)
        }
    }
}
