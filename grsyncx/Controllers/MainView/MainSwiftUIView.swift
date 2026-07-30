//
//  MainSwiftUIView.swift
//  grsyncx
//

import SwiftUI

struct MainSwiftUIView: View {
    @StateObject var viewModel = MainViewModel()
    @State private var showingAddProfile = false
    @State private var newProfileName = ""
    @State private var editingProfileIndex: Int?
    @State private var editingProfileName = ""
    @State private var showingWrapFolderHelp = false
    
    // Options tab selection
    @State private var selectedTab = 0 // 0 = Basic, 1 = Advanced
    
    var body: some View {
        NavigationView {
            // Sidebar: Profiles List
            VStack(alignment: .leading, spacing: 0) {
                List(selection: profileSelection) {
                    Section(header: Text("Profiles").font(.caption).foregroundColor(.secondary)) {
                        ForEach(0..<viewModel.profiles.count, id: \.self) { idx in
                            let profile = viewModel.profiles[idx]
                            let isSelected = viewModel.selectedProfileIndex == idx
                            HStack {
                                Image(systemName: "folder.badge.gear")
                                    .font(.title3)
                                    .foregroundColor(isSelected ? .white : .accentColor)
                                
                                if editingProfileIndex == idx {
                                    TextField("Profile Name", text: $editingProfileName, onCommit: {
                                        if !editingProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            viewModel.renameProfile(at: idx, newName: editingProfileName)
                                        }
                                        editingProfileIndex = nil
                                    })
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .foregroundColor(isSelected ? .white : .primary)
                                } else {
                                    Text(profile.name)
                                        .font(.body)
                                        .foregroundColor(isSelected ? .white : .primary)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 4)
                            .tag(idx)
                            .contextMenu {
                                Button("Rename") {
                                    editingProfileIndex = idx
                                    editingProfileName = profile.name
                                }
                                if viewModel.profiles.count > 1 {
                                    Button("Delete") {
                                        viewModel.deleteProfile(at: idx)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(SidebarListStyle())
                
                Divider()
                
                // Add Profile Button at the bottom of sidebar
                Button(action: {
                    newProfileName = ""
                    showingAddProfile = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Profile")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
            }
            .frame(minWidth: 180, idealWidth: 200, maxWidth: 240)
            
            // Detail Workspace
            VStack(spacing: 0) {
                if viewModel.selectedProfileIndex < viewModel.profiles.count {
                    detailView
                } else {
                    VStack {
                        Image(systemName: "square.and.arrow.down.on.square.and.arrow.up")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 16)
                        Text("Select or create a Profile")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 600, idealWidth: 650)
            .background(Color(NSColor.windowBackgroundColor))
            .sheet(isPresented: $showingAddProfile) {
                addProfileSheet
            }
            .sheet(isPresented: $viewModel.isRunningSync) {
                syncStatusSheet
            }
            .sheet(isPresented: $showingWrapFolderHelp) {
                wrapFolderHelpSheet
            }
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }

    private var profileSelection: Binding<Int?> {
        Binding(
            get: { viewModel.selectedProfileIndex },
            set: { selectedIndex in
                if let selectedIndex = selectedIndex {
                    viewModel.selectedProfileIndex = selectedIndex
                }
            }
        )
    }
    
    // MARK: - Detail View components
    private var detailView: some View {
        let profile = viewModel.activeProfile
        
        return VStack(spacing: 0) {
            // Header Profile Banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("rsync synchronization profile")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Source & Destination Cards
            HStack(spacing: 16) {
                // Source Card
                pathCard(
                    title: "Source",
                    subtitle: "Files/folders to copy",
                    path: profile.sourcePath,
                    systemImage: "folder.fill",
                    isSource: true
                )
                
                // Destination Card
                pathCard(
                    title: "Destination",
                    subtitle: "Where to save files",
                    path: profile.destinationPath,
                    systemImage: "folder.badge.plus",
                    isSource: false
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Source wrapper toggle
            HStack {
                Toggle("Wrap in Source folder", isOn: Binding<Bool>(
                    get: { profile.wrapInSourceFolder },
                    set: {
                        profile.wrapInSourceFolder = $0
                        viewModel.saveProfiles()
                        viewModel.objectWillChange.send()
                    }
                ))
                .help("If enabled, creates a subfolder with the source folder's name at the destination. If disabled, copies source files directly.")

                Button("How it works", systemImage: "questionmark.circle") {
                    showingWrapFolderHelp = true
                }
                .buttonStyle(BorderedButtonStyle())
                .help("Show an example of how the source folder is copied")
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Segmented Picker for basic / advanced settings
            Picker("", selection: $selectedTab) {
                Text("Basic Options").tag(0)
                Text("Advanced Options").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // The window's minimum height keeps this area fully visible at launch.
            VStack(alignment: .leading, spacing: 20) {
                if selectedTab == 0 {
                    basicOptionsGrid
                } else {
                    advancedOptionsGrid
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Keep the profile header and command bar in stable positions when
            // switching between option tabs with different intrinsic heights.
            Spacer(minLength: 0)
            
            Divider()
            
            // Command preview & Action buttons
            commandPreviewSection
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    // Path Card Component (Supports DND & Click to open OpenPanel)
    private func pathCard(title: String, subtitle: String, path: String?, systemImage: String, isSource: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Text(path ?? "Not selected")
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            
            Button("Choose...") {
                pickPath(isSource: isSource)
            }
            .buttonStyle(BorderedButtonStyle())
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
            if let provider = providers.first {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url {
                        DispatchQueue.main.async {
                            if isSource {
                                viewModel.activeProfile.sourcePath = url.path
                            } else {
                                viewModel.activeProfile.destinationPath = url.path
                            }
                            viewModel.saveProfiles()
                            viewModel.objectWillChange.send()
                        }
                    }
                }
                return true
            }
            return false
        }
    }
    
    // Basic Options Grid
    private var basicOptionsGrid: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Preservation")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                
                Toggle("Preserve file modification time", isOn: basicBinding(for: .preserveTime))
                    .help("Preserve file modification times (-t)")
                
                Toggle("Preserve file permissions", isOn: basicBinding(for: .preservePermissions))
                    .help("Preserve permissions (-p)")
                
                Toggle("Preserve file owner", isOn: basicBinding(for: .preserveOwner))
                    .help("Preserve owner (-o, super-user only)")
                
                Toggle("Preserve file group", isOn: basicBinding(for: .preserveGroup))
                    .help("Preserve group (-g)")
                
                Toggle("Preserve extended attributes", isOn: basicBinding(for: .preserveExtAttrs))
                    .help("Preserve Finder tags, resource forks, ACLs, and other extended attributes during the actual sync (-E). Apple openrsync omits this during Dry Run to avoid metadata errors.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Behavior & Safety")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                
                Toggle("Delete files on Destination", isOn: basicBinding(for: .deleteOnDest))
                    .help("Delete extraneous files from the destination directory (--delete)")
                
                Toggle("Do not leave file system", isOn: basicBinding(for: .dontLeaveFilesyst))
                    .help("Don't cross filesystem boundaries (-x)")
                
                Toggle("Verbose logging", isOn: basicBinding(for: .verbose))
                    .help("Increase sync log details (-v)")
                
                Toggle("Show transfer progress", isOn: basicBinding(for: .showTransProgress))
                    .help("Show real-time transfer progress details (--progress)")
                
                Toggle("Ignore existing files", isOn: basicBinding(for: .ignoreExisting))
                    .help("Skip updating files that already exist on destination (--ignore-existing)")
                
                Toggle("Compare size only", isOn: basicBinding(for: .sizeOnly))
                    .help("Skip files that match in size, ignoring time and checksum (--size-only)")
                
                Toggle("Skip files newer on Destination", isOn: basicBinding(for: .skipNewer))
                    .help("Skip updating files that are newer on the destination (-u)")
                
                Toggle("Windows compatibility", isOn: basicBinding(for: .windowsCompat))
                    .help("Compare modification times with reduced accuracy (FAT file system limitation, --modify-window=1)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // Advanced Options Grid
    private var advancedOptionsGrid: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Copy Rules")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    
                    Toggle("Always checksum", isOn: advancedBinding(for: .alwaysChecksum))
                        .help("Skip files based on checksum comparison, not time/size (-c)")
                    
                    Toggle("Compress file data during transfer", isOn: advancedBinding(for: .compressFileData))
                        .help("Compress data during transfer (-z)")
                    
                    Toggle("Preserve devices and specials", isOn: advancedBinding(for: .preserveDevices))
                        .help("Copy device and special files (-D)")
                    
                    Toggle("Only update existing files", isOn: advancedBinding(for: .existingFiles))
                        .help("Only update files that already exist, do not copy new files (--existing)")
                    
                    Toggle("Partial transfer files", isOn: advancedBinding(for: .partialTransFiles))
                        .help("Keep partially transferred files and show transfer progress (-P)")
                    
                    Toggle("No UID/GID name mapping", isOn: advancedBinding(for: .noUIDGIDMap))
                        .help("Keep numeric UID/GID instead of looking up names (--numeric-ids)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Special Files & Safety")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    
                    Toggle("Copy symbolic links as links", isOn: advancedBinding(for: .preserveSymlinks))
                        .help("Symbolic links are copied as links, not files (-l)")
                    
                    Toggle("Preserve hard links", isOn: advancedBinding(for: .preserveHardLinks))
                        .help("Preserve hard links (-H)")
                    
                    Toggle("Make backups of modified files", isOn: advancedBinding(for: .makeBackups))
                        .help("Make backups of existing destination files (--backup)")
                    
                    Toggle("Show itemized changes", isOn: advancedBinding(for: .showItemizedChanges))
                        .help("Show details of modified files (-i)")
                    
                    Toggle("Disable directory recursion", isOn: advancedBinding(for: .disableRecursion))
                        .help("If checked, ignores subdirectories (-d)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
            
            // Custom options section
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom Options")
                    .font(.headline)
                Text("Specify additional parameters directly; quoted values are supported")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("e.g. --exclude '*.log' --exclude '.DS_Store'", text: Binding<String>(
                    get: { viewModel.activeProfile.additionalOptions ?? "" },
                    set: {
                        viewModel.activeProfile.additionalOptions = $0.isEmpty ? nil : $0
                        viewModel.saveProfiles()
                        viewModel.objectWillChange.send()
                    }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body, design: .monospaced))
            }
        }
    }
    
    // Command preview & Exec buttons
    private var commandPreviewSection: some View {
        let profile = viewModel.activeProfile
        var args = profile.calculatedArguments ?? []
        if let calcSrc = profile.calculatedSourcePath {
            args.append(calcSrc)
        }
        if let calcDst = profile.calculatedDestinationPath {
            args.append(calcDst)
        }
        
        let customPath = UserDefaults.standard.string(forKey: "RSyncCommandPath") ?? "/usr/bin/rsync"
        let fullCommand = "\(customPath) \(args.joined(separator: " "))"
        
        return HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("rsync command preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(fullCommand)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity)
            
            // Dry Run Action
            Button(action: runDryRun) {
                Label("Dry Run", systemImage: "sparkles")
                .font(.body.weight(.semibold))
                .frame(width: 120, height: 36)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Execute Action
            Button(action: executeSync) {
                Label("Execute", systemImage: "play.fill")
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 120, height: 36)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func runDryRun() {
        viewModel.runSync(simulate: true)
    }

    private func executeSync() {
        viewModel.runSync(simulate: false)
    }
    
    // Add Profile Sheet modal
    private var addProfileSheet: some View {
        VStack(spacing: 20) {
            Text("Create New Profile")
                .font(.headline)
            
            TextField("Profile Name", text: $newProfileName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 250)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    showingAddProfile = false
                }
                .buttonStyle(BorderedButtonStyle())
                
                Button("Create") {
                    if !newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.addProfile(name: newProfileName)
                    }
                    showingAddProfile = false
                }
                .buttonStyle(DefaultButtonStyle())
                .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
    }

    // Help sheet for the source folder wrapper option
    private var wrapFolderHelpSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Wrap in Source folder", systemImage: "folder.badge.questionmark")
                    .font(.title2)
                Spacer()
            }

            Text("Choose whether the source folder itself is copied, or only its contents.")
                .foregroundColor(.secondary)

            Image("source_wrap_hint")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 520, maxHeight: 300)
                .accessibilityLabel("Diagram comparing copies with and without wrapping the source folder")

            Text("On: Destination/SourceFolder/files…\nOff: Destination/files…")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                Button("Done") {
                    showingWrapFolderHelp = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
    
    // Live Sync Progress overlay (Sheet)
    private var syncStatusSheet: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.isSimulation ? "Running Simulation Dry Run..." : "Synchronizing Files...")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(viewModel.syncStatusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if viewModel.isRunningSync {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title)
                }
            }
            .padding(.bottom, 8)
            
            // Progress Bar & Stats
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: viewModel.syncProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                HStack {
                    if viewModel.totalFilesToProcess > 0 {
                        Text("\(viewModel.filesProcessed) of \(viewModel.totalFilesToProcess) files processed")
                    } else {
                        Text("Analyzing files...")
                    }
                    Spacer()
                    Text(String(format: "%.0f%%", viewModel.syncProgress * 100))
                        .fontWeight(.bold)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Console Logs
            VStack(alignment: .leading, spacing: 6) {
                Text("Execution Logs")
                    .font(.headline)
                
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading) {
                            Text(viewModel.syncLog)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Color.clear.frame(height: 1).id("log_end")
                        }
                        .padding(8)
                        .onChange(of: viewModel.syncLog) { _ in
                            proxy.scrollTo("log_end", anchor: .bottom)
                        }
                    }
                }
                .background(Color.black)
                .cornerRadius(8)
                .frame(height: 300)
            }
            
            // Sheet actions
            HStack {
                Spacer()
                
                if viewModel.isRunningSync {
                    Button(action: {
                        viewModel.terminateSync()
                    }) {
                        Text("Stop Sync")
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button("Copy Log") {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(viewModel.syncLog, forType: .string)
                    }
                    .buttonStyle(BorderedButtonStyle())
                    
                    Button("Close") {
                        viewModel.isRunningSync = false
                    }
                    .buttonStyle(DefaultButtonStyle())
                }
            }
        }
        .padding(24)
        .frame(width: 600)
    }
    
    // Binding helper for basic option set
    private func basicBinding(for option: RSyncBasicProp) -> Binding<Bool> {
        Binding<Bool>(
            get: { viewModel.activeProfile.basicProperties.contains(option) },
            set: { isEnabled in
                if isEnabled {
                    viewModel.activeProfile.basicProperties.insert(option)
                } else {
                    viewModel.activeProfile.basicProperties.remove(option)
                }
                viewModel.saveProfiles()
                viewModel.objectWillChange.send()
            }
        )
    }
    
    // Binding helper for advanced option set
    private func advancedBinding(for option: RSyncAdvancedProp) -> Binding<Bool> {
        Binding<Bool>(
            get: { viewModel.activeProfile.advancedProperties.contains(option) },
            set: { isEnabled in
                if isEnabled {
                    viewModel.activeProfile.advancedProperties.insert(option)
                } else {
                    viewModel.activeProfile.advancedProperties.remove(option)
                }
                viewModel.saveProfiles()
                viewModel.objectWillChange.send()
            }
        )
    }
    
    // Folder pickers
    private func pickPath(isSource: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = isSource
        panel.allowsMultipleSelection = false
        
        if let currentPath = isSource ? viewModel.activeProfile.sourcePath : viewModel.activeProfile.destinationPath,
           !currentPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: currentPath)
        }
        
        panel.begin { response in
            if response == .OK, let selectedURL = panel.urls.first {
                DispatchQueue.main.async {
                    if isSource {
                        viewModel.activeProfile.sourcePath = selectedURL.path
                    } else {
                        viewModel.activeProfile.destinationPath = selectedURL.path
                    }
                    viewModel.saveProfiles()
                    viewModel.objectWillChange.send()
                }
            }
        }
    }
}

@objc(SwiftUIFactory)
class SwiftUIFactory: NSObject {
    @objc static func createMainView() -> NSView {
        return NSHostingView(rootView: MainSwiftUIView())
    }
}
