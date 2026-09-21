//// Property-based testing for Gleam, backed by the canonical Erlang SDK.

import hegel/gen.{type Generator}

pub type TestCase

@external(erlang, "hegel_gleam_ffi", "check")
pub fn check(property: fn(TestCase) -> Nil) -> Nil

@external(erlang, "hegel_gleam_ffi", "reproduce")
pub fn reproduce(property: fn(TestCase) -> Nil, blob: String) -> Nil

@external(erlang, "hegel", "draw_silent")
pub fn draw_silent(test_case: TestCase, generator: Generator(a)) -> a

@external(erlang, "hegel_gleam_ffi", "draw")
pub fn draw(test_case: TestCase, name: String, generator: Generator(a)) -> a

@external(erlang, "hegel", "assume")
pub fn assume(condition: Bool) -> Nil

@external(erlang, "hegel_gleam_ffi", "reject")
pub fn reject() -> Nil

@external(erlang, "hegel_gleam_ffi", "note")
pub fn note(value: a) -> Nil

@external(erlang, "hegel_gleam_ffi", "event")
pub fn event(name: String, value: a) -> Nil

@external(erlang, "hegel_gleam_ffi", "target")
pub fn target(name: String, value: Float) -> Nil
