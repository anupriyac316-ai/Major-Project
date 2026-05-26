import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import 'package:archive/archive.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with TickerProviderStateMixin {

  // ── Design tokens ───────────────────────────────────────────────
  static const Color _bg         = Color(0xFF070B14);
  static const Color _surface    = Color(0xFF0F1624);
  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _teal       = Color(0xFF00E5CC);
  static const Color _indigo     = Color(0xFF7C6FFF);
  static const Color _coral      = Color(0xFFFF6B6B);
  static const Color _gold       = Color(0xFFFFB547);
  static const Color _green      = Color(0xFF36E8A0);
  static const Color _rose       = Color(0xFFFF4D8D);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  // ── All original state unchanged ─────────────────────────────────
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController  = TextEditingController();

  List<String> _targetGroups    = ['students'];
  html.File?   _selectedFile;
  String?      _selectedFileBase64;
  String?      _selectedFileName;
  String?      _selectedFileType;

  bool _isUploading = false;

  String? editingDocId;
  String? editingGroup;

  List<Map<String, dynamic>> notifications = [];

  static const int _chunkSize = 600 * 1024;

  late AnimationController _orb1Ctrl;
  late AnimationController _orb2Ctrl;
  late AnimationController _fadeCtrl;
  late Animation<double>  _orb1Anim;
  late Animation<double>  _orb2Anim;
  late Animation<double>  _fadeAnim;

  @override
  void initState() {
    super.initState();
    _orb1Ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _orb2Ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _orb1Anim = Tween<double>(begin: 0, end: 24).animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim = Tween<double>(begin: 0, end: 18).animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    fetchNotifications();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════
  // ALL LOGIC BELOW IS 100% UNCHANGED FROM ORIGINAL
  // ════════════════════════════════════════════════════════════════

  String _compressAndEncode(Uint8List bytes) {
    final compressed = GZipEncoder().encode(bytes)!;
    return base64Encode(compressed);
  }

  Uint8List _decodeAndDecompress(String encoded) {
    final compressed = base64Decode(encoded);
    final decompressed = GZipDecoder().decodeBytes(compressed);
    return Uint8List.fromList(decompressed);
  }

  List<String> _splitIntoChunks(String data) {
    List<String> chunks = [];
    for (int i = 0; i < data.length; i += _chunkSize) {
      chunks.add(data.substring(i, i + _chunkSize > data.length ? data.length : i + _chunkSize));
    }
    return chunks;
  }

  Future<void> _saveChunks({required String group, required String docId, required String compressedBase64}) async {
    final chunks = _splitIntoChunks(compressedBase64);
    final batch  = FirebaseFirestore.instance.batch();
    for (int i = 0; i < chunks.length; i++) {
      final chunkRef = FirebaseFirestore.instance
          .collection('notifications').doc(group)
          .collection('messages').doc(docId)
          .collection('chunks').doc('chunk_$i');
      batch.set(chunkRef, {'index': i, 'data': chunks[i]});
    }
    await batch.commit();
  }

  Future<void> _deleteChunks({required String group, required String docId}) async {
    final snap = await FirebaseFirestore.instance
        .collection('notifications').doc(group)
        .collection('messages').doc(docId)
        .collection('chunks').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
  }

  Future<String?> _loadChunks({required String group, required String docId}) async {
    final snap = await FirebaseFirestore.instance
        .collection('notifications').doc(group)
        .collection('messages').doc(docId)
        .collection('chunks').orderBy('index').get();
    if (snap.docs.isEmpty) return null;
    final buffer = StringBuffer();
    for (final doc in snap.docs) buffer.write(doc.data()['data'] as String);
    return buffer.toString();
  }

  Future<void> pickFile() async {
    final uploadInput = html.FileUploadInputElement()..accept = '.pdf,.jpg,.jpeg,.png,.doc,.docx';
    uploadInput.click();
    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;
      final file   = files.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((_) {
        final bytes      = Uint8List.fromList(reader.result as List<int>);
        final compressed = _compressAndEncode(bytes);
        setState(() {
          _selectedFile       = file;
          _selectedFileName   = file.name;
          _selectedFileType   = file.type;
          _selectedFileBase64 = compressed;
        });
        final originalKB   = (bytes.length / 1024).toStringAsFixed(1);
        final compressedKB = (compressed.length / 1024).toStringAsFixed(1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("File compressed: ${originalKB}KB → ${compressedKB}KB (${_splitIntoChunks(compressed).length} chunk(s))"),
          backgroundColor: _teal.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      });
    });
  }

  Future<void> sendOrUpdateNotification() async {
    final title = _titleController.text.trim();
    final body  = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Title and message cannot be empty"),
        backgroundColor: _coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() => _isUploading = true);
    try {
      if (editingDocId != null && editingGroup != null) {
        await FirebaseFirestore.instance
            .collection('notifications').doc(editingGroup)
            .collection('messages').doc(editingDocId)
            .update({
          'title': title, 'body': body,
          'fileName': _selectedFileName, 'fileType': _selectedFileType,
          'hasFile': _selectedFileBase64 != null,
          'chunkCount': _selectedFileBase64 != null ? _splitIntoChunks(_selectedFileBase64!).length : 0,
          'timestamp': FieldValue.serverTimestamp(),
          'type': _selectedFileBase64 != null ? 'file' : 'text',
        });
        if (_selectedFileBase64 != null) {
          await _deleteChunks(group: editingGroup!, docId: editingDocId!);
          await _saveChunks(group: editingGroup!, docId: editingDocId!, compressedBase64: _selectedFileBase64!);
        }
      } else {
        for (final group in _targetGroups) {
          final docRef = await FirebaseFirestore.instance
              .collection('notifications').doc(group)
              .collection('messages').add({
            'title': title, 'body': body,
            'fileName': _selectedFileName, 'fileType': _selectedFileType,
            'hasFile': _selectedFileBase64 != null,
            'chunkCount': _selectedFileBase64 != null ? _splitIntoChunks(_selectedFileBase64!).length : 0,
            'timestamp': FieldValue.serverTimestamp(),
            'type': _selectedFileBase64 != null ? 'file' : 'text',
          });
          if (_selectedFileBase64 != null) {
            await _saveChunks(group: group, docId: docRef.id, compressedBase64: _selectedFileBase64!);
          }
        }
      }
      _titleController.clear();
      _bodyController.clear();
      setState(() {
        _selectedFile = null; _selectedFileBase64 = null;
        _selectedFileName = null; _selectedFileType = null;
        editingDocId = null; editingGroup = null; _isUploading = false;
      });
      fetchNotifications();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(editingDocId != null ? "Notification updated successfully" : "Notification sent successfully"),
        backgroundColor: _green.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error: $e"),
        backgroundColor: _coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> fetchNotifications() async {
    List<Map<String, dynamic>> all = [];
    for (final group in _targetGroups) {
      final snap = await FirebaseFirestore.instance
          .collection('notifications').doc(group)
          .collection('messages').orderBy('timestamp', descending: true).get();
      all.addAll(snap.docs.map((doc) => {'docId': doc.id, 'group': group, ...doc.data()}));
    }
    all.sort((a, b) {
      final t1 = a['timestamp'] as Timestamp?;
      final t2 = b['timestamp'] as Timestamp?;
      if (t1 == null || t2 == null) return 0;
      return t2.compareTo(t1);
    });
    setState(() => notifications = all);
  }

  Future<void> openFileFromChunks(Map<String, dynamic> n) async {
    final docId    = n['docId'] as String;
    final group    = n['group'] as String;
    final fileName = n['fileName'] as String? ?? 'attachment';
    final fileType = n['fileType'] as String? ?? 'application/octet-stream';
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Loading file, please wait..."),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
    try {
      final assembled = await _loadChunks(group: group, docId: docId);
      if (assembled == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("File not found"), backgroundColor: _coral,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      final bytes = _decodeAndDecompress(assembled);
      final blob  = html.Blob([bytes], fileType);
      final url   = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, fileName);
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Failed to open file: $e"), backgroundColor: _coral,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> deleteNotification(String group, String docId, String title) async {
    showDialog(
      context: context,
      builder: (context) => _StyledDialog(
        title: "Delete Notification",
        titleColor: _coral,
        titleIcon: Icons.delete_outline_rounded,
        content: 'Are you sure you want to delete "$title"?',
        actions: [
          _DialogBtn(label: "Cancel", onTap: () => Navigator.pop(context), filled: false),
          _DialogBtn(
            label: "Delete", accentColor: _coral,
            onTap: () async {
              await _deleteChunks(group: group, docId: docId);
              await FirebaseFirestore.instance
                  .collection('notifications').doc(group)
                  .collection('messages').doc(docId).delete();
              fetchNotifications();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text("Notification deleted successfully"),
                backgroundColor: _green.withOpacity(0.9),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
            },
          ),
        ],
      ),
    );
  }

  void editNotification(Map<String, dynamic> n) {
    setState(() {
      _titleController.text = n['title'] ?? '';
      _bodyController.text  = n['body']  ?? '';
      _selectedFileName   = n['fileName'];
      _selectedFileType   = n['fileType'];
      _selectedFileBase64 = null;
      editingDocId        = n['docId'];
      editingGroup        = n['group'];
      _selectedFile       = null;
    });
  }

  // ════════════════════════════════════════════════════════════════
  // UI
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isEditing = editingDocId != null;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [

        // Orbs
        AnimatedBuilder(
          animation: Listenable.merge([_orb1Ctrl, _orb2Ctrl]),
          builder: (_, __) => Stack(children: [
            Positioned(top: -50 + _orb1Anim.value, right: -60,
                child: _orb(240, _teal, 0.13)),
            Positioned(bottom: 100 - _orb2Anim.value, left: -60,
                child: _orb(200, _indigo, 0.14)),
            Positioned.fill(child: CustomPaint(
                painter: _DotPainter(color: _teal.withOpacity(0.04)))),
          ]),
        ),

        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(children: [

              // ── AppBar ──────────────────────────────────────────
              Container(
                color: _surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: _card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _cardBorder)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Notifications / Circulars",
                        style: TextStyle(color: _textPri, fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(isEditing ? "Editing notification" : "Send to students & staff",
                        style: const TextStyle(color: _textSec, fontSize: 11)),
                  ])),
                  if (notifications.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _teal.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _teal.withOpacity(0.25)),
                      ),
                      child: Text("${notifications.length}",
                          style: const TextStyle(color: _teal, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),

              // ── Body ────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [

                    // ── Compose card ───────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _teal.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(color: _teal.withOpacity(0.07), blurRadius: 30, offset: const Offset(0, 10)),
                          BoxShadow(color: _indigo.withOpacity(0.05), blurRadius: 50, offset: const Offset(0, 16)),
                        ],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        // Card header
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isEditing ? _gold : _teal).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: (isEditing ? _gold : _teal).withOpacity(0.25)),
                            ),
                            child: Icon(isEditing ? Icons.edit_rounded : Icons.send_rounded,
                                color: isEditing ? _gold : _teal, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(isEditing ? "Edit Notification" : "Send New Notification",
                                style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                            Text(
                              isEditing ? "Update the notification details"
                                  : "Create and send to students and staff",
                              style: const TextStyle(color: _textSec, fontSize: 11),
                            ),
                          ])),
                        ]),

                        const SizedBox(height: 20),

                        // Send To chips
                        _sectionLabel("Send To"),
                        const SizedBox(height: 10),
                        Row(children: [
                          _TargetChip(
                            label: "Students", icon: Icons.school_outlined,
                            selected: _targetGroups.contains('students'), accentColor: _teal,
                            onTap: () { setState(() { _targetGroups.contains('students') ? _targetGroups.remove('students') : _targetGroups.add('students'); fetchNotifications(); }); },
                          ),
                          const SizedBox(width: 10),
                          _TargetChip(
                            label: "Staff", icon: Icons.badge_outlined,
                            selected: _targetGroups.contains('staff'), accentColor: _indigo,
                            onTap: () { setState(() { _targetGroups.contains('staff') ? _targetGroups.remove('staff') : _targetGroups.add('staff'); fetchNotifications(); }); },
                          ),
                        ]),

                        const SizedBox(height: 20),

                        // Title
                        _sectionLabel("Title"),
                        const SizedBox(height: 8),
                        _DarkField(controller: _titleController, hint: "Enter notification title",
                            icon: Icons.title_rounded, accentColor: _teal),

                        const SizedBox(height: 16),

                        // Message
                        _sectionLabel("Message"),
                        const SizedBox(height: 8),
                        _DarkField(controller: _bodyController, hint: "Enter notification message",
                            icon: Icons.message_outlined, accentColor: _teal, maxLines: 5),

                        const SizedBox(height: 16),

                        // File picker
                        _sectionLabel("Attachment (Optional)"),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: pickFile,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF070B14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: _selectedFile != null ? _green.withOpacity(0.4) : _cardBorder),
                            ),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (_selectedFile != null ? _green : _textSec).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(Icons.attach_file_rounded,
                                    color: _selectedFile != null ? _green : _textSec, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedFile != null ? "New: ${_selectedFile!.name}"
                                      : (editingDocId != null && _selectedFileName != null)
                                      ? "Current: $_selectedFileName"
                                      : "Tap to attach a file",
                                  style: TextStyle(
                                    color: _selectedFile != null ? _green
                                        : _selectedFileName != null ? _teal : _textSec,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _teal.withOpacity(0.2)),
                                ),
                                child: const Text("PICK FILE",
                                    style: TextStyle(color: _teal, fontSize: 9,
                                        fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                              ),
                            ]),
                          ),
                        ),

                        if (_selectedFileBase64 != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _teal.withOpacity(0.06), borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _teal.withOpacity(0.15)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.info_outline_rounded, size: 14, color: _teal),
                              const SizedBox(width: 8),
                              Text(
                                "Will be saved in ${_splitIntoChunks(_selectedFileBase64!).length} chunk(s) to Firestore",
                                style: const TextStyle(fontSize: 11, color: _teal),
                              ),
                            ]),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Send/Update button
                        _isUploading
                            ? Center(child: SizedBox(width: 28, height: 28,
                            child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5,
                                backgroundColor: _teal.withOpacity(0.1))))
                            : _GlowButton(
                          label: isEditing ? "UPDATE NOTIFICATION" : "SEND NOTIFICATION",
                          icon: isEditing ? Icons.update_rounded : Icons.send_rounded,
                          accentColor: isEditing ? _gold : _teal,
                          onPressed: sendOrUpdateNotification,
                        ),

                        if (isEditing) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => setState(() {
                              editingDocId = null; editingGroup = null;
                              _titleController.clear(); _bodyController.clear();
                              _selectedFileName = null; _selectedFileType = null;
                              _selectedFileBase64 = null; _selectedFile = null;
                            }),
                            child: const Center(child: Text("Cancel Edit",
                                style: TextStyle(color: _textSec, fontSize: 12, fontWeight: FontWeight.w600))),
                          ),
                        ],
                      ]),
                    ),

                    const SizedBox(height: 28),

                    // ── Recent Notifications header ────────────
                    Row(children: [
                      Container(width: 3, height: 20,
                          decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      const Text("Recent Notifications",
                          style: TextStyle(color: _textPri, fontSize: 17, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (notifications.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _teal.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _teal.withOpacity(0.2)),
                          ),
                          child: Text("${notifications.length} total",
                              style: const TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                    ]),

                    const SizedBox(height: 14),

                    // ── Notifications list ─────────────────────
                    if (notifications.isEmpty)
                      _EmptyState(
                        icon: Icons.notifications_none_rounded,
                        message: "No Notifications Yet",
                        subtitle: _targetGroups.isEmpty
                            ? "Select target groups above"
                            : "Send your first notification to ${_targetGroups.join(', ')}",
                      )
                    else
                      Column(children: notifications.map((n) {
                        final ts         = n['timestamp'] as Timestamp?;
                        final time       = ts?.toDate();
                        final isFile     = n['type'] == 'file';
                        final chunkCount = n['chunkCount'] ?? 0;
                        final groupColor = _getGroupColor(n['group'] as String);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: groupColor.withOpacity(0.18)),
                            boxShadow: [
                              BoxShadow(color: groupColor.withOpacity(0.06),
                                  blurRadius: 14, offset: const Offset(0, 5)),
                            ],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: groupColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: groupColor.withOpacity(0.22)),
                                ),
                                child: Icon(isFile ? Icons.attach_file_rounded : Icons.notifications_rounded,
                                    size: 16, color: groupColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(n['title'] ?? '',
                                    style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: groupColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text((n['group'] as String).toUpperCase(),
                                      style: TextStyle(color: groupColor, fontSize: 9,
                                          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                                ),
                              ])),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit')   editNotification(n);
                                  if (value == 'delete') deleteNotification(n['group'], n['docId'], n['title']);
                                },
                                color: _surface,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: _cardBorder)),
                                icon: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(color: _cardBorder, borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.more_vert_rounded, size: 15, color: _textSec),
                                ),
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'edit',
                                      child: Row(children: [
                                        Icon(Icons.edit_rounded, color: _teal, size: 15),
                                        const SizedBox(width: 10),
                                        const Text("Edit", style: TextStyle(color: _textPri, fontSize: 13)),
                                      ])),
                                  PopupMenuItem(value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete_outline_rounded, color: _coral, size: 15),
                                        const SizedBox(width: 10),
                                        const Text("Delete", style: TextStyle(color: _coral, fontSize: 13)),
                                      ])),
                                ],
                              ),
                            ]),

                            const SizedBox(height: 12),
                            Text(n['body'] ?? '',
                                style: const TextStyle(color: _textSec, fontSize: 13, height: 1.5)),

                            if (isFile) ...[
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => openFileFromChunks(n),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _teal.withOpacity(0.05), borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _teal.withOpacity(0.2)),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                          color: _teal.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                      child: Icon(_getFileIcon(n['fileName'] as String?), color: _teal, size: 14),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(n['fileName'] ?? "Attachment",
                                          style: const TextStyle(color: _textPri, fontSize: 12, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis),
                                      Text("$chunkCount chunk(s) · tap to open",
                                          style: const TextStyle(color: _textSec, fontSize: 10)),
                                    ])),
                                    const Icon(Icons.open_in_new_rounded, color: _teal, size: 13),
                                  ]),
                                ),
                              ),
                            ],

                            const SizedBox(height: 10),
                            Row(children: [
                              const Icon(Icons.access_time_rounded, size: 11, color: _textSec),
                              const SizedBox(width: 4),
                              Text(
                                time != null
                                    ? "${_formatDate(time)} at ${_formatTime(time)}"
                                    : "No timestamp",
                                style: const TextStyle(color: _textSec, fontSize: 11),
                              ),
                            ]),
                          ]),
                        );
                      }).toList()),

                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(color: _textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5));

  Widget _orb(double size, Color color, double opacity) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent])));

  Color _getGroupColor(String group) {
    switch (group) {
      case 'students': return _teal;
      case 'staff':    return _indigo;
      default:         return _rose;
    }
  }

  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file_rounded;
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':              return Icons.picture_as_pdf_rounded;
      case 'jpg': case 'jpeg': case 'png': return Icons.image_rounded;
      case 'doc': case 'docx': return Icons.description_rounded;
      default:                 return Icons.insert_drive_file_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return "Today";
    if (d == today.subtract(const Duration(days: 1))) return "Yesterday";
    return "${date.day}/${date.month}/${date.year}";
  }

  String _formatTime(DateTime date) =>
      "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
}

