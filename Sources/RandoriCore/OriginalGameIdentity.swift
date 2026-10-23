/// What a game is called where the engine shows or stores something for it
/// (ENGINE_SPLIT E3b): its name in the stop message and its user-data folder.
/// The EXE model's own strings that name the game are the rules' branding
/// (`OriginalGameRules.Branding`, ENGINE_SPLIT E10; LF2 2.0a's by default):
/// the window class and title, the quit dialog's caption, the game's name in
/// the replay loader's two error texts, the credit lines and their links, the
/// menus' URLs and background 99's name. Every other EXE text stays the EXE's,
/// the "Error"/"ERROR" captions among them.
public struct OriginalGameIdentity: Equatable, Sendable {
    public let name: String, userDataFolder: String
    public init(name: String,userDataFolder: String) { self.name = name; self.userDataFolder = userDataFolder }
}
