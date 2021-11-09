
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

class FilterByTimeExtentViewController: UIViewController {
    
    @IBOutlet var mapView: AGSMapView!{
        didSet {
            mapView.map = AGSMap(basemapStyle: .arcGISTopographic)
            let url = URL(string: "https://services5.arcgis.com/N82JbI5EYtAkuUKU/ArcGIS/rest/services/Hurricane_time_enabled_layer_2005_1_day/FeatureServer/0")
            let featureTable = AGSServiceFeatureTable(url: url!)
            let featureLayer = AGSFeatureLayer(featureTable: featureTable)
            mapView.map?.operationalLayers.add(featureLayer)
        }
    }

    // MARK: UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        // Add the source code button item to the right of navigation bar.
        (navigationItem.rightBarButtonItem as? SourceCodeBarButtonItem)?.filenames = ["FilterByTimeExtentViewController"]
    }
}
