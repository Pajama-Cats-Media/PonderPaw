//
//  StoryManager.swift
//  PonderPaw
//
//  Created by Homer Quan on 2/6/25.
//  Updated on 2/6/25 for template + merge unzip logic.
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
    /// then downloads and unzips the story.zip (merging its contents). If errors occur during
    /// the story.zip extraction, the story folder is moved to a failed location.
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
                                // Proceed to download and merge the story zip.
                                downloadAndMergeStoryZip(storyId: storyId, storyFolderURL: storyFolderURL, completion: completion)
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
                        // Now download and merge the story.zip.
                        downloadAndMergeStoryZip(storyId: storyId, storyFolderURL: storyFolderURL, completion: completion)
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
    
    // MARK: - Story Zip Handling
    
    /// Downloads and merges the story zip into the story folder.
    ///
    /// - Parameters:
    ///   - storyId: The identifier for the story.
    ///   - storyFolderURL: The folder that already contains the unzipped template.
    ///   - completion: Completion handler with the final folder URL or an error.
    private static func downloadAndMergeStoryZip(storyId: String, storyFolderURL: URL, completion: @escaping (URL?, Error?) -> Void) {
        downloadStoryZip(for: storyId) { storyZipURL, error in
            if let error = error {
                print("Error downloading story zip: \(error.localizedDescription)")
                moveFolderToFailed(storyFolderURL)
                completion(nil, error)
                return
            }
            
            guard let storyZipURL = storyZipURL else {
                moveFolderToFailed(storyFolderURL)
                let err = NSError(domain: "StoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Story zip URL is nil"])
                completion(nil, err)
                return
            }
            
            do {
                // Unzip and merge (overwrite: true) so that any files from story.zip
                // will override the template files if needed.
                try Zip.unzipFile(storyZipURL, destination: storyFolderURL, overwrite: true, password: nil)
                print("Successfully merged story.zip into folder: \(storyFolderURL.path)")
                try FileManager.default.removeItem(at: storyZipURL)
                completion(storyFolderURL, nil)
            } catch {
                print("Error unzipping story zip: \(error.localizedDescription)")
                moveFolderToFailed(storyFolderURL)
                completion(nil, error)
            }
        }
    }
    
    /// Downloads the story zip file from Firebase Storage at "stories/<storyId>/story.zip".
    ///
    /// - Parameters:
    ///   - storyId: The identifier for the story.
    ///   - completion: Completion handler with the local URL of the downloaded zip or an error.
    private static func downloadStoryZip(for storyId: String, completion: @escaping (URL?, Error?) -> Void) {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        // Reference to the story file at "stories/<storyId>/story.zip"
        let fileRef = storageRef.child("stories/\(storyId)/story.zip")
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let localZipURL = tempDirectory.appendingPathComponent("story_\(storyId).zip")
        
        // Remove any existing file at the temp location.
        if FileManager.default.fileExists(atPath: localZipURL.path) {
            try? FileManager.default.removeItem(at: localZipURL)
        }
        
        fileRef.write(toFile: localZipURL) { url, error in
            if let error = error {
                print("Error downloading story zip: \(error.localizedDescription)")
                completion(nil, error)
            } else {
                print("Successfully downloaded story zip to: \(localZipURL.path)")
                completion(localZipURL, nil)
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
    
    /// Moves the story folder to a "failedStories" folder if an error occurs during the story.zip extraction.
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
