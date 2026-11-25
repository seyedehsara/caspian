import Foundation

/// A postage stamp the player can buy with points in the Collection.
/// `id` is also the asset name in Assets.xcassets.
struct PostageStamp: Identifiable, Hashable, Sendable {
    let id: String
    let countryID: String
    let title: String
    let price: Int
}

extension ContentLibrary {
    /// What one stamp costs: the same as the bonus for unlocking a country.
    static let stampPrice = pointsPerUnlock

    /// The stamps on sale, grouped by country in the order they appear in the Collection.
    /// To add one: drop the image into Assets.xcassets and add a line here.
    static let postageStamps: [PostageStamp] = [
        PostageStamp(id: "post_ita_roma",    countryID: "ITA", title: "Poste Italiane",  price: stampPrice),
        PostageStamp(id: "post_ita_venice",  countryID: "ITA", title: "Venice 1951",     price: stampPrice),
        PostageStamp(id: "post_irn_tehran",  countryID: "IRN", title: "Iran Post",       price: stampPrice),
        PostageStamp(id: "post_egy_giza",    countryID: "EGY", title: "Egypt Post",      price: stampPrice),
        PostageStamp(id: "post_mex_pyramid", countryID: "MEX", title: "Servicio Postal", price: stampPrice),
        PostageStamp(id: "post_rus_moscow",  countryID: "RUS", title: "Pochta Rossii",   price: stampPrice),
    ]

    static func postageStamps(for countryID: String) -> [PostageStamp] {
        postageStamps.filter { $0.countryID == countryID }
    }
}
