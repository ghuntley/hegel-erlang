import gleam/list
import gleeunit
import hegel/gen
import hegel/property

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn reverse_property_test() {
  property.check(fn(test_case) {
    let values = property.draw(test_case, "values", gen.list(gen.int()))
    assert list.reverse(list.reverse(values)) == values
  })
}
