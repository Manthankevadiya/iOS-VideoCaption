//
//  Globals.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 03/11/25.
//

import Speech
import UIKit
import AVFoundation
import CoreMedia

let allHexColors: [String] = [
    "#FFFFFF", // White (Perceived Brightness: 1.00)
    "#FFFFF0", // Ivory
    "#FFFAFA", // Snow
    "#FFFAF0", // FloralWhite
    "#FFF8DC", // Cornsilk
    "#FFF5EE", // SeaShell
    "#FDF5E6", // OldLace
    "#FFFACD", // LemonChiffon
    "#FFFFE0", // LightYellow
    "#FAFAD2", // LightGoldenRodYellow
    "#FFFF00", // Yellow
    "#FFEFD5", // PapayaWhip
    "#F5FFFA", // MintCream
    "#F0FFF0", // HoneyDew
    "#F5F5F5", // WhiteSmoke
    "#F8F8FF", // GhostWhite
    "#F0FFFF", // Azure
    "#F0F8FF", // AliceBlue
    "#E0FFFF", // LightCyan
    "#FAEBD7", // AntiqueWhite
    "#F5F5DC", // Beige
    "#F0E68C", // Khaki
    "#FFEBCD", // BlanchedAlmond
    "#FFE4C4", // Bisque
    "#FFDAB9", // PeachPuff
    "#FFE4E1", // MistyRose
    "#FFF0F5", // LavenderBlush
    "#FFE4B5", // Moccasin
    "#FFDEAD", // NavajoWhite
    "#FFEFD5", // PapayaWhip
    "#FFEBCD", // BlanchedAlmond
    "#FAF0E6", // Linen
    "#E6E6FA", // Lavender
    "#DCDCDC", // Gainsboro
    "#D3D3D3", // LightGray
    "#C0C0C0", // Silver
    "#B0E0E6", // PowderBlue
    "#AFEEEE", // PaleTurquoise
    "#BDB76B", // DarkKhaki
    "#FAFAD2", // LightGoldenRodYellow
    "#EEE8AA", // PaleGoldenRod
    "#F5DEB3", // Wheat
    "#DAA520", // GoldenRod
    "#FFD700", // Gold
    "#D8BFD8", // Thistle
    "#DDA0DD", // Plum
    "#EE82EE", // Violet
    "#DA70D6", // Orchid
    "#FFC0CB", // Pink
    "#FFB6C1", // LightPink
    "#FF69B4", // HotPink
    "#FF1493", // DeepPink
    "#C71585", // MediumVioletRed
    "#DB7093", // PaleVioletRed
    "#DC143C", // Crimson
    "#FF00FF", // Fuchsia/Magenta
    "#8B008B", // DarkMagenta
    "#9932CC", // DarkOrchid
    "#9400D3", // DarkViolet
    "#8A2BE2", // BlueViolet
    "#800080", // Purple
    "#663399", // RebeccaPurple
    "#4B0082", // Indigo
    "#BA55D3", // MediumOrchid
    "#9370DB", // MediumPurple
    "#6A5ACD", // SlateBlue
    "#7B68EE", // MediumSlateBlue
    "#483D8B", // DarkSlateBlue
    "#191970", // MidnightBlue
    "#000080", // Navy
    "#0000CD", // MediumBlue
    "#4169E1", // RoyalBlue
    "#0000FF", // Blue
    "#6495ED", // CornflowerBlue
    "#1E90FF", // DodgerBlue
    "#00BFFF", // DeepSkyBlue
    "#87CEFA", // LightSkyBlue
    "#ADD8E6", // LightBlue
    "#5F9EA0", // CadetBlue
    "#B0C4DE", // LightSteelBlue
    "#4682B4", // SteelBlue
    "#40E0D0", // Turquoise
    "#00CED1", // DarkTurquoise
    "#48D1CC", // MediumTurquoise
    "#7FFFD4", // Aquamarine
    "#66CDAA", // MediumAquaMarine
    "#20B2AA", // LightSeaGreen
    "#008B8B", // DarkCyan
    "#008080", // Teal
    "#00FFFF", // Cyan/Aqua (removed duplicate)
    "#98FB98", // PaleGreen
    "#90EE90", // LightGreen
    "#8FBC8F", // DarkSeaGreen
    "#ADFF2F", // GreenYellow
    "#7CFC00", // LawnGreen
    "#7FFF00", // Chartreuse
    "#9ACD32", // YellowGreen
    "#6B8E23", // OliveDrab
    "#808000", // Olive
    "#BDB76B", // DarkKhaki
    "#556B2F", // DarkOliveGreen
    "#008000", // Green
    "#228B22", // ForestGreen
    "#3CB371", // MediumSeaGreen
    "#2E8B57", // SeaGreen
    "#32CD32", // LimeGreen
    "#00FF00", // Lime
    "#00FF7F", // SpringGreen
    "#00FA9A", // MediumSpringGreen
    "#006400", // DarkGreen
    "#8A2BE2", // BlueViolet
    "#A52A2A", // Brown
    "#DEB887", // BurlyWood
    "#CD853F", // Peru
    "#D2691E", // Chocolate
    "#B22222", // FireBrick
    "#FF8C00", // DarkOrange
    "#FFA500", // Orange
    "#FF7F50", // Coral
    "#FF6347", // Tomato
    "#FF4500", // OrangeRed
    "#FF0000", // Red
    "#8B0000", // DarkRed
    "#BC8F8F", // RosyBrown
    "#CD5C5C", // IndianRed
    "#F08080", // LightCoral
    "#FFA07A", // LightSalmon
    "#FA8072", // Salmon
    "#F4A460", // SandyBrown
    "#E9967A", // DarkSalmon
    "#A0522D", // Sienna
    "#8B4513", // SaddleBrown
    "#800000", // Maroon
    "#708090", // SlateGray
    "#778899", // LightSlateGray
    "#696969", // DimGray
    "#808080", // Gray
    "#A9A9A9", // DarkGray
    "#2F4F4F", // DarkSlateGray
    "#3B3F43", // **BlackCurrant (New)**
    "#00008B", // DarkBlue
    "#000000", // Black (Perceived Brightness: 0.00)
]

