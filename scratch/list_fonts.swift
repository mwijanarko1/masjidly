import UIKit

let fonts = UIFont.familyNames.sorted()
for family in fonts {
    print("Family: \(family)")
    let names = UIFont.fontNames(forFamilyName: family)
    for name in names {
        print("  - \(name)")
    }
}
