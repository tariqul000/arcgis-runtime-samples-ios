// Copyright 2021 Esri
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

class AddContingentValuesViewController: UITableViewController {
    @IBOutlet var statusCell: UITableViewCell!
    @IBOutlet var protectionCell: UITableViewCell!
    @IBOutlet var bufferSizeCell: UITableViewCell!
    @IBOutlet var doneBarButtonItem: UIBarButtonItem!
    @IBOutlet var bufferSizePickerView: UIPickerView!
    
    // MARK: Actions
    
    @IBAction func cancelBarButtonItemTapped(_ sender: UIBarButtonItem) {
        graphicsOverlay?.graphics.removeLastObject()
        dismiss(animated: true)
    }
    
    @IBAction func doneBarButtonItemTapped(_ sender: Any) {
        
        dismiss(animated: true)
    }
    
    // MARK: Properties
    
    var featureTable: AGSArcGISFeatureTable?
    var contingentValuesDefinition: AGSContingentValuesDefinition?
    var feature: AGSArcGISFeature?
    var bufferSizes: [Int]?
    var graphicsOverlay: AGSGraphicsOverlay?
    /// Indicates whether the reference scale picker is currently hidden.
    var bufferSizePickerHidden = true
    
    var selectedStatus: AGSCodedValue? {
        didSet {
            if let codedValueName = selectedStatus?.name {
                editRightDetail(cell: statusCell, rightDetailText: codedValueName)
                resetCellStates()
            }
        }
    }
    
    var selectedProtection: AGSContingentCodedValue? {
        didSet {
            if let codedValueName = selectedProtection?.codedValue.name {
                editRightDetail(cell: protectionCell, rightDetailText: codedValueName)
            } else {
                editRightDetail(cell: protectionCell, rightDetailText: "")
            }
            resetCellStates()
        }
    }
    
    var selectedBufferSize: Int? {
        didSet {
            feature?.attributes["BufferSize"] = self.selectedBufferSize
            if let selectedBufferSize = selectedBufferSize {
                let bufferSize = String(selectedBufferSize)
                editRightDetail(cell: bufferSizeCell, rightDetailText: bufferSize)
                validateContingency()
            } else {
                editRightDetail(cell: bufferSizeCell, rightDetailText: " ")
                bufferSizePickerHidden = false
                toggleBufferSizePickerVisibility()
            }
        }
    }
    
    // MARK: Functions
    
    func showStatusOptions() {
        let previouslySelectedStatus = selectedStatus
        guard let featureTable = featureTable else { return }
        let statusField = featureTable.field(forName: "Status")
        let codedValueDomain = statusField?.domain as! AGSCodedValueDomain
        let status = codedValueDomain.codedValues
        let selectedIndex = status.firstIndex { $0.name == self.selectedStatus?.name } ?? nil
        let optionsViewController = OptionsTableViewController(labels: status.map { $0.name }, selectedIndex: selectedIndex) { newIndex in
            self.selectedStatus = status[newIndex]
            if self.selectedStatus != previouslySelectedStatus, self.selectedProtection != nil {
                self.selectedProtection = nil
                self.selectedBufferSize = nil
            }
            self.navigationController?.popViewController(animated: true)
        }
        optionsViewController.title = "Status"
        self.show(optionsViewController, sender: self)
    }
    
    func showProtectionOptions() {
        let previouslySelectedProtection = selectedProtection
        featureTable?.load { [weak self] error in
            guard let self = self else { return }
            self.contingentValuesDefinition = self.featureTable?.contingentValuesDefinition
            self.contingentValuesDefinition?.load { error in
                if let feature = self.featureTable?.createFeature() as? AGSArcGISFeature {
                    feature.attributes["Status"] = self.selectedStatus?.code
                    self.feature = feature
                    let contingentValuesResult = self.featureTable?.contingentValues(with: feature, field: "Protection")
                    guard let protectionGroupContingentValues = contingentValuesResult?.contingentValuesByFieldGroup["ProtectionFieldGroup"] as? [AGSContingentCodedValue] else { return }
                    let selectedIndex = protectionGroupContingentValues.firstIndex { $0.codedValue.name == self.selectedProtection?.codedValue.name} ?? nil
                    let optionsViewController = OptionsTableViewController(labels: protectionGroupContingentValues.map { $0.codedValue.name }, selectedIndex: selectedIndex) { newIndex in
                        self.selectedProtection = protectionGroupContingentValues[newIndex]
                        if self.selectedProtection != previouslySelectedProtection, self.selectedBufferSize != nil {
                            self.selectedBufferSize = nil
                        }
                        feature.attributes["Protection"] = self.selectedProtection?.codedValue.code
                        self.navigationController?.popViewController(animated: true)
                    }
                    optionsViewController.title = "Protection"
                    self.show(optionsViewController, sender: self)
                }
            }
        }
    }
    
