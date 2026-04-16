import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case globalPresets = "Global Caches"
    case localProjects = "Local Projects"
    case history = "History"
    
    var id: String { self.rawValue }
    var icon: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .globalPresets: return "archivebox.fill"
        case .localProjects: return "folder.fill"
        case .history: return "clock.fill"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    
    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.icon)
            }
        }
        .navigationTitle("DevReclaim")
    }
}