// ── Target chip ───────────────────────────────────────────────────────
class _TargetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _textSec    = Color(0xFF7A8DB0);

  const _TargetChip({required this.label, required this.icon, required this.selected,
    required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accentColor.withOpacity(0.12) : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? accentColor.withOpacity(0.4) : _cardBorder,
              width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(selected ? Icons.check_circle_rounded : icon,
              size: 15, color: selected ? accentColor : _textSec),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(
              color: selected ? accentColor : _textSec,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── Dark field ────────────────────────────────────────────────────────
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final int maxLines;

  static const Color _bgDeep     = Color(0xFF070B14);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  const _DarkField({required this.controller, required this.hint,
    required this.icon, required this.accentColor, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller, maxLines: maxLines,
      style: const TextStyle(color: _textPri, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _textSec.withOpacity(0.5), fontSize: 12),
        prefixIcon: maxLines == 1 ? Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: accentColor, size: 15),
        ) : null,
        filled: true, fillColor: _bgDeep,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: accentColor, width: 1.5)),
        isDense: true, contentPadding: EdgeInsets.all(maxLines > 1 ? 16 : 12),
      ),
    );
  }
}

// ── Glow button ───────────────────────────────────────────────────────
class _GlowButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onPressed;

  const _GlowButton({required this.label, required this.icon,
    required this.accentColor, required this.onPressed});

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        lowerBound: 0.96, upperBound: 1.0, value: 1.0);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _ctrl,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) { _ctrl.forward(); widget.onPressed(); },
        onTapCancel: () => _ctrl.forward(),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: widget.accentColor, borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: widget.accentColor.withOpacity(0.38), blurRadius: 20, offset: const Offset(0, 8)),
              BoxShadow(color: widget.accentColor.withOpacity(0.15), blurRadius: 40, spreadRadius: 2, offset: const Offset(0, 12)),
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, size: 17, color: const Color(0xFF070B14)),
            const SizedBox(width: 10),
            Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                letterSpacing: 1.5, color: Color(0xFF070B14))),
          ]),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;

  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _textSec    = Color(0xFF7A8DB0);

  const _EmptyState({required this.icon, required this.message, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder)),
      child: Column(children: [
        Icon(icon, size: 56, color: _textSec.withOpacity(0.25)),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(color: _textSec, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: _textSec.withOpacity(0.6), fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Styled dialog ─────────────────────────────────────────────────────
class _StyledDialog extends StatelessWidget {
  final String title;
  final Color titleColor;
  final IconData titleIcon;
  final String content;
  final List<Widget> actions;

  static const Color _surface    = Color(0xFF0F1624);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  const _StyledDialog({required this.title, required this.titleColor,
    required this.titleIcon, required this.content, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: _cardBorder)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: titleColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(titleIcon, color: titleColor, size: 26),
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(content, style: const TextStyle(color: _textSec, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 22),
          Row(children: actions
              .map((a) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: a)))
              .toList()),
        ]),
      ),
    );
  }
}

// ── Dialog button ─────────────────────────────────────────────────────
class _DialogBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color accentColor;

  static const Color _teal    = Color(0xFF00E5CC);
  static const Color _textSec = Color(0xFF7A8DB0);
  static const Color _card    = Color(0xFF151E30);

  const _DialogBtn({required this.label, required this.onTap,
    this.filled = true, this.accentColor = _teal});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? accentColor : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? Colors.transparent : _textSec.withOpacity(0.2)),
        ),
        child: Center(child: Text(label,
            style: TextStyle(color: filled ? const Color(0xFF070B14) : _textSec,
                fontSize: 13, fontWeight: FontWeight.w700))),
      ),
    );
  }
}

// ── Dot painter ───────────────────────────────────────────────────────
class _DotPainter extends CustomPainter {
  final Color color;
  _DotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const s = 28.0;
    for (double x = 0; x < size.width; x += s)
      for (double y = 0; y < size.height; y += s)
        canvas.drawCircle(Offset(x, y), 1.1, p);
  }

  @override
  bool shouldRepaint(_DotPainter o) => o.color != color;
}