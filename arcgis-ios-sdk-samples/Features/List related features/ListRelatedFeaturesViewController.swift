// Copyright 2017 Esri.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ArcGIS

class ListRelatedFeaturesViewController: UIViewController, AGSGeoViewTouchDelegate {
    @IBOutlet var mapView: AGSMapView!
    
    private var parksFeatureLayer: AGSFeatureLayer!
    private var parksFeatureTable: AGSServiceFeatureTable!
    private var selectedPark: AGSArcGISFeature!
    private var screenPoint: CGPoint!
    
    private var results = [AGSRelatedFeatureQueryResult]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // add the source code button item to the right of navigation bar
        (self.navigationItem.rightBarButtonItem as! SourceCodeBarButtonItem).filenames = ["ListRelatedFeaturesViewController", "RelatedFeaturesListViewController"]
        
        // Initialize map with a topographic basemap style.
        let map = AGSMap(basemapStyle: .arcGISTopographic)
        
        // add self as the touch delegate for map view
        // we will need to be notified when the user taps with the map
        self.mapView.touchDelegate = self
        
        // create feature table for the parks layer, the origin layer in the relationship
        self.parksFeatureTable = AGSServiceFeatureTable(url: URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/AlaskaNationalParksPreservesSpecies_List/FeatureServer/1")!)
        
        // feature layer for parks
        let parksFeatureLayer = AGSFeatureLayer(featureTable: self.parksFeatureTable)
        
        // add parks feature layer to the map
        map.operationalLayers.add(parksFeatureLayer)
        
        // Feature table for related Preserves layer
        let preservesFeatureTable = AGSServiceFeatureTable(url: URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/AlaskaNationalParksPreservesSpecies_List/FeatureServer/0")!)
        
        // Feature table for related Species layer
        let speciesFeatureTable = AGSServiceFeatureTable(url: URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/rest/services/AlaskaNationalParksPreservesSpecies_List/FeatureServer/2")!)
        
        // add these to the tables on the map
        // to query related features in a layer, the layer must either be added as a feature
        // layer in operational layers or as a feature table in tables on map
        map.tables.addObjects(from: [preservesFeatureTable, speciesFeatureTable])
        
        // assign map to the map view
        mapView.map = map
        let point = AGSPoint(x: -16507762.575543, y: 9058828.127243, spatialReference: .webMercator())
        mapView.setViewpoint(AGSViewpoint(center: point, scale: 36764077))
        
        // set selection color
        mapView.selectionProperties.color = .yellow
        
        // store the feature layer for later use
        self.parksFeatureLayer = parksFeatureLayer
    }
    
    // MARK: - AGSGeoViewTouchDelegate
    
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        // unselect previously selected park
        if let previousSelection = self.selectedPark {
            self.parksFeatureLayer.unselectFeature(previousSelection)
        }
        
        // show progress hud
        UIApplication.shared.showProgressHUD(message: "Identifying feature")
        
        // identify features at the tapped location
        self.mapView.identifyLayer(self.parksFeatureLayer, screenPoint: screenPoint, tolerance: 12, returnPopupsOnly: false) { [weak self] (result: AGSIdentifyLayerResult) in
            // dismiss progress hud
            UIApplication.shared.hideProgressHUD()
            
            if let error = result.error {
                // dismiss progress hud
                self?.presentAlert(error: error)
            }
            // Check if a feature is identified
            else if let feature = result.geoElements.first as? AGSArcGISFeature {
                // store as selected park to use for querying
                self?.selectedPark = feature
                
                // select feature on layer
                self?.parksFeatureLayer.select(feature)
                
                // store the screen point for the tapped location to show popover at that location
                self?.screenPoint = screenPoint
                
                // query for related features
                self?.queryRelatedFeatures()
            }
        }
    }

    // query for related features given the origin feature
    private func queryRelatedFeatures() {
        // show progress hud
        UIApplication.shared.showProgressHUD(message: "Querying related features")
        
        // query for related features
        self.parksFeatureTable.queryRelatedFeatures(for: self.selectedPark) { [weak self] (results: [AGSRelatedFeatureQueryResult]?, error: Error?) in
            // dismiss progress hud
            UIApplication.shared.hideProgressHUD()
            
            guard let self = self else { return }
            
            if let error = error {
                // display error
                self.presentAlert(error: error)
            } else if let results = results {
                // Show the related features found in popover
                if !results.isEmpty {
                    self.results = results
                    self.showRelatedFeatures()
                } else {  // else notify user
                    self.presentAlert(message: "No related features found")
                }
            }
        }
    }
    
    // show related features in a table view as popover
    private func showRelatedFeatures() {
        // perform popover segue
        self.performSegue(withIdentifier: "RelatedFeaturesSegue", sender: self)
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "RelatedFeaturesSegue",
            let navController = segue.destination as? UINavigationController,
            let controller = navController.viewControllers.first as? RelatedFeaturesListViewController {
            // set results from related features query
            controller.results = results
        }
     }
    
    // to hide popover controller on rotation
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.dismiss(animated: true)
    }
}
