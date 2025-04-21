//
//  HomeViewController.swift
//  SongRepoApp
//
//  Created by Phil Wright on 4/20/25.
//


import UIKit
import MusicKit

class HomeViewController: UIViewController {

    let songManager = SongRepositoryManager.shared

    // Remove the hardcoded search term
    // let searchTerm = "Taylor Swift"

    private var songs: [Song] = [] {
        didSet {
            updateUI()
        }
    }

    // MARK: - Properties

    // Add UISearchController
    private let searchController = UISearchController(searchResultsController: nil)

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(SongTableViewCell.self, forCellReuseIdentifier: "SongTableViewCell")
        table.backgroundColor = .systemGroupedBackground
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 80
        return table
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.text = "Enter a search term to find songs." // Updated initial text
        label.textColor = .secondaryLabel
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.numberOfLines = 0
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.color = .systemBlue
        return indicator
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupSearchController() // Call the search controller setup

        // Request authorization when the view loads
        requestMusicAuthorization()
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground // Match table view background
        title = "Song Search" // Add a title
        navigationController?.navigationBar.prefersLargeTitles = true // Optional: Use large titles

        view.addSubview(tableView)
        view.addSubview(statusLabel)
        view.addSubview(activityIndicator)

        tableView.delegate = self
        tableView.dataSource = self

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -16)
        ])

        updateUI() // Initial UI state
    }

    // Function to set up the search controller
    private func setupSearchController() {
        searchController.searchResultsUpdater = self // Delegate for text changes
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Artists, Songs, Albums"
        navigationItem.searchController = searchController // Add search bar to navigation bar
        definesPresentationContext = true
        searchController.searchBar.delegate = self // Delegate for search button tap
    }


    private func updateUI() {
        // Only show activity indicator when actively searching
        if activityIndicator.isAnimating {
            statusLabel.isHidden = false
            tableView.isHidden = true
        }
        
        if songs.isEmpty {
            statusLabel.text = navigationItem.searchController?.searchBar.text?.isEmpty ?? true ? "Enter a search term to find songs." : "No songs found. Try another search."
            statusLabel.isHidden = false
            tableView.isHidden = true
            activityIndicator.stopAnimating() // Ensure it stops if no songs found
        } else {
            statusLabel.isHidden = true
            activityIndicator.stopAnimating()
            tableView.isHidden = false
            tableView.reloadData()
        }
    }


    // Removed restart() function as it wasn't being used functionally

    private func requestMusicAuthorization() {
        Task {
            let authStatus = await MusicAuthorization.request()
            if authStatus == .authorized {
                // Don't automatically search on load. User will initiate via search bar.
                print("Music authorization successful.")
                // You might want to update the statusLabel here if needed
                 await MainActor.run {
                    // Keep the initial prompt or clear it
                     if songs.isEmpty && (searchController.searchBar.text ?? "").isEmpty {
                         statusLabel.text = "Enter a search term to find songs."
                         statusLabel.isHidden = false
                         activityIndicator.stopAnimating() // Stop indicator if shown initially
                     }
                 }
            } else {
                print("Music authorization failed: \(authStatus)")
                await MainActor.run {
                    statusLabel.text = "Music library access was not authorized.\nPlease check your privacy settings."
                    statusLabel.isHidden = false // Make sure label is visible
                    activityIndicator.stopAnimating()
                    searchController.searchBar.isHidden = true // Hide search bar if not authorized
                }
            }
        }
    }

    // Modify searchAndLoadSongs to take a search term parameter
    private func searchAndLoadSongs(term: String) async {
         // Ensure the term is not empty before searching
         guard !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
             print("Search term is empty.")
             await MainActor.run {
                 self.songs = [] // Clear previous results
                 statusLabel.text = "Enter a search term to find songs."
                 updateUI() // Update UI to show the prompt
             }
             return
         }

        await MainActor.run {
            statusLabel.text = "Searching for '\(term)'..."
            statusLabel.isHidden = false
            activityIndicator.startAnimating()
            tableView.isHidden = true // Hide table while searching
        }

        do {
            let fetchedSongs = try await songManager.searchSongs(term: term)
            await MainActor.run {
                print("Found \(fetchedSongs.count) songs matching '\(term)'")
                self.songs = fetchedSongs
                updateUI() // is called automatically by songs' didSet
            }
        } catch {
            print("Error searching for songs: \(error)")
            await MainActor.run {
                self.songs = [] // Clear songs on error
                statusLabel.text = "Error loading songs.\nPlease try again later."
                activityIndicator.stopAnimating() // Stop indicator on error
                updateUI() // Ensure UI reflects the error state
            }
        }
    }


    // Unused functions removed for brevity (loadSongByID, markSongAsPlayed, addSongToFavorites)
    // You can add them back if needed for other functionality.

}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension HomeViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SongTableViewCell", for: indexPath) as? SongTableViewCell else {
            fatalError("Could not dequeue SongTableViewCell")
        }
        let song = songs[indexPath.row]
        cell.configure(with: song)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedSong = songs[indexPath.row]
        print("Selected song: \(selectedSong.title)")

        // Assuming PlaybackViewController exists and is set up
        let playbackVC = PlaybackViewController()
        playbackVC.song = selectedSong
        // Consider presenting modally or pushing onto navigation stack
        playbackVC.modalPresentationStyle = .popover // Or .automatic, etc.
        present(playbackVC, animated: true, completion: nil)

        tableView.deselectRow(at: indexPath, animated: true) // Deselect after presenting
    }
}

