//! Visor JSON-Lines v2 backend: file inspection, sibling gallery, text previews, and cached PDF rendering.
use serde_json::{json, Value};
use std::cmp::Ordering;
use std::collections::VecDeque;
use std::fs::{self, File};
use std::io::{self, BufRead, Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicU64, Ordering as AtomicOrdering};
use std::sync::{Arc, Condvar, Mutex};
use std::thread::{self, JoinHandle};
use std::time::UNIX_EPOCH;

const MAX_TEXT_BYTES: usize = 512 * 1024;
const MAX_SIBLINGS: usize = 500;
const MIN_PDF_DPI: u32 = 72;
const MAX_PDF_DPI: u32 = 240;
static PDF_TMP_SEQ: AtomicU64 = AtomicU64::new(0);

fn event(kind: &str, data: Value) -> Value {
    json!({"version": 2, "type": kind, "data": data})
}

fn natural_cmp_chars(a: &[char], b: &[char]) -> Ordering {
    let (mut i, mut j) = (0, 0);
    while i < a.len() && j < b.len() {
        if a[i].is_ascii_digit() && b[j].is_ascii_digit() {
            let (mut end_a, mut end_b) = (i, j);
            while end_a < a.len() && a[end_a].is_ascii_digit() {
                end_a += 1;
            }
            while end_b < b.len() && b[end_b].is_ascii_digit() {
                end_b += 1;
            }
            let (mut sig_a, mut sig_b) = (i, j);
            while sig_a < end_a && a[sig_a] == '0' {
                sig_a += 1;
            }
            while sig_b < end_b && b[sig_b] == '0' {
                sig_b += 1;
            }
            let order = (end_a - sig_a)
                .cmp(&(end_b - sig_b))
                .then_with(|| a[sig_a..end_a].cmp(&b[sig_b..end_b]));
            if order != Ordering::Equal {
                return order;
            }
            i = end_a;
            j = end_b;
        } else {
            let order = a[i].cmp(&b[j]);
            if order != Ordering::Equal {
                return order;
            }
            i += 1;
            j += 1;
        }
    }
    (a.len() - i).cmp(&(b.len() - j))
}

fn extension_lower(path: &Path) -> String {
    path.extension()
        .and_then(|e| e.to_str())
        .map(|s| s.to_ascii_lowercase())
        .unwrap_or_default()
}

fn known_text_filename(path: &Path) -> bool {
    let Some(name) = path.file_name().and_then(|n| n.to_str()) else {
        return false;
    };
    matches!(
        name.to_ascii_lowercase().as_str(),
        "readme"
            | "license"
            | "makefile"
            | "dockerfile"
            | "cmakelists.txt"
            | "qmldir"
            | "pkgbuild"
            | ".gitignore"
            | ".env"
            | ".bashrc"
            | ".zshrc"
            | ".profile"
            | "cargo.lock"
    )
}

fn classify_by_name(path: &Path) -> Option<&'static str> {
    let ext = extension_lower(path);
    match ext.as_str() {
        "png" | "jpg" | "jpeg" | "webp" | "gif" | "bmp" | "ico" | "svg" | "tif" | "tiff"
        | "avif" => Some("image"),
        "mp4" | "mkv" | "webm" | "avi" | "mov" | "m4v" | "flv" | "wmv" | "ogv" | "mts" | "m2ts"
        | "mpg" | "mpeg" | "3gp" => Some("video"),
        "mp3" | "flac" | "wav" | "ogg" | "opus" | "m4a" | "aac" => Some("audio"),
        "pdf" => Some("pdf"),
        "txt" | "md" | "markdown" | "rst" | "rs" | "qml" | "js" | "mjs" | "cjs" | "jsx" | "ts"
        | "tsx" | "json" | "jsonc" | "py" | "sh" | "bash" | "zsh" | "fish" | "c" | "h" | "cpp"
        | "hpp" | "cc" | "cxx" | "go" | "rb" | "java" | "kt" | "swift" | "css" | "scss" | "less"
        | "html" | "htm" | "xml" | "yaml" | "yml" | "toml" | "ini" | "conf" | "cfg" | "env"
        | "log" | "csv" | "tsv" | "sql" | "lua" | "nix" | "cmake" | "diff" | "patch" | "service"
        | "desktop" | "lock" | "glsl" | "vert" | "frag" | "zig" | "vim" => Some("text"),
        _ if known_text_filename(path) => Some("text"),
        _ => None,
    }
}

