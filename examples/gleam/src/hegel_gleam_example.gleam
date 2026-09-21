import gleam/io
import gleam/list
import hegel/gen
import hegel/property

pub fn main() -> Nil {
  reverse_property()
  io.println("The reverse property passed.")
}

pub fn reverse_property() -> Nil {
  property.check(fn(test_case) {
    let values = property.draw(test_case, "values", gen.list(gen.int()))
    assert list.reverse(list.reverse(values)) == values
  })
}
