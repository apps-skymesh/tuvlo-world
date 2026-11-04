import SwiftUI

/// One pictured good across ingredients, products, stock and saved-item feedback.
struct HomesteadFarmGoodIcon: View {
    let good: HomesteadFarm.Good

    var body: some View {
        Image("WorldGood_" + good.rawValue)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