func getSupportedSpeechLanguages() -> [(id: String, name: String)] {
    let supportedLocales = SFSpeechRecognizer.supportedLocales()
    
    let languages: [(id: String, name: String)] = supportedLocales.map { locale in
        let id = locale.identifier
        let name = Locale.current.localizedString(forIdentifier: id) ?? id
        return (id: id, name: name)
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    
    return languages
}

func generateThumbnail(from videoURL: URL) async -> UIImage? {
    await withCheckedContinuation { continuation in
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1.5, preferredTimescale: 600)
        
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
            let image = cgImage.map { UIImage(cgImage: $0) }
            DispatchQueue.main.async {
                continuation.resume(returning: image)
            }
        }
    }
}

func saveVideoToDocuments(from tempURL: URL) -> URL? {
    let fileManager = FileManager.default
    
    // 1. Get the destination path
    let fileName = tempURL.lastPathComponent // Get the filename (e.g., A1B2C.MOV)
    let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let destinationURL = documentsDirectory.appendingPathComponent(fileName)
    
    // 2. Check and remove existing file (safety first)
    if fileManager.fileExists(atPath: destinationURL.path) {
        do {
            try fileManager.removeItem(at: destinationURL)
            print("Removed existing file at destination.")
        } catch {
            print("Error removing existing file: \(error.localizedDescription)")
            // If we can't remove the old file, we stop.
            return nil
        }
    }
    
    // 3. Perform the copy operation
    do {
        // The file at tempURL is guaranteed to exist at this point in the delegate call.
        try fileManager.copyItem(at: tempURL, to: destinationURL)
        print("✅ SUCCESS: Video permanently saved to: \(destinationURL.lastPathComponent)")
        return destinationURL // Return the permanent URL
    } catch {
        print("❌ CRITICAL FILE ERROR: Failed to copy video from temporary location: \(error.localizedDescription)")
        return nil
    }
}
func formatDuration(seconds: Double) -> String {
    // Round the seconds to the nearest whole number to avoid fractional display
    let time = Int(round(seconds))
    
    let hours = time / 3600
    let minutes = (time % 3600) / 60
    let seconds = time % 60
    
    // Choose the format based on duration: HH:MM:SS if > 1 hour, otherwise MM:SS
    if hours > 0 {
        // Format: HH:MM:SS
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    } else {
        // Format: MM:SS
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

func timeAgoString(from date: Date) -> String {
    let now = Date()
    let seconds = Int(now.timeIntervalSince(date))
    
    if seconds < 5 {
        return "just now"
    } else if seconds < 60 {
        // Less than a minute
        return "\(seconds) sec\(seconds == 1 ? "" : "s") ago"
    } else if seconds < 3600 {
        // Less than an hour
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if remainingSeconds == 0 {
            return "\(minutes) min\(minutes == 1 ? "" : "s") ago"
        } else {
            return "\(minutes) min\(minutes == 1 ? "" : "s") \(remainingSeconds) sec\(remainingSeconds == 1 ? "" : "s") ago"
        }
    } else if seconds < 86400 {
        // Less than a day
        let hours = seconds / 3600
        let remainingMinutes = (seconds % 3600) / 60
        if remainingMinutes == 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s") \(remainingMinutes) min\(remainingMinutes == 1 ? "" : "s") ago"
        }
    } else {
        // 1 day or more
        let days = seconds / 86400
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}
