import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class SeatClassModel {
  final int id;
  final String name;
  final String description;
  final String seatClass;
  final double price;
  final bool isAvailable;

  SeatClassModel({
    required this.id,
    required this.name,
    required this.description,
    required this.seatClass,
    required this.price,
    required this.isAvailable,
  });

  factory SeatClassModel.fromJson(Map<String, dynamic> json) {
    return SeatClassModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      seatClass: json['seatClass'] as String? ?? 'ordinary',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  String get imageAsset {
    switch (seatClass) {
      case 'granClass':
        return 'assets/images/seat-classes/gran.png';
      case 'eksekutifDualTone':
        return 'assets/images/seat-classes/eks-dualtone.png';
      case 'green':
        return 'assets/images/seat-classes/green.png';
      case 'ekonomiNewGenDual':
        return 'assets/images/seat-classes/eko-dualtone.png';
      case 'ekonomiPremium':
        return 'assets/images/seat-classes/premium.png';
      case 'ekonomiTosca':
        return 'assets/images/seat-classes/eko-tosca.png';
      case 'ordinary':
      default:
        return 'assets/images/seat-classes/ordinary.png';
    }
  }
}

class TrainScheduleModel {
  final int id;
  final String fromTime;
  final String toTime;
  final String trainNumber;
  final String trainName;
  final String trainImageName;
  final List<SeatClassModel> seatClasses;

  TrainScheduleModel({
    required this.id,
    required this.fromTime,
    required this.toTime,
    required this.trainNumber,
    required this.trainName,
    required this.trainImageName,
    required this.seatClasses,
  });

  factory TrainScheduleModel.fromJson(Map<String, dynamic> json) {
    return TrainScheduleModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fromTime: json['fromTime'] as String? ?? '',
      toTime: json['toTime'] as String? ?? '',
      trainNumber: json['trainNumber'] as String? ?? '',
      trainName: json['trainName'] as String? ?? '',
      trainImageName: json['trainImageName'] as String? ?? 'e7-series',
      seatClasses: (json['seatClasses'] as List<dynamic>? ?? [])
          .map((e) => SeatClassModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TrainCriteriaModel {
  final int id;
  final String fromStationJPName;
  final String fromStationName;
  final String toStationJPName;
  final String toStationName;
  final List<TrainScheduleModel> trainSchedules;

  TrainCriteriaModel({
    required this.id,
    required this.fromStationJPName,
    required this.fromStationName,
    required this.toStationJPName,
    required this.toStationName,
    required this.trainSchedules,
  });

  factory TrainCriteriaModel.fromJson(Map<String, dynamic> json) {
    return TrainCriteriaModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fromStationJPName: json['fromStationJPName'] as String? ?? 'GMR',
      fromStationName: json['fromStationName'] as String? ?? 'Gambir',
      toStationJPName: json['toStationJPName'] as String? ?? 'SBI',
      toStationName: json['toStationName'] as String? ?? 'Surabaya',
      trainSchedules: (json['trainSchedules'] as List<dynamic>? ?? [])
          .map((e) => TrainScheduleModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<TrainCriteriaModel> loadFromAssets() async {
    final raw = await rootBundle.loadString('assets/data/TrainCriteria.json');
    return TrainCriteriaModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

class TransformedModelEntity {
  final String modelEntity;
  final vm.Vector3 position;
  final vm.Vector3 rotation;

  TransformedModelEntity({
    required this.modelEntity,
    required this.position,
    required this.rotation,
  });

  factory TransformedModelEntity.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>? ?? {};
    final rot = json['rotation'] as Map<String, dynamic>? ?? {};
    return TransformedModelEntity(
      modelEntity: json['modelEntity'] as String? ?? '',
      position: vm.Vector3(
        (pos['x'] as num?)?.toDouble() ?? 0,
        (pos['y'] as num?)?.toDouble() ?? 0,
        (pos['z'] as num?)?.toDouble() ?? 0,
      ),
      rotation: vm.Vector3(
        (rot['x'] as num?)?.toDouble() ?? 0,
        (rot['y'] as num?)?.toDouble() ?? 0,
        (rot['z'] as num?)?.toDouble() ?? 0,
      ),
    );
  }
}

class ReservableEntity {
  final int id;
  final String name;
  final String carNumber;
  final bool isAvailable;
  final TransformedModelEntity transformedModelEntity;

  ReservableEntity({
    required this.id,
    required this.name,
    required this.carNumber,
    required this.isAvailable,
    required this.transformedModelEntity,
  });

  factory ReservableEntity.fromJson(Map<String, dynamic> json) {
    return ReservableEntity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      carNumber: json['carNumber'] as String? ?? '',
      isAvailable: json['isAvailable'] as bool? ?? true,
      transformedModelEntity: TransformedModelEntity.fromJson(
        json['transformedModelEntity'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class SeatClassEntity {
  final int id;
  final String seatClass;
  final String name;
  final String carNumber;
  final List<ReservableEntity> reservableEntities;
  final double lowerZ;
  final double upperZ;
  final List<TransformedModelEntity> transformedModelEntities;

  SeatClassEntity({
    required this.id,
    required this.seatClass,
    required this.name,
    required this.carNumber,
    required this.reservableEntities,
    required this.lowerZ,
    required this.upperZ,
    required this.transformedModelEntities,
  });

  factory SeatClassEntity.fromJson(Map<String, dynamic> json) {
    final range = json['viewableRange'] as List<dynamic>? ?? [];
    double z0 = 0, z1 = 100;
    if (range.length >= 2) {
      z0 = ((range[0] as Map<String, dynamic>)['z'] as num?)?.toDouble() ?? 0;
      z1 = ((range[1] as Map<String, dynamic>)['z'] as num?)?.toDouble() ?? 100;
    }
    return SeatClassEntity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      seatClass: json['seatClass'] as String? ?? 'ordinary',
      name: json['name'] as String? ?? '',
      carNumber: json['carNumber'] as String? ?? '',
      reservableEntities: (json['reservableEntities'] as List<dynamic>? ?? [])
          .map((e) => ReservableEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
      lowerZ: z0 < z1 ? z0 : z1,
      upperZ: z0 > z1 ? z0 : z1,
      transformedModelEntities:
          (json['transformedModelEntities'] as List<dynamic>? ?? [])
              .map((e) => TransformedModelEntity.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class TextNodeEntity {
  final String text;
  final double fontSize;
  final String textAlignment;
  final vm.Vector3 position;
  final vm.Vector3 rotation;

  TextNodeEntity({
    required this.text,
    required this.fontSize,
    required this.textAlignment,
    required this.position,
    required this.rotation,
  });

  factory TextNodeEntity.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>? ?? {};
    final rot = json['rotation'] as Map<String, dynamic>? ?? {};
    final font = json['font'] as Map<String, dynamic>? ?? {};
    return TextNodeEntity(
      text: json['text'] as String? ?? '',
      fontSize: (font['size'] as num?)?.toDouble() ?? 0.2,
      textAlignment: json['textAlignment'] as String? ?? 'center',
      position: vm.Vector3(
        (pos['x'] as num?)?.toDouble() ?? 0,
        (pos['y'] as num?)?.toDouble() ?? 0,
        (pos['z'] as num?)?.toDouble() ?? 0,
      ),
      rotation: vm.Vector3(
        (rot['x'] as num?)?.toDouble() ?? 0,
        (rot['y'] as num?)?.toDouble() ?? 0,
        (rot['z'] as num?)?.toDouble() ?? 0,
      ),
    );
  }
}

class SeatMapModel {
  final int id;
  final String name;
  final List<SeatClassEntity> seatClassEntities;
  final List<TransformedModelEntity> transformedModelEntities;
  final List<TextNodeEntity> transformedTextModelEntities;

  SeatMapModel({
    required this.id,
    required this.name,
    required this.seatClassEntities,
    required this.transformedModelEntities,
    required this.transformedTextModelEntities,
  });

  factory SeatMapModel.fromJson(Map<String, dynamic> json) {
    return SeatMapModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      seatClassEntities: (json['seatClassEntities'] as List<dynamic>? ?? [])
          .map((e) => SeatClassEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
      transformedModelEntities:
          (json['transformedModelEntities'] as List<dynamic>? ?? [])
              .map((e) => TransformedModelEntity.fromJson(e as Map<String, dynamic>))
              .toList(),
      transformedTextModelEntities:
          (json['transformedTextModelEntities'] as List<dynamic>? ?? [])
              .map((e) => TextNodeEntity.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  static Future<SeatMapModel> loadFromAssets() async {
    final raw = await rootBundle.loadString('assets/data/SeatMap.json');
    return SeatMapModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

class BookingHeaderInformation {
  String dayOfWeek;
  String date;
  String fromStation;
  String? fromTime;
  String toStation;
  String? toTime;
  String? trainNumber;
  String? trainName;
  String? carNumber;
  String? className;
  String? seatNumber;
  String? price;

  BookingHeaderInformation({
    required this.dayOfWeek,
    required this.date,
    required this.fromStation,
    required this.toStation,
    this.fromTime,
    this.toTime,
    this.trainNumber,
    this.trainName,
    this.carNumber,
    this.className,
    this.seatNumber,
    this.price,
  });

  BookingHeaderInformation copy() => BookingHeaderInformation(
        dayOfWeek: dayOfWeek,
        date: date,
        fromStation: fromStation,
        toStation: toStation,
        fromTime: fromTime,
        toTime: toTime,
        trainNumber: trainNumber,
        trainName: trainName,
        carNumber: carNumber,
        className: className,
        seatNumber: seatNumber,
        price: price,
      );
}

class KAIFormatters {
  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  static String formatRupiah(num amount) {
    final intVal = amount.round();
    final str = intVal.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(str[i]);
    }
    return 'Rp $buf';
  }

  static String formatFullDate(DateTime d) {
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String formatWeekday(DateTime d) {
    return _weekdays[d.weekday - 1];
  }

  static ({int hour, int minute, int second}) getJSTComponents(String iso) {
    final reg = RegExp(r'T(\d{2}):(\d{2}):(\d{2})');
    final m = reg.firstMatch(iso);
    if (m != null) {
      return (
        hour: int.parse(m.group(1)!),
        minute: int.parse(m.group(2)!),
        second: int.parse(m.group(3)!),
      );
    }
    final dt = DateTime.tryParse(iso) ?? DateTime.now();
    return (hour: dt.hour, minute: dt.minute, second: dt.second);
  }

  static String formatTimeWithOffset(String iso, int offsetSec) {
    final comp = getJSTComponents(iso);
    final totalMin = comp.hour * 60 + comp.minute + (offsetSec ~/ 60);
    final h = (totalMin ~/ 60) % 24;
    final m = totalMin % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String formatDurationOffset(String fromIso, String toIso) {
    final f = getJSTComponents(fromIso);
    final t = getJSTComponents(toIso);
    final diffMin = (t.hour * 60 + t.minute) - (f.hour * 60 + f.minute);
    final hrs = diffMin ~/ 60;
    final mins = diffMin % 60;
    if (hrs > 0) return '$hrs hr';
    if (mins > 0) return '$mins min';
    return '26 min';
  }
}
