// DocuCraft CRDT FFI API — Exposed to Flutter via flutter_rust_bridge
//
// This wraps Loro CRDT engine for collaborative slide/document editing.
// All functions are synchronous (blocking) for FFI simplicity.

use flutter_rust_bridge::frb;
use loro::{LoroDoc, ExportMode, LoroValue, ToJson};
use std::sync::Arc;
use tokio::sync::Mutex;
use serde::{Deserialize, Serialize};

// ═══════════════════════════════════════════════════════════════
// OPAQUE HANDLE
// ═══════════════════════════════════════════════════════════════

#[frb(opaque)]
pub struct DocHandle {
    pub(crate) inner: Arc<Mutex<LoroDoc>>,
    pub(crate) doc_id: String,
}

impl DocHandle {
    pub fn new(doc_id: String) -> Self {
        let doc = LoroDoc::new();
        Self {
            inner: Arc::new(Mutex::new(doc)),
            doc_id,
        }
    }

    pub fn from_bytes(doc_id: String, bytes: Vec<u8>) -> Result<Self, String> {
        let doc = LoroDoc::from_snapshot(&bytes).map_err(|e| format!("Restore failed: {e}"))?;
        Ok(Self {
            inner: Arc::new(Mutex::new(doc)),
            doc_id,
        })
    }
}

// ═══════════════════════════════════════════════════════════════
// DOC LIFECYCLE
// ═══════════════════════════════════════════════════════════════

#[frb(sync)]
pub fn doc_create(doc_id: String) -> DocHandle {
    DocHandle::new(doc_id)
}

#[frb(sync)]
pub fn doc_from_snapshot(doc_id: String, bytes: Vec<u8>) -> Result<DocHandle, String> {
    DocHandle::from_bytes(doc_id, bytes)
}

#[frb(sync)]
pub fn doc_peer_id(handle: &DocHandle) -> Result<u64, String> {
    let doc = handle.inner.blocking_lock();
    Ok(doc.peer_id())
}

// ═══════════════════════════════════════════════════════════════
// META (root level)
// ═══════════════════════════════════════════════════════════════

#[frb(sync)]
pub fn doc_set_meta(handle: &DocHandle, key: String, value: String) -> Result<(), String> {
    let doc = handle.inner.blocking_lock();
    let meta = doc.get_map("meta");
    meta.insert(&key, value).map_err(|e| e.to_string())?;
    doc.commit();
    Ok(())
}

#[frb(sync)]
pub fn doc_get_meta(handle: &DocHandle, key: String) -> Result<Option<String>, String> {
    let doc = handle.inner.blocking_lock();
    let meta = doc.get_map("meta");
    Ok(meta.get(&key).map(|v| v.to_string()))
}

// ═══════════════════════════════════════════════════════════════
// SLIDES (Presentation) — MovableList of slide IDs, each slide = Map
// ═══════════════════════════════════════════════════════════════

#[frb(sync)]
pub fn doc_create_slide(handle: &DocHandle, layout: String) -> Result<String, String> {
    let doc = handle.inner.blocking_lock();
    let peer = doc.peer_id();
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
    let slide_id = format!("slide_{peer}_{ts}");

    let slides = doc.get_movable_list("slides");
    slides.push(slide_id.clone()).map_err(|e| e.to_string())?;

    let prefix = format!("slide:{slide_id}");
    let slide = doc.get_map(&prefix);
    slide.ensure_mergeable_text("title").map_err(|e| e.to_string())?;
    slide.ensure_mergeable_text("body").map_err(|e| e.to_string())?;
    slide.ensure_mergeable_list("bullets").map_err(|e| e.to_string())?;
    slide.ensure_mergeable_map("elements").map_err(|e| e.to_string())?;
    slide.ensure_mergeable_text("notes").map_err(|e| e.to_string())?;
    slide.ensure_mergeable_map("meta").map_err(|e| e.to_string())?;

    let meta = slide.get_map("meta");
    meta.set("layout", layout).map_err(|e| e.to_string())?;
    meta.set("created_by", peer.to_string()).map_err(|e| e.to_string())?;

    doc.commit();
    Ok(slide_id)
}

#[frb(sync)]
pub fn doc_delete_slide(handle: &DocHandle, slide_id: String) -> Result<(), String> {
    let doc = handle.inner.blocking_lock();
    let slides = doc.get_movable_list("slides");
    for i in 0..slides.len() {
        if let Some(val) = slides.get(i) {
            if val.to_string() == slide_id {
                slides.delete(i, 1).map_err(|e| e.to_string())?;
                doc.commit();
                return Ok(());
            }
        }
    }
    Err(format!("Slide {slide_id} not found"))
}

