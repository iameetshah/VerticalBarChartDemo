//
//  CornerRadiusStackBarRenderer.swift
//  verticalBarChartDemo
//
//  Created by Mit Shah on 13/03/21.
//

import Foundation
import Charts

class CornerRadiusStackBarRenderer: BarChartRenderer {
    
    let cornerRadius: CGFloat = 2.0
    
    private class Buffer {
        var rects = [CGRect]()
    }
    
    // [CGRect] per dataset
    private var _buffers = [Buffer]()
    
    override func initBuffers() {
        if let barData = dataProvider?.barData {
            // Matche buffers count to dataset count
            if _buffers.count != barData.dataSetCount {
                while _buffers.count < barData.dataSetCount {
                    _buffers.append(Buffer())
                }
                while _buffers.count > barData.dataSetCount {
                    _buffers.removeLast()
                }
            }
            
            for index in stride(from: 0, to: barData.dataSetCount, by: 1) {
                guard let set = barData.dataSets[index] as? IBarChartDataSet else {
                    continue
                }
                let size = set.entryCount * (set.isStacked ? set.stackSize : 1)
                if _buffers[index].rects.count != size {
                    _buffers[index].rects = [CGRect](repeating: CGRect(), count: size)
                }
            }
        }
        else {
            _buffers.removeAll()
        }
    }
    
    private func prepareBuffer(dataSet: IBarChartDataSet, index: Int) {
        guard
            let dataProvider = dataProvider,
            let barData = dataProvider.barData
        else { return }
        
        let barWidthHalf = barData.barWidth / 2.0
        
        let buffer = _buffers[index]
        var bufferIndex = 0
        let containsStacks = dataSet.isStacked
        
        let isInverted = dataProvider.isInverted(axis: dataSet.axisDependency)
        let phaseY = animator.phaseY
        var barRect = CGRect()
        var originX: Double
        var originY: Double
        
        for index in stride(from: 0, to: min(Int(ceil(Double(dataSet.entryCount) * animator.phaseX)), dataSet.entryCount), by: 1) {
            guard let currentEntry = dataSet.entryForIndex(index) as? BarChartDataEntry else { continue }
            
            let vals = currentEntry.yValues
            
            originX = currentEntry.x
            originY = currentEntry.y
            
            if !containsStacks || vals == nil {
                let left = CGFloat(originX - barWidthHalf)
                let right = CGFloat(originX + barWidthHalf)
                var top = isInverted
                    ? (originY <= 0.0 ? CGFloat(originY) : 0)
                    : (originY >= 0.0 ? CGFloat(originY) : 0)
                var bottom = isInverted
                    ? (originY >= 0.0 ? CGFloat(originY) : 0)
                    : (originY <= 0.0 ? CGFloat(originY) : 0)
                
                // Multiply the height of the rect with the phase
                if top > 0 {
                    top *= CGFloat(phaseY)
                } else {
                    bottom *= CGFloat(phaseY)
                }
                
                barRect.origin.x = left
                barRect.size.width = right - left
                barRect.origin.y = top
                barRect.size.height = bottom - top
                
                buffer.rects[bufferIndex] = barRect
                bufferIndex += 1
            }
            else {
                var posY = 0.0
                var negY = -currentEntry.negativeSum
                var yStart = 0.0
                
                // Fill the stack
                for valsIndex in 0 ..< vals!.count {
                    let value = vals![valsIndex]
                    
                    if value == 0.0 && (posY == 0.0 || negY == 0.0) {
                        // Take care of the situation of a 0.0 value, which overlaps a non-zero bar
                        originY = value
                        yStart = originY
                    }
                    else if value >= 0.0 {
                        originY = posY
                        yStart = posY + value
                        posY = yStart
                    }
                    else {
                        originY = negY
                        yStart = negY + abs(value)
                        negY += abs(value)
                    }
                    
                    let left = CGFloat(originX - barWidthHalf)
                    let right = CGFloat(originX + barWidthHalf)
                    var top = isInverted
                        ? (originY <= yStart ? CGFloat(originY) : CGFloat(yStart))
                        : (originY >= yStart ? CGFloat(originY) : CGFloat(yStart))
                    var bottom = isInverted
                        ? (originY >= yStart ? CGFloat(originY) : CGFloat(yStart))
                        : (originY <= yStart ? CGFloat(originY) : CGFloat(yStart))
                    
                    // Multiply the height of the rect with the phase
                    top *= CGFloat(phaseY)
                    bottom *= CGFloat(phaseY)
                    
                    barRect.origin.x = left
                    barRect.size.width = right - left
                    barRect.origin.y = top
                    barRect.size.height = bottom - top
                    
                    buffer.rects[bufferIndex] = barRect
                    bufferIndex += 1
                }
            }
        }
    }
    
