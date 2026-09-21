import hegel/gen
import hegel/property

pub fn main() -> Nil {
  property.check(fn(test_case) {
    let value = property.draw(test_case, "value", gen.int_range(0, 100))
    assert value < 10
  })
}
