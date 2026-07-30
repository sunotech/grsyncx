//
//  MainViewModel.swift
//  grsyncx
//

import Foundation
import Combine
import AppKit

class MainViewModel: ObservableObject {
    @Published var profiles: [SyncProfile] = []
    @Published var selectedProfileIndex: Int = 0 {
        didSet {
            if selectedProfileIndex >= 0 && selectedProfileIndex < profiles.count {
                let prof = profiles[selectedProfileIndex]
                Settings.shared.lastUsedProfile = prof
            }
        }
    }
    
    var activeProfile: SyncProfile {
        if selectedProfileIndex >= 0 && selectedProfileIndex < profiles.count {
            return profiles[selectedProfileIndex]
        }
        return SyncProfile.default()
    }
    
    // For sync runner
    @Published var isRunningSync = false
    @Published var isSimulation = false
    @Published var syncProgress: Double = 0.0
    @Published var syncLog = ""
    @Published var syncStatusMessage = ""
    @Published var filesProcessed = 0
    @Published var totalFilesToProcess = 0
    
    private var process: Process?
    private var outputPipe: Pipe?
    
    init() {
        loadProfiles()
    }
    
    func loadProfiles() {
        let defaults = UserDefaults.standard
        if let savedDicts = defaults.array(forKey: "SavedSyncProfiles") as? [[String: Any]] {
            var loaded: [SyncProfile] = []
            for dict in savedDicts {
                let prof = SyncProfile(from: dict)
                loaded.append(prof)
            }
            if loaded.isEmpty {
                loaded = [SyncProfile.default()]
            }
            self.profiles = loaded
        } else {
            let lastProf = Settings.shared.lastUsedProfile
            self.profiles = [lastProf]
        }
        
        let lastUsed = Settings.shared.lastUsedProfile
        if let idx = profiles.firstIndex(where: { $0.name == lastUsed.name }) {
            self.selectedProfileIndex = idx
        } else {
            self.selectedProfileIndex = 0
        }
    }
    
    func saveProfiles() {
        let dicts = profiles.map { $0.asDictionary() as Any }
        UserDefaults.standard.set(dicts, forKey: "SavedSyncProfiles")
        Settings.shared.lastUsedProfile = activeProfile
    }
    
    func addProfile(name: String) {
        let newProf = SyncProfile.default()
        newProf.name = name
        
        let current = activeProfile
        newProf.sourcePath = current.sourcePath
        newProf.destinationPath = current.destinationPath
        newProf.wrapInSourceFolder = current.wrapInSourceFolder
        newProf.basicProperties = current.basicProperties
        newProf.advancedProperties = current.advancedProperties
        newProf.additionalOptions = current.additionalOptions
        
        profiles.append(newProf)
        selectedProfileIndex = profiles.count - 1
        saveProfiles()
    }
    
    func deleteProfile(at index: Int) {
        guard profiles.count > 1 else { return }
        profiles.remove(at: index)
        if selectedProfileIndex >= profiles.count {
            selectedProfileIndex = profiles.count - 1
        }
        saveProfiles()
    }
    
    func renameProfile(at index: Int, newName: String) {
        guard index >= 0 && index < profiles.count else { return }
        profiles[index].name = newName
        saveProfiles()
        objectWillChange.send()
    }
    
    func runSync(simulate: Bool) {
        let profile = activeProfile
        
        guard let src = profile.sourcePath, !src.isEmpty,
              let dst = profile.destinationPath, !dst.isEmpty else {
            self.syncStatusMessage = "Source or destination path is empty."
            return
        }
        
        let fm = FileManager.default
        if !fm.fileExists(atPath: src) {
            self.syncStatusMessage = "Source path does not exist."
            return
        }
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: dst, isDirectory: &isDir) || !isDir.boolValue {
            self.syncStatusMessage = "Destination path is invalid."
            return
        }
        
        self.isRunningSync = true
        self.isSimulation = simulate
        self.syncProgress = 0.0
        self.filesProcessed = 0
        self.totalFilesToProcess = 0
        self.syncLog = ""
        self.syncStatusMessage = simulate ? "Running dry run simulation..." : "Running backup sync..."
        
        profile.simulatedRun = simulate
        var args = profile.calculatedArguments ?? []
        profile.simulatedRun = false
        if let calcSrc = profile.calculatedSourcePath {
            args.append(calcSrc)
        }
        if let calcDst = profile.calculatedDestinationPath {
            args.append(calcDst)
        }
        
        var rsyncPath = "/usr/bin/rsync"
        if let customPath = UserDefaults.standard.string(forKey: "RSyncCommandPath"), !customPath.isEmpty {
            rsyncPath = customPath
        }
        
        self.syncLog += "\(rsyncPath) \(args.joined(separator: " "))\n\n"
        if simulate && profile.basicProperties.contains(.preserveExtAttrs) {
            self.syncLog += "Note: Extended attributes (-E) are omitted from Dry Run because Apple's openrsync reports synthetic metadata errors when -n and -E are combined. They remain enabled for the actual sync.\n\n"
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: rsyncPath)
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        self.process = process
        self.outputPipe = pipe
        
        let fileHandle = pipe.fileHandleForReading
        
        do {
            try process.run()
        } catch {
            self.syncStatusMessage = "Failed to launch rsync: \(error.localizedDescription)"
            self.isRunningSync = false
            return
        }
        
        var totalFiles = 0
        var blockCounter = 0
        var checkingToCheck = false
        
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let line = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.syncLog += line
                    
                    let cons = " files to consider"
                    let toCheck = " to-check="
                    
                    if line.contains(cons) {
                        let lines = line.components(separatedBy: "\n")
                        for ln in lines {
                            if ln.contains(cons) {
                                if let val = Double(ln.components(separatedBy: " ").first ?? "") {
                                    totalFiles = Int(val)
                                    self.totalFilesToProcess = totalFiles
                                }
                            }
                        }
                    }
                    
                    if totalFiles > 0 {
                        if line.contains(toCheck) {
                            checkingToCheck = true
                            if let remainingStr = line.components(separatedBy: toCheck).last?.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "/").first,
                               let remaining = Int(remainingStr) {
                                blockCounter = totalFiles - remaining
                            }
                        } else if !checkingToCheck {
                            blockCounter += line.components(separatedBy: "\n").count - 1
                        }
                        
                        let progress = min(max(Double(blockCounter) / Double(totalFiles), 0.0), 0.99)
                        self.syncProgress = progress
                        self.filesProcessed = blockCounter
                    }
                }
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            process.waitUntilExit()
            fileHandle.readabilityHandler = nil
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRunningSync = false
                let exitCode = process.terminationStatus
                if exitCode == 0 {
                    self.syncProgress = 1.0
                    self.syncStatusMessage = "Finished successfully!"
                } else {
                    self.syncStatusMessage = "Finished with exit code \(exitCode)."
                }
                self.saveProfiles()
            }
        }
    }
    
    func terminateSync() {
        process?.terminate()
        self.syncStatusMessage = "Sync stopped by user."
        self.isRunningSync = false
    }
}
