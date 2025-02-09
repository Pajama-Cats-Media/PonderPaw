//
//  StoryManager.swift
//  PonderPaw
//
//  Created by Homer Quan on 2/6/25.
//  Updated on 2/6/25 for template + merge unzip logic.
//  Updated on 2/9/25 to download all story files instead of a zip.
//

import Foundation
import FirebaseStorage
import FirebaseFirestore
import Zip

/// Manages downloading and preparing story assets.
class StoryManager {
    
    /// Retrieves the local URL for a story.
    ///
    /// The process now downloads a template zip based on the story’s type (from Firestore)
    /// from Firebase Storage at "common/templates/<storyType>.zip". If that file isn’t found
    /// (or if the type is nil), it falls back to "general.zip". It unzips the template first,
    /// then downloads and “merges” (copies) all the story files from Firebase Storage.
    /// If errors occur during the file download, the story folder is moved to a failed location.
    ///
    /// - Parameters:
    ///   - storyId: The identifier for the story.
    ///   - completion: Completion handler with the URL of the story folder or an error.
    static func getStoryPath(for storyId: String, completion: @escaping (URL?, Error?) -> Void) {
        // Retrieve story details from Firestore
        fetchStoryDetails(for: storyId) { storyType, storyURL, error in
            if let error = error {
                print("Error fetching story details: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            // Log the fetched details.
            print("Story Type: \(storyType ?? "nil")")
            print("Story URL: \(storyURL ?? "nil")")
            
            // Destination folder for this story in the app’s Application Support directory.
            let storyFolderURL = getApplicationSupportDirectory().appendingPathComponent(storyId)
            
            // If the folder already exists, return it.
            if FileManager.default.fileExists(atPath: storyFolderURL.path) {
                print("Story folder exists for storyId: \(storyId)")
                completion(storyFolderURL, nil)
                return
            }
            
            // Create the folder.
            do {
                try FileManager.default.createDirectory(at: storyFolderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating story folder: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            // Step 1: Download and unzip the template zip.
            // Use the fetched story type if available; otherwise, fall back to "general".
            let templateType = storyType ?? "general"
            downloadTemplateZip(for: templateType) { templateZipURL, error in
                if let error = error {
                    // If the template for the given type isn’t found, try "general.zip".
                    if templateType != "general" {
                        print("Error downloading \(templateType).zip; falling back to general.zip: \(error.localizedDescription)")
                        downloadTemplateZip(for: "general") { fallbackZipURL, fallbackError in
                            if let fallbackError = fallbackError {
                                print("Error downloading fallback general.zip: \(fallbackError.localizedDescription)")
                                cleanupFolder(storyFolderURL)
                                completion(nil, fallbackError)
                                return
                            }
                            processTemplateZip(templateZipURL: fallbackZipURL!, storyFolderURL: storyFolderURL) { success in
                                if !success {
                                    cleanupFolder(storyFolderURL)
                                    let unzipError = NSError(domain: "StoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to unzip fallback template zip"])
                                    completion(nil, unzipError)
                                    return
                                }
                                // Proceed to download and merge the story files.
                                downloadAndMergeStoryFiles(storyId: storyId, destinationFolder: storyFolderURL, completion: completion)
                            }
                        }
                    } else {
                        // Already using general; cannot recover.
                        cleanupFolder(storyFolderURL)
                        completion(nil, error)
                    }
                } else {
                    processTemplateZip(templateZipURL: templateZipURL!, storyFolderURL: storyFolderURL) { success in
                        if !success {
                            cleanupFolder(storyFolderURL)
                            let unzipError = NSError(domain: "StoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to unzip template zip"])
                            completion(nil, unzipError)
                            return
                        }
                        // Now download and merge the story files.
                        downloadAndMergeStoryFiles(storyId: storyId, destinationFolder: storyFolderURL, completion: completion)
                    }
                }
            }
        }
    }
    
    // MARK: - Template Zip Handling
    
    /// Downloads the template zip from Firebase Storage at "common/templates/<templateType>.zip".
    ///
    /// - Parameters:
    ///   - templateType: The type to use in the filename.
    ///   - completion: Completion handler with the local URL of the downloaded zip or an error.
    private static func downloadTemplateZip(for templateType: String, completion: @escaping (URL?, Error?) -> Void) {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let fileRef = storageRef.child("common/templates/\(templateType).zip")
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let localZipURL = tempDirectory.appendingPathComponent("template_\(templateType).zip")
        
        // Remove any existing file at the temp location.
        if FileManager.default.fileExists(atPath: localZipURL.path) {
            try? FileManager.default.removeItem(at: localZipURL)
        }
        
        fileRef.write(toFile: localZipURL) { url, error in
            if let error = error {
                print("Error downloading template zip for \(templateType): \(error.localizedDescription)")
                completion(nil, error)
            } else {
                print("Successfully downloaded template zip to: \(localZipURL.path)")
                completion(localZipURL, nil)
            }
        }
    }
    
    /// Unzips the template zip file into the story folder.
    ///
    /// - Parameters:
    ///   - templateZipURL: The URL of the downloaded template zip.
    ///   - storyFolderURL: The destination folder where the zip is extracted.
    ///   - completion: Completion handler with a Bool indicating success.
    private static func processTemplateZip(templateZipURL: URL, storyFolderURL: URL, completion: (Bool) -> Void) {
        do {
            try Zip.unzipFile(templateZipURL, destination: storyFolderURL, overwrite: true, password: nil)
            print("Successfully unzipped template zip into folder: \(storyFolderURL.path)")
            try FileManager.default.removeItem(at: templateZipURL)
            completion(true)
        } catch {
            print("Error unzipping template zip: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // MARK: - Story Files Handling (Replacing Story Zip)
    
    /// Downloads all files (including subfolders) from Firebase Storage at "stories/<storyId>"
    /// and copies them into the provided destination folder.
    ///
    /// - Parameters:
    ///   - storyId: The identifier for the story.
    ///   - destinationFolder: The folder that already contains the unzipped template.
    ///   - completion: Completion handler with the final folder URL or an error.
    private static func downloadAndMergeStoryFiles(storyId: String, destinationFolder: URL, completion: @escaping (URL?, Error?) -> Void) {
        downloadStoryFiles(for: storyId, into: destinationFolder) { error in
            if let error = error {
                print("Error downloading story files: \(error.localizedDescription)")
                moveFolderToFailed(destinationFolder)
                completion(nil, error)
            } else {
                print("Successfully downloaded story files into folder: \(destinationFolder.path)")
                completion(destinationFolder, nil)
            }
        }
    }
    
    /// Downloads all files (and subfolders) from Firebase Storage at "stories/<storyId>" into the destination folder.
    ///
    /// - Parameters:
    ///   - storyId: The identifier for the story.
    ///   - destinationURL: The local destination folder.
    ///   - completion: Completion handler with an optional error.
    private static func downloadStoryFiles(for storyId: String, into destinationURL: URL, completion: @escaping (Error?) -> Void) {
        let storage = Storage.storage()
        let storyRef = storage.reference().child("stories/\(storyId)")
        downloadFilesRecursively(from: storyRef, to: destinationURL, completion: completion)
    }
    
    /// Recursively downloads files from the given StorageReference into the local folder.
    ///
    /// - Parameters:
    ///   - storageRef: The Firebase Storage reference.
    ///   - localURL: The local destination folder.
    ///   - completion: Completion handler with an optional error.
    private static func downloadFilesRecursively(from storageRef: StorageReference, to localURL: URL, completion: @escaping (Error?) -> Void) {
        storageRef.listAll { (result, error) in
            if let error = error {
                completion(error)
                return
            }
            
            // Unwrap the optional result
            guard let result = result else {
                let unwrapError = NSError(domain: "StoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result returned from Firebase Storage"])
                completion(unwrapError)
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var downloadError: Error?
            
            // Download files in the current directory.
            for item in result.items {
                dispatchGroup.enter()
                let destinationFileURL = localURL.appendingPathComponent(item.name)
                // Ensure the parent directory exists.
                let parentDir = destinationFileURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: parentDir.path) {
                    do {
                        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
                    } catch {
                        print("Error creating directory \(parentDir.path): \(error.localizedDescription)")
                        downloadError = error
                        dispatchGroup.leave()
                        continue
                    }
                }
                item.write(toFile: destinationFileURL) { url, error in
                    if let error = error {
                        print("Error downloading file \(item.fullPath): \(error.localizedDescription)")
                        downloadError = error
                    } else {
                        print("Downloaded file \(item.fullPath) to \(destinationFileURL.path)")
                    }
                    dispatchGroup.leave()
                }
            }
            
            // Process subdirectories.
            for prefix in result.prefixes {
                dispatchGroup.enter()
                let subfolderURL = localURL.appendingPathComponent(prefix.name)
                // Create the local subfolder if it doesn't exist.
                if !FileManager.default.fileExists(atPath: subfolderURL.path) {
                    do {
                        try FileManager.default.createDirectory(at: subfolderURL, withIntermediateDirectories: true, attributes: nil)
                    } catch {
                        print("Error creating subfolder \(subfolderURL.path): \(error.localizedDescription)")
                        downloadError = error
                        dispatchGroup.leave()
                        continue
                    }
                }
                // Recursively download files from this subfolder.
                downloadFilesRecursively(from: prefix, to: subfolderURL) { error in
                    if let error = error {
                        downloadError = error
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(downloadError)
            }
        }
    }
    
    // MARK: - Firestore Fetch
    
    /// Fetches the story details from Firestore, including its type and URL.
    ///
    /// - Parameters:
    ///   - storyId: The identifier for the story.
    ///   - completion: Completion handler with the type, URL, or an error.
    private static func fetchStoryDetails(for storyId: String, completion: @escaping (String?, String?, Error?) -> Void) {
        let db = Firestore.firestore()
        let storyRef = db.collection("stories").document(storyId)
        
        storyRef.getDocument { document, error in
            if let error = error {
                completion(nil, nil, error)
                return
            }
            
            guard let document = document, document.exists else {
                let err = NSError(domain: "StoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Story not found in Firestore"])
                completion(nil, nil, err)
                return
            }
            
            // Extract the story type and URL from the Firestore document.
            let storyType = document.get("type") as? String
            let storyURL = document.get("url") as? String
            
            completion(storyType, storyURL, nil)
        }
    }
    
    // MARK: - File System Helpers
    
    /// Returns the URL for the app's Application Support directory.
    ///
    /// This directory is generally used for files that the app uses but that are not directly exposed to the user.
    private static func getApplicationSupportDirectory() -> URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[0]
        
        // Ensure the directory exists.
        if !FileManager.default.fileExists(atPath: appSupportURL.path) {
            do {
                try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            } catch {
                print("Error creating Application Support directory: \(error.localizedDescription)")
            }
        }
        
        return appSupportURL
    }
    
    /// Removes the specified folder (used for cleanup on error).
    ///
    /// - Parameter folderURL: The URL of the folder to remove.
    private static func cleanupFolder(_ folderURL: URL) {
        do {
            if FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.removeItem(at: folderURL)
                print("Cleaned up folder: \(folderURL.path)")
            }
        } catch {
            print("Error cleaning up folder \(folderURL.path): \(error.localizedDescription)")
        }
    }
    
    /// Moves the story folder to a "failedStories" folder if an error occurs during the file download.
    ///
    /// - Parameter folderURL: The URL of the story folder.
    private static func moveFolderToFailed(_ folderURL: URL) {
        let appSupport = getApplicationSupportDirectory()
        let failedFolder = appSupport.appendingPathComponent("failedStories")
        
        // Ensure the "failedStories" directory exists.
        if !FileManager.default.fileExists(atPath: failedFolder.path) {
            do {
                try FileManager.default.createDirectory(at: failedFolder, withIntermediateDirectories: true)
            } catch {
                print("Error creating failedStories directory: \(error.localizedDescription)")
            }
        }
        
        // Append a suffix to indicate failure.
        let destination = failedFolder.appendingPathComponent(folderURL.lastPathComponent + "_failed")
        
        do {
            try FileManager.default.moveItem(at: folderURL, to: destination)
            print("Moved folder to failed location: \(destination.path)")
        } catch {
            print("Error moving folder to failed location: \(error.localizedDescription)")
        }
    }
}
