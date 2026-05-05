#if os(macOS)
import Foundation

enum MacRoute: Hashable {
    case home
    case stats
    case search
    case sources
    case playlistImport
    case duplicates
    case scrobble
    case section(LibrarySection)
    case source(String)
}
#endif
