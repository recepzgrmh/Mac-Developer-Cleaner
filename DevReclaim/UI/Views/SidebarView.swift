import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case globalPresets = "Global Caches"
    case localProjects = "Local Projects"
    case history = "History"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .overview: return "internaldrive"
        case .globalPresets: return "archivebox"
        case .localProjects: return "hammer"
        case .history: return "clock.arrow.circlepath"
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
                SidebarLabel(item: .localProjects)
            }
            
            Section("Activity") {
                SidebarLabel(item: .history)
            }
        }
        .listStyle(.sidebar)
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
