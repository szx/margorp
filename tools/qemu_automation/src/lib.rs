use anyhow::Result;
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::str::FromStr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

pub struct State {
    qemu_process: Arc<Mutex<std::process::Child>>,
    is_running: Arc<AtomicBool>,
    is_reading: Arc<AtomicBool>,
    read_stream: UnixStream,
    write_stream: UnixStream,

    log: String,
}

impl State {
    pub fn new() -> Self {
        let mut path = PathBuf::from_str(env!("CARGO_MANIFEST_DIR")).unwrap();
        path.push("..");
        path.push("run_qemu");
        path.set_extension("sh");
        let path = path.canonicalize().unwrap();
        let cwd = path.clone();
        let cwd = cwd.parent().unwrap();
        let qemu_process = std::process::Command::new("bash")
            .arg("-c")
            .arg(path)
            .current_dir(cwd)
            .spawn()
            .unwrap();

        let read_stream: UnixStream;
        loop {
            if let Ok(stream) = UnixStream::connect("/tmp/qemu-monitor-socket") {
                read_stream = stream;
                break;
            }
            thread::sleep(Duration::from_millis(100));
        }
        let write_stream = read_stream.try_clone().expect("write stream");
        Self {
            qemu_process: Arc::new(Mutex::new(qemu_process)),
            is_running: Arc::new(AtomicBool::new(true)),
            is_reading: Arc::new(AtomicBool::new(true)),
            read_stream,
            write_stream,
            log: "started".to_owned(),
        }
    }

    pub fn handle_read(&self) -> Result<()> {
        self.read_stream
            .set_read_timeout(Some(Duration::new(1, 0)))?;
        let mut stream = BufReader::new(&self.read_stream);
        loop {
            if !self.is_running.load(Ordering::Relaxed) {
                return Ok(());
            }
            let mut line = String::new();
            stream.read_line(&mut line)?;
            // println!("QEMU read:\t{line}");
            self.is_reading.store(true, Ordering::Relaxed);
        }
    }

    pub fn handle_write(&self) -> Result<()> {
        let mut stream = BufWriter::new(&self.write_stream);
        self.write_to_qemu_monitor(&mut stream, &format!("cont\n"))?;
        thread::sleep(Duration::new(1, 0)); // Needs to wait.

        let path = PathBuf::from_str(env!("CARGO_MANIFEST_DIR"))?
            .join("../../src/forth.margorp")
            .canonicalize()?;
        let chars = std::fs::read_to_string(path)?;
        let chars = chars.chars();
        // TODO: Probably could just poke keyboard buffer memory.
        for c in chars {
            let c = match c {
                'a'..='z' => c.to_string(),
                'A'..='Z' => format!("shift-{}", c.to_ascii_lowercase()),
                '0'..='9' => c.to_string(),
                '\n' => "ret".into(),
                ' ' => "spc".into(),
                ';' => "semicolon".into(),
                ':' => "shift-semicolon".into(),
                '=' => "equal".into(),
                '+' => "shift-equal".into(),
                '.' => "dot".into(),
                '>' => "shift-dot".into(),
                '!' => "shift-1".into(),
                '@' => "shift-2".into(),
                '#' => "shift-3".into(),
                '$' => "shift-4".into(),
                '%' => "shift-5".into(),
                '^' => "shift-6".into(),
                '&' => "shift-7".into(),
                '*' => "shift-8".into(),
                '(' => "shift-9".into(),
                ')' => "shift-0".into(),
                '-' => "minus".into(),
                '_' => "shift-minus".into(),
                ',' => "comma".into(),
                '<' => "shift-comma".into(),
                '/' => "slash".into(),
                '?' => "shift-slash".into(),
                '\\' => "backslash".into(),
                '|' => "shift-backslash".into(),
                '[' => "bracket_left".into(),
                '{' => "shift-bracket_left".into(),
                ']' => "bracket_right".into(),
                '}' => "shift-bracket_right".into(),
                '\'' => "apostrophe".into(),
                '"' => "shift-apostrophe".into(),
                _ => todo!("c: '{c}'"),
            };
            self.write_to_qemu_monitor(&mut stream, &format!("sendkey {c} 1\n"))?;
        }

        stream.write_all("sendkey ret\n".as_bytes())?;
        self.is_running.store(false, Ordering::Relaxed);
        Ok(())
    }

    fn write_to_qemu_monitor(&self, stream: &mut BufWriter<&UnixStream>, s: &str) -> Result<()> {
        while !self.is_reading.load(Ordering::Relaxed) {}
        self.is_reading.store(false, Ordering::Relaxed);
        thread::sleep(Duration::new(0, 2 * 1000000));
        stream.write_all(s.as_bytes())?;
        stream.flush()?;
        //dbg!(&s);
        Ok(())
    }

    pub fn kill(&self) {
        self.is_running.store(false, Ordering::Relaxed);
    }

    pub fn wait_for_qemu_exit(&self) -> Result<()> {
        let qemu_process = self.qemu_process.clone();
        let mut qemu_process = qemu_process.lock().unwrap();
        qemu_process.wait()?;
        Ok(())
    }
}
