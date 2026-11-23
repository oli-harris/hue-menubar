import Foundation

// One executable, two modes: started by Contents/Resources/hue (HUE_CLI) or with a command it is the CLI, otherwise the menu bar app
@main
enum Entry {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        
        guard ProcessInfo.processInfo.environment["HUE_CLI"] != nil || args.first.map(CLI.commands.contains) == true else {
            HueMenuBarApp.main()
            return
        }
        Task { @MainActor in exit(await CLI.run(args)) }
        dispatchMain()
    }
}
