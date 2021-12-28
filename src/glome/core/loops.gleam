import glome/core/error.{GlomeError, LoopNil}
import gleam/result
import gleam/io

pub fn start_state_change_event_publisher(
  loop: fn() -> Result(Nil, GlomeError),
) -> Nil {
  loop()
  |> result.map_error(fn(error) {
    case error {
      LoopNil -> Nil
      other -> {
        io.println("")
        io.println("### Error in publisher loop ###")
        io.println("")
        io.debug(other)
        io.println("")
        io.println("### Error in publisher loop ###")
        Nil
      }
    }
  })
  start_state_change_event_publisher(loop)
}

pub fn start_state_change_event_receiver(
  loop: fn() -> Result(Nil, GlomeError),
) -> Nil {
  loop()
  |> result.map_error(fn(error) {
    case error {
      LoopNil -> Nil
      other -> {
        io.println("### Error in receiver loop ###")
        io.debug(other)
        Nil
      }
    }
  })
  start_state_change_event_receiver(loop)
}
