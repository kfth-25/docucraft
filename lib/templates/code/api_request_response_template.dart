// DocuCraft — API Request Response Template (Flutter-native)
// 1:1 dengan APIRequestResponseSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tema code:
//   - Background #101B37 (navy gelap)
//   - Font: Nunito Sans
//   - Card: #0F172B80, Stroke: #1D293D80
//   - Primary: #2B7FFF33 (badge bg), #51A2FF (badge text)
//   - Text: #ffffff (title), #dde5ff (endpoint), #90a1d8 (label)
//
// Tata letak:
//   p-[53px] container
//   Title: 64px font-medium lh 105% #ffffff
//   Grid: mt-22px grid-cols-2 gap-22px
//     Left col (flex gap-12):
//       Endpoint card: rounded-14 border p-12
//         Row: method badge (POST) + endpoint
//         Label header + 2 baris header
//       Request code card: rounded-18 flex-1
//         Bar nama file + konten code
//     Right col:
//       Response code card: rounded-18 flex-1
//         Bar nama file + konten code

import 'package:flutter/material.dart';

class ApiRequestResponseTemplate extends StatelessWidget {
  final String title;
  final String method;
  final String endpoint;
  final List<String> headers;
  final String requestFileName;
  final String requestContent;
  final String responseFileName;
  final String responseContent;

  const ApiRequestResponseTemplate({
    super.key,
    this.title = 'API Request / Response',
    this.method = 'POST',
    this.endpoint = '/api/v1/users/authenticate',
    this.headers = const [
      'Content-Type: application/json',
      'Authorization: Bearer <token>',
    ],
    this.requestFileName = 'request.json',
    this.requestContent =
        '{\n  "email": "user@example.com",\n  "password": "securepassword123"\n}',
    this.responseFileName = 'response.json',
    this.responseContent =
        '{\n  "success": true,\n  "user": {\n    "id": "usr_1234567890",\n    "email": "user@example.com",\n    "name": "John Doe",\n    "role": "admin"\n  },\n  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",\n  "expiresIn": 3600\n}',
  });

  // ── Code theme colors ──
  static const _bg = Color(0xFF101B37);
  static const _card = Color(0x800F172B); // #0F172B80
  static const _cardHeader = Color(0x801D293D); // #1D293D80
  static const _stroke = Color(0x801D293D); // #1D293D80
  static const _title = Color(0xFFFFFFFF);
  static const _endpoint = Color(0xFFDDE5FF);
  static const _label = Color(0xFF90A1D8);
  static const _codeText = Color(0xFFCAD5E2);
  static const _badgeBg = Color(0x332B7FFF); // #2B7FFF33
  static const _badgeText = Color(0xFF51A2FF);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;
      final pad = 53 * s; // p-[53px]

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Background ──
          Positioned.fill(
            child: Container(color: _bg),
          ),

          // ── Content container p-[53px] ──
          Positioned(
            left: pad,
            right: pad,
            top: pad,
            bottom: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title: 64px font-medium lh 105% ──
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 64 * s,
                    fontWeight: FontWeight.w500,
                    color: _title,
                    height: 1.05,
                  ),
                ),

                SizedBox(height: 22 * s), // mt-[22px]

                // ── Grid: grid-cols-2 gap-[22px] ──
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Left column: endpoint card + request card ──
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Endpoint card: rounded-[14px] border p-[12px] ──
                            Container(
                              padding: EdgeInsets.all(12 * s),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(14 * s),
                                border: Border.all(color: _stroke),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Row: method badge + endpoint (border-b pb-12)
                                  Container(
                                    padding: EdgeInsets.only(bottom: 12 * s),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: _stroke),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Method badge
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 23 * s,
                                            vertical: 10 * s,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _badgeBg,
                                            borderRadius: BorderRadius.circular(12 * s),
                                          ),
                                          child: Text(
                                            method.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 14 * s,
                                              color: _badgeText,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.06 * 14 * s, // tracking
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 20 * s), // gap-5
                                        // Endpoint
                                        Expanded(
                                          child: Text(
                                            endpoint,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 23 * s,
                                              color: _endpoint,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Headers label: mt-14 18px uppercase
                                  Padding(
                                    padding: EdgeInsets.only(top: 14 * s),
                                    child: Text(
                                      'Headers',
                                      style: TextStyle(
                                        fontSize: 18 * s,
                                        color: _label,
                                        letterSpacing: 0.08 * 18 * s,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  // Header lines: mt-10 space-y-4 18px
                                  Padding(
                                    padding: EdgeInsets.only(top: 10 * s),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        for (final h in headers)
                                          Padding(
                                            padding: EdgeInsets.only(bottom: 4 * s),
                                            child: Text(
                                              h,
                                              style: TextStyle(
                                                fontSize: 18 * s,
                                                color: _codeText,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 12 * s), // gap-[12px]

                            // ── Request code card: rounded-[18px] flex-1 ──
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(18 * s),
                                  border: Border.all(color: _stroke),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18 * s),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // File name bar
                                      Container(
                                        padding: EdgeInsets.all(14 * s),
                                        decoration: BoxDecoration(
                                          color: _cardHeader,
                                          border: Border(
                                            bottom: BorderSide(color: _stroke),
                                          ),
                                        ),
                                        child: Text(
                                          requestFileName,
                                          style: TextStyle(
                                            fontSize: 18 * s,
                                            color: _codeText,
                                          ),
                                        ),
                                      ),
                                      // Code content
                                      Expanded(
                                        child: Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.all(14 * s),
                                          alignment: Alignment.topLeft,
                                          child: SingleChildScrollView(
                                            child: Text(
                                              requestContent,
                                              style: TextStyle(
                                                fontSize: 14 * s,
                                                color: const Color(0xFFFFFFFF),
                                                fontFamily: 'monospace',
                                                height: 1.18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 22 * s), // gap-[22px]

                      // ── Right column: response code card ──
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(18 * s),
                            border: Border.all(color: _stroke),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18 * s),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // File name bar
                                Container(
                                  padding: EdgeInsets.all(14 * s),
                                  decoration: BoxDecoration(
                                    color: _cardHeader,
                                    border: Border(
                                      bottom: BorderSide(color: _stroke),
                                    ),
                                  ),
                                  child: Text(
                                    responseFileName,
                                    style: TextStyle(
                                      fontSize: 18 * s,
                                      color: _codeText,
                                    ),
                                  ),
                                ),
                                // Code content
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(14 * s),
                                    alignment: Alignment.topLeft,
                                    child: SingleChildScrollView(
                                      child: Text(
                                        responseContent,
                                        style: TextStyle(
                                          fontSize: 14 * s,
                                          color: const Color(0xFFFFFFFF),
                                          fontFamily: 'monospace',
                                          height: 1.18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
