pub type Generator(a)

@external(erlang, "hegel_gen", "boolean")
pub fn bool() -> Generator(Bool)

@external(erlang, "hegel_gen", "integer")
pub fn int() -> Generator(Int)

@external(erlang, "hegel_gen", "integer")
pub fn int_range(min: Int, max: Int) -> Generator(Int)

@external(erlang, "hegel_gen", "float")
pub fn float() -> Generator(Float)

@external(erlang, "hegel_gen", "float")
pub fn float_range(min: Float, max: Float) -> Generator(Float)

@external(erlang, "hegel_gen", "binary")
pub fn bit_array() -> Generator(BitArray)

@external(erlang, "hegel_gen", "utf8")
pub fn string() -> Generator(String)

@external(erlang, "hegel_gen", "constant")
pub fn constant(value: a) -> Generator(a)

@external(erlang, "hegel_gen", "one_of")
pub fn one_of(generators: List(Generator(a))) -> Generator(a)

@external(erlang, "hegel_gen", "list")
pub fn list(generator: Generator(a)) -> Generator(List(a))

@external(erlang, "hegel_gen", "map")
fn map_ffi(mapper: fn(a) -> b, generator: Generator(a)) -> Generator(b)

pub fn map(generator: Generator(a), mapper: fn(a) -> b) -> Generator(b) {
  map_ffi(mapper, generator)
}

@external(erlang, "hegel_gen", "bind")
fn bind_ffi(
  generator: Generator(a),
  then: fn(a) -> Generator(b),
) -> Generator(b)

pub fn then(
  generator: Generator(a),
  next: fn(a) -> Generator(b),
) -> Generator(b) {
  bind_ffi(generator, next)
}

@external(erlang, "hegel_gen", "filter")
fn filter_ffi(predicate: fn(a) -> Bool, generator: Generator(a)) -> Generator(a)

pub fn filter(
  generator: Generator(a),
  predicate: fn(a) -> Bool,
) -> Generator(a) {
  filter_ffi(predicate, generator)
}
