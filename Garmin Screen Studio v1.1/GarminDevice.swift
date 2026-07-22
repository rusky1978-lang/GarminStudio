import Foundation

class GarminDevice {
    
    func downloadBMPFile(
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
        
        let result = LIBMTP_Get_File_To_File(
            device,
            itemID,
            destination,
            nil,
            nil
        )
        
        if result != 0 {
            
            LIBMTP_Dump_Errorstack(device)
            LIBMTP_Clear_Errorstack(device)
            
        }
        
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
    
    func bmpFilesCount(
        _ files: UnsafeMutablePointer<LIBMTP_file_t>?,
        parentFolderID: UInt32
    ) -> Int {
        
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
        
    }
    
    func printFiles(
        _ files: UnsafeMutablePointer<LIBMTP_file_t>?,
        device: UnsafeMutablePointer<LIBMTP_mtpdevice_t>,
        parentFolderID: UInt32,
        progressUpdate: (Double) -> Void,
        statusUpdate: (String) -> Void
    ) {
        
        guard let files else {
            print("❌ No files found")
            return
        }
        
        var current: UnsafeMutablePointer<LIBMTP_file_t>? = files
        var bmpCount = 0
        let totalBMPs = bmpFilesCount(
            files,
            parentFolderID: parentFolderID
        )
        
        while let file = current {
            
            let name = String(cString: file.pointee.filename)
            
            if name.uppercased().hasSuffix(".BMP"),
               file.pointee.parent_id == parentFolderID {
                
                print("")
                print("🎬 BMP FOUND")
                print("Item ID   : \(file.pointee.item_id)")
                print("Parent ID : \(file.pointee.parent_id)")
                print("Filename  : \(name)")
                
                bmpCount += 1
                
                if totalBMPs > 0 {
                    progressUpdate(Double(bmpCount) / Double(totalBMPs))
                }
                
                if bmpCount % 25 == 0 {
                    statusUpdate("⬇️ Downloading \(bmpCount) of \(totalBMPs)")
                }
                
                downloadBMPFile(
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
}
