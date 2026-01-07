//
//  CoreDataManager.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 10/11/25.
//

import Foundation
import CoreData
import UIKit

// MARK: - Core Data Stack
final class CoreDataManager {
    
    static let shared = CoreDataManager()
    
    // Private initializer for Singleton pattern
    private init() {}
    
    // The main container for the Core Data stack
    lazy var persistentContainer: NSPersistentContainer = {
        // IMPORTANT: Must match the name of your .xcdatamodeld file!
        let container = NSPersistentContainer(name: "iOS_VideoCaption")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // In a production app, you would log this error.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    // Context for performing read/write operations (main thread context)
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Saving
    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

// MARK: - Video Project CRUD Operations (Using CaptionEntity/TranscribedEntity)

extension CoreDataManager {
    
    // MARK: - Initial Project Creation (Step 1: After video selection/recording)
    
    /**
     Creates a new CaptionEntity record when a video is selected or recorded.
     Sets all the initial style and language defaults.
     
     - Parameters:
        - name: The name of the video file.
        - link: Local file URL string where the video asset is stored.
        - duration: The total duration of the video in seconds (Double).
     - Returns: The newly created CaptionEntity object.
     */
    func createNewProject(name: String, link: String, duration: Double) -> CaptionEntity {
        let newProject = CaptionEntity(context: viewContext)
        newProject.videoID = UUID()
        newProject.videoName = name
        newProject.videoLink = link
        newProject.totalDuration = duration // Stored as Double
        newProject.dateCreated = Date()
        newProject.dateLastEdited = Date()
        
        // --- Set Initial Default Transcribe/Style Preferences ---
        newProject.selectedLanguage = "en-US"
        newProject.fullCaptionText = nil      // Generated later
        
        // --- Default Styling ---
        newProject.captionFontName = "PingFangTC-Semibold"
        newProject.captionFontSize = 20
        newProject.captionFontColor = "#FFFFFF" // White
        newProject.captionHighlightColor = "#FFFF00" // Yellow
        newProject.captionPositionX = 0.5       // Center X (Normalized)
        newProject.captionPositionY = 0.85       // Near the bottom (Normalized)
        newProject.captionAnimationType = "Pop Word"
        newProject.wordsPerLine = 4
        
        // --- Default Font Style ---
        newProject.shadowRadius = 4.0
        newProject.shadowColor = "#000000"      // Black shadow
        newProject.borderThickness = 0.0
        newProject.borderColor = "#FFFFFF"      // White border
        
        saveContext()
        return newProject
    }
    
    // MARK: - Post-Transcription Storage (Step 2: After SFSpeechRecognizer completes)
    
    /**
     Updates the project with the final transcription data and selected language.
     **NOTE:** This function automatically clears all old TranscribedEntity records.
     
     - Parameters:
        - project: The CaptionEntity to update.
        - language: The language code used for transcription.
        - fullText: The full transcribed text block.
        - wordData: An array of tuples containing word, start time, and end time.
     */
    func saveTranscription(to project: CaptionEntity, language: String, fullText: String, wordData: [(text: String, startTime: Double, endTime: Double)]) {
        
        // 1. Clear any existing transcription data first
        if let existingWords = project.words {
            existingWords.forEach { viewContext.delete($0 as! TranscribedEntity) }
        }
        
        // 2. Update parent properties
        project.selectedLanguage = language
        project.fullCaptionText = fullText
        
        // 3. Create new TranscribedEntity entities
        var wordObjects: [TranscribedEntity] = []
        for (text, start, end) in wordData {
            let newWord = TranscribedEntity(context: viewContext)
            newWord.text = text
            newWord.startTime = start
            newWord.endTime = end
            wordObjects.append(newWord)
        }
        
        // ⭐ Use the dynamic setter for ordered relationships
        let mutableWords = project.mutableOrderedSetValue(forKey: "words")
        mutableWords.removeAllObjects()
        mutableWords.addObjects(from: wordObjects)
        
        project.dateLastEdited = Date()
        saveContext()
    }
    
    // MARK: - Style Update (Step 3: From CaptionVC when user edits styles)
    
    /**
     Updates all dynamic styling preferences for a given project after user editing.
     */
    func updateProjectStyle(project: CaptionEntity,
                            fontName: String,
                            fontSize: Float,
                            fontColor: String,
                            fontHighlightColor: String,
                            positionX: Float,
                            positionY: Float,
                            animationType: String,
                            wordsPerLine: Int16,
                            shadowRadius: Float,
                            shadowColor: String,
                            borderThickness: Float,
                            borderColor: String) {
        
        project.captionFontName = fontName
        project.captionFontSize = fontSize
        project.captionFontColor = fontColor
        project.captionHighlightColor = fontHighlightColor
        project.captionPositionX = positionX
        project.captionPositionY = positionY
        project.captionAnimationType = animationType
        project.wordsPerLine = wordsPerLine
        
        project.shadowRadius = shadowRadius
        project.shadowColor = shadowColor
        project.borderThickness = borderThickness
        project.borderColor = borderColor
        
        project.dateLastEdited = Date()
        saveContext()
    }
    
    func updateCaptionStyle(project: CaptionEntity, fontName: String,fontSize: Float, fontColor: String, fontHighlightColor: String, animationType: String, borderColor: String) {
        project.captionFontName = fontName
        project.captionFontSize = fontSize
        project.captionFontColor = fontColor
        project.captionHighlightColor = fontHighlightColor
        project.captionAnimationType = animationType
        project.borderColor = borderColor
        
        project.dateLastEdited = Date()
        saveContext()
    }
    
    // MARK: - Fetching and Deletion
    
    /**
     Fetches all existing projects, sorted by last edited date.
     */
    func fetchAllProjects() -> [CaptionEntity] {
        let request: NSFetchRequest<CaptionEntity> = CaptionEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "dateLastEdited", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Failed to fetch projects: \(error)")
            return []
        }
    }
    
    func fetchProject(byID id: UUID) -> CaptionEntity? {
        let request: NSFetchRequest<CaptionEntity> = CaptionEntity.fetchRequest()
        
        // 1. Create a Predicate to filter by the videoID
        // We use the 'description' of the UUID to match the stored UUID type.
        request.predicate = NSPredicate(format: "videoID == %@", id as CVarArg)
        
        // 2. Limit the fetch to one result, as the ID is unique
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first // Returns the single project or nil
        } catch {
            print("Failed to fetch project by ID \(id.uuidString): \(error)")
            return nil
        }
    }
    
