import Foundation

struct AppSkeletonGenerator {
    let appDirectory: URL
    let appName: String

    init(appName: String) {
        let currentDirectory = FileManager.default.currentDirectoryPath
        self.appDirectory = URL(fileURLWithPath: currentDirectory).appendingPathComponent("\(appName).app")
        self.appName = appName
    }

    func generateSkeleton() throws {
        try createDirectoryStructure()
        try createInfoPlist()
        try createBinarySymlink()
    }

    private func createDirectoryStructure() throws {
        let contentsDir = appDirectory.appendingPathComponent("Contents")
        let macOSDir = contentsDir.appendingPathComponent("MacOS")
        let resourcesDir = contentsDir.appendingPathComponent("Resources")

        do {
            try FileManager.default.createDirectory(at: macOSDir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true, attributes: nil)
            print("Created app directory structure.")
        } catch {
            print("Failed to create directory structure: \(error.localizedDescription)")
            throw error
        }
    }

    private func createInfoPlist() throws {
        let contentsDir = appDirectory.appendingPathComponent("Contents")
        let plistPath = contentsDir.appendingPathComponent("info.plist")

        let plistTemplate = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleName</key>
            <string>\(appName)</string>
            <key>CFBundleIdentifier</key>
            <string>com.leviouwendijk.\(appName.lowercased())</string>
            <key>CFBundleVersion</key>
            <string>1.0</string>
            <key>CFBundleExecutable</key>
            <string>\(appName)</string>
        </dict>
        </plist>
        """

        try plistTemplate.write(to: plistPath, atomically: true, encoding: .utf8)
        print("Created info.plist.")
    }

    private func createBinarySymlink() {
        let binaryPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/release")
            .appendingPathComponent(appName)

        let symlinkPath = appDirectory
            .appendingPathComponent("Contents/MacOS")
            .appendingPathComponent(appName)

        let fileManager = FileManager.default

        // Check if the binary exists
        if fileManager.fileExists(atPath: binaryPath.path) {
            do {
                // Remove existing symlink if it exists
                if fileManager.fileExists(atPath: symlinkPath.path) {
                    try fileManager.removeItem(at: symlinkPath)
                }

                // Create the symlink
                try fileManager.createSymbolicLink(at: symlinkPath, withDestinationURL: binaryPath)
                print("Created symlink: \(symlinkPath.path) -> \(binaryPath.path)")
            } catch {
                print("Failed to create symlink: \(error.localizedDescription)")
            }
        } else {
            print("Binary not found at expected path: \(binaryPath.path). Skipping symlink creation.")
        }
    }
}

func main() {
    print("Enter the name of your app:")
    guard let appName = readLine(), !appName.isEmpty else {
        print("Error: App name cannot be empty.")
        return
    }

    let generator = AppSkeletonGenerator(appName: appName)
    do {
        try generator.generateSkeleton()
        print("App skeleton generated successfully for '\(appName)'.")
    } catch {
        print("Failed to generate app skeleton: \(error.localizedDescription)")
    }
}

main()


