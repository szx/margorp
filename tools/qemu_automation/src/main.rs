use anyhow::Result;
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::str::FromStr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

fn main() -> Result<()> {
    println!("start");

    let is_running = Arc::new(AtomicBool::new(true));
    let read_stream = UnixStream::connect("/tmp/qemu-monitor-socket")?;
    let write_stream = read_stream.try_clone()?;

    thread::scope(|scope| {
        scope.spawn(|| {
            handle_read(is_running.clone(), read_stream).map_err(|e| {
                is_running.store(false, Ordering::Relaxed);
                dbg!(e)
            })
        });
        scope.spawn(|| {
            handle_write(is_running.clone(), write_stream).map_err(|e| {
                is_running.store(false, Ordering::Relaxed);
                dbg!(e)
            })
        });
    });

    println!("finish");
    Ok(())
}

fn handle_read(is_running: Arc<AtomicBool>, stream: UnixStream) -> Result<()> {
    stream.set_read_timeout(Some(Duration::new(1, 0)))?;
    let stream = BufReader::new(stream);
    for line in stream.lines() {
        println!("read: {}", line?);
    }
    Ok(())
}

fn handle_write(is_running: Arc<AtomicBool>, stream: UnixStream) -> Result<()> {
    let mut stream = BufWriter::new(stream);

    let path = PathBuf::from_str(env!("CARGO_MANIFEST_DIR"))?
        .join("../../src/forth.margorp")
        .canonicalize()?;
    for c in std::fs::read_to_string(path)?.chars() {
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
        stream.write_all(format!("sendkey {c}\n").as_bytes())?;
        stream.flush()?;
        thread::sleep(Duration::new(0, 100 * 1000000));
    }

    stream.write_all("sendkey spc\n".as_bytes())?;
    is_running.store(false, Ordering::Relaxed);
    Ok(())
}
