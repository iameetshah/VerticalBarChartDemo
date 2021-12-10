//
//  ViewController.swift
//  verticalBarChartDemo
//
//  Created by Mit Shah on 13/03/21.
//

import UIKit
import Charts

class ViewController: UIViewController {
    
    @IBOutlet var barChartView: BarChartView!
    
    let months = ["J","F","M","A","M","J","J","A","S","O","N","D"]
    let percentages = [52.0, 40.0, 68.0, 100.0, 0.0, 90.0, 75.0, 100.0, 20.0, 10.0, 0.0, 95.0]

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupVerticalChart()
        setupData()
    }

    func setupVerticalChart() {
        // Graph Position
        barChartView.extraLeftOffset = 0
        barChartView.extraTopOffset = 0
        barChartView.extraBottomOffset = 0
        barChartView.extraRightOffset = 0
        
        let xAxis = barChartView.xAxis
        let rightAxis = barChartView.rightAxis
        barChartView.leftAxis.enabled = false
        xAxis.labelPosition = .bottom
        barChartView.legend.enabled = false
        barChartView.drawGridBackgroundEnabled = false
        xAxis.granularity = 1.0
        xAxis.labelCount = 12
        
        barChartView.pinchZoomEnabled = false
        barChartView.doubleTapToZoomEnabled = false
        
        barChartView.backgroundColor = .white
        
        // Graph X Axis and Right Axis Color
        xAxis.axisLineColor = .clear//UIColor.black.withAlphaComponent(0.2)
        xAxis.gridColor = .clear//UIColor.black.withAlphaComponent(0.2)
        xAxis.labelTextColor = UIColor.black.withAlphaComponent(0.5)
        rightAxis.gridColor = .clear//UIColor.black.withAlphaComponent(0.2)
        rightAxis.axisLineColor = .clear//UIColor.black.withAlphaComponent(0.2)
        rightAxis.labelTextColor = UIColor.black.withAlphaComponent(0.5)
        
        // Graph X Axis and Right Axis Font
        rightAxis.labelFont = UIFont.systemFont(ofSize: 12)
        xAxis.labelFont = UIFont.systemFont(ofSize: 12)
        
        rightAxis.drawZeroLineEnabled = false
        rightAxis.drawAxisLineEnabled = false
        barChartView.delegate = self
    }
    func setupData() {
        var barEntries = [BarChartDataEntry]()
      
        for interval in 0..<months.count {
            let val1 = Double(percentages[interval])
            let val2 = 100 - val1
            barEntries.append(BarChartDataEntry(x:  Double(interval), yValues: [val1, val2]))
        }
        
        let barDataSet = dataSetWith(entries: barEntries,
                                     colors: [UIColor.orange.withAlphaComponent(0.7), UIColor.black.withAlphaComponent(0.2)],
                                     highlightColor: UIColor.orange.withAlphaComponent(1.0),
                                             label: "label")

        barChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: months)
        setupRightAxisFormatter()

        let barData = BarChartData(dataSet: barDataSet)
        barData.barWidth = 0.65
        
        barDataSet.barBorderWidth = 0.5
        barDataSet.barBorderColor = UIColor.black.withAlphaComponent(0.1)

        
        barChartView.data = barData
        barChartView.fitBars = true
        barDataSet.axisDependency = .right

        barChartView.notifyDataSetChanged()
    }
    func setupRightAxisFormatter() {
        let rightAxisFormatter = NumberFormatter()
        rightAxisFormatter.positiveSuffix = "%"
        let rightAxis = barChartView.rightAxis
        rightAxis.valueFormatter = DefaultAxisValueFormatter(formatter: rightAxisFormatter)
        rightAxis.axisMinimum = 0
        rightAxis.axisMaximum = 100
        rightAxis.granularity = 25
    }
    func dataSetWith(entries: [BarChartDataEntry],
                     colors: [UIColor] = [.black],
                     highlightColor: UIColor,
                     label: String = "") -> BarChartDataSet {
        
        let barDataSet = BarChartDataSet(entries: entries, label: label)
        barDataSet.drawIconsEnabled = false
        barDataSet.drawValuesEnabled = false
        barDataSet.colors = colors
        barDataSet.highlightColor = highlightColor
        barDataSet.highlightAlpha = 1.0
        barDataSet.highlightLineWidth = 0
        
        return barDataSet
    }
}
extension ViewController: ChartViewDelegate {
    
    func chartValueSelected(_ chartView: ChartViewBase,
                            entry: ChartDataEntry,
                            highlight: Highlight) {
        let highlight = Highlight(x: entry.x, dataSetIndex: 0, stackIndex: 0)
        chartView.highlightValues([highlight])
    }
}
