// Copyright 2016 Esri.
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

class EditFeaturesOnlineViewController: UIViewController, AGSGeoViewTouchDelegate, AGSPopupsViewControllerDelegate, FeatureTemplatePickerDelegate {
    @IBOutlet private weak var mapView: AGSMapView!
    @IBOutlet private weak var sketchToolbar: UIToolbar!
    @IBOutlet private weak var doneBBI: UIBarButtonItem!
    
    private var map: AGSMap!
    private var sketchEditor: AGSSketchEditor!
    private var featureLayer: AGSFeatureLayer!
    private var popupsViewController: AGSPopupsViewController!
    
    private var lastQuery: AGSCancelable!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // add the source code button item to the right of navigation bar
        (self.navigationItem.rightBarButtonItem as! SourceCodeBarButtonItem).filenames = ["EditFeaturesOnlineViewController", "FeatureTemplatePickerViewController"]
        
        self.map = AGSMap(basemapStyle: .arcGISTopographic)
        self.mapView.map = self.map
        self.mapView.setViewpoint(AGSViewpoint(center: AGSPoint(x: -9184518.55, y: 3240636.90, spatialReference: .webMercator()), scale: 7e5))
        self.mapView.touchDelegate = self
        
        let featureTable = AGSServiceFeatureTable(url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0")!)
        let featureLayer = AGSFeatureLayer(featureTable: featureTable)
        self.map.operationalLayers.add(featureLayer)
        
        // initialize sketch editor and assign to map view
        self.sketchEditor = AGSSketchEditor()
        self.mapView.sketchEditor = self.sketchEditor
        
        // hide the sketchToolbar initially
        self.sketchToolbar.isHidden = true
        
        // store the feature layer for later use
        self.featureLayer = featureLayer
    }
    
    private func dismissFeatureTemplatePickerViewController() {
        self.dismiss(animated: true)
    }
    
    func applyEdits() {
        // show progress hud
        UIApplication.shared.showProgressHUD(message: "Applying edits")
        
        (featureLayer.featureTable as! AGSServiceFeatureTable).applyEdits { [weak self] (_, error) in
            UIApplication.shared.hideProgressHUD()
            
            if let error = error {
                self?.presentAlert(message: "Error while applying edits: \(error.localizedDescription)")
            } else {
                self?.presentAlert(message: "Edits applied successfully!")
            }
        }
    }
    
    // MARK: - AGSGeoViewTouchDelegate
    
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        if let lastQuery = self.lastQuery {
            lastQuery.cancel()
        }
        
