//
//  DirectoryLocations.swift
//  Mousecape
//
//  Swift replacement for NSFileManager+DirectoryLocations
//  Provides convenient methods for finding and creating app directories
//

import Foundation

extension FileManager {

    /// Error types for directory operations
    enum DirectoryLocationError: Error, LocalizedError {
        case noPathFound(directory: FileManager.SearchPathDirectory, domain: FileManager.SearchPathDomainMask)
        case fileExistsAtLocation(path: String)
        case creationFailed(path: String, underlyingError: Error)

        var errorDescription: String? {
            switch self {
            case .noPathFound(let directory, let domain):
                return "No path found for directory \(directory) in domain \(domain)"
            case .fileExistsAtLocation(let path):
                return "A file exists at the location: \(path)"
            case .creationFailed(let path, let underlyingError):
                return "Failed to create directory at \(path): \(underlyingError.localizedDescription)"
            }
        }
    }

    /// Find or create a directory at the specified search path
    /// - Parameters:
    ///   - searchPathDirectory: The search path directory type
    ///   - domainMask: The domain mask for the search
    ///   - appendComponent: Optional path component to append
    /// - Returns: URL to the directory
    /// - Throws: DirectoryLocationError if the directory cannot be found or created
    func findOrCreateDirectory(
        _ searchPathDirectory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask,
        appendingPathComponent appendComponent: String? = nil
    ) throws -> URL {
        // Get the search paths
        let urls = urls(for: searchPathDirectory, in: domainMask)

        guard let baseURL = urls.first else {
            throw DirectoryLocationError.noPathFound(directory: searchPathDirectory, domain: domainMask)
        }

        // Append the extra path component if provided
        var resolvedURL = baseURL
        if let appendComponent = appendComponent {
            resolvedURL = baseURL.appendingPathComponent(appendComponent)
        }

        // Create the directory if it doesn't exist
        do {
            try createDirectory(at: resolvedURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw DirectoryLocationError.creationFailed(path: resolvedURL.path, underlyingError: error)
        }

        return resolvedURL
    }

    /// Returns the URL to the application support directory for this app
    /// Creates the directory if it doesn't exist
    var applicationSupportDirectoryURL: URL? {
        guard let executableName = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String else {
            return nil
        }

        do {
            return try findOrCreateDirectory(.applicationSupportDirectory, in: .userDomainMask, appendingPathComponent: executableName)
        } catch {
            print("Unable to find or create application support directory: \(error)")
            return nil
        }
    }

    /// Returns the path to the application support directory for this app (legacy compatibility)
    /// Creates the directory if it doesn't exist
    @objc var applicationSupportDirectory: String? {
        return applicationSupportDirectoryURL?.path
    }
}
