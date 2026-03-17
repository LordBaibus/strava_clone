import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'record_models.dart';

final recordStateProvider = StateProvider<RecordState>((ref) => const RecordState());
