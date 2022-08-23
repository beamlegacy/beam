//
//  SearchLocationView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 23/08/2021.
//

import SwiftUI

struct SearchLocationView: View {

    @ObservedObject var viewModel: SearchViewModel
    @State var hoveredPosition: Double?

    let height: CGFloat

    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .top)) {
            if !viewModel.incompleteSearch && viewModel.foundOccurences > 0 {
                ForEach(viewModel.positions, id: \.self) { position in
                    VStack {
                        Spacer()
                            .frame(height: computePosition(globalHeight: height, relativePosition: position))
                        PositionIndicator(isCurrent: isIndicatorSelected(position: position), isHovered: hoveredPosition == position)
                            .onHover(perform: { hovering in
                                if hovering {
                                    hoveredPosition = position
                                } else if hoveredPosition == position {
                                    hoveredPosition = nil
                                }
                        })
                            .onTapGesture {
                                viewModel.onLocationIndicatorTap?(position)
                            }
                    }.transition(.move(edge: .trailing))
                }
            }
        }
        .transition(.move(edge: .trailing))
        .padding(.vertical, 2)
    }

    func computePosition(globalHeight: CGFloat, relativePosition: Double) -> CGFloat {
        guard let pageGlobalHeight = viewModel.pageHeight else { return 0 }
        let position = height * CGFloat(relativePosition / pageGlobalHeight)
        return position
    }

    func isIndicatorSelected(position: Double) -> Bool {
        return position == viewModel.currentPosition
    }
}

struct SearchLocationView_Previews: PreviewProvider {
    static var previews: some View {
        SearchLocationView(viewModel: SearchViewModel(context: .card, found: 5), height: 50)
    }
}

struct PositionIndicator: View {

    var isCurrent: Bool
    var isHovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: 100)
            .foregroundColor(indicatorColor)
            .frame(width: 8, height: 3, alignment: .center)
    }

    var indicatorColor: Color {
        if isCurrent {
            return isHovered ? BeamColor.Search.currentElementHover.swiftUI : BeamColor.Search.currentElement.swiftUI
        } else {
            return isHovered ? BeamColor.Search.foundElementHover.swiftUI : BeamColor.Search.foundElement.swiftUI
        }
    }
}

struct PositionIndicator_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PositionIndicator(isCurrent: true)
            PositionIndicator(isCurrent: false)
        }
    }
}