    func saveVideoImages(to project: CaptionEntity, thumbnail: UIImage, timelineImages: [UIImage]) {
        
        // 1. Convert UIImage to Data for the main thumbnail
        // Using JPEG for smaller file size, with moderate compression (0.8)
        project.videoThumbnail = thumbnail.jpegData(compressionQuality: 0.8)
        
        // 2. Encode the Array of Timeline Images
        // First, convert each UIImage in the array to Data
        let timelineDataArray: [Data] = timelineImages.compactMap { $0.jpegData(compressionQuality: 0.6) }
        
        do {
            // Encode the array of Data objects into a single Data blob for storage
            project.timelineImages = try JSONEncoder().encode(timelineDataArray)
        } catch {
            print("❌ Error encoding timeline images for Core Data: \(error)")
            project.timelineImages = nil
        }
        
        project.dateLastEdited = Date()
        saveContext()
        print("✅ Core Data: Successfully saved video thumbnail and timeline images.")
    }
    
    /**
     Decodes the stored timeline image data back into an array of UIImages.
     
     - Parameter project: The CaptionEntity containing the timelineImages Data.
     - Returns: An array of UIImages, or an empty array if decoding fails.
     */
    func fetchTimelineImages(for project: CaptionEntity) -> [UIImage] {
        guard let imageData = project.timelineImages else {
            return []
        }
        
        do {
            // Decode the single Data blob back into an array of Data
            let timelineDataArray = try JSONDecoder().decode([Data].self, from: imageData)
            
            // Convert each Data object back into a UIImage
            let images: [UIImage] = timelineDataArray.compactMap { UIImage(data: $0) }
            
            return images
        } catch {
            print("❌ Error decoding timeline images from Core Data: \(error)")
            return []
        }
    }
    
    /**
     Retrieves the transcribed words for a given project, correctly ordered by time.
     **/
    func fetchTranscription(for project: CaptionEntity) -> [TranscribedEntity] {
        
        // ⭐ Use the new, safe accessor:
        guard let wordsSet = project.orderedWords,
              let wordsArray = wordsSet.array as? [TranscribedEntity] else {
            return []
        }
        
        return wordsArray
    }
    
    /**
     Deletes a specific project record and all its associated words (due to Cascade delete rule).
     */
    func deleteProject(_ project: CaptionEntity) {
        // You would typically include file deletion logic here as well
        viewContext.delete(project)
        saveContext()
    }
}

extension CaptionEntity {
    
    public var orderedWords: NSOrderedSet? {
        return self.value(forKey: "words") as? NSOrderedSet
    }
    
    var currentAbsoluteVideoURL: URL? {
        guard let storedFileName = self.videoLink, !storedFileName.isEmpty else {
            print("Warning: videoLink (filename) is missing from Core Data.")
            return nil
        }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let finalURL = documentsDirectory.appendingPathComponent(storedFileName)
        
        if !FileManager.default.fileExists(atPath: finalURL.path) {
            print("❌ ERROR: File does NOT exist at reconstructed path: \(finalURL.path)")
            return nil
        }
        return finalURL
    }
    
}