#[frb(sync)]
pub fn doc_get_slide_ids(handle: &DocHandle) -> Result<Vec<String>, String> {
    let doc = handle.inner.blocking_lock();
    let slides = doc.get_movable_list("slides");
    let mut ids = Vec::with_capacity(slides.len());
    for i in 0..slides.len() {
        if let Some(v) = slides.get(i) {
            ids.push(v.to_string());
        }
    }
    Ok(ids)
}

#[frb(sync)]
pub fn doc_move_slide(handle: &DocHandle, from: usize, to: usize) -> Result<(), String> {
    let doc = handle.inner.blocking_lock();
    let slides = doc.get_movable_list("slides");
    slides.move_(from, to).map_err(|e| e.to_string())?;
    doc.commit();
    Ok(())
}

#[frb(sync)]
pub fn doc_set_slide_title(handle: &DocHandle, slide_id: String, title: String) -> Result<(), String> {
    let doc = handle.inner.blocking_lock();
    let slide = doc.get_map(&format!("slide:{slide_id}"));
    let text = slide.get_text("title");
    let len = text.len_unicode();
    if len > 0 { text.delete(0, len).map_err(|e| e.to_string())?; }
    text.insert(0, &title).map_err(|e| e.to_string())?;
    doc.commit();
    Ok(())
}

#[frb(sync)]
pub fn doc_get_slide_title(handle: &DocHandle, slide_id: String) -> Result<String, String> {
    let doc = handle.inner.blocking_lock();
    let slide = doc.get_map(&format!("slide:{slide_id}"));
    Ok(slide.get_text("title").to_string())
}

#[frb(sync)]
pub fn doc_set_slide_body(handle: &DocHandle, slide_id: String, body: String) -> Result<(), String> {
    let doc = handle.inner.blocking_lock();
    let slide = doc.get_map(&format!("slide:{slide_id}"));
    let text = slide.get_text("body");
    let len = text.len_unicode();
    if len > 0 { text.delete(0, len).map_err(|e| e.to_string())?; }
    text.insert(0, &body).map_err(|e| e.to_string())?;
    doc.commit();
    Ok(())
}

#[frb(sync)]
pub fn doc_get_slide_body(handle: &DocHandle, slide_id: String) -> Result<String, String> {
    let doc = handle.inner.blocking_lock();
    Ok(doc.get_map(&format!("slide:{slide_id}")).get_text("body").to_string())
}

#[frb(sync)]
pub fn doc_get_slide_layout(handle: &DocHandle, slide_id: String) -> Result<String, String> {
    let doc = handle.inner.blocking_lock();
    let slide = doc.get_map(&format!("slide:{slide_id}"));
    Ok(slide.get_map("meta").get("layout").unwrap_or(loro::LoroValue::String("title-body".into())).to_string())
}

// ═══════════════════════════════════════════════════════════════
// PAGES (Document mode)
// ═══════════════════════════════════════════════════════════════

#[frb(sync)]
pub fn doc_create_page(handle: &DocHandle) -> Result<String, String> {
    let doc = handle.inner.blocking_lock();
    let peer = doc.peer_id();
    let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
    let page_id = format!("page_{peer}_{ts}");

    let pages = doc.get_movable_list("pages");
    pages.push(page_id.clone()).map_err(|e| e.to_string())?;

    let prefix = format!("page:{page_id}");
    let page = doc.get_map(&prefix);
    page.ensure_mergeable_text("content").map_err(|e| e.to_string())?;
    page.ensure_mergeable_list("headings").map_err(|e| e.to_string())?;
    page.ensure_mergeable_map("elements").map_err(|e| e.to_string())?;

    doc.commit();
    Ok(page_id)
}

#[frb(sync)]
pub fn doc_get_page_ids(handle: &DocHandle) -> Result<Vec<String>, String> {
    let doc = handle.inner.blocking_lock();
    let pages = doc.get_movable_list("pages");
    let mut ids = Vec::with_capacity(pages.len());
    for i in 0..pages.len() {
        if let Some(v) = pages.get(i) { ids.push(v.to_string()); }
    }
    Ok(ids)
}