    private var _barShadowRectBuffer: CGRect = CGRect()
    
    override func drawDataSet(context: CGContext, dataSet: IBarChartDataSet, index: Int) {
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        prepareBuffer(dataSet: dataSet, index: index)
        trans.rectValuesToPixel(&_buffers[index].rects)
        
        let borderWidth = dataSet.barBorderWidth
        let borderColor = dataSet.barBorderColor
        let drawBorder = borderWidth > 0.0
        
        context.saveGState()
        
        // Draw the bar shadow before the values
        if dataProvider.isDrawBarShadowEnabled {
            drawShadow(context: context, dataSet: dataSet, dataProvider: dataProvider, trans: trans, index: index)
        }
        
        let buffer = _buffers[index]
        
        let isSingleColor = dataSet.colors.count == 1
        
        if isSingleColor {
            context.setFillColor(dataSet.color(atIndex: 0).cgColor)
        }
        
        for bufferIndex in stride(from: 0, to: buffer.rects.count, by: 1) {
            let barRect = buffer.rects[bufferIndex]
            
            if !viewPortHandler.isInBoundsLeft(barRect.origin.x + barRect.size.width) {
                continue
            }
            
            if !viewPortHandler.isInBoundsRight(barRect.origin.x) {
                break
            }
            
            if !isSingleColor {
                // Set the color for the currently drawn value. If the index is out of bounds, reuse colors.
                context.setFillColor(dataSet.color(atIndex: bufferIndex).cgColor)
            }
            
            let stackIndex = bufferIndex == 0 || bufferIndex % 2 == 0 ? 0 : 1
            setupCorner(context: context, dataSet: dataSet, index: Int(bufferIndex / 2), stackIndex: stackIndex, barRect: barRect, border: false)
            
            if drawBorder {
                
                context.setStrokeColor(borderColor.cgColor)
                context.setLineWidth(borderWidth)
                setupCorner(context: context, dataSet: dataSet, index: index, stackIndex: stackIndex, barRect: barRect, border: true)
            }
        }
        
        context.restoreGState()
    }
    func setupCorner(context:CGContext, dataSet: IBarChartDataSet, index: Int, stackIndex:Int, barRect:CGRect, border:Bool) {
        if let currentEntry = dataSet.entryForIndex(index) as? BarChartDataEntry {
            let bezierPath = UIBezierPath(roundedRect: barRect, byRoundingCorners: [.allCorners], cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
            if currentEntry.yValues![stackIndex] == 0 || currentEntry.yValues![stackIndex] == 100 {
                let roundedPath = bezierPath.cgPath
                context.addPath(roundedPath)
                if border {
                    
                    context.strokePath()
                }
                else {
                    context.fillPath()
                }
            }
            else {
                if stackIndex == 0 {
                    let bezierPath = UIBezierPath(roundedRect: barRect, byRoundingCorners: [.allCorners], cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
                    let roundedPath = bezierPath.cgPath
                    context.addPath(roundedPath)
                    if border {
                        context.strokePath()
                    }
                    else {
                        context.fillPath()
                    }
                    
                }
                else {
                    
                    if border {
                        let bezierPath = UIBezierPath(roundedRect: barRect, byRoundingCorners: [.allCorners], cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
                        let roundedPath = bezierPath.cgPath
                        context.addPath(roundedPath)
                        context.strokePath()
                    }
                    else {
                        let bezierPath = UIBezierPath(roundedRect: barRect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
                        let roundedPath = bezierPath.cgPath
                        context.addPath(roundedPath)
                        context.fillPath()
                    }
                }
            }
        }
    }
    
    func drawShadow(context: CGContext, dataSet: IBarChartDataSet, dataProvider: BarChartDataProvider, trans: Transformer, index: Int) {
        guard let barData = dataProvider.barData else { return }
        
        let barWidth = barData.barWidth
        let barWidthHalf = barWidth / 2.0
        var originX: Double = 0.0
        
        for index in stride(from: 0, to: min(Int(ceil(Double(dataSet.entryCount) * animator.phaseX)), dataSet.entryCount), by: 1) {
            guard let currentEntry = dataSet.entryForIndex(index) as? BarChartDataEntry else { continue }
            
            originX = currentEntry.x
            
            _barShadowRectBuffer.origin.x = CGFloat(originX - barWidthHalf)
            _barShadowRectBuffer.size.width = CGFloat(barWidth)
            
            trans.rectValueToPixel(&_barShadowRectBuffer)
            
            if !viewPortHandler.isInBoundsLeft(_barShadowRectBuffer.origin.x + _barShadowRectBuffer.size.width) {
                continue
            }
            
            if !viewPortHandler.isInBoundsRight(_barShadowRectBuffer.origin.x) {
                break
            }
            
            _barShadowRectBuffer.origin.y = viewPortHandler.contentTop
            _barShadowRectBuffer.size.height = viewPortHandler.contentHeight
            
            context.setFillColor(dataSet.barShadowColor.cgColor)
            context.fill(_barShadowRectBuffer)
        }
        
        let buffer = _buffers[index]
        
        // Draw the bar shadow before the values
        for index in stride(from: 0, to: buffer.rects.count, by: 1) {
            let barRect = buffer.rects[index]
            
            if !viewPortHandler.isInBoundsLeft(barRect.origin.x + barRect.size.width) {
                continue
            }
            
            if !viewPortHandler.isInBoundsRight(barRect.origin.x) {
                break
            }
            
            context.setFillColor(dataSet.barShadowColor.cgColor)
            context.fill(barRect)
        }
    }
    
    override func drawHighlighted(context: CGContext, indices: [Highlight]) {
        guard
            let dataProvider = dataProvider,
            let barData = dataProvider.barData
        else { return }
        
        context.saveGState()
        
        var barRect = CGRect()
        
        for high in indices {
            guard
                let set = barData.getDataSetByIndex(high.dataSetIndex) as? IBarChartDataSet,
                set.isHighlightEnabled
            else { continue }
            
            if let currentEntry = set.entryForXValue(high.x, closestToY: high.y) as? BarChartDataEntry {
                let trans = dataProvider.getTransformer(forAxis: set.axisDependency)
                
                context.setFillColor(set.highlightColor.cgColor)
                context.setAlpha(set.highlightAlpha)
                
                let isStack = high.stackIndex >= 0 && currentEntry.isStacked
                
                let y1: Double
                let y2: Double
                
                if isStack {
                    if dataProvider.isHighlightFullBarEnabled {
                        y1 = currentEntry.positiveSum
                        y2 = -currentEntry.negativeSum
                    }
                    else {
                        let range = currentEntry.ranges?[high.stackIndex]
                        
                        y1 = range?.from ?? 0.0
                        y2 = range?.to ?? 0.0
                    }
                }
                else {
                    y1 = currentEntry.y
                    y2 = 0.0
                }
                
                prepareBarHighlight(x: currentEntry.x, y1: y1, y2: y2, barWidthHalf: barData.barWidth / 2.0, trans: trans, rect: &barRect)
                
                setHighlightDrawPos(highlight: high, barRect: barRect)
                
                setupCorner(context: context, dataSet: set, index: Int(high.x), stackIndex: high.stackIndex, barRect: barRect, border: false)
            }
        }
        
        context.restoreGState()
    }
    
    // Sets the drawing position of the highlight object based on the riven bar-rect.
    func setHighlightDrawPos(highlight high: Highlight, barRect: CGRect) {
        high.setDraw(x: barRect.midX, y: barRect.origin.y)
    }
}
