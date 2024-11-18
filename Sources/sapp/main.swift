import Foundation

func createSymlink(source: URL, destination: URL) throws {
    let fileManager = FileManager.default

    try fileManager.createSymbolicLink(at: destination, withDestinationURL: source)
    print("Created symlink: \(destination.path) -> \(source.path)")
}

func removeDirectoryIfEmpty(destination: URL) throws {
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: destination.path) else {
        print("Directory does not exist: \(destination.path)")
        return
    }

    let contents = try fileManager.contentsOfDirectory(atPath: destination.path)

    if contents.isEmpty {
        try fileManager.removeItem(at: destination)
        print("Removed empty directory: \(destination.path)")
    } else {
        throw NSError(
            domain: "SymlinkError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Destination \(destination.path) is not empty."]
        )
    }
}

func handleSymResources(appName: String) {
    let currentDirectory = FileManager.default.currentDirectoryPath
    let appPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent("\(appName).app")
    let appResourcesPath = appPath.appendingPathComponent("Contents/Resources")
    let buildBundlePath = URL(fileURLWithPath: currentDirectory)
        .appendingPathComponent(".build/release")
        .appendingPathComponent("\(appName)_\(appName).bundle")

    // Check if {appName}.app exists
    guard FileManager.default.fileExists(atPath: appPath.path) else {
        print("Error: \(appName).app does not exist. Please initialize the app first.")
        return
    }

    // Ensure the .bundle exists
    guard FileManager.default.fileExists(atPath: buildBundlePath.path) else {
        print("Error: \(buildBundlePath.path) not found. Ensure resources are bundled during build.")
        return
    }

    // Remove existing symlink or directory
    do {
        try removeDirectoryIfEmpty(destination: appResourcesPath)
    } catch {
        print("Error: \(error.localizedDescription)")
        return
    }

    // Create symlink to the .bundle
    do {
        try createSymlink(source: buildBundlePath, destination: appResourcesPath)
    } catch {
        print("Error: Failed to create symlink: \(error.localizedDescription)")
    }
}

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
        createBinarySymlink()
    }

    private func createDirectoryStructure() throws {
        let contentsDir = appDirectory.appendingPathComponent("Contents")
        let macOSDir = contentsDir.appendingPathComponent("MacOS")
        let resourcesSymlinkPath = contentsDir.appendingPathComponent("Resources")

        do {
            // Create MacOS directory for binary
            try FileManager.default.createDirectory(at: macOSDir, withIntermediateDirectories: true, attributes: nil)

            // Locate the .bundle in the build directory
            if let buildBundlePath = findBuildBundlePath() {
                try createSymlink(source: buildBundlePath, destination: resourcesSymlinkPath)
                print("Created symlink: \(resourcesSymlinkPath.path) -> \(buildBundlePath.path)")
            } else {
                print("No .bundle file found in build directory. Skipping Resources symlink creation.")
            }

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

        if fileManager.fileExists(atPath: binaryPath.path) {
            do {
                if fileManager.fileExists(atPath: symlinkPath.path) {
                    try fileManager.removeItem(at: symlinkPath)
                }

                try fileManager.createSymbolicLink(at: symlinkPath, withDestinationURL: binaryPath)
                print("Created symlink: \(symlinkPath.path) -> \(binaryPath.path)")
            } catch {
                print("Failed to create symlink: \(error.localizedDescription)")
            }
        } else {
            print("Binary not found at expected path: \(binaryPath.path). Skipping symlink creation.")
        }
    }

    private func createResourcesSymlinkIfNeeded() throws {
        let appResourcesPath = appDirectory.appendingPathComponent("Contents/Resources")

        // Locate the `.bundle` file in the build directory
        guard let buildBundlePath = findBuildBundlePath() else {
            print("No .bundle file found in the build directory. Ensure resources are bundled during the build process.")
            return
        }

        // Remove existing symlink or directory if it's empty
        do {
            try removeDirectoryIfEmpty(destination: appResourcesPath)
        } catch {
            print("Error: \(error.localizedDescription). Cannot reset Resources.")
            throw error
        }

        // Create symlink from the `.bundle` to `Contents/Resources`
        try createSymlink(source: buildBundlePath, destination: appResourcesPath)
    }

    private func findBuildBundlePath() -> URL? {
        let currentDirectory = FileManager.default.currentDirectoryPath
        let buildDir = URL(fileURLWithPath: currentDirectory).appendingPathComponent(".build/release")

        // Construct the expected `.bundle` path based on app name
        let bundlePath = buildDir.appendingPathComponent("\(appName)_\(appName).bundle")

        // Check if the `.bundle` exists
        if FileManager.default.fileExists(atPath: bundlePath.path) {
            return bundlePath
        }

        print("Expected bundle not found at path: \(bundlePath.path)")
        return nil
    }

    func resetResourcesSymlink() throws {
        try createResourcesSymlinkIfNeeded()
    }
}

func main() {
    let arguments = CommandLine.arguments

    if arguments.count == 3, arguments[1] == "-sym", arguments[2] == "resources" {
        print("")
        print("Enter the name of your app:".ansi(.bold))
        guard let appName = readLine(), !appName.isEmpty else {
            print("")
            print("Error: App name cannot be empty.".ansi(.red))
            return
        }

        handleSymResources(appName: appName)
        return
    }

    print("")
    print("Enter the name of your app:".ansi(.bold))
    guard let appName = readLine(), !appName.isEmpty else {
        print("")
        print("Error: App name cannot be empty.".ansi(.red))
        return
    }

    print("")

    let generator = AppSkeletonGenerator(appName: appName)
    do {
        try generator.generateSkeleton()
        print("App skeleton generated successfully for ".ansi(.green) + "\(appName)".ansi(.bold))
    } catch {
        print("Failed to generate app skeleton: \(error.localizedDescription)".ansi(.red))
    }
    print("")
}

main()


