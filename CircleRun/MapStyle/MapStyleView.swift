////
////  MapStyleView.swift
////  CircleRun
////
////  Created by Anjan Athreya on 4/5/25.
////
//
//import SwiftUI
//
//struct MapStyleView: View {
//    @Environment(\.dismiss) private var dismiss
//    @Binding var MapStyleConfig: MapStyleConfig
//    var body: some View {
//        NavigationStack {
//            VStack(alignment: .leading) {
//                LabeledContent("Base Style") {
//                    Picker("Base Style", selection: $MapStyleConfig.baseStyle) {
//                        ForEach(MapStyleConfig.BaseMapStyle.allCases, id: \.self)
//                        {
//                            type in Text(type.label)
//                        }
//                    }
//                }
//                LabeledContent("Elevation") {
//                    Picker("Elevation", selection: $MapStyleConfig.elevation) {
//                        Text("Flat").tag(MapStyleConfig.MapElevaton.flat)
//                        Text("Realistic").tag(MapStyleConfig.MapElevaton.realistic)
//                    }
//                }
//                if MapStyleConfig.baseStyle != .imagery {
//                    LabeledContent("Points of Interest") {
//                        Picker("Points of Interest", selection:
//                                $MapStyleConfig.pointsOfInterest) {
//                            Text("None").tag(MapStyleConfig.MapPOI.excludingAll)
//                            Text("All").tag(MapStyleConfig.MapPOI.all)
//                        }
//                    }
//                    
//                }
//            }
//            .padding()
//            .navigationTitle("Map Style")
//            .navigationBarTitleDisplayMode(.inline)
//        }
//    }
//}
//
//#Preview {
//    MapStyleView(MapStyleConfig: .constant(MapStyleConfig.init()))
//}
