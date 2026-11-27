// DocuCraft — HTML Template Viewer (STUB untuk mobile/desktop)
// Conditional import: file ini dipakai saat kIsWeb == false.

/// No-op on mobile — tidak ada iframe
void registerHtmlViewer(String viewType, String htmlPath) {
  // Mobile tidak support HtmlElementView / iframe
  // Fallback ke TemplateRenderer JSON sudah ditangani di HtmlTemplatePreview
}
