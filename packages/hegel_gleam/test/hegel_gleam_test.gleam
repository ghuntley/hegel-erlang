import gleeunit
import hegel_gleam
import hegel_gleam/gen

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn successful_property_test() {
  hegel_gleam.check(fn(test_case) {
    let _value = hegel_gleam.draw(test_case, "value", gen.int_range(0, 10))
    Nil
  })
}