        self.lastQuery = self.mapView.identifyLayer(self.featureLayer, screenPoint: screenPoint, tolerance: 12, returnPopupsOnly: false, maximumResults: 10) { [weak self] (identifyLayerResult: AGSIdentifyLayerResult) in
            guard let self = self else { return }
            if let error = identifyLayerResult.error {
                print(error)
            } else if !identifyLayerResult.geoElements.isEmpty {
                let popups = identifyLayerResult.geoElements.map(AGSPopup.init(geoElement:))
                self.popupsViewController = AGSPopupsViewController(popups: popups, containerStyle: .navigationBar)
                self.popupsViewController.modalPresentationStyle = .formSheet
                self.popupsViewController.isModalInPresentation = true
                self.present(self.popupsViewController, animated: true)
                self.popupsViewController.delegate = self
            }
        }
    }
    
    // MARK: - AGSPopupsViewControllerDelegate methods
    
    func popupsViewController(_ popupsViewController: AGSPopupsViewController, sketchEditorFor popup: AGSPopup) -> AGSSketchEditor? {
        if let geometry = popup.geoElement.geometry {
            // start sketch editing
            self.mapView.sketchEditor?.start(with: geometry)
            
            // zoom to the existing feature's geometry
            self.mapView.setViewpointGeometry(geometry.extent, padding: 10, completion: nil)
        }
        
        return self.sketchEditor
    }
    
    func popupsViewController(_ popupsViewController: AGSPopupsViewController, readyToEditGeometryWith sketchEditor: AGSSketchEditor?, for popup: AGSPopup) {
        // Dismiss the popup view controller
        self.dismiss(animated: true)
        
        // Prepare the current view controller for sketch mode
        self.mapView.callout.isHidden = true
        
        // hide the back button
        self.navigationItem.hidesBackButton = true
        
        // disable the code button
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        
        // unhide the sketchToolbar
        self.sketchToolbar.isHidden = false
        
        // disable the done button until any geometry changes
        self.doneBBI.isEnabled = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(EditFeaturesOnlineViewController.sketchChanged(_:)), name: .AGSSketchEditorGeometryDidChange, object: nil)
    }
    
    func popupsViewController(_ popupsViewController: AGSPopupsViewController, didCancelEditingFor popup: AGSPopup) {
        // stop sketch editor
        self.disableSketchEditor()
    }
    
    func popupsViewController(_ popupsViewController: AGSPopupsViewController, didFinishEditingFor popup: AGSPopup) {
        // stop sketch editor
        self.disableSketchEditor()
        
        let feature = popup.geoElement as! AGSFeature
        
        // simplify the geometry, this will take care of self intersecting polygons and
        feature.geometry = AGSGeometryEngine.simplifyGeometry(feature.geometry!)
        
        // normalize the geometry, this will take care of geometries that extend beyone the dateline
        // (ifwraparound was enabled on the map)
        feature.geometry = AGSGeometryEngine.normalizeCentralMeridian(of: feature.geometry!)
        
        // apply edits
        self.applyEdits()
    }
    
    func popupsViewControllerDidFinishViewingPopups(_ popupsViewController: AGSPopupsViewController) {
        // dismiss the popups view controller
        self.dismiss(animated: true)
        
        self.popupsViewController = nil
    }
    
    @objc
    func sketchChanged(_ notification: Notification) {
        // Check if the sketch geometry is valid to decide whether to enable
        // the sketchCompleteButton
        if let geometry = self.mapView.sketchEditor?.geometry, !geometry.isEmpty {
            self.doneBBI.isEnabled = true
        }
    }
    
    @IBAction func sketchDoneAction() {
        // enable or unhide navigation bar button
        self.navigationItem.hidesBackButton = false
        self.navigationItem.rightBarButtonItem?.isEnabled = true
        
        // present the popups view controller again
        self.present(self.popupsViewController, animated: true)
        
        // remove self as observer for notifications
        NotificationCenter.default.removeObserver(self, name: .AGSSketchEditorGeometryDidChange, object: nil)
    }
    
    private func disableSketchEditor() {
        // stop sketch editor
        self.mapView.sketchEditor?.stop()
        
        // hide sketch toolbar
        self.sketchToolbar.isHidden = true
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "FeatureTemplateSegue",
           let navigationController = segue.destination as? UINavigationController,
           let featureTemplatePickerViewController = navigationController.topViewController as? FeatureTemplatePickerViewController {
            featureTemplatePickerViewController.addTemplatesFromLayer(featureLayer)
            featureTemplatePickerViewController.delegate = self
        }
    }
    
    // MARK: - FeatureTemplatePickerDelegate
    
    func featureTemplatePickerViewController(_ controller: FeatureTemplatePickerViewController, didSelectFeatureTemplate template: AGSFeatureTemplate, forFeatureLayer featureLayer: AGSFeatureLayer) {
        let featureTable = self.featureLayer.featureTable as! AGSArcGISFeatureTable
        // create a new feature based on the template
        let newFeature = featureTable.createFeature(with: template)!
        
        // set the geometry as the center of the screen
        if let visibleArea = self.mapView.visibleArea {
            newFeature.geometry = visibleArea.extent.center
        } else {
            newFeature.geometry = AGSPoint(x: 0, y: 0, spatialReference: self.map.spatialReference)
        }
        
        // initialize a popup definition using the feature layer
        let popupDefinition = AGSPopupDefinition(popupSource: self.featureLayer)
        // create a popup
        let popup = AGSPopup(geoElement: newFeature, popupDefinition: popupDefinition)
        
        // initialize popups view controller
        self.popupsViewController = AGSPopupsViewController(popups: [popup], containerStyle: .navigationBar)
        self.popupsViewController.delegate = self
        
        // Only for iPad, set presentation style to Form sheet
        // We don't want it to cover the entire screen
        self.popupsViewController.modalPresentationStyle = .formSheet
        self.popupsViewController.isModalInPresentation = true
        
        // First, dismiss the Feature Template Picker
        self.dismiss(animated: false)
        
        // Next, Present the popup view controller
        self.present(self.popupsViewController, animated: true) { [weak self] in
            self?.popupsViewController.startEditingCurrentPopup()
        }
    }
    
    func featureTemplatePickerViewControllerWantsToDismiss(_ controller: FeatureTemplatePickerViewController) {
        self.dismissFeatureTemplatePickerViewController()
    }
}
