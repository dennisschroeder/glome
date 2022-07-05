import gleam/list.{contains, fold_right, map}
import gleam/pair

/// A Group ist a Tuple with a key and a List of values
pub type Group(k, v) =
  #(k, List(v))

/// A List of Groups
pub type Groups(k, v) =
  List(Group(k, v))

fn insert_to_group(groups: Groups(k, v), pair: #(k, v)) -> Groups(k, v) {
  let append_if_key_matches = fn(group: Group(k, v)) {
    case pair.0 == group.0 {
      True -> #(group.0, [pair.1, ..group.1])
      False -> group
    }
  }

  let is_key_known =
    map(groups, pair.first)
    |> contains(pair.0)

  case is_key_known {
    True -> map(groups, append_if_key_matches)
    False -> [#(pair.0, [pair.1]), ..groups]
  }
}

/// Takes a lists and groups the values by a key
/// which is build from a key_selector function
/// and the values are stored in a new List.
///
/// ## Examples
///
/// ```gleam
/// > [Ok(3), Error("Wrong"), Ok(200), Ok(73)]
///   |> group(with: fn(i) {
///     case i {
///       Ok(_) -> "Successful"
///       Error(_) -> "Failed"
///     }
///   })
///
/// [
///   #("Failed", [Error("Wrong")]),
///   #("Successful", [Ok(3), Ok(200), Ok(73)])
/// ]
///
/// > group(from: [1,2,3,4,5], with: fn(i) {fn(i) { i - i / 3 * 3 }})
/// [#(0, [3]), #(1, [1, 4]), #(2, [2, 5])]
/// ```
///
pub fn group(from list: List(v), with key_selector: fn(v) -> k) -> Groups(k, v) {
  map(list, fn(x) { #(key_selector(x), x) })
  |> fold_right([], insert_to_group)
}
