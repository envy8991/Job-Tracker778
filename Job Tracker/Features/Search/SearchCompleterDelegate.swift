//
//  SearchCompleterDelegate.swift
//  Cable South Job Tracker
//
//  Created by Quinton  Thompson  on 2/7/25.
//


import SwiftUI
import MapKit

class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    static let usBiasRegion: MKCoordinateRegion? = {
        let center = CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795) // continental US
        let span = MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 60) // wide enough for lower 48
        return MKCoordinateRegion(center: center, span: span)
    }()
    
    var onUpdate: (([MKLocalSearchCompletion]) -> Void)?
    var onFail: ((Error) -> Void)?
    
    let completer: MKLocalSearchCompleter
    
    override init() {
        completer = MKLocalSearchCompleter()
        completer.resultTypes = .address
        if let region = Self.usBiasRegion { completer.region = region }
        super.init()
        completer.delegate = self
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate?(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        onFail?(error)
    }
}
