import Foundation

let toBeFiltered = ["star0", "star2", "star1", "star0", "star3", "star4"]
let theFilter = ["star1", "star3"]

Set(toBeFiltered).intersection(Set(theFilter))
Set(toBeFiltered).subtracting(Set(theFilter))
