use anyhow::Result;
use eframe::egui;
use qemu_automation::State;
use std::sync::{Arc, LazyLock, Mutex};
use std::thread;

fn main() -> Result<()> {
    println!("start debug_ui");

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default().with_inner_size([320.0, 240.0]),
        ..Default::default()
    };

    eframe::run_native(
        "My egui App",
        options,
        Box::new(|_cc| Ok(Box::new(App::default()))),
    )
    .unwrap();

    println!("finish debug_ui");
    Ok(())
}

struct App {
    qemu: Arc<qemu_automation::State>,
}

impl Default for App {
    fn default() -> Self {
        let qemu = Arc::new(qemu_automation::State::new());
        thread::spawn({
            let qemu = qemu.clone();
            move || {
                qemu.handle_read().map_err(|e| {
                    qemu.kill();
                    dbg!(e)
                })
            }
        });
        thread::spawn({
            let qemu = qemu.clone();
            move || {
                qemu.handle_write().map_err(|e| {
                    qemu.kill();
                    dbg!(e)
                })
            }
        });
        thread::spawn({
            let qemu = qemu.clone();
            move || {
                qemu.wait_for_qemu_exit().map_err(|e| {
                    qemu.kill();
                    dbg!(e)
                })
            }
        });

        Self { qemu }
    }
}

impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {
        egui::CentralPanel::default().show(ctx, |ui| {
            ui.heading("MARGORP debug UI");
            // TUTAJ: egui with:
            //       - button to start/stop
            //       - button to start transcription
            //       - text field with interesting buffers
        });
    }
}