// MARK: - UISearchResultsUpdating and UISearchBarDelegate
extension HomeViewController: UISearchResultsUpdating, UISearchBarDelegate {

    // Called when the search text changes (useful for live search suggestions, but not triggering the main search here)
    func updateSearchResults(for searchController: UISearchController) {
        // You could implement live search suggestions here if desired.
        // For now, we'll trigger the search only on button press.
        let searchText = searchController.searchBar.text ?? ""
        print("Search text changed: \(searchText)")
        // Optionally clear results or show prompt if text is cleared
         if searchText.isEmpty && !activityIndicator.isAnimating {
              Task { // Use Task for async context if needed inside sync function
                  await MainActor.run {
                     self.songs = [] // Clear results when search text is empty
                     statusLabel.text = "Enter a search term to find songs."
                     updateUI() // Update UI immediately
                  }
              }
         }
    }

    // Called when the user taps the search button on the keyboard
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchTerm = searchBar.text, !searchTerm.isEmpty else {
            print("Search button clicked with empty text.")
            // Optionally clear results or show prompt
             Task {
                 await MainActor.run {
                     self.songs = []
                     statusLabel.text = "Enter a search term to find songs."
                     updateUI()
                 }
             }
            return
        }
        print("Search button clicked with term: \(searchTerm)")
        // Dismiss keyboard
        searchBar.resignFirstResponder()
        // Perform the search asynchronously
        Task {
            await searchAndLoadSongs(term: searchTerm)
        }
    }

     // Optional: Called when the cancel button is clicked
     func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
         print("Cancel button clicked.")
         // Clear the search results and reset UI
         Task {
             await MainActor.run {
                 self.songs = []
                 statusLabel.text = "Enter a search term to find songs."
                 updateUI()
             }
         }
     }
}

// MARK: - Supporting Classes and Extensions
//class SongTableViewCell: UITableViewCell {
//    func configure(with song: Song) { /* Configure cell appearance */
//        textLabel?.text = song.title
//        detailTextLabel?.text = song.artistName
//    }
//}

//class PlaybackViewController: UIViewController { var song: Song? }
//class SongRepositoryManager {
//    static let shared = SongRepositoryManager()
//    func searchSongs(term: String) async throws -> [Song] { /* Actual search logic */ return [] }
//    func addSong(_ song: Song) { /* Add logic */ }
//    func addToRecentlyPlayed(_ song: Song) { /* Add logic */ }
//    func addToFavorites(_ song: Song) { /* Add logic */ }
//}
//
//// MusicKit requires struct definitions or typealiases if not using real framework
//struct Song: Identifiable { // Make sure Song conforms to Identifiable
//    var id: MusicItemID
//    var title: String?
//    var artistName: String?
//    // Add other properties as needed from MusicKit.Song
//}
//struct MusicItemID: Hashable { let rawValue: String } // Basic identifiable ID

// Make sure MusicKit types used are defined if you're not importing the actual framework
// typealias MusicItemID = String // Or use a struct as above
// typealias MusicAuthorization = MusicKit.MusicAuthorization // Assuming MusicKit import
// typealias MusicCatalogResourceRequest = MusicKit.MusicCatalogResourceRequest
