//
//  LayoutView.swift
//  HealthChart
//
//  Created by jz5 on 2023/02/23.
//

import SwiftUI
import HealthKit

struct LayoutView<Header: View, Chart: View, Footer: View>: View {
    @Binding var isLoading: Bool
    @Binding var isEmpty: Bool
    @Binding var requested: Bool
    
    var header: Header
    var chart: Chart
    var footer: Footer

    @Environment(\.colorScheme) var colorScheme
    
    @State var orientation: UIDeviceOrientation
    @State var showActivityIndicator: Bool = false

    let isHealthDataAvailable = HKHealthStore.isHealthDataAvailable()
    
    init(isLoading: Binding<Bool>,
         isEmpty: Binding<Bool>,
         requested: Binding<Bool>,
         @ViewBuilder header: () -> Header,
         @ViewBuilder chart: () -> Chart,
         @ViewBuilder footer: () -> Footer) {

        self.header = header()
        self.chart = chart()
        self.footer = footer()
        self._orientation = State(wrappedValue: UIDevice.current.orientation)

        self._isLoading = isLoading
        self._isEmpty = isEmpty
        self._requested = requested
    }
    
    var body: some View {
        if (!isHealthDataAvailable) {
            Text("この端末はサポートしていません")
                .background(.background)

        } else if (isLoading) {
            ProgressView()
                .background(.background)

        } else if (isEmpty) {
            VStack {
                Text("記録がありません。または、ヘルスケアデータの読み取り許可がありません。")
                AuthorizationView(requested: $requested)
                .padding(.top)
            }
            .padding([.bottom, .horizontal])
            .background(.background)


        } else if (isPortrait()) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        header
                    }
                    .padding(.horizontal)
                    chart
                        .frame(height: 350)
                        .padding()
                }
                .background(.background)
                footer
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                orientation = UIDevice.current.orientation
            }
            .background(Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.secondarySystemBackground))
            /*.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: Image(uiImage: generateSnapshot()),
                              preview: SharePreview("グラフ", image: Image(uiImage: generateSnapshot())))
                }
            }*/
            
        } else {
            ZStack {
                chart
                    .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                        orientation = UIDevice.current.orientation
                    }
                .padding()
            }
            .background(.background)
            /*.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: Image(uiImage: generateSnapshot()),
                              preview: SharePreview("グラフ", image: Image(uiImage: generateSnapshot())))
                }
            }*/
        }
    }
    
    @MainActor
    private func generateSnapshot() -> UIImage {
        print("generateSnapshot")
        let renderer = ImageRenderer(content: chart)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(CGSize(width: 800, height: 400))
        return renderer.uiImage ?? UIImage()
    }
    
    private func isPortrait() -> Bool {
        
        var isLandscape = orientation.isLandscape
        var isPortrait = orientation.isPortrait
        
        if !isLandscape && !isPortrait {
            isPortrait = UIScreen.main.bounds.width < UIScreen.main.bounds.height
            isLandscape = !isPortrait
        }
        
        return isPortrait
    }
}