fn looks_like_text(path: &Path) -> bool {
    let Ok(mut file) = File::open(path) else {
        return false;
    };
    let mut sample = [0u8; 4096];
    let Ok(n) = file.read(&mut sample) else {
        return false;
    };
    if n == 0 {
        return true;
    }
    let slice = &sample[..n];
    if slice.contains(&0) {
        return false;
    }
    match std::str::from_utf8(slice) {
        Ok(_) => true,
        Err(e) => e.error_len().is_none(), // partial UTF-8 sequence at end of 4K sample is fine
    }
}

fn classify_file(path: &Path) -> &'static str {
    if let Some(kind) = classify_by_name(path) {
        return kind;
    }
    if looks_like_text(path) {
        "text"
    } else {
        "unsupported"
    }
}

fn read_text_preview(path: &Path, total_size: u64) -> Result<(String, usize, bool), String> {
    let file = File::open(path).map_err(|e| format!("No se pudo leer el archivo: {e}"))?;
    let mut buf = Vec::with_capacity((total_size as usize).min(MAX_TEXT_BYTES + 1));
    file.take((MAX_TEXT_BYTES + 1) as u64)
        .read_to_end(&mut buf)
        .map_err(|e| format!("Error al leer el archivo: {e}"))?;
    let truncated = buf.len() > MAX_TEXT_BYTES;
    if truncated {
        buf.truncate(MAX_TEXT_BYTES);
    }
    let content = match String::from_utf8(buf) {
        Ok(s) => s,
        Err(e) => {
            let valid_up_to = e.utf8_error().valid_up_to();
            let bytes = e.into_bytes();
            if truncated && valid_up_to > 0 && bytes.len() - valid_up_to <= 4 {
                String::from_utf8_lossy(&bytes[..valid_up_to]).into_owned()
            } else {
                String::from_utf8_lossy(&bytes).into_owned()
            }
        }
    };
    let line_count = if content.is_empty() {
        0
    } else {
        content.lines().count().max(1)
    };
    Ok((content, line_count, truncated))
}

fn parse_pdfinfo(stdout: &str) -> (u32, String, String, String) {
    let mut pages = 0u32;
    let mut title = String::new();
    let mut author = String::new();
    let mut page_size = String::new();
    for line in stdout.lines() {
        let Some((key, val)) = line.split_once(':') else {
            continue;
        };
        let value = val.trim();
        match key.trim() {
            "Pages" => {
                if let Ok(n) = value.parse::<u32>() {
                    pages = n;
                }
            }
            "Title" => title = value.to_string(),
            "Author" => author = value.to_string(),
            "Page size" => page_size = value.to_string(),
            _ => {}
        }
    }
    (pages, title, author, page_size)
}

fn inspect_pdf(path: &Path) -> (u32, String, String, String, bool) {
    match Command::new("pdfinfo")
        .arg(path)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .output()
    {
        Ok(out) if out.status.success() => {
            let text = String::from_utf8_lossy(&out.stdout);
            let (pages, title, author, size) = parse_pdfinfo(&text);
            (pages, title, author, size, true)
        }
        Ok(_) => (0, String::new(), String::new(), String::new(), true),
        Err(_) => (0, String::new(), String::new(), String::new(), false),
    }
}

fn format_unix_mode(mode: u32) -> String {
    let bits = mode & 0o777;
    let mut s = String::with_capacity(9);
    for shift in [6, 3, 0] {
        let triad = (bits >> shift) & 0o7;
        s.push(if triad & 4 != 0 { 'r' } else { '-' });
        s.push(if triad & 2 != 0 { 'w' } else { '-' });
        s.push(if triad & 1 != 0 { 'x' } else { '-' });
    }
    format!("{s} ({bits:04o})")
}

