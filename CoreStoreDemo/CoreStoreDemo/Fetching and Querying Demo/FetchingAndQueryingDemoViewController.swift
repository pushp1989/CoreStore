//
//  FetchingAndQueryingDemoViewController.swift
//  CoreStoreDemo
//
//  Created by John Rommel Estropia on 2015/06/12.
//  Copyright © 2015 John Rommel Estropia. All rights reserved.
//

import UIKit
import CoreStore


private struct Static {
    
    static let timeZonesStack: DataStack = {
        
        let dataStack = DataStack()
        try! dataStack.addStorageAndWait(
            SQLiteStore(
                fileName: "TimeZoneDemo.sqlite",
                configuration: "FetchingAndQueryingDemo",
                localStorageOptions: .recreateStoreOnModelMismatch
            )
        )
    
        _ = dataStack.beginSynchronous { (transaction) -> Void in
            
            transaction.deleteAll(From<TimeZone>())
            
            for name in Foundation.TimeZone.knownTimeZoneNames {
                
                let rawTimeZone = Foundation.TimeZone(name: name)!
                let cachedTimeZone = transaction.create(Into<TimeZone>())
                
                cachedTimeZone.name = rawTimeZone.name
                cachedTimeZone.abbreviation = rawTimeZone.abbreviation ?? ""
                cachedTimeZone.secondsFromGMT = Int32(rawTimeZone.secondsFromGMT)
                cachedTimeZone.hasDaylightSavingTime = rawTimeZone.isDaylightSavingTime
                cachedTimeZone.daylightSavingTimeOffset = rawTimeZone.daylightSavingTimeOffset
            }
            
            _ = transaction.commitAndWait()
        }
        
        return dataStack
    }()
}


// MARK: - FetchingAndQueryingDemoViewController

class FetchingAndQueryingDemoViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: UIViewController
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        if self.didAppearOnce {
            
            return
        }
        
        self.didAppearOnce = true
        
        let alert = UIAlertController(
            title: "Fetch and Query Demo",
            message: "This demo shows how to execute fetches and queries.\n\nEach menu item executes and displays a preconfigured fetch/query.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?) {
        
        super.prepare(for: segue, sender: sender)
        
        if let indexPath = sender as? IndexPath {
            
            switch segue.destinationViewController {
                
            case let controller as FetchingResultsViewController:
                let item = self.fetchingItems[indexPath.row]
                controller.set(timeZones: item.fetch(), title: item.title)
                
            case let controller as QueryingResultsViewController:
                let item = self.queryingItems[indexPath.row]
                controller.set(value: item.query(), title: item.title)
                
            default:
                break
            }
        }
    }
    
    
    // MARK: UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch self.segmentedControl?.selectedSegmentIndex {
            
        case Section.fetching.rawValue?:
            return self.fetchingItems.count
            
        case Section.querying.rawValue?:
            return self.queryingItems.count
            
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell")!
        
        switch self.segmentedControl?.selectedSegmentIndex {
            
        case Section.fetching.rawValue?:
            cell.textLabel?.text = self.fetchingItems[indexPath.row].title
            
        case Section.querying.rawValue?:
            cell.textLabel?.text = self.queryingItems[indexPath.row].title
            
        default:
            cell.textLabel?.text = nil
        }
        
        return cell
    }
    
    
    // MARK: UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch self.segmentedControl?.selectedSegmentIndex {
            
        case Section.fetching.rawValue?:
            self.performSegue(withIdentifier: "FetchingResultsViewController", sender: indexPath)
            
        case Section.querying.rawValue?:
            self.performSegue(withIdentifier: "QueryingResultsViewController", sender: indexPath)
            
        default:
            break
        }
    }
    
    
    // MARK: Private
    
    private enum Section: Int {
        
        case fetching
        case querying
    }
    
    private let fetchingItems = [
        (
            title: "All Time Zones",
            fetch: { () -> [TimeZone] in
                
                return Static.timeZonesStack.fetchAll(
                    From<TimeZone>(),
                    OrderBy(.ascending("name"))
                )!
            }
        ),
        (
            title: "Time Zones in Asia",
            fetch: { () -> [TimeZone] in
                
                return Static.timeZonesStack.fetchAll(
                    From<TimeZone>(),
                    Where("%K BEGINSWITH[c] %@", "name", "Asia"),
                    OrderBy(.ascending("secondsFromGMT"))
                )!
            }
        ),
        (
            title: "Time Zones in America and Europe",
            fetch: { () -> [TimeZone] in
                
                return Static.timeZonesStack.fetchAll(
                    From<TimeZone>(),
                    Where("%K BEGINSWITH[c] %@", "name", "America")
                        || Where("%K BEGINSWITH[c] %@", "name", "Europe"),
                    OrderBy(.ascending("secondsFromGMT"))
                )!
            }
        ),
        (
            title: "All Time Zones Except America",
            fetch: { () -> [TimeZone] in
                
                return Static.timeZonesStack.fetchAll(
                    From<TimeZone>(),
                    !Where("%K BEGINSWITH[c] %@", "name", "America"),
                    OrderBy(.ascending("secondsFromGMT"))
                    )!
            }
        ),
        (
            title: "Time Zones with Summer Time",
            fetch: { () -> [TimeZone] in
                
                return Static.timeZonesStack.fetchAll(
                    From<TimeZone>(),
                    Where("hasDaylightSavingTime", isEqualTo: true),
                    OrderBy(.ascending("name"))
                )!
            }
        )
    ]
    
    private let queryingItems = [
        (
            title: "Number of Time Zones",
            query: { () -> AnyObject in
                
                return Static.timeZonesStack.queryValue(
                    From<TimeZone>(),
                    Select<NSNumber>(.count("name"))
                )!
            }
        ),
        (
            title: "Abbreviation For Tokyo's Time Zone",
            query: { () -> AnyObject in
                
                return Static.timeZonesStack.queryValue(
                    From<TimeZone>(),
                    Select<String>("abbreviation"),
                    Where("%K ENDSWITH[c] %@", "name", "Tokyo")
                )!
            }
        ),
        (
            title: "All Abbreviations",
            query: { () -> AnyObject in
                
                return Static.timeZonesStack.queryAttributes(
                    From<TimeZone>(),
                    Select<NSDictionary>("name", "abbreviation"),
                    OrderBy(.ascending("name"))
                )!
            }
        ),
        (
            title: "Number of Countries per Time Zone",
            query: { () -> AnyObject in
                
                return Static.timeZonesStack.queryAttributes(
                    From<TimeZone>(),
                    Select<NSDictionary>(.count("abbreviation"), "abbreviation"),
                    GroupBy("abbreviation"),
                    OrderBy(.ascending("secondsFromGMT"), .ascending("name"))
                )!
            }
        ),
        (
            title: "Number of Countries with Summer Time",
            query: { () -> AnyObject in
                
                return Static.timeZonesStack.queryAttributes(
                    From<TimeZone>(),
                    Select<NSDictionary>(
                        .count("hasDaylightSavingTime", As: "numberOfCountries"),
                        "hasDaylightSavingTime"
                    ),
                    GroupBy("hasDaylightSavingTime"),
                    OrderBy(.descending("hasDaylightSavingTime"))
                )!
            }
        )
    ]
    
    var didAppearOnce = false
    
    @IBOutlet dynamic weak var segmentedControl: UISegmentedControl?
    @IBOutlet dynamic weak var tableView: UITableView?
    
    @IBAction dynamic func segmentedControlValueChanged(_ sender: AnyObject?) {
        
        self.tableView?.reloadData()
    }
}
