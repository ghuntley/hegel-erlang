import gleeunit
import hegel/gen
import hegel/property

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn successful_property_test() {
  property.check(fn(test_case) {
    let _value = property.draw(test_case, "value", gen.int_range(0, 10))
    Nil
  })
}