    func showBufferSizeOptions() {
        guard let feature = feature else { return }
        let contingentValueResult = featureTable?.contingentValues(with: feature, field: "BufferSize")
        guard let bufferSizeGroupContingentValues = contingentValueResult?.contingentValuesByFieldGroup["BufferSizeFieldGroup"] as? [AGSContingentRangeValue] else { return }
        let minValue = bufferSizeGroupContingentValues[0].minValue as! Int
        let maxValue = bufferSizeGroupContingentValues[0].maxValue as! Int
        bufferSizes = Array(minValue...maxValue)
        bufferSizePickerView.reloadAllComponents()
    }
    
    func validateContingency() {
        guard let featureTable = featureTable, let feature = feature else { return }
        let contingencyViolations = featureTable.validateContingencyConstraints(with: feature)
        if contingencyViolations.isEmpty {
            doneBarButtonItem.isEnabled = true
        } else {
//            let errorMessage = "Invalid contingent values"
//            presentAlert(error: errorMessage as! Error)
            presentAlert(title: "", message: "Invalid contingent values")
        }
    }
    
    // MARK: UI Functions
    
    func editRightDetail(cell: UITableViewCell, rightDetailText: String?) {
        cell.detailTextLabel?.text = rightDetailText
    }
    
    func resetCellStates() {
        if selectedStatus == nil {
            protectionCell.textLabel?.isEnabled = false
            protectionCell.isUserInteractionEnabled = false
        } else {
            protectionCell.textLabel?.isEnabled = true
            protectionCell.isUserInteractionEnabled = true
        }
        if selectedProtection == nil {
            bufferSizeCell.textLabel?.isEnabled = false
            bufferSizeCell.isUserInteractionEnabled = false
        } else {
            bufferSizeCell.textLabel?.isEnabled = true
            bufferSizeCell.isUserInteractionEnabled = true
        }
    }
    
    /// Toggles visisbility of the reference scale picker.
    func toggleBufferSizePickerVisibility() {
        let bufferSizePicker = IndexPath(row: 3, section: 0)
        let bufferSizeLabel = bufferSizeCell.detailTextLabel
        tableView.performBatchUpdates({
            if bufferSizePickerHidden {
                bufferSizeLabel?.textColor = .accentColor
                tableView.insertRows(at: [bufferSizePicker], with: .fade)
                bufferSizePickerHidden = false
            } else {
                bufferSizeLabel?.textColor = nil
                tableView.deleteRows(at: [bufferSizePicker], with: .fade)
                bufferSizePickerHidden = true
            }
        }, completion: nil)
    }
    
    // MARK: UITableViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        switch cell {
        case statusCell:
            showStatusOptions()
        case protectionCell:
            showProtectionOptions()
        case bufferSizeCell:
            tableView.deselectRow(at: indexPath, animated: true)
            showBufferSizeOptions()
            if selectedProtection != nil {
                toggleBufferSizePickerVisibility()
            } else {
                return
            }
        default:
            return
        }
    }
        
    /* UITableViewDataSource */
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberOfRows = super.tableView(tableView, numberOfRowsInSection: section)
        if bufferSizePickerHidden {
            return numberOfRows - 1
        } else {
            return numberOfRows
        }
    }
}

// MARK: Pickerview

extension AddContingentValuesViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return bufferSizes!.count
    }
}

extension AddContingentValuesViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if let bufferSizes = bufferSizes {
            let bufferSizeTitle = String(bufferSizes[row])
            return bufferSizeTitle
        }
        return ""
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if let bufferSizes = bufferSizes {
            selectedBufferSize = bufferSizes[row]
        }
    }
}
