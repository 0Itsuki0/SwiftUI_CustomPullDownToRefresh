import SwiftUI

struct CustomRefreshWithModifier: View {
    @State private var isRefreshing: Bool = false
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        Text("Index: \(index)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Rectangle().fill(.yellow.opacity(0.2)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

            }
            .refreshable(
                isRefreshing: $isRefreshing,
                action: {
                    print("refresh start")
                    try? await Task.sleep(for: .seconds(2))
                    print("refresh end")
                }, indicatorView: {
                    Text(isRefreshing ? "Refreshing" : "Refresh?")
                }
            )
            .navigationTitle("Custom Refresh")
            .navigationBarTitleDisplayMode(.inline)
            
        }

    }
}

extension ScrollView {
    nonisolated func refreshable<V>(
        isRefreshing: Binding<Bool>,
        action: @escaping () async -> Void,
        @ViewBuilder indicatorView: () -> V,
        refreshThreshold: CGFloat = 64.0,
        displayIndicatorThreshold: CGFloat = 0.6,
    ) -> some View where V: View {
        self
            .modifier(RefreshableViewModifier(
                isRefreshing: isRefreshing,
                refreshThreshold: refreshThreshold,
                displayIndicatorThreshold: displayIndicatorThreshold,
                refreshAction: action,
                indicatorView: indicatorView()
            ))

    }
}



private struct RefreshableViewModifier<V>: ViewModifier where V: View {
    @Binding var isRefreshing: Bool

    
    // how much the user has to pull down to trigger refresh action
    var refreshThreshold: CGFloat = 64.0
    
    // how much the user has to pull down to start displaying an indicator.
    // a value between 0 and 1 as a ratio of the refreshThreshold.
    // User can still cancel the refresh action by pushing the view up, like the system refreshable
    var displayIndicatorThreshold: CGFloat = 0.6
    
    // the refresh action to perform
    var refreshAction: () async -> Void = {
//        print("refresh start")
//        try? await Task.sleep(for: .seconds(2))
//        print("refresh end")
    }
    
    var indicatorView: V

    // actually refreshing
    
    @State private var contentInsetDifference: CGFloat = 0.0
    
    @State private var indicatorViewDefaultHeight: CGFloat? = nil

    
    func body(content: Content) -> some View {
        ScrollView {
            VStack {
                let differenceThresholdFactor = contentInsetDifference / -refreshThreshold
               
                if differenceThresholdFactor > displayIndicatorThreshold || isRefreshing {
                    // point 1: (displayIndicatorThreshold, 0), point 2: (1, 1)
                    // todo: check if displayIndicatorThreshold is 1
                    let scaleFactor =
                        displayIndicatorThreshold >= 1 ? 1.0 :
                        1 / (1 - displayIndicatorThreshold) * differenceThresholdFactor + (1 - 1 / (1 - displayIndicatorThreshold))

//                    Text("Refreshing")
                    indicatorView
                        .overlay(content: {
                            GeometryReader { geometry in
                                if self.indicatorViewDefaultHeight != geometry.size.height {
                                    DispatchQueue.main.async {
                                        self.indicatorViewDefaultHeight = geometry.size.height
                                    }
                                }
                                return Color.clear
                            }

                        })
                        .scaleEffect(!isRefreshing ? min(scaleFactor, 1.0) : 1.0)
                        .frame(height: (!isRefreshing && indicatorViewDefaultHeight != nil) ? min(scaleFactor, 1.0) * indicatorViewDefaultHeight! : nil)
                        .transition(.asymmetric(insertion: .identity, removal: .scale.combined(with: .opacity)))
                }
                
                content

            }
            .scrollTargetLayout()
        }
//            .refreshable(action: {
//                try? await Task.sleep(for: .seconds(2))
//            })
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            return geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, new in
            self.contentInsetDifference = new
        }
        
        // will not working for list or scrollview reader
        .onScrollPhaseChange({ old, new, context in
            guard old == .interacting, new != .interacting else {
                return
            }
            
            let geometry = context.geometry
            if geometry.contentOffset.y + geometry.contentInsets.top < -refreshThreshold {
                self.isRefreshing = true
            }
        })
        .onChange(of: self.isRefreshing, {
            guard self.isRefreshing else { return }
            Task {
                await refreshAction()
                self.isRefreshing = false
            }
        })
        .animation(.default, value: self.isRefreshing)

    }

}

#Preview {
    CustomRefreshWithModifier()
}