fn system_time_secs(res: io::Result<std::time::SystemTime>) -> i64 {
    res.ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn collect_siblings(canonical_file: &Path, active_kind: &'static str) -> (Vec<Value>, i64) {
    let Some(parent) = canonical_file.parent() else {
        return (Vec::new(), -1);
    };
    let show_hidden = canonical_file
        .file_name()
        .and_then(|n| n.to_str())
        .map(|n| n.starts_with('.'))
        .unwrap_or(false);
    let Ok(read) = fs::read_dir(parent) else {
        return (Vec::new(), -1);
    };
    let mut items: Vec<(String, Vec<char>, String, &'static str)> = Vec::new();
    for entry in read.flatten() {
        let Ok(name) = entry.file_name().into_string() else {
            continue;
        };
        if !show_hidden && name.starts_with('.') {
            continue;
        }
        let path = entry.path();
        let Ok(meta) = fs::metadata(&path) else {
            continue;
        };
        if !meta.is_file() {
            continue;
        }
        let Ok(canon) = fs::canonicalize(&path) else {
            continue;
        };
        let Some(canon_str) = canon.to_str() else {
            continue;
        };
        let kind = if canon == canonical_file {
            active_kind
        } else {
            match classify_by_name(&canon) {
                Some(k) => k,
                None => continue,
            }
        };
        let lower_chars = name.to_lowercase().chars().collect::<Vec<_>>();
        items.push((name, lower_chars, canon_str.to_string(), kind));
    }
    items.sort_by(|a, b| natural_cmp_chars(&a.1, &b.1).then_with(|| a.0.cmp(&b.0)));

    let target_str = canonical_file.to_str().unwrap_or("");
    let raw_index = items
        .iter()
        .position(|item| item.2 == target_str)
        .map(|i| i as i64)
        .unwrap_or(-1);

    // Keep a balanced window around active file if directory has > MAX_SIBLINGS items.
    let (slice, adjusted_index) = if items.len() > MAX_SIBLINGS && raw_index >= 0 {
        let idx = raw_index as usize;
        let half = MAX_SIBLINGS / 2;
        let start = idx
            .saturating_sub(half)
            .min(items.len().saturating_sub(MAX_SIBLINGS));
        let end = (start + MAX_SIBLINGS).min(items.len());
        (&items[start..end], (idx - start) as i64)
    } else {
        let end = items.len().min(MAX_SIBLINGS);
        let idx = if raw_index >= 0 && (raw_index as usize) < end {
            raw_index
        } else {
            -1
        };
        (&items[..end], idx)
    };

    let json_items = slice
        .iter()
        .map(|(name, _, path, kind)| json!({"name": name, "path": path, "kind": kind}))
        .collect();
    (json_items, adjusted_index)
}

fn open_file(data: &Value) -> Result<Value, String> {
    let path_str = data
        .get("path")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or("Indica una ruta de archivo válida.")?;
    let raw = Path::new(path_str);
    if !raw.is_absolute() {
        return Err("La ruta debe ser absoluta.".into());
    }
    let canonical = fs::canonicalize(raw).map_err(|e| format!("{path_str}: {e}"))?;
    let meta = fs::metadata(&canonical).map_err(|e| format!("{path_str}: {e}"))?;
    if !meta.is_file() {
        return Err("La ruta seleccionada no es un archivo regular.".into());
    }
    let canonical_str = canonical
        .to_str()
        .ok_or("La ruta del archivo no es UTF-8 válida.")?;
    let name = canonical
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or(canonical_str)
        .to_string();
    let parent = canonical
        .parent()
        .and_then(Path::to_str)
        .unwrap_or("")
        .to_string();
    let ext = extension_lower(&canonical).to_uppercase();
    let size = meta.len();
    let mtime = system_time_secs(meta.modified());
    #[cfg(unix)]
    let permissions = {
        use std::os::unix::fs::PermissionsExt;
        format_unix_mode(meta.permissions().mode())
    };
    #[cfg(not(unix))]
    let permissions = String::new();

    let kind = classify_file(&canonical);
    let (siblings, sibling_index) = collect_siblings(&canonical, kind);

    let mut payload = json!({
        "name": name,
        "path": canonical_str,
        "parent": parent,
        "extension": ext,
        "kind": kind,
        "size": size,
        "mtime": mtime,
        "permissions": permissions,
        "siblings": siblings,
        "siblingIndex": sibling_index,
        "textContent": "",
        "lineCount": 0,
        "truncated": false,
        "pageCount": 0,
        "pdfTitle": "",
        "pdfAuthor": "",
        "pageSize": "",
        "pdfAvailable": true,
    });

    if kind == "text" {
        let (text_content, line_count, truncated) = read_text_preview(&canonical, size)?;
        payload["textContent"] = json!(text_content);
        payload["lineCount"] = json!(line_count);
        payload["truncated"] = json!(truncated);
    } else if kind == "pdf" {
        let (page_count, pdf_title, pdf_author, page_size, available) = inspect_pdf(&canonical);
        payload["pageCount"] = json!(page_count);
        payload["pdfTitle"] = json!(pdf_title);
        payload["pdfAuthor"] = json!(pdf_author);
        payload["pageSize"] = json!(page_size);
        payload["pdfAvailable"] = json!(available);
    }

    Ok(payload)
}

fn pdf_cache_dir() -> PathBuf {
    if let Some(cache) = std::env::var_os("XDG_CACHE_HOME").filter(|s| !s.is_empty()) {
        return PathBuf::from(cache).join("gema-visor").join("pdf-pages");
    }
    if let Some(home) = std::env::var_os("HOME").filter(|s| !s.is_empty()) {
        return PathBuf::from(home)
            .join(".cache")
            .join("gema-visor")
            .join("pdf-pages");
    }
    std::env::temp_dir().join("gema-visor-pdf-pages")
}

fn fnv1a_64(parts: &[&[u8]]) -> u64 {
    let mut hash: u64 = 0xcbf29ce484222325;
    for part in parts {
        for &byte in *part {
            hash ^= u64::from(byte);
            hash = hash.wrapping_mul(0x100000001b3);
        }
        hash ^= 0xff;
        hash = hash.wrapping_mul(0x100000001b3);
    }
    hash
}

fn pdf_page_key(canonical: &str, size: u64, mtime: i64, page: u32, dpi: u32) -> String {
    format!(
        "{:016x}",
        fnv1a_64(&[
            canonical.as_bytes(),
            &size.to_le_bytes(),
            &mtime.to_le_bytes(),
            &page.to_le_bytes(),
            &dpi.to_le_bytes(),
        ])
    )
}

fn render_pdf_page_in(path_str: &str, page: u32, dpi: u32, cache_dir: &Path) -> Result<PathBuf, String> {
    if page == 0 {
        return Err("El número de página debe ser >= 1.".into());
    }
    let dpi = dpi.clamp(MIN_PDF_DPI, MAX_PDF_DPI);
    let raw = Path::new(path_str);
    if !raw.is_absolute() {
        return Err("La ruta del PDF debe ser absoluta.".into());
    }
    let canonical = fs::canonicalize(raw).map_err(|e| format!("{path_str}: {e}"))?;
    let meta = fs::metadata(&canonical).map_err(|e| format!("{path_str}: {e}"))?;
    if !meta.is_file() {
        return Err("La ruta del PDF no es un archivo regular.".into());
    }
    let canonical_str = canonical.to_str().ok_or("Ruta PDF no es UTF-8.")?;
    let mtime = system_time_secs(meta.modified());
    let key = pdf_page_key(canonical_str, meta.len(), mtime, page, dpi);
    let out_png = cache_dir.join(format!("{key}.png"));
    if fs::metadata(&out_png)
        .map(|m| m.is_file() && m.len() > 0)
        .unwrap_or(false)
    {
        return Ok(out_png);
    }
    fs::create_dir_all(cache_dir).map_err(|e| format!("No se pudo crear caché PDF: {e}"))?;
    let seq = PDF_TMP_SEQ.fetch_add(1, AtomicOrdering::Relaxed);
    let tmp_prefix = cache_dir.join(format!("{key}.{}.{seq}.tmp", std::process::id()));
    let tmp_png = cache_dir.join(format!("{key}.{}.{seq}.tmp.png", std::process::id()));

    let status = Command::new("pdftoppm")
        .args([
            "-png",
            "-r",
            &dpi.to_string(),
            "-f",
            &page.to_string(),
            "-l",
            &page.to_string(),
            "-singlefile",
        ])
        .arg(&canonical)
        .arg(&tmp_prefix)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| {
            if e.kind() == io::ErrorKind::NotFound {
                "Falta pdftoppm (instala el paquete poppler para ver PDF).".to_string()
            } else {
                format!("No se pudo ejecutar pdftoppm: {e}")
            }
        })?;

    if !status.status.success()
        || !fs::metadata(&tmp_png)
            .map(|m| m.is_file() && m.len() > 0)
            .unwrap_or(false)
    {
        let _ = fs::remove_file(&tmp_png);
        let msg = String::from_utf8_lossy(&status.stderr).trim().to_string();
        return Err(if msg.is_empty() {
            format!("No se pudo renderizar la página {page} del PDF.")
        } else {
            msg
        });
    }

    if fs::rename(&tmp_png, &out_png).is_err() {
        let _ = fs::remove_file(&tmp_png);
        if !fs::metadata(&out_png)
            .map(|m| m.is_file() && m.len() > 0)
            .unwrap_or(false)
        {
            return Err("No se pudo guardar la página renderizada en caché.".into());
        }
    }
    Ok(out_png)
}

struct PdfJob {
    generation: u64,
    path: String,
    page: u32,
    dpi: u32,
}

struct PdfQueue {
    generation: u64,
    jobs: VecDeque<PdfJob>,
    shutdown: bool,
}

struct PdfWorker {
    state: Arc<(Mutex<PdfQueue>, Condvar)>,
    out: Arc<Mutex<io::Stdout>>,
    cache_dir: PathBuf,
    threads: Mutex<Vec<JoinHandle<()>>>,
}

impl PdfWorker {
    fn new(out: Arc<Mutex<io::Stdout>>, cache_dir: PathBuf) -> Self {
        Self {
            state: Arc::new((
                Mutex::new(PdfQueue {
                    generation: 0,
                    jobs: VecDeque::new(),
                    shutdown: false,
                }),
                Condvar::new(),
            )),
            out,
            cache_dir,
            threads: Mutex::new(Vec::new()),
        }
    }

    fn ensure_started(&self) {
        let mut threads = self.threads.lock().unwrap();
        if !threads.is_empty() {
            return;
        }
        for _ in 0..2 {
            let state = Arc::clone(&self.state);
            let out = Arc::clone(&self.out);
            let cache_dir = self.cache_dir.clone();
            threads.push(thread::spawn(move || loop {
                let job = {
                    let (lock, cvar) = &*state;
                    let mut guard = lock.lock().unwrap();
                    while guard.jobs.is_empty() && !guard.shutdown {
                        guard = cvar.wait(guard).unwrap();
                    }
                    if guard.shutdown {
                        return;
                    }
                    let Some(j) = guard.jobs.pop_front() else {
                        continue;
                    };
                    if j.generation != guard.generation {
                        continue;
                    }
                    j
                };
                let result = render_pdf_page_in(&job.path, job.page, job.dpi, &cache_dir);
                let still_current = {
                    let guard = state.0.lock().unwrap();
                    !guard.shutdown && guard.generation == job.generation
                };
                if !still_current {
                    continue;
                }
                let payload = match result {
                    Ok(img_path) => event(
                        "pdf.pageRendered",
                        json!({
                            "generation": job.generation,
                            "path": job.path,
                            "page": job.page,
                            "dpi": job.dpi,
                            "imagePath": img_path.to_str().unwrap_or("")
                        }),
                    ),
                    Err(msg) => event(
                        "pdf.pageError",
                        json!({
                            "generation": job.generation,
                            "path": job.path,
                            "page": job.page,
                            "message": msg
                        }),
                    ),
                };
                if let Ok(mut guard) = out.lock() {
                    let _ = emit(&mut *guard, &payload);
                }
            }));
        }
    }

    fn enqueue(&self, generation: u64, path: String, page: u32, dpi: u32, reset: bool) {
        self.ensure_started();
        let (lock, cvar) = &*self.state;
        let mut guard = lock.lock().unwrap();
        if reset || generation > guard.generation {
            guard.generation = generation;
            guard.jobs.clear();
        }
        guard.jobs.push_back(PdfJob {
            generation,
            path,
            page,
            dpi,
        });
        cvar.notify_all();
    }
}

impl Drop for PdfWorker {
    fn drop(&mut self) {
        {
            let (lock, cvar) = &*self.state;
            let mut guard = lock.lock().unwrap();
            guard.shutdown = true;
            guard.jobs.clear();
            cvar.notify_all();
        }
        if let Ok(mut threads) = self.threads.lock() {
            for handle in threads.drain(..) {
                let _ = handle.join();
            }
        }
    }
}

fn parse_pdf_render_req(data: &Value) -> Result<(u64, String, u32, u32, bool), String> {
    let obj = data.as_object().ok_or("data debe ser un objeto")?;
    let generation = obj.get("generation").and_then(Value::as_u64).unwrap_or(1);
    let path = obj
        .get("path")
        .and_then(Value::as_str)
        .filter(|s| !s.is_empty())
        .ok_or("path debe ser una cadena no vacía")?
        .to_string();
    let page = obj
        .get("page")
        .and_then(Value::as_u64)
        .filter(|&p| p >= 1 && p <= u32::MAX as u64)
        .ok_or("page debe ser un entero >= 1")? as u32;
    let dpi = obj
        .get("dpi")
        .and_then(Value::as_u64)
        .unwrap_or(150)
        .clamp(MIN_PDF_DPI as u64, MAX_PDF_DPI as u64) as u32;
    let reset = obj.get("reset").and_then(Value::as_bool).unwrap_or(false);
    Ok((generation, path, page, dpi, reset))
}

fn open_external(data: &Value) -> Result<Value, String> {
    let path_str = data
        .get("path")
        .and_then(Value::as_str)
        .filter(|s| !s.is_empty())
        .ok_or("path debe ser una cadena no vacía")?;
    let path = Path::new(path_str);
    if !path.is_absolute() || !path.exists() {
        return Err("El archivo no existe.".into());
    }
    let mut child = Command::new("xdg-open")
        .arg(path)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("No se pudo lanzar xdg-open: {e}"))?;
    thread::spawn(move || {
        let _ = child.wait();
    });
    Ok(event("viewer.externalOpened", json!({"path": path_str})))
}

