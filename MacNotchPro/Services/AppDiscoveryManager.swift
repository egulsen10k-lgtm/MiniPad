//
//  AppDiscoveryManager.swift
//  MiniPad
//

import SwiftUI
import AppKit
import Combine

// MARK: - Categories
enum AppCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case apple = "Apple"
    case developer = "Developer"
    case productivity = "Productivity"
    case finance = "Finance"
    case games = "Games"
    case media = "Media & Design"
    case social = "Social & Chat"
    case utilities = "Utilities"
    case folders = "Folders"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all:          return "sparkles"
        case .apple:        return "apple.logo"
        case .developer:    return "curlybraces"
        case .productivity: return "doc.text.fill"
        case .finance:      return "chart.line.uptrend.xyaxis"
        case .games:        return "gamecontroller.fill"
        case .media:        return "paintbrush.fill"
        case .social:       return "message.fill"
        case .utilities:    return "wrench.and.screwdriver.fill"
        case .folders:      return "folder.fill"
        }
    }
}

// MARK: - Models
enum ItemType: String, Codable {
    case app
    case folder
}

struct LaunchpadItem: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var type: ItemType
    var path: String?
    var subAppPaths: [String]? // For folders: list of app paths
    var isFavorite: Bool = false
    var favoriteTimestamp: TimeInterval = 0
    
    var isFolder: Bool {
        type == .folder
    }
    
    static func == (lhs: LaunchpadItem, rhs: LaunchpadItem) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.subAppPaths == rhs.subAppPaths && lhs.isFavorite == rhs.isFavorite
    }
}

struct AppMetadata {
    var name: String
    var path: String
    var bundleId: String
    var categoryType: String
    var categories: Set<AppCategory>
    var icon: NSImage
}

class AppDiscoveryManager: ObservableObject {
    static let shared = AppDiscoveryManager()
    
    @Published var items: [LaunchpadItem] = []
    @Published var allAppsCache: [String: AppMetadata] = [:] // Path -> Metadata
    @Published var filteredItems: [LaunchpadItem] = []
    
    // Multi-Selection & Edit Mode (Shake & Vibrate)
    @Published var isEditing: Bool = false
    @Published var selectedItems: Set<String> = []
    
    // Internal Drag State for instant zero-latency drag and drop
    @Published var draggedItemId: String? = nil
    @Published var draggedItems: Set<String> = []
    @Published var dropTargetId: String? = nil
    @Published var dropSideIsRight: Bool = false
    
    // Scroll Lock State (locked whenever a popup/modal is open on top)
    @Published var isModalOrPopupActive: Bool = false
    
    var isScrollLocked: Bool {
        isModalOrPopupActive || activeFolder != nil || SettingsWindowManager.shared.isSettingsOpen
    }
    
    @Published var selectedCategory: AppCategory = .all {
        didSet {
            currentPage = 0
            filterItems()
        }
    }
    
    @Published var searchText: String = "" {
        didSet {
            currentPage = 0
            filterItems()
        }
    }
    @Published var currentPage: Int = 0
    @Published var totalPages: Int = 1
    @Published var isLoading: Bool = true
    
    // Active Open Folder Modal
    @Published var activeFolder: LaunchpadItem? = nil
    
    var itemsPerPage: Int {
        AppSettings.shared.itemsPerPage
    }
    
    private let storageKey = "MiniPad_Launchpad_Layout_V2"
    
    init() {
        refreshApps()
    }
    
    // MARK: - App Scanning & Layout Restoration
    func refreshApps() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let scannedApps = self.scanInstalledApplications()
            var metaCache: [String: AppMetadata] = [:]
            
