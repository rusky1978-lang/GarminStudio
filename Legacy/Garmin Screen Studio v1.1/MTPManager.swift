import Foundation
import Combine

@MainActor
class MTPManager: ObservableObject {
    
    @Published var status = "🔌 Connect your Garmin and press Import Latest Recording"
    @Published var activityLog: [String] = []
    
    @Published var progress: Double = 0
    
    @Published var isWorking = false
    @Published var finished = false
    @Published var outputVideo: URL?
    
    
    private var parentFolderID: UInt32 = 0
    
    private let converter = VideoConverter()
    private let fileManager = FileManager.default
    
    func log(_ message: String) {

        print(message)

        activityLog.append(message)

        if activityLog.count > 8 {
            activityLog.removeFirst()
        }

    }
    
    func downloadBMP(
        device: UnsafeMutablePointer<LIBMTP_mtpdevice_t>,
        itemID: UInt32,
        filename: String
    ) {

        let folder = NSHomeDirectory() + "/Movies/Garmin Screen Studio/Latest Recording"

        try? FileManager.default.createDirectory(
            atPath: folder,
            withIntermediateDirectories: true
        )

        let destination = folder + "/" + filename

        print("⬇️ Downloading \(filename)")

        let result = LIBMTP_Get_File_To_File(
            device,
            itemID,
            destination,
            nil,
            nil
        )

        if result == 0 {

            print("✅ Download complete")

        } else {

            print("❌ Download failed")

            LIBMTP_Dump_Errorstack(device)
            LIBMTP_Clear_Errorstack(device)

        }

    }   // <-- downloadBMP ends here

    func clearLatestRecordingFolder() {

        let folder = URL(fileURLWithPath:
            NSHomeDirectory() + "/Movies/Garmin Screen Studio/Latest Recording"
        )

        do {

            let files = try fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )

            for file in files {

                if file.pathExtension.lowercased() == "bmp" {

                    try? fileManager.removeItem(at: file)

                }

            }

            log("🧹 Cleared previous recording")

        } catch {

            log("📁 Recording folder doesn't exist yet")

        }

    }
    
    func test() {

            finished = false
            isWorking = true
            progress = 0
            
            clearLatestRecordingFolder()
            
            status = "🔍 Looking for Garmin..."
            
            log("🚀 Initialising libmtp...")
            
            LIBMTP_Init()
            
            guard let device = LIBMTP_Get_First_Device() else {
                print("❌ No device found")
                return
        }
        
        status = "🟢 Garmin Connected"
        log("🟢 Garmin connected")
        
        guard let folders = LIBMTP_Get_Folder_List(device) else {
            print("❌ Folder tree is nil")
            LIBMTP_Release_Device(device)
            return
        }
        
        log("📂 Reading latest recording")
        
        
        if let latestRecording = latestRecordingFolder(folders) {
            
            print("")
            print("Latest recording folder ID: \(latestRecording)")
            
            // Temporary until we automatically discover it
            let childFolderID = latestRecording
            parentFolderID = childFolderID
            
            print("Child folder ID: \(childFolderID)")
            print("")
            print("📂 Loading complete file listing...")
            
            let files = LIBMTP_Get_Filelisting_With_Callback(
                device,
                nil,
                nil
            )
            
            print("✅ File list loaded")
            print("")
            
            printFiles(
                files,
                device: device,
                parentFolderID: childFolderID
            )
            
        }
        
        LIBMTP_Release_Device(device)
        
        print("")
        log("✅ Import complete")
        status = "✅ Finished"

        isWorking = false
        finished = true
        
        progress = 1.0
        
        convertLatestRecording()
    }
    
    func printFiles(
        _ files: UnsafeMutablePointer<LIBMTP_file_t>?,
        device: UnsafeMutablePointer<LIBMTP_mtpdevice_t>,
        parentFolderID: UInt32
    ) {
        
        guard let files else {
            
            print("❌ No files found")
            return
            
        }
        
        var current: UnsafeMutablePointer<LIBMTP_file_t>? = files
        
        var bmpCount = 0
        let totalBMPs = bmpFilesCount(files)
        while let file = current {
            
            let name = String(cString: file.pointee.filename)
            
            if name.uppercased().hasSuffix(".BMP") &&
                file.pointee.parent_id == parentFolderID {
                
                print("")
                print("🎬 BMP FOUND")
                print("Item ID   : \(file.pointee.item_id)")
                print("Parent ID : \(file.pointee.parent_id)")
                print("Filename  : \(name)")
                
                bmpCount += 1
                progress = Double(bmpCount) / Double(totalBMPs)
                
                
                if bmpCount % 25 == 0 {

                    status = "⬇️ Downloading \(bmpCount) of \(totalBMPs)"

                }
                
                downloadBMP(
                    device: device,
                    itemID: file.pointee.item_id,
                    filename: name
                )
                
            }
            
            current = file.pointee.next
            
        }
        
        print("")
        print("✅ Total BMP files found: \(bmpCount)")
        
        LIBMTP_destroy_file_t(files)
        
    }
    
    func latestRecordingFolder(_ folder: UnsafeMutablePointer<LIBMTP_folder_t>?) -> UInt32? {
        
        guard let folder else { return nil }
        
        var newestName = ""
        var newestID: UInt32?
        
        func walk(_ node: UnsafeMutablePointer<LIBMTP_folder_t>?) {
            
            guard let node else { return }
            
            var current: UnsafeMutablePointer<LIBMTP_folder_t>? = node
            
            while let folder = current {
                
                let name = String(cString: folder.pointee.name)
                
                if name.hasPrefix("2026-") {
                    
                    if name > newestName {
                        
                        newestName = name
                        
                        if let child = folder.pointee.child {
                            
                            newestID = child.pointee.folder_id
                            
                        }
                        
                    }
                    
                }
                
                walk(folder.pointee.child)
                
                current = folder.pointee.sibling
                
            }
            
        }
        
        walk(folder)
        
        print("")
        print("Newest recording: \(newestName)")
        print("Folder ID: \(newestID ?? 0)")
        
        return newestID
    }
    func convertLatestRecording() {
        
        let folder = URL(fileURLWithPath:
                            NSHomeDirectory() + "/Movies/Garmin Screen Studio/Latest Recording"
        )
        
        do {
            
            let images = try fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )
                .filter {
                    $0.pathExtension.lowercased() == "bmp"
                }
                .sorted {
                    $0.lastPathComponent < $1.lastPathComponent
                }
            
            log("🎬 Converting to MP4...")
            log("🖼️ Found \(images.count) frames")
            
            self.outputVideo = self.converter.convert(images: images)
            if let video = outputVideo {

                status = "✅ \(images.count) frames converted"
                log("✅ \(images.count) frames converted")

                log("🎥 Saved: \(video.lastPathComponent)")

            }
            
        } catch {
            
            print("❌ Couldn't read downloaded BMP folder")
            
        }
        
    }
    func isGarminConnected() -> Bool {
        
        LIBMTP_Init()
        
        guard let device = LIBMTP_Get_First_Device() else {
            return false
        }
        
        LIBMTP_Release_Device(device)
        
        return true
        
    }
    func bmpFilesCount(_ files: UnsafeMutablePointer<LIBMTP_file_t>?) -> Int {

        guard let files else { return 0 }

        var count = 0
        var current: UnsafeMutablePointer<LIBMTP_file_t>? = files

        while let file = current {

            let name = String(cString: file.pointee.filename)

            if name.uppercased().hasSuffix(".BMP") &&
               file.pointee.parent_id == parentFolderID {

                count += 1

            }

            current = file.pointee.next

        }

        return count

    }}
    
