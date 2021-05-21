// Copyright 2021 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ArcGIS

class DisplayOGCAPICollectionViewController: UIViewController {
    // MARK: Instance properties
    
    /// The map view managed by the view controller.
    @IBOutlet var mapView: AGSMapView! {
        didSet {
            let map = AGSMap(basemapStyle: .arcGISTopographic)
            map.operationalLayers.add(ogcFeatureLayer)
            mapView.map = map
            // Set the viewpoint to Daraa, Syria.
            mapView.setViewpoint(AGSViewpoint(latitude: 32.62, longitude: 36.10, scale: 20_000))
        }
    }
    
    /// The last query job.
    var lastQuery: AGSCancelable?
    /// The KVO on navigating status of the map view.
    var navigatingObservation: NSKeyValueObservation?
    /// The base query parameters to populate features from the OGC API service.
    let visibleExtentQueryParameters: AGSQueryParameters = {
        let queryParameters = AGSQueryParameters()
        queryParameters.spatialRelationship = .intersects
        // Set a limit of 5000 on the number of returned features per request,
        // because the default on some services could be as low as 10.
        queryParameters.maxFeatures = 5_000
        return queryParameters
    }()
    
    /// A feature layer to visualize the OGC API features.
    let ogcFeatureLayer: AGSFeatureLayer = {
        // Note: the collection ID can be accessed later via
        // `featureCollectionInfo.collectionID` property of the feature table.
        let table = AGSOGCFeatureCollectionTable(
            url: URL(string: "https://demo.ldproxy.net/daraa")!,
            collectionID: "TransportationGroundCrv"
        )
        // Set the feature request mode to manual (only manual is currently
        // supported). In this mode, you must manually populate the table -
        // panning and zooming won't request features automatically.
        table.featureRequestMode = .manualCache
        
        let featureLayer = AGSFeatureLayer(featureTable: table)
        let lineSymbol = AGSSimpleLineSymbol(style: .solid, color: .blue, width: 3)
        featureLayer.renderer = AGSSimpleRenderer(symbol: lineSymbol)
        return featureLayer
    }()
    
    // MARK: Method
    
    func populateFeaturesFromQuery() {
        // Cancel if there is an existing query request.
        lastQuery?.cancel()
        
        // Set the query's geometry to the current visible extent.
        visibleExtentQueryParameters.geometry = mapView.visibleArea?.extent
        
        // Populate the table with the query. Setting `outFields` to `nil`
        // requests all fields.
        let table = ogcFeatureLayer.featureTable as! AGSOGCFeatureCollectionTable
        lastQuery = table.populateFromService(
            with: visibleExtentQueryParameters,
            clearCache: false,
            outfields: nil
        ) { [weak self] _, error in
            if let error = error,
               // Do not display error if user simply cancelled the request.
               (error as NSError).code != NSUserCancelledError {
                self?.presentAlert(error: error)
            }
        }
    }
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Add the source code button item to the right of navigation bar.
        (navigationItem.rightBarButtonItem as? SourceCodeBarButtonItem)?.filenames = ["DisplayOGCAPICollectionViewController"]
        // Query for features with the initial extent.
        populateFeaturesFromQuery()
        // Query for features whenever map's viewpoint change has finished.
        navigatingObservation = mapView.observe(\.isNavigating, options: .new) { _, change in
            if change.newValue == false {
                DispatchQueue.main.async {
                    self.populateFeaturesFromQuery()
                }
            }
        }
    }
}
