use anyhow::Result;
use qemu_automation::State;
use std::sync::LazyLock;
use std::thread;

static STATE: LazyLock<State> = LazyLock::new(|| State::new());

fn main() -> Result<()> {
    println!("start qemu_automation");

    thread::scope(|scope| {
        scope.spawn(|| {
            STATE.handle_read().map_err(|e| {
                STATE.kill();
                dbg!(e)
            })
        });
        scope.spawn(|| {
            STATE.handle_write().map_err(|e| {
                STATE.kill();
                dbg!(e)
            })
        });
    });

    STATE.wait_for_qemu_exit()?;
    println!("finish qemu_automation");
    Ok(())
}
