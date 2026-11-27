import 'dart:convert';
import 'dart:io';
import 'package:docucraft_app/models/slide.dart';
import 'package:docucraft_app/services/pptx_export.dart';

void main() async {
  // Buat workspace dulu di GenOffice via API
  final wsClient = HttpClient();
  final wsReq = await wsClient.post('127.0.0.1', 3001, '/api/v1/workspace/open');
  wsReq.headers.contentType = ContentType.json;
  wsReq.write(jsonEncode({'topic': 'Upload Test PPTX', 'slideCount': 3}));
  final wsResp = await wsReq.close();
  final wsBody = await wsResp.transform(utf8.decoder).join();
  
  final wsJson = jsonDecode(wsBody) as Map<String, dynamic>;
  final workspaceId = wsJson['workspaceId'] as String?;
  print('Workspace: $workspaceId (HTTP ${wsResp.statusCode})');
  wsClient.close();

  if (workspaceId == null) {
    print('ERROR: Failed to open workspace');
    return;
  }

  // Export slides ke PPTX
  final slides = [
    Slide(title: 'Test Slide 1', subtitle: 'Hello from DocuCraft', backgroundGradient: 'indigo'),
    Slide(title: 'Test Slide 2', subtitle: 'Second slide', backgroundGradient: 'blue'),
    Slide(title: 'Test Slide 3', subtitle: 'Third slide', backgroundGradient: 'emerald'),
  ];

  final exporter = PptxExporter(slides: slides);
  final bytes = exporter.exportAsBytes();
  final base64 = base64Encode(bytes);

  print('📤 Exported PPTX: ${bytes.length} bytes, base64: ${base64.length} chars');

  // Upload ke GenOffice
  final client = HttpClient();
  final request = await client.post(
    '127.0.0.1', 3001, '/api/v1/workspace/import-pptx',
  );
  request.headers.contentType = ContentType.json;
  final body = jsonEncode({'workspaceId': workspaceId, 'pptx': base64});
  request.write(body);
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();

  print('📥 HTTP ${response.statusCode}');
  print('📥 Response: $responseBody');
  print('✅ Upload complete — check GenOffice terminal for logs');
  client.close();
}