fn handle(line: &str, pdf_worker: Option<&PdfWorker>) -> Value {
    let result = (|| -> Result<Value, String> {
        let command: Value =
            serde_json::from_str(line).map_err(|e| format!("JSON inválido: {e}"))?;
        if command.get("version").and_then(Value::as_u64) != Some(2) {
            return Err("Versión de protocolo no soportada (se requiere version: 2)".into());
        }
        let data = command.get("data").unwrap_or(&Value::Null);
        match command.get("type").and_then(Value::as_str) {
            Some("app.check") => Ok(event("app.checked", json!({"ok": true, "engine": "rust"}))),
            Some("viewer.open") => Ok(event("viewer.opened", open_file(data)?)),
            Some("viewer.openExternal") => open_external(data),
            Some("pdf.renderPage") => {
                let (generation, path, page, dpi, reset) = parse_pdf_render_req(data)?;
                if let Some(worker) = pdf_worker {
                    worker.enqueue(generation, path.clone(), page, dpi, reset);
                }
                Ok(event(
                    "pdf.pageQueued",
                    json!({"generation": generation, "path": path, "page": page, "dpi": dpi}),
                ))
            }
            _ => Err("Acción no reconocida por el motor Visor".into()),
        }
    })();
    result.unwrap_or_else(|message| event("error", json!({"message": message})))
}