            for (name, path, bundleId, catType) in scannedApps {
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 64, height: 64)
                let cats = self.determineCategories(name: name, path: path, bundleId: bundleId, categoryType: catType)
                metaCache[path] = AppMetadata(
                    name: name,
                    path: path,
                    bundleId: bundleId,
                    categoryType: catType,
                    categories: cats,
                    icon: icon
                )
            }
            
            let simpleScanned = scannedApps.map { (name: $0.0, path: $0.1) }
            let restoredItems = self.loadSavedLayout(scannedApps: simpleScanned)
            
            DispatchQueue.main.async {
                self.allAppsCache = metaCache
                self.items = restoredItems
                self.filterItems()
                self.isLoading = false
            }
        }
    }
    
    private func scanInstalledApplications() -> [(name: String, path: String, bundleId: String, categoryType: String)] {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser.path
        
        let searchDirectories = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "\(homeDir)/Applications",
            "/System/Library/CoreServices/Applications"
        ]
        
        var discovered: [String: (name: String, path: String, bundleId: String, categoryType: String)] = [:]
        
        for dir in searchDirectories {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }
            
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    let path = fileURL.path
                    
                    if !name.contains("Helper") && !name.contains("XPCServices") && discovered[name] == nil {
                        var bundleId = ""
                        var catType = ""
                        let infoPlistPath = fileURL.appendingPathComponent("Contents/Info.plist").path
                        if let dict = NSDictionary(contentsOfFile: infoPlistPath) {
                            bundleId = dict["CFBundleIdentifier"] as? String ?? ""
                            catType = dict["LSApplicationCategoryType"] as? String ?? ""
                        }
                        discovered[name] = (name: name, path: path, bundleId: bundleId, categoryType: catType)
                    }
                }
            }
        }
        
        let sorted = discovered.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        return sorted.compactMap { discovered[$0] }
    }
    
    // MARK: - Smart Category Classifier
    private func determineCategories(name: String, path: String, bundleId: String, categoryType: String) -> Set<AppCategory> {
        var categories: Set<AppCategory> = [.all]
        
        let isApple = bundleId.hasPrefix("com.apple.") || path.hasPrefix("/System")
        if isApple {
            categories.insert(.apple)
        }
        
        let lowerCat = categoryType.lowercased()
        let lowerName = name.lowercased()
        let lowerPath = path.lowercased()
        let lowerBid = bundleId.lowercased()
        
        // Games
        if lowerCat.contains("game") || lowerName.contains("game") || lowerBid.contains("game") || lowerName.contains("steam") || lowerName.contains("minecraft") || lowerName.contains("chess") || lowerName.contains("arcade") || lowerName.contains("epic games") || lowerName.contains("roblox") || lowerName.contains("blizzard") || lowerName.contains("riot") {
            categories.insert(.games)
        }
        
        // Developer Tools
        if lowerCat.contains("developer") || lowerName.contains("xcode") || lowerName.contains("code") || lowerName.contains("terminal") || lowerName.contains("iterm") || lowerName.contains("git") || lowerName.contains("docker") || lowerName.contains("postman") || lowerName.contains("sublime") || lowerName.contains("pycharm") || lowerName.contains("intellij") || lowerName.contains("cursor") || lowerName.contains("warp") || lowerName.contains("beeper") || lowerName.contains("antigravity") || lowerName.contains("claude") || lowerName.contains("opencode") || lowerBid.contains("developer") {
            categories.insert(.developer)
        }
        
        // Finance & Business
        if lowerCat.contains("finance") || lowerCat.contains("business") || lowerName.contains("stock") || lowerName.contains("finance") || lowerName.contains("bank") || lowerName.contains("crypto") || lowerName.contains("wallet") || lowerName.contains("money") || lowerName.contains("ledger") || lowerName.contains("excel") || lowerName.contains("numbers") || lowerName.contains("tax") || lowerName.contains("quickbooks") || lowerName.contains("midas") || lowerName.contains("trading") || lowerBid.contains("finance") {
            categories.insert(.finance)
        }
        
        // Productivity
        if lowerCat.contains("productivity") || lowerCat.contains("education") || lowerCat.contains("reference") || lowerName.contains("safari") || lowerName.contains("chrome") || lowerName.contains("firefox") || lowerName.contains("brave") || lowerName.contains("edge") || lowerName.contains("arc") || lowerName.contains("word") || lowerName.contains("pages") || lowerName.contains("notes") || lowerName.contains("reminders") || lowerName.contains("calendar") || lowerName.contains("mail") || lowerName.contains("notion") || lowerName.contains("obsidian") || lowerName.contains("raycast") || lowerName.contains("copyclip") || lowerName.contains("hazeover") || lowerName.contains("gmail") {
            categories.insert(.productivity)
        }
        
        // Media & Design
        if lowerCat.contains("graphics") || lowerCat.contains("photo") || lowerCat.contains("video") || lowerCat.contains("music") || lowerCat.contains("entertainment") || lowerName.contains("photo") || lowerName.contains("figma") || lowerName.contains("sketch") || lowerName.contains("blender") || lowerName.contains("final cut") || lowerName.contains("premiere") || lowerName.contains("spotify") || lowerName.contains("music") || lowerName.contains("logic pro") || lowerName.contains("garageband") || lowerName.contains("audacity") || lowerName.contains("vlc") || lowerName.contains("quicktime") || lowerName.contains("iina") {
            categories.insert(.media)
        }
        
        // Social & Communication
        if lowerCat.contains("social") || lowerName.contains("telegram") || lowerName.contains("discord") || lowerName.contains("slack") || lowerName.contains("whatsapp") || lowerName.contains("signal") || lowerName.contains("messages") || lowerName.contains("facetime") || lowerName.contains("zoom") || lowerName.contains("teams") || lowerName.contains("skype") || lowerName.contains("wechat") {
            categories.insert(.social)
        }
        
        // Utilities & System Tools
        if lowerCat.contains("utilities") || lowerPath.contains("utilities") || lowerName.contains("calc") || lowerName.contains("settings") || lowerName.contains("cleaner") || lowerName.contains("rar") || lowerName.contains("fix") || lowerName.contains("displaybuddy") || lowerName.contains("onyx") || lowerName.contains("atoll") || lowerName.contains("unsplash") || lowerName.contains("remote") || lowerName.contains("neardrop") || lowerName.contains("mechanic") || lowerName.contains("loopback") || lowerName.contains("activity monitor") || lowerName.contains("disk utility") || lowerName.contains("finder") {
            categories.insert(.utilities)
        }
        
        // Fallback
        if categories.count == 1 {
            categories.insert(isApple ? .utilities : .productivity)
        }
        
        return categories
    }
    
    // Count items matching a category
    func count(for category: AppCategory) -> Int {
        if category == .all {
            return items.count
        }
        if category == .folders {
            return items.filter { $0.isFolder }.count
        }
        
        var count = 0
        for item in items {
            if item.isFolder {
                let hasMatchingApp = item.subAppPaths?.contains { path in
                    allAppsCache[path]?.categories.contains(category) == true
                } ?? false
                if hasMatchingApp { count += 1 }
            } else if let path = item.path {
                if allAppsCache[path]?.categories.contains(category) == true {
                    count += 1
                }
            }
        }
        return count
    }
    
    private func loadSavedLayout(scannedApps: [(name: String, path: String)]) -> [LaunchpadItem] {
        let scannedPathsSet = Set(scannedApps.map { $0.path })
        var currentItems: [LaunchpadItem] = []
        
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([LaunchpadItem].self, from: data) {
            var trackedPaths = Set<String>()
            
            for var item in saved {
                if item.isFolder {
                    item.subAppPaths = item.subAppPaths?.filter { scannedPathsSet.contains($0) } ?? []
                    item.subAppPaths?.forEach { trackedPaths.insert($0) }
                    
                    if let subs = item.subAppPaths, subs.count == 1, let singleAppPath = subs.first {
                        let singleAppName = scannedApps.first(where: { $0.path == singleAppPath })?.name ?? (singleAppPath as NSString).lastPathComponent
                        currentItems.append(LaunchpadItem(id: singleAppPath, name: singleAppName, type: .app, path: singleAppPath, subAppPaths: nil))
                    } else if let subs = item.subAppPaths, subs.count > 1 {
                        currentItems.append(item)
                    }
                } else if let path = item.path, scannedPathsSet.contains(path) {
                    trackedPaths.insert(path)
                    currentItems.append(item)
                }
            }
            
            for app in scannedApps where !trackedPaths.contains(app.path) {
                currentItems.append(LaunchpadItem(id: app.path, name: app.name, type: .app, path: app.path, subAppPaths: nil))
            }
        } else {
            currentItems = scannedApps.map {
                LaunchpadItem(id: $0.path, name: $0.name, type: .app, path: $0.path, subAppPaths: nil)
            }
        }
        
        return currentItems
    }
    
    func saveLayout() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    // MARK: - Filtering & Search & Categories
    func filterItems() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var baseItems = items
        
        // Apply Category Filter
        if selectedCategory == .folders {
            baseItems = baseItems.filter { $0.isFolder }
        } else if selectedCategory != .all {
            baseItems = baseItems.filter { item in
                if item.isFolder {
                    return item.subAppPaths?.contains { path in
                        allAppsCache[path]?.categories.contains(selectedCategory) == true
                    } ?? false
                } else if let path = item.path {
                    return allAppsCache[path]?.categories.contains(selectedCategory) == true
                }
                return false
            }
        }
        
        // Apply Search Filter
        if query.isEmpty {
            filteredItems = baseItems
        } else {
            var matches: [LaunchpadItem] = []
            for item in baseItems {
                if item.isFolder {
                    let folderNameMatches = item.name.lowercased().contains(query)
                    let matchingSubApps = item.subAppPaths?.filter { path in
                        let name = allAppsCache[path]?.name ?? ""
                        return name.lowercased().contains(query)
                    } ?? []
                    
                    if folderNameMatches || !matchingSubApps.isEmpty {
                        matches.append(item)
                    }
                } else {
                    let appName = item.name.lowercased()
                    let pathName = (item.path ?? "").lowercased()
                    let lastComp = ((item.path ?? "") as NSString).lastPathComponent.lowercased()
                    if appName.contains(query) || pathName.contains(query) || lastComp.contains(query) {
                        matches.append(item)
                    }
                }
            }
            filteredItems = matches
        }
        
        // Apply Sort Mode
        if AppSettings.shared.sortMode == .alphabetical {
            filteredItems.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        
        // Pinned Favorites: Always placed at the very top, ordered by favorite creation time (1st favorite in 1st place, 2nd favorite in 2nd place, etc.)
        let favorites = filteredItems.filter { $0.isFavorite }.sorted { $0.favoriteTimestamp < $1.favoriteTimestamp }
        let nonFavorites = filteredItems.filter { !$0.isFavorite }
        filteredItems = favorites + nonFavorites
        
        let perPage = max(1, itemsPerPage)
        totalPages = max(1, Int(ceil(Double(filteredItems.count) / Double(perPage))))
        if currentPage >= totalPages {
            currentPage = max(0, totalPages - 1)
        }
    }
    
    func itemsForCurrentPage() -> [LaunchpadItem] {
        let perPage = max(1, itemsPerPage)
        let startIndex = currentPage * perPage
        let endIndex = min(startIndex + perPage, filteredItems.count)
        guard startIndex < filteredItems.count else { return [] }
        return Array(filteredItems[startIndex..<endIndex])
    }
    
    func nextPage() {
        guard !isScrollLocked else { return }
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }
    
    func previousPage() {
        guard !isScrollLocked else { return }
        if currentPage > 0 {
            currentPage -= 1
        }
    }
    
    func toggleSelection(itemId: String) {
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
            if selectedItems.isEmpty {
                isEditing = false
            }
        } else {
            selectedItems.insert(itemId)
            isEditing = true
        }
    }
    
    func exitEditingMode() {
        isEditing = false
        selectedItems.removeAll()
    }
    
    func launchSelectedItems() {
        for itemId in selectedItems {
            if let item = items.first(where: { $0.id == itemId }), let path = item.path {
                launchApp(at: path) { }
            }
        }
        exitEditingMode()
    }

    func moveMultipleItems(sourceIds: Set<String>, to destinationId: String, insertAfter: Bool = false) {
        withAnimation(.spring()) {
            let movingItems = items.filter { sourceIds.contains($0.id) }
            items.removeAll { sourceIds.contains($0.id) }
            
            guard var targetIndex = items.firstIndex(where: { $0.id == destinationId }) else { return }
            if insertAfter {
                targetIndex += 1
            }
            if targetIndex > items.count { targetIndex = items.count }
            
            items.insert(contentsOf: movingItems, at: targetIndex)
            saveLayout()
            filterItems()
            objectWillChange.send()
        }
    }
    
    func addMultipleItemsToFolder(sourceIds: Set<String>, folderId: String) {
        guard let folderIndex = items.firstIndex(where: { $0.id == folderId }) else { return }
        var folder = items[folderIndex]
        var subPaths = folder.subAppPaths ?? []
        
        let sourcePaths = items.filter { sourceIds.contains($0.id) }.compactMap { $0.path }
        
        for path in sourcePaths {
            if !subPaths.contains(path) {
                subPaths.append(path)
            }
        }
        
        folder.subAppPaths = subPaths
        items[folderIndex] = folder
        items.removeAll { sourceIds.contains($0.id) }
        saveLayout()
        filterItems()
        if activeFolder?.id == folderId {
            activeFolder = folder
        }
    }

    func createFolderFromSelectedItems() {
        let selected = items.filter { selectedItems.contains($0.id) }
        guard selected.count >= 2 else { return }
        
        let subPaths = selected.compactMap { $0.path }
        let folderId = UUID().uuidString
        let folderName = "New Folder"
        let newFolder = LaunchpadItem(
            id: folderId,
            name: folderName,
            type: .folder,
            path: nil,
            subAppPaths: subPaths
        )
        
        // Remove selected items
        items.removeAll { selectedItems.contains($0.id) }
        
        // Insert new folder at start of grid
        items.insert(newFolder, at: 0)
        
        saveLayout()
        filterItems()
        exitEditingMode()
    }
    
    // MARK: - Drag & Drop Operations
    func moveItem(from sourceId: String, to destinationId: String, insertAfter: Bool = false) {
        guard sourceId != destinationId else { return }
        
        guard let fromIndex = items.firstIndex(where: { $0.id == sourceId }),
              let toIndex = items.firstIndex(where: { $0.id == destinationId }) else { return }
        
        withAnimation(.spring()) {
            let item = items.remove(at: fromIndex)
            var targetIndex = items.firstIndex(where: { $0.id == destinationId }) ?? toIndex
            if insertAfter {
                targetIndex += 1
            }
            if targetIndex > items.count { targetIndex = items.count }
            items.insert(item, at: targetIndex)
            saveLayout()
            filterItems()
            objectWillChange.send()
        }
    }
    
    func createFolder(with sourceId: String, onto targetId: String) {
        guard sourceId != targetId,
              let fromIndex = items.firstIndex(where: { $0.id == sourceId }),
              let toIndex = items.firstIndex(where: { $0.id == targetId }) else { return }
        
        let sourceItem = items[fromIndex]
        let targetItem = items[toIndex]
        
        // Cannot create nested folders
        if sourceItem.isFolder {
            return
        }
        
        if targetItem.isFolder {
            addItemToFolder(sourceId: sourceId, folderId: targetId)
            return
        }
        
        guard let sourcePath = sourceItem.path, let targetPath = targetItem.path else { return }
        
        let folderId = UUID().uuidString
        let folderName = "New Folder"
        let newFolder = LaunchpadItem(
            id: folderId,
            name: folderName,
            type: .folder,
            path: nil,
            subAppPaths: [targetPath, sourcePath]
        )
        
        let lowerIndex = min(fromIndex, toIndex)
        let higherIndex = max(fromIndex, toIndex)
        items.remove(at: higherIndex)
        items.remove(at: lowerIndex)
        
        let insertIndex = min(toIndex, items.count)
        items.insert(newFolder, at: insertIndex)
        
        saveLayout()
        filterItems()
    }
    
    func createNewEmptyFolder(named name: String = "Untitled Folder") {
        let newFolder = LaunchpadItem(
            id: UUID().uuidString,
            name: name,
            type: .folder,
            path: nil,
            subAppPaths: []
        )
        items.insert(newFolder, at: 0)
        saveLayout()
        filterItems()
        activeFolder = newFolder
    }
    
    func reorderInsideFolder(folderId: String, fromPath: String, toPath: String) {
        guard fromPath != toPath,
              let folderIndex = items.firstIndex(where: { $0.id == folderId }) else { return }
        
        var folder = items[folderIndex]
        var paths = folder.subAppPaths ?? []
        
        guard let fromIdx = paths.firstIndex(of: fromPath),
              let toIdx   = paths.firstIndex(of: toPath) else { return }
        
        paths.remove(at: fromIdx)
        paths.insert(fromPath, at: toIdx)
        
        folder.subAppPaths = paths
        items[folderIndex] = folder
        
        if activeFolder?.id == folderId {
            activeFolder = folder
        }
        saveLayout()
        filterItems()
    }
    
    func addItemToFolder(sourceId: String, folderId: String) {
        guard let sourceIndex = items.firstIndex(where: { $0.id == sourceId }),
              let folderIndex = items.firstIndex(where: { $0.id == folderId }),
              let sourcePath = items[sourceIndex].path else { return }
        
        var folder = items[folderIndex]
        var subPaths = folder.subAppPaths ?? []
        if !subPaths.contains(sourcePath) {
            subPaths.append(sourcePath)
            folder.subAppPaths = subPaths
            items[folderIndex] = folder
            items.remove(at: sourceIndex)
            saveLayout()
            filterItems()
            if activeFolder?.id == folderId {
                activeFolder = folder
            }
        }
    }
    
    func toggleFavorite(itemId: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        
        var item = items[index]
        item.isFavorite.toggle()
        
        if item.isFavorite {
            item.favoriteTimestamp = Date().timeIntervalSince1970
        } else {
            item.favoriteTimestamp = 0
        }
        
        items[index] = item
        saveLayout()
        filterItems()
    }
    
    func removeItemFromFolder(appPath: String, folderId: String) {
        guard let folderIndex = items.firstIndex(where: { $0.id == folderId }) else { return }
        
        var folder = items[folderIndex]
        folder.subAppPaths?.removeAll { $0 == appPath }
        
        let appName = allAppsCache[appPath]?.name ?? (appPath as NSString).lastPathComponent
        let extractedApp = LaunchpadItem(id: appPath, name: appName, type: .app, path: appPath, subAppPaths: nil)
        items.insert(extractedApp, at: folderIndex + 1)
        
        // If there is only 1 app left in the folder, automatically delete the folder and reveal the remaining app!
        if let remaining = folder.subAppPaths, remaining.count <= 1 {
            if remaining.count == 1, let lastPath = remaining.first {
                let lastName = allAppsCache[lastPath]?.name ?? (lastPath as NSString).lastPathComponent
                let lastApp = LaunchpadItem(id: lastPath, name: lastName, type: .app, path: lastPath, subAppPaths: nil)
                items[folderIndex] = lastApp
            } else {
                items.remove(at: folderIndex)
            }
            if activeFolder?.id == folderId {
                activeFolder = nil
            }
        } else {
            items[folderIndex] = folder
            if activeFolder?.id == folderId {
                activeFolder = folder
            }
        }
        
        saveLayout()
        filterItems()
    }
    
    func renameFolder(folderId: String, newName: String) {
        guard let index = items.firstIndex(where: { $0.id == folderId }) else { return }
        items[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Folder" : newName
        saveLayout()
        filterItems()
        if activeFolder?.id == folderId {
            activeFolder = items[index]
        }
    }
    
    func deleteFolder(folderId: String) {
        guard let index = items.firstIndex(where: { $0.id == folderId }) else { return }
        let folder = items[index]
        
        if let subPaths = folder.subAppPaths {
            for path in subPaths {
                let name = allAppsCache[path]?.name ?? (path as NSString).lastPathComponent
                let appItem = LaunchpadItem(id: path, name: name, type: .app, path: path, subAppPaths: nil)
                items.insert(appItem, at: index)
            }
        }
        
        items.removeAll { $0.id == folderId }
        saveLayout()
        filterItems()
        if activeFolder?.id == folderId {
            activeFolder = nil
        }
    }
    
    // MARK: - App Launching
    func launchApp(at path: String, completion: (() -> Void)? = nil) {
        let url = URL(fileURLWithPath: path)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error launching \(path): \(error.localizedDescription)")
                }
                completion?()
            }
        }
    }
    
    // MARK: - Icon Resolution via IconPackManager
    func icon(for path: String) -> NSImage {
        let metadata = allAppsCache[path]
        let appName = metadata?.name ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let bundleId = metadata?.bundleId ?? ""
        let defaultRawIcon = metadata?.icon ?? {
            let ic = NSWorkspace.shared.icon(forFile: path)
            ic.size = NSSize(width: 64, height: 64)
            return ic
        }()
        
        return IconPackManager.shared.icon(
            for: path,
            appName: appName,
            bundleId: bundleId,
            style: AppSettings.shared.iconPackStyle,
            defaultIcon: defaultRawIcon
        )
    }
}
