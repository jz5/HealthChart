//
//  SampleView.swift
//  HealthChart
//
//  Created by jz5 on 2023/02/22.
//

import SwiftUI
import Sliders
import Charts

struct SampleView: View {
    
    @State var value = 0.5
    @State var range: ClosedRange<Int>
    @State var inRange: ClosedRange<Int>
    
    @State var x = 0.5
    @State var y = 0.5
    
    @State var isEmpty = false
    @State var isLoading = false
    @State var requested = false
    @State var flag = false
    
    init() {
        _range = State(initialValue: 0...100)
        _inRange = State(initialValue: 0...100)
    }
    
    var body: some View {
        LayoutView(isLoading: $isEmpty, isEmpty: $isLoading, requested: $requested) {
            Group {
                
            }
        } chart: {
            Chart {
                
            }
        } footer: {
            Form {
                Section {
                    Button {
                        flag.toggle()
                    } label: {
                        HStack {
                            Text("お気に入り")
                            
                            Spacer()
                            Image(systemName: "star")
                                .symbolVariant(flag ? .fill : .none)
                                
                        }
                    }
                }
                
                ValueSlider(value: $value)
                RangeSlider(range: $range, in: inRange, step: 1, distance: 0...2)
                PointSlider(x: $x, y: $y)
                Button {
                    range = 10...90
                    inRange = 0...100
                    
                } label: {
                    Text("test")
                }

            }
            .onAppear() {
                //range = 0...100
                //inRange = 0...100
            }
            .frame(height: 500)
        }

        
    }
}

struct SampleView_Previews: PreviewProvider {
    static var previews: some View {
        SampleView()
    }
}