fn emit(out: &mut impl Write, value: &Value) -> io::Result<()> {
    serde_json::to_writer(&mut *out, value)?;
    writeln!(out)?;
    out.flush()
}

fn main() -> io::Result<()> {
    let out = Arc::new(Mutex::new(io::stdout()));
    {
        let mut guard = out.lock().unwrap();
        emit(
            &mut *guard,
            &event(
                "app.ready",
                json!({"name": "Visor", "version": env!("CARGO_PKG_VERSION"), "engine": "rust"}),
            ),
        )?;
    }
    let pdf_worker = PdfWorker::new(Arc::clone(&out), pdf_cache_dir());
    let mut input = io::stdin().lock();
    let mut buf = Vec::new();
    loop {
        buf.clear();
        if input.read_until(b'\n', &mut buf)? == 0 {
            return Ok(());
        }
        let response = match std::str::from_utf8(&buf) {
            Ok(line) if line.trim().is_empty() => continue,
            Ok(line) => handle(line, Some(&pdf_worker)),
            Err(_) => event("error", json!({"message": "Entrada no es UTF-8 válida"})),
        };
        let mut guard = out.lock().unwrap();
        emit(&mut *guard, &response)?;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::AtomicUsize;
    static NEXT: AtomicUsize = AtomicUsize::new(0);

    struct Temp(PathBuf);
    impl Temp {
        fn new() -> Self {
            let dir = std::env::temp_dir().join(format!(
                "visor-test-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, AtomicOrdering::Relaxed)
            ));
            fs::create_dir_all(&dir).unwrap();
            Self(dir)
        }
    }
    impl Drop for Temp {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn classify_media_and_text_types() {
        assert_eq!(classify_by_name(Path::new("/a/photo.PNG")), Some("image"));
        assert_eq!(classify_by_name(Path::new("/a/clip.mp4")), Some("video"));
        assert_eq!(classify_by_name(Path::new("/a/song.flac")), Some("audio"));
        assert_eq!(classify_by_name(Path::new("/a/doc.pdf")), Some("pdf"));
        assert_eq!(classify_by_name(Path::new("/a/main.rs")), Some("text"));
        assert_eq!(classify_by_name(Path::new("/a/Makefile")), Some("text"));
        assert_eq!(classify_by_name(Path::new("/a/archive.bin")), None);
    }

    #[test]
    fn open_text_and_binary_detection_and_siblings() {
        let temp = Temp::new();
        let a = temp.0.join("1_note.txt");
        let b = temp.0.join("2_photo.png");
        let c = temp.0.join("10_code.rs");
        let unknown_text = temp.0.join("plainfile");
        let bin = temp.0.join("raw.dat");
        fs::write(&a, "línea 1\nlínea 2\n").unwrap();
        fs::write(&b, b"\x89PNG\r\n\x1a\n").unwrap();
        fs::write(&c, "fn main() {}\n").unwrap();
        fs::write(&unknown_text, "texto sin extensión").unwrap();
        fs::write(&bin, b"\x00\x01\x02\xff\xfe").unwrap();

        let opened = open_file(&json!({"path": a})).unwrap();
        assert_eq!(opened["kind"], "text");
        assert_eq!(opened["lineCount"], 2);
        assert_eq!(opened["truncated"], false);
        assert_eq!(opened["siblingIndex"], 0);
        let names: Vec<&str> = opened["siblings"]
            .as_array()
            .unwrap()
            .iter()
            .map(|s| s["name"].as_str().unwrap())
            .collect();
        assert_eq!(names, ["1_note.txt", "2_photo.png", "10_code.rs"]);

        let detected = open_file(&json!({"path": unknown_text})).unwrap();
        assert_eq!(detected["kind"], "text");

        let unsupported = open_file(&json!({"path": bin})).unwrap();
        assert_eq!(unsupported["kind"], "unsupported");

        assert!(open_file(&json!({"path": "relative.txt"})).is_err());
        assert!(open_file(&json!({"path": &temp.0})).is_err());
    }

    #[test]
    fn parse_pdfinfo_and_cache_key() {
        let sample = "Title:          Guía Gema\nAuthor:         David\nPages:          14\nPage size:      595.28 x 841.89 pts (A4)\n";
        let (pages, title, author, size) = parse_pdfinfo(sample);
        assert_eq!(pages, 14);
        assert_eq!(title, "Guía Gema");
        assert_eq!(author, "David");
        assert!(size.contains("A4"));

        let k1 = pdf_page_key("/tmp/a.pdf", 500, 1700000000, 1, 150);
        let k2 = pdf_page_key("/tmp/a.pdf", 500, 1700000000, 2, 150);
        let k3 = pdf_page_key("/tmp/a.pdf", 500, 1700000000, 1, 200);
        assert_eq!(k1.len(), 16);
        assert_ne!(k1, k2);
        assert_ne!(k1, k3);
    }

    #[test]
    fn protocol_validation_and_pdf_queue() {
        let check = handle(r#"{"version":2,"type":"app.check"}"#, None);
        assert_eq!(check["type"], "app.checked");

        let bad_ver = handle(r#"{"version":1,"type":"app.check"}"#, None);
        assert_eq!(bad_ver["type"], "error");

        let pdf_req = handle(
            r#"{"version":2,"type":"pdf.renderPage","data":{"generation":3,"path":"/tmp/doc.pdf","page":2,"dpi":180}}"#,
            None,
        );
        assert_eq!(pdf_req["type"], "pdf.pageQueued");
        assert_eq!(pdf_req["data"]["page"], 2);
        assert_eq!(pdf_req["data"]["dpi"], 180);

        let bad_page = handle(
            r#"{"version":2,"type":"pdf.renderPage","data":{"path":"/tmp/doc.pdf","page":0}}"#,
            None,
        );
        assert_eq!(bad_page["type"], "error");
    }
}
