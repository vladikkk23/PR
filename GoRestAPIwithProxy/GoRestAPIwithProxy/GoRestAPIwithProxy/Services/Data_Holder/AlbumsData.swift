//
//  AlbumsData.swift
//  GoRestAPIwithProxy
//
//  Created by vladikkk on 13/04/2020.
//  Copyright © 2020 PR. All rights reserved.
//

import UIKit

/*
 A Singleton for extracting Albums.
 */
class AlbumsData: ObservableObject {
    
    // MARK: Properties
    
    // Singleton
    static let shared = AlbumsData()
    
    // Published Albums
    @Published var albums = [Album]()
    
    // Store last 10 albums
    @Published var topAlbums = [Album(id: "5357", userID: "1717", title: "Test Album", links: Post_Links(linksSelf: Href(href: "LINK"), edit: Href(href: "LINK")))]
    var published = false
    
    private let albumRequests = AlbumsRequests.shared
    private let photoRequests = PhotosRequests.shared
    private var albumID = ""
    
    var timer: Timer?
    
    var currentPages = [180, 160]
    
    private init() {
        self.fetchAlbums()
    }
    
    // MARK: Methods
    
    // Add new album
    func addNewAlbum(withAlbumData newAlbum: New_Album, withPhotoData newPhotos: [UIImage?], withPhotoTitles photoTitles: [String]) {
        let delay = DispatchTime.now() + .seconds(8)
        
        self.albumRequests.POST_NEW_ALBUM(withData: newAlbum)
        self.albumID = String(Int(self.albumID)! + 1)
        
        PhotosData.shared.uploadAlbumPhotos(images: newPhotos)
        
        self.updateAlbums()
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: delay) {
            let photoUrls = PhotosData.shared.imgurUrls
            let thumbUrls = PhotosData.shared.thmbUrls
            
            for it in 0..<photoUrls.count {
                let newPhoto = New_Photo(albumID: self.albumID, title: photoTitles[it], url: photoUrls[it], thumb: thumbUrls[it])
                
                self.photoRequests.POST_NEW_PHOTO(withData: newPhoto)
            }
        }
    }
    
    // Fetching top '$albumsCount' albums
    private func fetchTopAlbums(albumsCount: Int) {
        var topAlbums = [Album]()
        
        if self.albums.count < albumsCount {
            for it in 0..<self.albums.count {
                topAlbums.append(self.albums[it])
            }
        } else {
            for it in 0..<albumsCount {
                topAlbums.append(self.albums[it])
            }
        }
        
        DispatchQueue.main.async {
            self.topAlbums = topAlbums
        }
    }
    
    // Updating albums with newly added
    func updateAlbums() {
        let delay = DispatchTime.now() + .seconds(2)
        
        // Check last 5 pages for new Albums
        self.albumRequests.GET_ALL_ALBUMS(fromPage: self.currentPages[0], toPage: self.currentPages[0] - 15)
        
        DispatchQueue.main.asyncAfter(deadline: delay) {
            self.albums = self.sortAlbums(albums: self.albumRequests.albums)
            self.albumID = self.albums.first!.id
            
            if self.albums.count > 10 {
                self.fetchTopAlbums(albumsCount: 10)
            } else {
                self.fetchTopAlbums(albumsCount: self.albums.count)
            }
        }
    }
    
    // Fetching all albums
    @objc
    func fetchAlbums() {
        self.startTimer()
        
        let delay = DispatchTime.now() + .seconds(4)
        self.albumRequests.GET_ALL_ALBUMS(fromPage: self.currentPages[0], toPage: self.currentPages[1])
        
        DispatchQueue.main.asyncAfter(deadline: delay) {
            self.albums = self.sortAlbums(albums: self.albumRequests.albums)
            self.albumID = self.albums.last!.id
            
            if !self.published {
                self.fetchTopAlbums(albumsCount: 10)
                self.published.toggle()
            }
        }
        
        self.currentPages[0] = self.currentPages[1] - 1
        
        if self.currentPages[1] > 20 {
            self.currentPages[1] -= 20
        } else if self.currentPages[1] == 20 {
            self.currentPages[1] = 1
        } else {
            self.currentPages = [180, 160]
            self.stopTimer()
        }
    }
    
    // Setup and Start timer
    private func startTimer() {
        if self.timer == nil {
            self.timer = Timer.scheduledTimer(timeInterval: 40, target: self, selector: #selector(self.fetchAlbums), userInfo: nil, repeats: true)
            NSLog("Timer Started.")
        }
    }
    
    // Stop timer
    private func stopTimer() {
        if self.timer != nil {
            self.timer!.invalidate()
            self.timer = nil
            NSLog("Timer Stopped.")
        }
    }
    
    private func removeEmptyAlbums(fromArray albums: [Album]) -> [Album] {
        var sortedAlbums = albums
        var count = 0
        var emptyAlbumsRemoved = 0
        
        for album in albums {
            count += 1
            if album.id.isEmpty {
                sortedAlbums.remove(at: count)
                emptyAlbumsRemoved += 1
            }
        }
        
        return sortedAlbums
    }
    
    private func sortAlbums(albums: [Album]) -> [Album] {
        let sortedAlbums = self.removeEmptyAlbums(fromArray: albums)
        var uniqueAlbums = sortedAlbums.removingDuplicates()
        
        uniqueAlbums = uniqueAlbums.sorted(by: { (album1, album2) -> Bool in
            Int(album1.id)! > Int(album2.id)!
        })
        
        return uniqueAlbums
    }
}