#[frb(sync)]
pub fn doc_set_page_content(handle: &DocHandle, page_id: String, content: String) -> Result<(), String> {
    let doc = handle.inner.blocking_lock();
    let page = doc.get_map(&format!("page:{page_id}"));
    let text = page.get_text("content");
    let len = text.len_unicode();
    if len > 0 { text.delete(0, len).map_err(|e| e.to_string())?; }
    text.insert(0, &content).map_err(|e| e.to_string())?;
    doc.commit();
    Ok(())
}

#[frb(sync)]
pub fn doc_get_page_content(handle: &DocHandle, page_id: String) -> Result<String, String> {
    let doc = handle.inner.blocking_lock();
    Ok(doc.get_map(&format!("page:{page_id}")).get_text("content").to_string())
}

// ═══════════════════════════════════════════════════════════════
// SYNC (Export/Import binary updates)
// ═══════════════════════════════════════════════════════════════

#[frb(sync)]
pub fn doc_export_snapshot(handle: &DocHandle) -> Result<Vec<u8>, String> {
    let doc = handle.inner.blocking_lock();
    doc.export(ExportMode::Snapshot).map_err(|e| e.to_string())
}

#[frb(sync)]
pub fn doc_export_update(handle: &DocHandle) -> Result<Vec<u8>, String> {
    let doc = handle.inner.blocking_lock();
    doc.export(ExportMode::all_updates()).map_err(|e| e.to_string())
}

#[frb(sync)]
pub fn doc_import(handle: &DocHandle, bytes: Vec<u8>) -> Result<(), String> {
    let doc = handle.inner.blocking_lock();
    doc.import(&bytes).map_err(|e| e.to_string())?;
    Ok(())
}

#[frb(sync)]
pub fn doc_import_batch(handle: &DocHandle, bytes: Vec<Vec<u8>>) -> Result<(), String> {
    let doc = handle.inner.blocking_lock();
    let refs: Vec<&[u8]> = bytes.iter().map(|b| b.as_slice()).collect();
    doc.import_batch(&refs).map_err(|e| e.to_string())?;
    Ok(())
}

#[frb(sync)]
pub fn doc_to_json(handle: &DocHandle) -> Result<String, String> {
    let doc = handle.inner.blocking_lock();
    let value = doc.get_deep_value();
    serde_json::to_string_pretty(&value.to_json_value()).map_err(|e| e.to_string())
}

// ═══════════════════════════════════════════════════════════════
// VERSION / TIME TRAVEL (stubs for now)
// ═══════════════════════════════════════════════════════════════

#[frb(sync)]
pub fn doc_get_version(handle: &DocHandle) -> Result<String, String> {
    let doc = handle.inner.blocking_lock();
    Ok(format!("{:?}", doc.oplog_vv()))
}

#[frb(sync)]
pub fn doc_op_count(handle: &DocHandle) -> Result<usize, String> {
    let doc = handle.inner.blocking_lock();
    Ok(doc.len_ops())
}

// ═══════════════════════════════════════════════════════════════
// PRESENCE (ephemeral cursors)
// ═══════════════════════════════════════════════════════════════

#[frb(sync)]
pub fn doc_set_cursor(handle: &DocHandle, container: String, position: usize) -> Result<(), String> {
    let doc = handle.inner.blocking_lock();
    let presence = doc.get_map("presence");
    let peer = doc.peer_id().to_string();
    presence.insert(&format!("{container}:{peer}"), position.to_string()).map_err(|e| e.to_string())?;
    Ok(())
}

#[frb(sync)]
pub fn doc_get_cursors(handle: &DocHandle) -> Result<Vec<(String, String, String)>, String> {
    let doc = handle.inner.blocking_lock();
    let presence = doc.get_map("presence");
    let mut result = Vec::new();
    presence.for_each(|key, val| {
        let parts: Vec<&str> = key.splitn(2, ':').collect();
        if parts.len() == 2 {
            result.push((parts[0].to_string(), parts[1].to_string(), val.to_string()));
        }
    });
    Ok(result)
}

// ═══════════════════════════════════════════════════════════════
// BASE64 HELPERS
// ═══════════════════════════════════════════════════════════════

#[frb(sync)]
pub fn bytes_to_base64(bytes: Vec<u8>) -> String {
    base64::engine::general_purpose::STANDARD.encode(&bytes)
}

#[frb(sync)]
pub fn base64_to_bytes(encoded: String) -> Result<Vec<u8>, String> {
    base64::engine::general_purpose::STANDARD.decode(&encoded).map_err(|e| e.to_string())
}