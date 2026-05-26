import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExamTimetableTemplatePage extends StatefulWidget {
  const ExamTimetableTemplatePage({super.key});

  @override
  State<ExamTimetableTemplatePage> createState() =>
      _ExamTimetableTemplatePageState();
}

class _ExamTimetableTemplatePageState
    extends State<ExamTimetableTemplatePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? templateType; // master | bachelor
  List<String> years = [];

  /// Dates
  List<TextEditingController> dateControllers = [
    TextEditingController()
  ];

  /// Subjects [date][year]
  List<List<TextEditingController>> subjectControllers = [];

  /// Sessions (max 2)
  List<Map<String, TextEditingController>> sessions = [
    {
      "name": TextEditingController(text: "FN"),
      "time": TextEditingController(text: "09:30 - 12:30"),
    }
  ];

  @override
  void initState() {
    super.initState();
  }

  void _setTemplate(String type) {
    templateType = type;
    years = type == "master"
        ? ["I", "II"]
        : ["I", "II", "III"];
    _initSubjects();
    setState(() {});
  }

  void _initSubjects() {
    subjectControllers = List.generate(
      dateControllers.length,
          (_) => List.generate(years.length, (_) => TextEditingController()),
    );
  }

  void _addDate() {
    setState(() {
      dateControllers.add(TextEditingController());
      subjectControllers.add(
        List.generate(years.length, (_) => TextEditingController()),
      );
    });
  }

  void _removeDate(int index) {
    setState(() {
      dateControllers[index].dispose();
      dateControllers.removeAt(index);
      subjectControllers.removeAt(index);
    });
  }

  void _addSession() {
    if (sessions.length == 2) return;
    setState(() {
      sessions.add({
        "name": TextEditingController(),
        "time": TextEditingController(),
      });
    });
  }

  void _removeSession(int index) {
    if (sessions.length == 1) return;
    setState(() {
      sessions[index]["name"]!.dispose();
      sessions[index]["time"]!.dispose();
      sessions.removeAt(index);
    });
  }

  Future<void> _storeTemplate() async {
    if (templateType == null) return;

    await _firestore
        .collection("exam_templates")
        .doc(templateType)
        .set({
      "type": templateType,
      "years": years,
      "sessions": sessions
          .map((s) => {
        "name": s["name"]!.text,
        "time": s["time"]!.text,
      })
          .toList(),
      "timetable": List.generate(dateControllers.length, (row) {
        return {
          "date": dateControllers[row].text,
          "subjects": List.generate(
            years.length,
                (col) => subjectControllers[row][col].text,
          ),
        };
      }),
      "updatedAt": FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Template stored successfully")),
    );
  }

  @override
  void dispose() {
    for (var d in dateControllers) {
      d.dispose();
    }
    for (var row in subjectControllers) {
      for (var c in row) {
        c.dispose();
      }
    }
    for (var s in sessions) {
      s["name"]!.dispose();
      s["time"]!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Exam Timetable Template"),
        backgroundColor: Colors.pinkAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _storeTemplate,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// TEMPLATE TYPE
            DropdownButtonFormField<String>(
              value: templateType,
              hint: const Text("Select Template Type"),
              items: const [
                DropdownMenuItem(
                  value: "master",
                  child: Text("Master (M.Com / M.Sc)"),
                ),
                DropdownMenuItem(
                  value: "bachelor",
                  child: Text("Bachelor (B.Sc / B.Com / BA)"),
                ),
              ],
              onChanged: (val) => _setTemplate(val!),
            ),

            const SizedBox(height: 20),

            /// SESSIONS
            const Text(
              "Sessions",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...List.generate(sessions.length, (i) {
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: sessions[i]["name"],
                      decoration:
                      const InputDecoration(labelText: "Session"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: sessions[i]["time"],
                      decoration:
                      const InputDecoration(labelText: "Time"),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle),
                    onPressed: () => _removeSession(i),
                  ),
                ],
              );
            }),
            if (sessions.length < 2)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addSession,
                ),
              ),

            const SizedBox(height: 20),

            /// TABLE
            if (years.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  border: TableBorder.all(),
                  columns: [
                    const DataColumn(label: Text("Date")),
                    ...years.map(
                          (y) => DataColumn(label: Text("$y Year")),
                    ),
                    const DataColumn(label: Text("")),
                  ],
                  rows: List.generate(dateControllers.length, (row) {
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: dateControllers[row],
                              decoration: const InputDecoration(
                                hintText: "DD.MM.YYYY",
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        ...List.generate(years.length, (col) {
                          return DataCell(
                            TextField(
                              controller:
                              subjectControllers[row][col],
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "Subject",
                              ),
                            ),
                          );
                        }),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeDate(row),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                ),
                onPressed: _addDate,
                icon: const Icon(Icons.add),
                label: const Text("Add Date"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
