import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:p_student/models/student_time.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class StudentTimeViewModel extends ChangeNotifier {
  List<StudentTime> studentLate = [];
  bool isLoading = false;
  List<StudentTime> filterStudents = [];
  String todayDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

  Future<void> processStudentData(String className) async {
    isLoading = true;
    // notifyListeners();
    final response = await http.get(
      Uri.parse('https://p-care-e73a4-default-rtdb.firebaseio.com/BYT.json'),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic>? data = json.decode(response.body);
      if (data != null && data.containsKey(className)) {
        final classData = data[className] as Map<String, dynamic>;
        final studentsData = classData['students'] as Map<String, dynamic>;
        studentLate = studentsData.entries
            .map((entry) => StudentTime.fromJson(entry.value))
            .where((student) =>
                DateFormat('dd/MM/yyyy').format(DateTime.parse(student.day)) ==
                todayDate)
            .toList();
        log(studentLate.length.toString());
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void filter(String filter) {}

  Future<void> exportToExcel(String className) async {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance(); // Tạo một đối tượng Excel
    Excel excel = Excel.createExcel();
    String? path = prefs.getString(className);
    Sheet sheet;

    String pathSave = "";

    if (path == null) {
      // Lần đầu tiên lưu
      final Directory appDocumentsDir =
          await getApplicationDocumentsDirectory();
      String selectedDirectory =
          await FilePicker.platform.getDirectoryPath() ?? appDocumentsDir.path;
      pathSave = '$selectedDirectory\\$className.xlsx';
      // Tạo một sheet mới với tên ngày tháng hiện tại
      sheet = excel[convertDateFormat(todayDate)];
    } else {
      File file = File(path);
      if (file.existsSync()) {
        // Đọc file excel đã có
        var bytes = file.readAsBytesSync();
         excel = Excel.decodeBytes(bytes);
        // Tạo một sheet mới với tên ngày tháng hiện tại
        sheet = excel[convertDateFormat(todayDate)];
        pathSave = path;
      } else {
        // File không tồn tại
        final Directory appDocumentsDir =
            await getApplicationDocumentsDirectory();
        String selectedDirectory =
            await FilePicker.platform.getDirectoryPath() ??
                appDocumentsDir.path;
        pathSave = '$selectedDirectory\\$className.xlsx';
        // Tạo một sheet mới với tên ngày tháng hiện tại
        sheet = excel[convertDateFormat(todayDate)];
      }
    }
// Đặt tên cho các cột
    sheet.cell(CellIndex.indexByString('A1')).value = 'STT';
    sheet.cell(CellIndex.indexByString('B1')).value = 'Họ và tên';
    sheet.cell(CellIndex.indexByString('C1')).value = 'Thời gian';
    sheet.cell(CellIndex.indexByString('D1')).value = 'Ngày';
    sheet.cell(CellIndex.indexByString('E1')).value = 'Trạng thái';

// Đặt giá trị cho từng ô
    for (var i = 0; i < studentLate.length; i++) {
      sheet.cell(CellIndex.indexByString('A${i + 2}')).value =
          studentLate[i].stt.toDouble();
      sheet.cell(CellIndex.indexByString('B${i + 2}')).value =
          studentLate[i].name;
      sheet.cell(CellIndex.indexByString('C${i + 2}')).value =
          studentLate[i].time;
      sheet.cell(CellIndex.indexByString('D${i + 2}')).value =
          studentLate[i].day;
      sheet.cell(CellIndex.indexByString('E${i + 2}')).value = "Đi muộn";
    }

// Lưu và mở file excel
    final File file = File(pathSave);
    await file.writeAsBytes(excel.encode()!, flush: true);
    OpenFile.open(pathSave);
    prefs.setString(className, pathSave);
  }

  String convertDateFormat(String inputDate) {
    List<String> dateParts = inputDate.split('/');
    String formattedDate = dateParts.join('_');
    return formattedDate;
  }
}
