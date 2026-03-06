import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/moi_receipt_generator.dart';
import '../../utils/network_utils.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../../services/thermal_printer_service.dart';
import 'package:flutter/foundation.dart';  // ✅ Add this for compute()
import 'package:path_provider/path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:async' show unawaited;

class CollectMoiScreen extends StatefulWidget {
  const CollectMoiScreen({super.key});

  @override
  State<CollectMoiScreen> createState() => _CollectMoiScreenState();
}

class _CollectMoiScreenState extends State<CollectMoiScreen> {
  final _supabase = Supabase.instance.client;
  // Add this state variable at the top of your state class:
  List<String> _villageSuggestions = [];
  bool _showVillageSuggestions = false;
  int _villageHighlightIndex = -1;
  int _jobHighlightIndex = -1;
  final LayerLink _villageLayerLink = LayerLink();
  OverlayEntry? _villageOverlayEntry;
  final ScrollController _villageScrollController = ScrollController();
  final ScrollController _jobScrollController = ScrollController();

  // Add these state variables:
  List<String> _jobSuggestions = [];
  bool _showJobSuggestions = false;


  // Controllers
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode(); // ✅ ADD THIS
  final _villageController = TextEditingController();
  final _livingPlaceController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();
  final _villageFocusNode = FocusNode();
  final _livingPlaceFocusNode = FocusNode();
  final _person1NameFocusNode = FocusNode();
  final _person1JobFocusNode = FocusNode();
  final _person2FocusNode = FocusNode();
  final _notesFocusNode = FocusNode();

  // Person 1 controllers (2 fields now)
  final _person1Field1Controller = TextEditingController(); // Init + Name
  final _person1Field2Controller = TextEditingController(); // Education + Job

  // Person 2 controller (combined)
  final _person2Controller = TextEditingController();

  // Denomination controllers with dropdown support
  final List<Map<String, dynamic>> _denomRows = [];
  final _formKey = GlobalKey<FormState>();

  // In state variables section, add:
  final _amountFocusNode = FocusNode();
  final _firstDenomFocusNode = FocusNode(); // For Ctrl+D shortcut

  bool _isSerialReserved = false;
  String? _reservedSerialId; // Track the reservation record ID

  // State variables
  String? _eventId;
  String? _operatorId;
  int? _serialNo;
  String _paymentMethod = 'CASH';
  bool _isUncle = false;
  bool _isLoading = true;
  String? _lockedPaymentMethod; // Add this line
  bool _skipDenomination = false;  // ADD
  bool _skipPrint = false;         // ADD
  bool _isPrinting = false;
  bool _isCollectionDetailsEditPage = false;  // ✅ ADD THIS LINE

  // Edit mode variables
  bool _isEditMode = false;
  String? _editingMoiId;
  int? _currentGroupId;
  List<Map<String, dynamic>> _groupedMois = [];
  Map<String, dynamic>? _originalData;
  // Store the original auto-filled data to track changes
  Map<String, dynamic>? _autoFilledData;

  // Event details for receipt footer
  String? _customerName;
  String? _city;
  String? _customerPhone;

  bool _isClearPressed = false;
  double _clearPressProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeDenominations();

    _person1JobFocusNode.addListener(() async {
      if (!_person1JobFocusNode.hasFocus) {
        final jobText = _person1Field2Controller.text.trim();
        print('🔔 JOB FOCUS LOST - text: "$jobText"');
        if (jobText.isNotEmpty) {
          await _saveNewJobToDatabase(jobText);
        }
      }
    });

    _villageFocusNode.addListener(() {
      if (!_villageFocusNode.hasFocus) {
        _removeVillageOverlay();
        setState(() {
          _showVillageSuggestions = false;
          _villageSuggestions = [];
          _villageHighlightIndex = -1;
        });
      }
    });

    _villageFocusNode.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final key = event.logicalKey;
      final isShift = HardwareKeyboard.instance.isShiftPressed;

      if (key == LogicalKeyboardKey.tab && !isShift && _showVillageSuggestions) {
        if (_villageHighlightIndex >= _villageSuggestions.length - 1) {
          setState(() {
            _villageSuggestions = [];
            _showVillageSuggestions = false;
            _villageHighlightIndex = -1;
          });
          FocusScope.of(context).requestFocus(_livingPlaceFocusNode);
          return KeyEventResult.handled;
        }
        // TAB down
        setState(() {
          _villageHighlightIndex = _villageHighlightIndex + 1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _villageOverlayEntry?.markNeedsBuild(); // ← REPLACE _showVillageOverlay()
          _scrollToHighlightedItem(_villageScrollController, _villageHighlightIndex);
        });
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.tab && isShift && _showVillageSuggestions) {
        if (_villageHighlightIndex <= 0) {
          setState(() {
            _villageSuggestions = [];
            _showVillageSuggestions = false;
            _villageHighlightIndex = -1;
          });
          return KeyEventResult.handled;
        }
        // SHIFT+TAB up
        setState(() {
          _villageHighlightIndex = _villageHighlightIndex - 1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _villageOverlayEntry?.markNeedsBuild(); // ← REPLACE _showVillageOverlay()
          _scrollToHighlightedItem(_villageScrollController, _villageHighlightIndex);
        });
        return KeyEventResult.handled;
      }

      if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) &&
          _showVillageSuggestions &&
          _villageHighlightIndex >= 0 &&
          _villageHighlightIndex < _villageSuggestions.length) {
        setState(() {
          _villageController.text = _villageSuggestions[_villageHighlightIndex];
          _villageController.selection = TextSelection.fromPosition(
              TextPosition(offset: _villageController.text.length));
          _villageSuggestions = [];
          _showVillageSuggestions = false;
          _villageHighlightIndex = -1;
        });
        _removeVillageOverlay();   // ← ADD THIS LINE
        FocusScope.of(context).requestFocus(_livingPlaceFocusNode);
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };

    // ── ADD HERE ──────────────────────────────────────────
    _person1JobFocusNode.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final key = event.logicalKey;
      final isShift = HardwareKeyboard.instance.isShiftPressed;

      if (key == LogicalKeyboardKey.tab && !isShift && _showJobSuggestions) {
        if (_jobHighlightIndex >= _jobSuggestions.length - 1) {
          if (_jobHighlightIndex == -1 && _person1Field2Controller.text.trim().isNotEmpty) {
            _saveNewJobToDatabase(_person1Field2Controller.text.trim());
          }
          setState(() {
            _jobSuggestions = [];
            _showJobSuggestions = false;
            _jobHighlightIndex = -1;
          });
          FocusScope.of(context).requestFocus(_person2FocusNode);
          return KeyEventResult.handled;
        }
        setState(() {
          _jobHighlightIndex = _jobHighlightIndex + 1;
        });
        // ✅ Scroll to keep highlighted item visible
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedItem(_jobScrollController, _jobHighlightIndex);
        });
        return KeyEventResult.handled;
      }

      // SHIFT+TAB → move highlight UP
      if (key == LogicalKeyboardKey.tab && isShift && _showJobSuggestions) {
        if (_jobHighlightIndex <= 0) {
          setState(() {
            _jobSuggestions = [];
            _showJobSuggestions = false;
            _jobHighlightIndex = -1;
          });
          return KeyEventResult.handled;
        }
        setState(() {
          _jobHighlightIndex = _jobHighlightIndex - 1;
        });
        // ✅ Scroll to keep highlighted item visible
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedItem(_jobScrollController, _jobHighlightIndex);
        });
        return KeyEventResult.handled;
      }

      // ENTER or SPACE → select highlighted and go to next field
      if ((key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space) &&
          _showJobSuggestions &&
          _jobHighlightIndex >= 0 &&
          _jobHighlightIndex < _jobSuggestions.length) {
        setState(() {
          _person1Field2Controller.text = _jobSuggestions[_jobHighlightIndex];
          _person1Field2Controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _person1Field2Controller.text.length));
          _jobSuggestions = [];
          _showJobSuggestions = false;
          _jobHighlightIndex = -1;
        });
        FocusScope.of(context).requestFocus(_person2FocusNode);
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };
    // ── END ADD ───────────────────────────────────────────

  } // ← this is the closing } of initState()

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _loadArguments();
    }
  }
  void _scrollToHighlightedItem(ScrollController controller, int index, {double itemHeight = 40.0}) {
    if (!controller.hasClients) return;
    const double maxVisible = 5; // ~200px / 40px per item
    final double scrollOffset = index * itemHeight;
    final double currentOffset = controller.offset;
    final double visibleEnd = currentOffset + (maxVisible * itemHeight);

    if (scrollOffset < currentOffset) {
      // Item is above visible area - scroll up
      controller.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    } else if (scrollOffset + itemHeight > visibleEnd) {
      // Item is below visible area - scroll down
      controller.animateTo(
        scrollOffset - ((maxVisible - 1) * itemHeight),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }


  void _initializeDenominations() {
    _denomRows.add({
      'selectedDenom': null, // Empty by default
      'countController': TextEditingController(),
      'denomController': TextEditingController(), // For user input
    });

    _denomRows[0]['countController'].addListener(_onDenomCountChanged);
  }

  void _onDenomCountChanged() {
    if (_paymentMethod == 'CASH') {
      setState(() {
        _updateDenominationRows();
      });
    }
  }

  void _removeVillageOverlay() {
    _villageOverlayEntry?.remove();
    _villageOverlayEntry = null;
  }

  void _showVillageOverlay() {
    _removeVillageOverlay();

    _villageOverlayEntry = OverlayEntry(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return CompositedTransformFollower(
          link: _villageLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: screenWidth - 48,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blue, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    controller: _villageScrollController,
                    child: ListView.builder(
                      controller: _villageScrollController,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _villageSuggestions.length,
                      itemBuilder: (context, index) {
                        final isHighlighted = index == _villageHighlightIndex;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _villageController.text = _villageSuggestions[index];
                              _villageController.selection =
                                  TextSelection.fromPosition(TextPosition(
                                      offset: _villageController.text.length));
                              _villageSuggestions = [];
                              _showVillageSuggestions = false;
                              _villageHighlightIndex = -1;
                            });
                            _removeVillageOverlay();
                            FocusScope.of(context).requestFocus(_livingPlaceFocusNode);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isHighlighted
                                  ? Colors.blue[100]
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                    color: Colors.grey[200]!, width: 1),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (isHighlighted)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.chevron_right,
                                        size: 14, color: Colors.blue),
                                  ),
                                Expanded(
                                  child: Text(
                                    _villageSuggestions[index],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isHighlighted
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isHighlighted
                                          ? Colors.blue[900]
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_villageOverlayEntry!);
  }

  void _updateDenominationRows() {
    if (_denomRows.isEmpty) return;

    final lastRow = _denomRows[_denomRows.length - 1];
    final count = int.tryParse(lastRow['countController'].text) ?? 0;
    final selectedDenom = lastRow['selectedDenom'];

    // If last row has denomination and count entered, add new empty row
    if (count != 0 && selectedDenom != null) {
      final controller = TextEditingController();
      controller.addListener(_onDenomCountChanged);

      setState(() {
        _denomRows.add({
          'selectedDenom': null,
          'countController': controller,
          'denomController': TextEditingController(),
        });
      });
    }
  }

  Future<void> _loadJobSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _jobSuggestions = []; _showJobSuggestions = false; });
      return;
    }
    try {
      final response = await _supabase
          .from('jobs')
          .select('job')
          .not('job', 'is', null)
          .ilike('job', '${query.trim()}%')
          .limit(10);

      List<String> suggestions = [];
      for (var row in response) {
        String job = (row['job'] ?? '').trim();
        if (job.isNotEmpty) suggestions.add(job);
      }
      setState(() {
        _jobSuggestions = suggestions;
        _showJobSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      print('Error loading job suggestions: $e');
    }
  }

  Future<void> _loadEventDetails() async {
    if (_eventId == null) return;

    try {
      final response = await _supabase
          .from('events')
          .select('customer_name, city, customer_phone')
          .eq('id', _eventId!)
          .single();

      setState(() {
        _customerName = response['customer_name'];
        _city = response['city'];
        _customerPhone = response['customer_phone'];
      });
    } catch (e) {
      print('Error loading event details: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadEventDetails,
          customMessage: 'Error loading event details',
        );
      }
    }
  }

  Future<void> _saveNewJobToDatabase(String jobName) async {
    if (jobName.trim().isEmpty) return;

    print('💾 _saveNewJobToDatabase called with: "$jobName"');

    try {
      // Check if job already exists (case-insensitive)
      final existing = await _supabase
          .from('jobs')
          .select('id, job')
          .ilike('job', jobName.trim())
          .limit(1)
          .maybeSingle();

      print('🔍 Existing check result: $existing');

      if (existing == null) {
        print('➕ Inserting new job: "$jobName"');

        final response = await _supabase
            .from('jobs')
            .insert({'job': jobName.trim()})
            .select('id, job')
            .single();

        print('✅ Successfully inserted job: $response');
      } else {
        print('⏭️ Job already exists: ${existing['job']}');
      }
    } catch (e, stack) {
      print('❌ FAILED to save job "$jobName": $e');
      print('❌ Stack: $stack');
    }
  }

  // Add this method:
  Future<void> _loadVillageSuggestions(String query) async {
    if (query.trim().isEmpty || _eventId == null) {
      setState(() {
        _villageSuggestions = [];
        _showVillageSuggestions = false;
      });
      return;
    }
    try {
      final response = await _supabase
          .from('mois')
          .select('village_name')
          .eq('event_id', _eventId!)
          .eq('is_deleted', false)
          .not('village_name', 'is', null);

      Set<String> uniqueVillages = {};
      for (var row in response) {
        String village = (row['village_name'] ?? '').trim();
        if (village.toLowerCase().startsWith(query.toLowerCase())) {
          uniqueVillages.add(village);
        }
      }

      setState(() {
        _villageSuggestions = uniqueVillages.toList()..sort();
        _showVillageSuggestions = _villageSuggestions.isNotEmpty;
      });
      if (_villageSuggestions.isNotEmpty) {
        _showVillageOverlay();
      } else {
        _removeVillageOverlay();
      }
    } catch (e) {
      print('Error loading village suggestions: $e');
    }
  }

  // ✅ NEW: Get preview serial number (for UI display only, not guaranteed)
  // ✅ REPLACE the entire function with this:
  Future<void> _loadPreviewSerialNo() async {
    if (_eventId == null) return;

    try {
      // Get highest serial_no for THIS OPERATOR only (for preview)
      final response = await _supabase
          .from('mois')
          .select('serial_no')
          .eq('event_id', _eventId!)
          .eq('is_deleted', false)
          .order('serial_no', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['serial_no'] != null) {
        setState(() {
          _serialNo = (response['serial_no'] as int) + 1;
        });
        print('✅ Preview serial (Operator $_operatorId): $_serialNo');
      } else {
        setState(() {
          _serialNo = 1;
        });
        print('⚠️ No existing records for operator, serial: 1');
      }
    } catch (e) {
      print('❌ Error getting preview serial no: $e');
      setState(() {
        _serialNo = 1;
      });
    }
  }

  // ✅ REPLACE the entire function:
  Future<int> _getPreviewGroupId() async {
    if (_eventId == null) return 1;

    try {
      // Get highest group_id from ALL operators in this event (for preview)
      final response = await _supabase
          .from('mois')
          .select('group_id')
          .eq('event_id', _eventId!)
          .eq('is_deleted', false)
          .order('group_id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['group_id'] != null) {
        int nextGroup = (response['group_id'] as int) + 1;
        print('✅ Preview group ID: $nextGroup');
        return nextGroup;
      }

      print('⚠️ No existing records, defaulting to group ID: 1');
      return 1;
    } catch (e) {
      print('❌ Error getting preview group ID: $e');
      return 1;
    }
  }

// ✅ FIX 1: Update _loadArguments to properly load skip flags from EVENT table
  Future<void> _loadArguments() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _eventId = args['id'];
      _operatorId = args['operator_id'];

      _isCollectionDetailsEditPage = args['isCollectionDetailsEditPage'] ?? false;

      // ✅ CRITICAL FIX: Always fetch skip flags from events table (not from arguments)
      // This ensures we get the latest values even in edit mode
      await _loadSkipFlagsFromEvent();

      print('🔍 Loaded skip flags from EVENT: denomination=$_skipDenomination, print=$_skipPrint');

      // ✅ Load event details for receipt footer
      await _loadEventDetails();

      if (args['edit_mode'] == true && args['moi_data'] != null) {
        _isEditMode = true;
        final moiData = args['moi_data'] as Map<String, dynamic>;
        await _loadEditData(moiData);
      } else {
        await _loadPreviewSerialNo();
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // ✅ NEW METHOD: Fetch skip flags from events table
  Future<void> _loadSkipFlagsFromEvent() async {
    if (_eventId == null) return;

    try {
      final response = await _supabase
          .from('events')
          .select('skip_denomination, skip_print')
          .eq('id', _eventId!)
          .single();

      setState(() {
        _skipDenomination = response['skip_denomination'] ?? false;
        _skipPrint = response['skip_print'] ?? false;
      });

      print('✅ Successfully loaded skip flags from events table');
    } catch (e) {
      print('❌ Error loading skip flags: $e');
      // Default to false if error
      setState(() {
        _skipDenomination = false;
        _skipPrint = false;
      });
    }
  }


  Future<void> _loadEditData(Map<String, dynamic> moiData) async {
    _originalData = Map<String, dynamic>.from(moiData);

    setState(() {
      _editingMoiId = moiData['id'];
      _serialNo = moiData['serial_no'];
      _phoneController.text = moiData['phone'] ?? '';
      _villageController.text = moiData['village_name'] ?? '';
      _livingPlaceController.text = moiData['living_place'] ?? '';
      _notesController.text = moiData['notes'] ?? '';
      _paymentMethod = moiData['payment_method'] ?? 'CASH';
      _isUncle = moiData['is_uncle'] ?? false;
      _currentGroupId = moiData['group_id'];

      if (_currentGroupId != null) {
        _lockedPaymentMethod = moiData['payment_method'] ?? 'CASH';
      }

      if (moiData['persons'] != null) {
        List<dynamic> personsList = moiData['persons'] as List;
        if (personsList.isNotEmpty) {
          var person1 = personsList[0];
          _person1Field1Controller.text = person1['name'] ?? '';
          _person1Field2Controller.text = person1['job'] ?? '';
        }
        if (personsList.length > 1) {
          var person2 = personsList[1];
          _person2Controller.text = person2['details'] ?? '';
        }
      }

      var amountValue = moiData['amount'];
      if (amountValue != null) {
        if (amountValue is double) {
          _amountController.text = amountValue.toInt().toString();
        } else {
          _amountController.text = amountValue.toString();
        }
      } else {
        _amountController.text = '0';
      }
    });

    // Load group entries first
    // ✅ FIX: Load group entries FIRST, then denominations
    if (_currentGroupId != null) {
      await _loadGroupedMois();
      print('📦 Loaded ${_groupedMois.length} grouped MOIs');

      // ✅ CRITICAL FIX: Load denominations from FIRST entry in group
      if (_paymentMethod == 'CASH' && !_skipDenomination && _groupedMois.isNotEmpty) {
        String firstEntryId = _groupedMois[0]['id'];
        print('🔍 Loading denominations from FIRST entry: $firstEntryId');
        await _loadDenominations(firstEntryId);
      }
    } else {
      // Single entry - use its own ID
      if (_paymentMethod == 'CASH' && !_skipDenomination) {
        await _loadDenominations(moiData['id']);
      }
    }
  }

  Future<void> _loadDenominations(String moiId) async {
    print('🔍 Loading denominations for MOI ID: $moiId');

    try {
      final response = await _supabase
          .from('moi_denominations')
          .select('*')
          .eq('moi_id', moiId)
          .maybeSingle();

      print('📦 Denomination response: $response');

      if (response != null) {
        for (var row in _denomRows) {
          row['countController'].dispose();
          if (row.containsKey('denomController')) {
            row['denomController'].dispose();
          }
        }
        _denomRows.clear();

        Map<int, int> savedDenoms = {
          500: response['denom_500'] ?? 0,
          200: response['denom_200'] ?? 0,
          100: response['denom_100'] ?? 0,
          50: response['denom_50'] ?? 0,
          20: response['denom_20'] ?? 0,
          10: response['denom_10'] ?? 0,
          5: response['denom_5'] ?? 0,
          1: response['denom_1'] ?? 0,
        };

        print('💰 Saved denominations: $savedDenoms');

        List<int> sortedDenoms = savedDenoms.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        for (int denom in sortedDenoms) {
          int count = savedDenoms[denom]!;

          if (count != 0) {
            print('➕ Adding row: ₹$denom × $count');

            final countController =
            TextEditingController(text: count.toString());
            countController.addListener(_onDenomCountChanged);

            final denomController =
            TextEditingController(text: denom.toString());

            _denomRows.add({
              'selectedDenom': denom,
              'countController': countController,
              'denomController': denomController,
            });
          }
        }

        print('✅ Total rows added: ${_denomRows.length}');

        // ✅ ALWAYS add empty row at the end
        final emptyCountController = TextEditingController();
        emptyCountController.addListener(_onDenomCountChanged);

        _denomRows.add({
          'selectedDenom': null,
          'countController': emptyCountController,
          'denomController': TextEditingController(),
        });

        setState(() {});
      } else {
        print('❌ No denomination record found for MOI ID: $moiId');
        _initializeDenominations();
        setState(() {});
      }
    } catch (e) {
      print('❌ Error loading denominations: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: () => _loadDenominations(moiId),
          customMessage: 'Error loading denominations',
        );
      }
      _initializeDenominations();
      setState(() {});
    }
  }

  Future<void> _loadGroupedMois() async {
    if (_currentGroupId == null) return;

    try {
      final response = await _supabase
          .from('mois')
          .select('*')
          .eq('event_id', _eventId!)
          .eq('group_id', _currentGroupId!)
          .eq('is_deleted', false)
          .order('created_at', ascending: true);

      setState(() {
        _groupedMois = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading grouped MOIs: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadGroupedMois,
          customMessage: 'Error loading grouped MOIs',
        );
      }
    }
  }

  Future<void> _loadGroupedEntryForEdit(Map<String, dynamic> moiData) async {
    _originalData = Map<String, dynamic>.from(moiData);

    setState(() {
      _editingMoiId = moiData['id'];
      _serialNo = moiData['serial_no'];
      _phoneController.text = moiData['phone'] ?? '';
      _villageController.text = moiData['village_name'] ?? '';
      _livingPlaceController.text = moiData['living_place'] ?? '';
      _notesController.text = moiData['notes'] ?? '';
      _paymentMethod = moiData['payment_method'] ?? 'CASH';
      _isUncle = moiData['is_uncle'] ?? false;
      _isEditMode = true;

      if (moiData['persons'] != null) {
        List<dynamic> personsList = moiData['persons'] as List;
        if (personsList.isNotEmpty) {
          var person1 = personsList[0];
          _person1Field1Controller.text = person1['name'] ?? '';
          _person1Field2Controller.text = person1['job'] ?? '';
        }
        if (personsList.length > 1) {
          var person2 = personsList[1];
          _person2Controller.text = person2['details'] ?? '';
        }
      }

      var amountValue = moiData['amount'];
      if (amountValue != null) {
        if (amountValue is double) {
          _amountController.text = amountValue.toInt().toString();
        } else {
          _amountController.text = amountValue.toString();
        }
      } else {
        _amountController.text = '0';
      }
    });

    // ✅ FIX: Load denominations from FIRST entry in the group (ALWAYS)
    if (_currentGroupId != null && _groupedMois.isNotEmpty) {
      if (_paymentMethod == 'CASH' && !_skipDenomination) {
        String firstEntryId = _groupedMois[0]['id'];
        print('🔍 Loading denominations from FIRST entry in group: $firstEntryId');
        await _loadDenominations(firstEntryId);
        print('✅ Loaded denominations successfully');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _checkExistingEntry() async {
    try {
      // Get the values to check
      String villageName = _villageController.text.trim().replaceAll(' ', '');
      int amount = _paymentMethod == 'CASH'
          ? _getTotalAmount()
          : int.tryParse(_amountController.text) ?? 0;

      // Parse Person 1 name
      String person1Name = _person1Field1Controller.text.trim().replaceAll(' ', '');

// Parse Person 1 job
      String person1Job = _person1Field2Controller.text.trim();

// Parse Person 2 details
      String person2Details = _person2Controller.text.trim();

      // Query all entries for this event (not deleted)
      final response = await _supabase
          .from('mois')
          .select('*')
          .eq('event_id', _eventId!)
          .eq('is_deleted', false);

      List<Map<String, dynamic>> matchingEntries = [];

      // Check each entry for matches
      for (var entry in response) {
        // Check village name
        String entryVillage = entry['village_name'] ?? '';
        if (entryVillage.toLowerCase() != villageName.toLowerCase()) continue;

        // Check amount
        var entryAmount = entry['amount'];
        int entryAmountInt = 0;
        if (entryAmount is int) {
          entryAmountInt = entryAmount;
        } else if (entryAmount is double) {
          entryAmountInt = entryAmount.toInt();
        }
        if (entryAmountInt != amount) continue;

        // Check persons
        // Check persons
        if (entry['persons'] != null) {
          List<dynamic> personsList = entry['persons'] as List;

          // Check Person 1 name and job
          if (personsList.isNotEmpty) {
            var p1 = personsList[0];
            String entryP1Name = p1['name'] ?? '';
            String entryP1Job = p1['job'] ?? '';

            if (entryP1Name.toLowerCase() != person1Name.toLowerCase())
              continue;
            if (person1Job.isNotEmpty &&
                entryP1Job.toLowerCase() != person1Job.toLowerCase()) continue;
          }

          // Check Person 2 details
          if (person2Details.isNotEmpty && personsList.length > 1) {
            var p2 = personsList[1];
            String entryP2Details = p2['details'] ?? '';

            if (entryP2Details.toLowerCase() != person2Details.toLowerCase())
              continue;
          }
        }

        // If we reach here, all fields match
        matchingEntries.add(entry);
      }

      return matchingEntries;
    } catch (e) {
      print('Error checking existing entry: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _checkExistingEntry,
          customMessage: 'Error checking existing entry',
        );
      }
      return [];
    }
  }

  Future<bool> _showExistingEntryDialog(
      List<Map<String, dynamic>> existingEntries) async {
    String serialNumbers =
    existingEntries.map((e) => 'O${e['serial_no']}').join(', ');

    // Build the complete data display
    String entryDetails = '';
    if (existingEntries.isNotEmpty) {
      var entry = existingEntries[0];

      // Show ALL fields
      entryDetails += '📍 Village: ${entry['village_name'] ?? 'N/A'}\n';
      entryDetails += '🏙️ Living Place: ${entry['living_place'] ?? 'N/A'}\n';
      entryDetails += '📞 Phone: ${entry['phone'] ?? 'N/A'}\n';
      entryDetails += '💰 Amount: ₹${entry['amount']}\n';
      entryDetails += '💳 Payment: ${entry['payment_method'] ?? 'N/A'}\n';
      entryDetails +=
      '👤 Uncle: ${(entry['is_uncle'] ?? false) ? 'Yes' : 'No'}\n';

      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          var p1 = personsList[0];
          entryDetails += '\n👤 Person 1:\n';
          entryDetails += '  Name: ${p1['name'] ?? 'N/A'}\n';
          entryDetails += '  Job: ${p1['job'] ?? 'N/A'}\n';
        }
        if (personsList.length > 1) {
          var p2 = personsList[1];
          entryDetails += '\n👤 Person 2:\n';
          entryDetails += '  Details: ${p2['details'] ?? 'N/A'}\n';
        }
      }

      if (entry['notes'] != null && entry['notes'].toString().isNotEmpty) {
        entryDetails += '\n📝 Notes: ${entry['notes']}\n';
      }
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '⚠️ Entry Already Exists!',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          // Added ScrollView for long content
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This entry already exists in Serial No: $serialNumbers',
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Existing Entry Details:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 8),
              Text(
                entryDetails,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Do you want to proceed anyway?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'DISCARD',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'PROCEED',
              style:
              TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _autoFillFromPhoneNumber(String phoneNumber) async {
    if (phoneNumber.trim().isEmpty || phoneNumber.length != 10) return;

    try {
      final response = await _supabase
          .from('mois')
          .select('*')
          .eq('phone', phoneNumber.trim())
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _autoFilledData = {
          'living_place': response['living_place'],
          'village_name': response['village_name'],
          'persons': response['persons'],
        };

        setState(() {
          if (response['living_place'] != null) {
            _livingPlaceController.text = response['living_place'];
          }
          if (response['village_name'] != null) {
            _villageController.text = response['village_name'];
          }

          if (response['persons'] != null) {
            List<dynamic> personsList = response['persons'] as List;

            if (personsList.isNotEmpty) {
              var person1 = personsList[0];
              _person1Field1Controller.text = person1['name'] ?? '';
              _person1Field2Controller.text = person1['job'] ?? '';
            }

            if (personsList.length > 1) {
              var person2 = personsList[1];
              _person2Controller.text = person2['details'] ?? '';
            }
          }
        });

        // ✅ NEW: Jump cursor to amount field after auto-fill
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(_amountFocusNode);
        });
      }
    } catch (e) {
      print('Error auto-filling from phone number: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: () => _autoFillFromPhoneNumber(phoneNumber),
          customMessage: 'Error auto-filling data',
        );
      }
    }
  }

  // Check if auto-filled data was modified
  // Check if auto-filled data was modified
  bool _hasAutoFilledDataChanged() {
    if (_autoFilledData == null) {
      print('⏭️ No auto-filled data to compare');
      return false;
    }

    // Get current data from FIRST grouped entry (not form fields, as they might be cleared)
    String currentLivingPlace = '';
    String currentVillage = '';
    String currentP1Name = '';
    String currentP1Job = '';
    String currentP2Details = '';

    if (_groupedMois.isNotEmpty) {
      var firstEntry = _groupedMois[0];
      currentLivingPlace = firstEntry['living_place'] ?? '';
      currentVillage = firstEntry['village_name'] ?? '';

      if (firstEntry['persons'] != null) {
        List<dynamic> personsList = firstEntry['persons'] as List;
        if (personsList.isNotEmpty) {
          currentP1Name = personsList[0]['name'] ?? '';
          currentP1Job = personsList[0]['job'] ?? '';
        }
        if (personsList.length > 1) {
          currentP2Details = personsList[1]['details'] ?? '';
        }
      }
    }

    print('🔍 Comparing auto-filled data:');
    print('  Living Place: "$currentLivingPlace" vs "${_autoFilledData!['living_place']}"');
    print('  Village: "$currentVillage" vs "${_autoFilledData!['village_name']}"');

    // Check if living place changed
    String originalLivingPlace = _autoFilledData!['living_place'] ?? '';
    if (currentLivingPlace != originalLivingPlace) {
      print('✅ Living place changed!');
      return true;
    }

    // Check if village name changed
    String originalVillage = _autoFilledData!['village_name'] ?? '';
    if (currentVillage != originalVillage) {
      print('✅ Village name changed!');
      return true;
    }

    // Check if person data changed
    if (_autoFilledData!['persons'] != null) {
      List<dynamic> originalPersons = _autoFilledData!['persons'] as List;

      if (originalPersons.isNotEmpty) {
        var origP1 = originalPersons[0];
        String origP1Name = origP1['name'] ?? '';
        String origP1Job = origP1['job'] ?? '';

        if (currentP1Name != origP1Name) {
          print('✅ Person 1 name changed!');
          return true;
        }
        if (currentP1Job != origP1Job) {
          print('✅ Person 1 job changed!');
          return true;
        }
      }

      if (originalPersons.length > 1) {
        var origP2 = originalPersons[1];
        String origP2Details = origP2['details'] ?? '';

        if (currentP2Details != origP2Details) {
          print('✅ Person 2 details changed!');
          return true;
        }
      }
    }

    print('❌ No changes detected');
    return false;
  }

  Future<void> _updateAllEntriesWithPhoneNumber(String phoneNumber) async {
    try {
      // ✅ FIX: Get data from FIRST GROUPED ENTRY (not from cleared form controllers)
      String? livingPlace;
      String? villageName;
      List<Map<String, dynamic>> personsData = [];

      if (_groupedMois.isNotEmpty) {
        var firstEntry = _groupedMois[0];
        livingPlace = firstEntry['living_place'];
        villageName = firstEntry['village_name'];

        // Get persons data from first entry
        if (firstEntry['persons'] != null) {
          personsData = List<Map<String, dynamic>>.from(firstEntry['persons']);
        }
      }

      print('🔄 Updating all entries with phone: $phoneNumber');
      print('📍 Living Place: $livingPlace');
      print('📍 Village Name: $villageName');
      print('👥 Persons Data: $personsData');

      // Update all entries with this phone number
      final updateData = {
        'living_place': livingPlace,
        'village_name': villageName,
        'persons': personsData,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('mois')
          .update(updateData)
          .eq('phone', phoneNumber)
          .eq('is_deleted', false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('✅ All entries with this phone number have been updated!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error updating entries: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: () => _updateAllEntriesWithPhoneNumber(phoneNumber),
          customMessage: 'Error updating entries',
        );
      }
    }
  }

  Future<bool> _showGlobalUpdateConfirmation(String phoneNumber) async {
    // Count how many entries will be affected
    int affectedCount = 0;
    try {
      final response = await _supabase
          .from('mois')
          .select('id')
          .eq('phone', phoneNumber)
          .eq('is_deleted', false);

      affectedCount = response.length;
    } catch (e) {
      print('Error counting entries: $e');
    }

    if (affectedCount <= 1) {
      // Only current entry, no need to update globally
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '📝 Update All Entries?',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have modified the auto-filled details for phone number: $phoneNumber',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ This will affect $affectedCount existing entries with this phone number!',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fields that will be updated:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text('• Village Name', style: TextStyle(fontSize: 11)),
                  const Text('• Living Place', style: TextStyle(fontSize: 11)),
                  const Text('• Person Details',
                      style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Do you want to update all existing entries with this phone number?',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'NO, ONLY THIS ENTRY',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'YES, UPDATE ALL',
              style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  int _getTotalAmount() {
    if (_paymentMethod == 'CASH') {
      int total = 0;
      for (var row in _denomRows) {
        int? denom = row['selectedDenom']; // ✅ Can be null now
        int count = int.tryParse(row['countController'].text) ?? 0;

        // ✅ Only calculate if denomination is selected
        if (denom != null && count != 0) {
          total += denom * count;
        }
      }
      return total;
    } else {
      String amountText = _amountController.text.trim();
      if (amountText.isEmpty) return 0;
      double? doubleValue = double.tryParse(amountText);
      if (doubleValue != null) {
        return doubleValue.round();
      }
      return 0;
    }
  }

  int _getTotalCount() {
    int count = 0;
    for (var row in _denomRows) {
      int rowCount = int.tryParse(row['countController'].text) ?? 0;
      int? denom = row['selectedDenom']; // ✅ Check denomination exists

      // ✅ Only count if denomination is selected and count is positive
      if (denom != null && rowCount > 0) {
        count += rowCount;
      }
    }
    return count;
  }

  bool _validatePhoneForAmountChange() {
    // Check if we're editing an existing entry (not temp)
    bool isEditingExistingEntry = _isEditMode &&
        _editingMoiId != null &&
        _originalData != null &&
        _originalData!['is_temp'] != true;

    if (!isEditingExistingEntry) return true; // Not editing existing, skip check

    // Check if amount changed
    var originalAmount = _originalData!['amount'];
    int originalAmountInt = 0;
    if (originalAmount is int) {
      originalAmountInt = originalAmount;
    } else if (originalAmount is double) {
      originalAmountInt = originalAmount.toInt();
    }

    int currentAmount = int.tryParse(_amountController.text) ?? 0;
    bool amountChanged = originalAmountInt != currentAmount;

    if (!amountChanged) return true; // Amount not changed, skip check

    // Amount changed - check if phone number exists
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📞 Phone number is mandatory when changing amount for existing entry!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return false;
    }

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📞 Phone number must be exactly 10 digits!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    return true;
  }


  Future<void> _handleGroup() async {
    // Connection check
    if (!await NetworkUtils.checkConnectionBeforeRequest(context,
        onRetry: _handleGroup)) {
      return;
    }
    final jobText = _person1Field2Controller.text.trim();
    if (jobText.isNotEmpty) {
      print('💾 Saving job on Group press: "$jobText"');
      await _saveNewJobToDatabase(jobText);
    }
    if (!_validatePhoneForAmountChange()) {
      return;
    }

    // Validation checks
    bool hasValidPerson = _person1Field1Controller.text.trim().isNotEmpty ||
        _person2Controller.text.trim().isNotEmpty;

    // Add in _handleGroup() after line 900:
    if (_villageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Village name is mandatory!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_person1Field1Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Person 1 name is mandatory!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

// The amount validation already exists, keep it

    if (!hasValidPerson) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one person with a name'),
          backgroundColor: Colors.red,
        ),
      );
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (_amountController.text.trim().isEmpty ||
        int.tryParse(_amountController.text) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount is mandatory! Please enter the amount.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // ✅ CASE 1: Editing an existing entry in MOI Details
      if (_isEditMode && _editingMoiId != null) {
        int index = _groupedMois.indexWhere((moi) => moi['id'] == _editingMoiId);
        if (index != -1) {
          setState(() {
            _groupedMois[index] = {
              ..._groupedMois[index],
              'phone': _phoneController.text.trim(),
              'village_name': _villageController.text.trim(),
              'living_place': _livingPlaceController.text.trim(),
              'notes': _notesController.text.trim(),
              'amount': int.tryParse(_amountController.text) ?? 0,
              'is_uncle': _isUncle,
              'persons': _buildPersonsData(),
              'is_modified': true,

            };
          });

          setState(() {
            _isEditMode = false;
            _editingMoiId = null;
            _originalData = null;
          });

          await _clearFormForNextEntry();
          _phoneFocusNode.requestFocus();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Entry updated in MOI Details'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
        return;  // ✅ EXIT HERE - Don't continue to CASE 2
      }

      // ✅ CASE 2: Adding NEW entry to MOI Details (in memory only - no RPC yet)
      int? groupId;
      if (_currentGroupId != null) {
        groupId = _currentGroupId!;
      } else {
        groupId = null;
      }

      // Lock payment method after first entry
      if (_groupedMois.isEmpty) {
        _lockedPaymentMethod = _paymentMethod;
      }

      // ✅ Create temporary entry (NOT SAVED TO DB)
      final tempEntry = {
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'serial_no': _serialNo,  // Preview serial (will be replaced by RPC)
        'phone': _phoneController.text.trim(),
        'village_name': _villageController.text.trim(),
        'living_place': _livingPlaceController.text.trim(),
        'notes': _notesController.text.trim(),
        'amount': int.tryParse(_amountController.text) ?? 0,
        'payment_method': _paymentMethod,
        'is_uncle': _isUncle,
        'persons': _buildPersonsData(),
        'group_id': groupId,  // ✅ Will be null for first entry, then use actual from RPC
        'is_temp': true,
      };

      setState(() {
        _currentGroupId = groupId;  // ✅ Will be null initially
        _groupedMois.add(tempEntry);
      });

      await _clearFormForNextEntry();
      await _loadPreviewSerialNo();  // ✅ Update preview for next entry

// Move focus to denomination after grouping
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_paymentMethod == 'CASH' && !_skipDenomination) {
            FocusScope.of(context).requestFocus(_firstDenomFocusNode);
          } else {
            FocusScope.of(context).requestFocus(_villageFocusNode);
          }
        });
      }

    } catch (e) {
      print('Error in group operation: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _handleGroup,
          customMessage: 'Error in group operation',
        );
      }
    }
  }

  // ✅ NEW: Check for duplicate in BOTH MOI Details AND Database
  Future<bool> _checkDuplicateInMoiDetails() async {
    try {
      // Get values to check
      String villageName = _villageController.text.trim().replaceAll(' ', '');
      int amount = int.tryParse(_amountController.text) ?? 0;
      String person1Name = _person1Field1Controller.text.trim().replaceAll(' ', '');
      String person1Job = _person1Field2Controller.text.trim();

      // ✅ STEP 1: Check in MOI Details box (local list)
      bool foundInMoiDetails = _groupedMois.any((entry) {
        // Skip if this is the entry we're editing
        if (_isEditMode && _editingMoiId != null && entry['id'] == _editingMoiId) {
          return false;
        }

        // Check village name (case-insensitive)
        String entryVillage = entry['village_name'] ?? '';
        if (entryVillage.toLowerCase() != villageName.toLowerCase()) return false;

        // Check amount
        int entryAmount = 0;
        var entryAmountValue = entry['amount'];
        if (entryAmountValue is int) {
          entryAmount = entryAmountValue;
        } else if (entryAmountValue is double) {
          entryAmount = entryAmountValue.toInt();
        } else if (entryAmountValue != null) {
          entryAmount = int.tryParse(entryAmountValue.toString()) ?? 0;
        }
        if (entryAmount != amount) return false;

        // Check persons
        if (entry['persons'] != null) {
          List<dynamic> personsList = entry['persons'] as List;

          // Check Person 1 name and job
          if (personsList.isNotEmpty) {
            var p1 = personsList[0];
            String entryP1Name = p1['name'] ?? '';
            String entryP1Job = p1['job'] ?? '';

            if (entryP1Name.toLowerCase() != person1Name.toLowerCase()) return false;
            if (person1Job.isNotEmpty && entryP1Job.toLowerCase() != person1Job.toLowerCase()) return false;
          }
        }

        // All fields match
        return true;
      });

      if (foundInMoiDetails) {
        // Show popup for MOI Details duplicate
        final shouldProceed = await _showDuplicateInMoiDetailsDialog();
        return !shouldProceed; // Return true if duplicate should prevent adding
      }

      // ✅ STEP 2: Check in Database (entire mois table for this event)
      final response = await _supabase
          .from('mois')
          .select('*')
          .eq('event_id', _eventId!)
          .eq('is_deleted', false);

      List<Map<String, dynamic>> matchingEntries = [];

      // Check each entry for matches
      for (var entry in response) {
        // Skip if this is the entry we're currently editing
        if (_isEditMode && _editingMoiId != null && entry['id'] == _editingMoiId) {
          continue;
        }

        // Check village name (case-insensitive)
        String entryVillage = entry['village_name'] ?? '';
        if (entryVillage.toLowerCase() != villageName.toLowerCase()) continue;

        // Check amount
        int entryAmount = 0;
        var entryAmountValue = entry['amount'];
        if (entryAmountValue is int) {
          entryAmount = entryAmountValue;
        } else if (entryAmountValue is double) {
          entryAmount = entryAmountValue.toInt();
        } else if (entryAmountValue is num) {
          entryAmount = entryAmountValue.toInt();
        }
        if (entryAmount != amount) continue;

        // Check persons
        if (entry['persons'] != null) {
          List<dynamic> personsList = entry['persons'] as List;

          // Check Person 1 name and job
          if (personsList.isNotEmpty) {
            var p1 = personsList[0];
            String entryP1Name = p1['name'] ?? '';
            String entryP1Job = p1['job'] ?? '';

            if (entryP1Name.toLowerCase() != person1Name.toLowerCase()) continue;

            // Only check job if current entry has a job entered
            if (person1Job.isNotEmpty &&
                entryP1Job.toLowerCase() != person1Job.toLowerCase()) continue;
          }
        }

        // All fields match - add to matching entries
        matchingEntries.add(entry);
      }

      if (matchingEntries.isNotEmpty) {
        // Show popup with all matching entries from database
        final shouldProceed = await _showDuplicateInDatabaseDialog(matchingEntries);
        return !shouldProceed; // Return true if duplicate should prevent adding
      }

      return false; // No duplicate found in either MOI Details or Database
    } catch (e) {
      print('Error checking duplicate: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _checkDuplicateInMoiDetails,
          customMessage: 'Error checking for duplicates',
        );
      }
      return false;
    }
  }


// ✅ Dialog for MOI Details duplicate (shows simpler message)
  Future<bool> _showDuplicateInMoiDetailsDialog() async {
    // Build current entry details
    String entryDetails = '';
    entryDetails += '📍 Village: ${_villageController.text.trim()}\n';
    entryDetails += '💰 Amount: ₹${_amountController.text.trim()}\n';
    entryDetails += '\n👤 Person 1:\n';
    entryDetails += '  Name: ${_person1Field1Controller.text.trim()}\n';
    if (_person1Field2Controller.text.trim().isNotEmpty) {
      entryDetails += '  Job: ${_person1Field2Controller.text.trim()}\n';
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '⚠️ Entry Already Exists in MOI Details!',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This entry already exists in the MOI Details box above with the same:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• Village Name', style: TextStyle(fontSize: 11)),
                    const Text('• Amount', style: TextStyle(fontSize: 11)),
                    const Text('• Person 1 Name', style: TextStyle(fontSize: 11)),
                    if (_person1Field2Controller.text.trim().isNotEmpty)
                      const Text('• Person 1 Job', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Current Entry Details:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 8),
              Text(
                entryDetails,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Do you want to add this entry anyway?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'ADD ANYWAY',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

// ✅ Dialog for Database duplicate (shows detailed comparison)
  Future<bool> _showDuplicateInDatabaseDialog(
      List<Map<String, dynamic>> existingEntries) async {

    // Get serial numbers of all matching entries
    String serialNumbers = existingEntries.map((e) => 'O${e['serial_no']}').join(', ');

    // Build current entry details
    String currentEntryDetails = '';
    currentEntryDetails += '📍 Village: ${_villageController.text.trim()}\n';
    currentEntryDetails += '💰 Amount: ₹${_amountController.text.trim()}\n';
    currentEntryDetails += '\n👤 Person 1:\n';
    currentEntryDetails += '  Name: ${_person1Field1Controller.text.trim()}\n';
    if (_person1Field2Controller.text.trim().isNotEmpty) {
      currentEntryDetails += '  Job: ${_person1Field2Controller.text.trim()}\n';
    }

    // Build details of first matching entry (as example)
    String existingEntryDetails = '';
    if (existingEntries.isNotEmpty) {
      var entry = existingEntries[0];

      existingEntryDetails += '📍 Village: ${entry['village_name'] ?? 'N/A'}\n';
      existingEntryDetails += '🏙️ Living Place: ${entry['living_place'] ?? 'N/A'}\n';
      existingEntryDetails += '📞 Phone: ${entry['phone'] ?? 'N/A'}\n';
      existingEntryDetails += '💰 Amount: ₹${entry['amount']}\n';
      existingEntryDetails += '💳 Payment: ${entry['payment_method'] ?? 'N/A'}\n';
      existingEntryDetails += '👤 Uncle: ${(entry['is_uncle'] ?? false) ? 'Yes' : 'No'}\n';

      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          var p1 = personsList[0];
          existingEntryDetails += '\n👤 Person 1:\n';
          existingEntryDetails += '  Name: ${p1['name'] ?? 'N/A'}\n';
          existingEntryDetails += '  Job: ${p1['job'] ?? 'N/A'}\n';
        }
        if (personsList.length > 1) {
          var p2 = personsList[1];
          existingEntryDetails += '\n👤 Person 2:\n';
          existingEntryDetails += '  Details: ${p2['details'] ?? 'N/A'}\n';
        }
      }

      if (entry['notes'] != null && entry['notes'].toString().isNotEmpty) {
        existingEntryDetails += '\n📝 Notes: ${entry['notes']}\n';
      }
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '⚠️ Duplicate Entry Found in Database!',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existingEntries.length == 1
                    ? 'This entry already exists in Serial No: $serialNumbers'
                    : 'This entry already exists in ${existingEntries.length} records: $serialNumbers',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Matching Fields:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.red),
                    ),
                    const SizedBox(height: 4),
                    const Text('• Village Name', style: TextStyle(fontSize: 11)),
                    const Text('• Amount', style: TextStyle(fontSize: 11)),
                    const Text('• Person 1 Name', style: TextStyle(fontSize: 11)),
                    if (_person1Field2Controller.text.trim().isNotEmpty)
                      const Text('• Person 1 Job', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Current Entry:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 8),
              Text(
                currentEntryDetails,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Existing Entry Details:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 8),
              Text(
                existingEntryDetails,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Do you want to add this entry anyway?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'ADD ANYWAY',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ✅ NEW: Helper method to build persons data
  List<Map<String, dynamic>> _buildPersonsData() {
    List<Map<String, dynamic>> personsData = [];

    if (_person1Field1Controller.text.trim().isNotEmpty ||
        _person1Field2Controller.text.trim().isNotEmpty) {
      personsData.add({
        'name': _person1Field1Controller.text.trim(),
        'job': _person1Field2Controller.text.trim(),
      });
    }

    if (_person2Controller.text.trim().isNotEmpty) {
      personsData.add({
        'details': _person2Controller.text.trim(),
      });
    }

    return personsData;
  }

// ✅ NEW: Helper method to check if entries are identical
  bool _areEntriesIdentical(
      Map<String, dynamic> entry1, Map<String, dynamic> entry2) {
    // Compare basic fields
    if (entry1['phone'] != entry2['phone']) return false;
    if (entry1['village_name'] != entry2['village_name']) return false;
    if (entry1['living_place'] != entry2['living_place']) return false;
    if (entry1['is_uncle'] != entry2['is_uncle']) return false;

    // Compare amount
    int amount1 = 0;
    if (entry1['amount'] is int) {
      amount1 = entry1['amount'];
    } else if (entry1['amount'] is double) {
      amount1 = entry1['amount'].toInt();
    } else if (entry1['amount'] != null) {
      amount1 = int.tryParse(entry1['amount'].toString()) ?? 0;
    }

    int amount2 = 0;
    if (entry2['amount'] is int) {
      amount2 = entry2['amount'];
    } else if (entry2['amount'] is double) {
      amount2 = entry2['amount'].toInt();
    } else if (entry2['amount'] != null) {
      amount2 = int.tryParse(entry2['amount'].toString()) ?? 0;
    }

    if (amount1 != amount2) return false;

    // Compare persons
    List<dynamic> persons1 = entry1['persons'] ?? [];
    List<dynamic> persons2 = entry2['persons'] ?? [];

    if (persons1.length != persons2.length) return false;

    for (int i = 0; i < persons1.length; i++) {
      var p1 = persons1[i];
      var p2 = persons2[i];

      if (p1['name'] != p2['name']) return false;
      if (p1['job'] != p2['job']) return false;
      if (p1['details'] != p2['details']) return false;
    }

    return true;
  }

  bool _isFormDataNotInGroupedMois() {
    // If editing, ignore this scenario
    if (_isEditMode) return false;

    // If MOI Details is empty, definitely not grouped
    if (_groupedMois.isEmpty) return false;

    // ✅ FIX: Check if current form data (serial + phone) exists in _groupedMois
    final currentPhone = _phoneController.text.trim();
    final currentSerial = _serialNo;

    // If this exact serial OR phone exists in grouped list, it means form data IS in MOI Details
    bool existsInGroup = _groupedMois.any((entry) =>
    entry['serial_no'] == currentSerial ||
        (currentPhone.isNotEmpty && entry['phone'] == currentPhone)
    );

    // Return TRUE if form has data but NOT in grouped list (ungrouped)
    return !existsInGroup && _hasFormData();
  }


  Future<String?> _saveMoi(int? groupId, {bool forceUpdate = false}) async {
    List<Map<String, dynamic>> personsData = [];

    // Build persons data
    if (_person1Field1Controller.text.trim().isNotEmpty ||
        _person1Field2Controller.text.trim().isNotEmpty) {
      personsData.add({
        'name': _person1Field1Controller.text.trim(),
        'job': _person1Field2Controller.text.trim(),
      });
    }

    if (_person2Controller.text.trim().isNotEmpty) {
      personsData.add({
        'details': _person2Controller.text.trim(),
      });
    }

    try {
      dynamic response;
      String moiId;

      if (forceUpdate && _editingMoiId != null) {

        // ✅ NEW: Fetch current data before updating (for old_data)
        final currentData = await _supabase
            .from('mois')
            .select('*')
            .eq('id', _editingMoiId!)
            .single();

        // ✅ EDIT MODE: Use traditional UPDATE (no RPC)
        final moiData = {
          'event_id': _eventId,
          'operator_id': _operatorId,
          'serial_no': _serialNo,
          'amount': int.tryParse(_amountController.text) ?? 0,
          'payment_method': _paymentMethod,
          'persons': personsData,
          'village_name': _villageController.text.trim().isEmpty
              ? null
              : _villageController.text.trim(),
          'living_place': _livingPlaceController.text.trim().isEmpty
              ? null
              : _livingPlaceController.text.trim(),
          'phone': _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          'is_uncle': _isUncle,
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          'group_id': groupId,
          'updated_at': DateTime.now().toIso8601String(),
          // ✅ FIX: Always preserve old_data on update
          'old_data': currentData,  // Store the FULL current state
        };

        response = await _supabase
            .from('mois')
            .update(moiData)
            .eq('id', _editingMoiId!)
            .select()
            .single();

        moiId = _editingMoiId!;
        print('✅ Updated existing MOI: $moiId with serial_no: $_serialNo');
      } else {
        // ✅ NEW ENTRY MODE: Use RPC with group_id
        print('🔒 Calling insert_moi_safe RPC with group_id: $groupId');

        response = await _supabase.rpc('insert_moi_safe', params: {
          'p_event_id': _eventId,
          'p_operator_id': _operatorId,
          'p_amount': double.tryParse(_amountController.text) ?? 0,
          'p_payment_method': _paymentMethod,
          'p_persons': personsData.isEmpty ? null : personsData,
          'p_village_name': _villageController.text.trim().isEmpty
              ? null
              : _villageController.text.trim(),
          'p_living_place': _livingPlaceController.text.trim().isEmpty
              ? null
              : _livingPlaceController.text.trim(),
          'p_phone': _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          'p_is_uncle': _isUncle,
          'p_notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          'p_group_id': groupId,  // ✅ PASS GROUP_ID (can be null or shared)

        });

        final result = (response as Map<String, dynamic>);
        moiId = result['id'];

        setState(() {
          _serialNo = result['serial_no'];
        });


        print('✅ Inserted new MOI: $moiId with serial_no: ${response['serial_no']}, group_id: ${response['group_id']}');
      }

      await _saveDenominations(moiId);
      return moiId;
    } catch (e) {
      print('❌ Error saving MOI: $e');
      rethrow;
    }
  }

  Future<void> _saveDenominations(String moiId) async {
    if (_paymentMethod != 'CASH') return;
    if (_skipDenomination) return;

    // Build denomination data from rows
    Map<String, dynamic> denomData = {
      'moi_id': moiId,
      'event_id': _eventId!,
      'operator_id': _operatorId!,
      'denom_500': 0,
      'denom_200': 0,
      'denom_100': 0,
      'denom_50': 0,
      'denom_20': 0,
      'denom_10': 0,
      'denom_5': 0,
      'denom_1': 0,
    };

    // Accumulate counts for same denomination
    for (var row in _denomRows) {
      int? denom = row['selectedDenom'];
      int count = int.tryParse(row['countController'].text) ?? 0;

      if (denom != null && count != 0) {
        denomData['denom_$denom'] = (denomData['denom_$denom'] as int) + count;
      }
    }

    // ✅ For grouped entries, save denomination only for the FIRST entry
    if (_currentGroupId != null && _groupedMois.isNotEmpty) {
      // Use the first entry's ID as the reference for denominations
      String firstMoiId = _groupedMois[0]['id'];
      await _supabase
          .from('moi_denominations')
          .upsert({...denomData, 'moi_id': firstMoiId});
    } else {
      // For single entry, use its own ID
      await _supabase.from('moi_denominations').upsert(denomData);
    }
  }

  Future<void> _handleSaveAndPrint() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final jobText = _person1Field2Controller.text.trim();
    if (jobText.isNotEmpty) {
      print('💾 Saving job on Save press: "$jobText"');
      await _saveNewJobToDatabase(jobText);
    }


    try {
      // Around line 1100, after the ungrouped data check
      if (!_validatePhoneForAmountChange()) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // ✅ STEP 0: Check if input fields have data (ungrouped data)
      bool hasUngroupedData = _person1Field1Controller.text
          .trim()
          .isNotEmpty ||
          _person1Field2Controller.text
              .trim()
              .isNotEmpty ||
          _person2Controller.text
              .trim()
              .isNotEmpty ||
          _villageController.text
              .trim()
              .isNotEmpty ||
          _livingPlaceController.text
              .trim()
              .isNotEmpty ||
          _amountController.text
              .trim()
              .isNotEmpty;

      if (hasUngroupedData && !_isEditMode) {
        final shouldProceed = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              AlertDialog(
                title: const Text(
                  '⚠️ Ungrouped Data Detected!',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You have data in the input fields that has not been added to MOI Details.',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border.all(color: Colors.orange, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠️ Input fields must be empty before saving!',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                                fontSize: 13),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Please choose one of the following:',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                              '1. Click "Group" to add this data to MOI Details',
                              style: TextStyle(fontSize: 11)),
                          Text('2. Click "Clear" to discard this data',
                              style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'What would you like to do?',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'clear'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: const Text(
                      'CLEAR DATA',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'group'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue[100],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: const Text(
                      'GROUP FIRST',
                      style: TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
        );

        if (shouldProceed == 'clear') {
          await _clearFormForNextEntry();
          _phoneFocusNode.requestFocus();

          if (mounted) setState(() => _isLoading = false);
          return;
        } else if (shouldProceed == 'group') {
          // Don't proceed with save, let user click Group button
          if (mounted) setState(() => _isLoading = false);
          return;
        } else {
          // User closed dialog without choosing
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      // ✅ STEP 1: Check if editing a single entry with no changes
      if (
      _isEditMode &&
          _editingMoiId != null &&
          _currentGroupId == null &&
          _hasNoChanges()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No changes detected. Nothing to save.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // ✅ STEP 2: Check if editing grouped entry with unsaved changes
      if (_isEditMode && _editingMoiId != null && _currentGroupId != null &&
          !_hasNoChanges()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ You have unsaved changes! Please press "Group" (Ctrl+Enter) to confirm your edits before saving.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // ✅ STEP 3: Check for ungrouped data in form (handles BOTH empty and non-empty _groupedMois)
      if (_hasFormData()) {
        // Check if this form data is already in MOI Details
        bool isAlreadyGrouped = _groupedMois.any((entry) {
          // Compare by serial number (most reliable unique identifier)
          return entry['serial_no'] == _serialNo;
        });

        if (!isAlreadyGrouped) {
          // Form has data but it's NOT in MOI Details - show warning popup
          final shouldDiscard = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                AlertDialog(
                  title: const Text(
                    '⚠️ Entry Not Grouped!',
                    style: TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _groupedMois.isEmpty
                            ? 'You have entered data in the form but have not added it to MOI Details yet.'
                            : 'You filled a new entry but did NOT click "Group" to add it to MOI Details.',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⚠️ This entry will NOT be saved!',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 13),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'To save this entry, please:',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                                '1. Click "Group" button (or press Ctrl+Enter)',
                                style: TextStyle(fontSize: 11)),
                            Text('2. Then click "Save & Print"',
                                style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Do you want to discard this entry and continue?',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red[100],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      child: const Text(
                        'DISCARD & CONTINUE',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
          );

          if (shouldDiscard != true) {
            return; // User cancelled
          }
          // User chose to discard
          await _clearFormCompletely();
          _phoneFocusNode.requestFocus();
          setState(() => _isLoading = false);

          return;
        }
      }

      // ✅ STEP 4: Check if MOI Details is completely empty
      if (_groupedMois.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠️ Please add entry to MOI Details first using "Group" button (Ctrl+Enter)'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // ✅ NEW: Check for similar entries in grouped list BEFORE saving
      for (var entry in _groupedMois) {
        // Skip if this is an existing entry (already in DB)
        if (entry['is_temp'] != true) continue;

        // Get entry details
        String villageName = (entry['village_name'] ?? '').trim();
        String person1Name = '';
        String person1Job = '';

        if (entry['persons'] != null) {
          List<dynamic> personsList = entry['persons'] as List;
          if (personsList.isNotEmpty) {
            person1Name = (personsList[0]['name'] ?? '').trim();
            person1Job = (personsList[0]['job'] ?? '').trim();
          }
        }

        if (villageName.isEmpty || person1Name.isEmpty) {
          continue; // Skip check if essential fields are empty
        }

        // Query database for similar entries
        try {
          final response = await _supabase
              .from('mois')
              .select('*')
              .eq('event_id', _eventId!)
              .eq('is_deleted', false);

          Map<String, dynamic>? matchingEntry;

          for (var dbEntry in response) {
            // Check village name (case-insensitive)
            String entryVillage = (dbEntry['village_name'] ?? '')
                .trim()
                .toLowerCase();
            if (entryVillage != villageName.toLowerCase()) continue;

            // Check person 1
            if (dbEntry['persons'] != null) {
              List<dynamic> personsList = dbEntry['persons'] as List;
              if (personsList.isNotEmpty) {
                String entryP1Name = (personsList[0]['name'] ?? '')
                    .trim()
                    .toLowerCase();
                String entryP1Job = (personsList[0]['job'] ?? '')
                    .trim()
                    .toLowerCase();

                if (entryP1Name == person1Name.toLowerCase() &&
                    entryP1Job == person1Job.toLowerCase()) {
                  matchingEntry = dbEntry;
                  break;
                }
              }
            }
          }

          if (matchingEntry != null) {
            // Show dialog with 3 options: Overwrite, New Entry, Cancel
            // ✅ Build FULL existing entry details
            String existingEntryDetails = '';
            existingEntryDetails += '📍 Village: ${matchingEntry?['village_name'] ?? 'N/A'}\n';
            existingEntryDetails += '🏙️ Living Place: ${matchingEntry?['living_place'] ?? 'N/A'}\n';
            existingEntryDetails += '📞 Phone: ${matchingEntry?['phone'] ?? 'N/A'}\n';
            existingEntryDetails += '💰 Amount: ₹${matchingEntry?['amount'] ?? '0'}\n';
            existingEntryDetails += '💳 Payment: ${matchingEntry?['payment_method'] ?? 'N/A'}\n';
            existingEntryDetails += '👤 Uncle: ${(matchingEntry?['is_uncle'] ?? false) ? 'Yes' : 'No'}\n';

            if (matchingEntry?['persons'] != null) {
              List<dynamic> personsList = matchingEntry!['persons'] as List;
              if (personsList.isNotEmpty) {
                var p1 = personsList[0];
                existingEntryDetails += '\n👤 Person 1:\n';
                existingEntryDetails += '  Name: ${p1['name'] ?? 'N/A'}\n';
                existingEntryDetails += '  Job: ${p1['job'] ?? 'N/A'}\n';
              }
              if (personsList.length > 1) {
                var p2 = personsList[1];
                existingEntryDetails += '\n👤 Person 2:\n';
                existingEntryDetails += '  Details: ${p2['details'] ?? 'N/A'}\n';
              }
            }

            if (matchingEntry?['notes'] != null && matchingEntry!['notes'].toString().isNotEmpty) {
              existingEntryDetails += '\n📝 Notes: ${matchingEntry['notes']}\n';
            }

// ✅ Get serial number safely
            final serialNo = matchingEntry?['serial_no'] ?? 0;

// ✅ Show dialog with 2 options only (REMOVED OVERWRITE)
            final result = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text(
                  '⚠️ Similar Entry Found!',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'An entry with the same Village, Person 1 Name, and Job already exists in Serial No: O$serialNo',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Existing Entry Details:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            decoration: TextDecoration.underline),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          existingEntryDetails,
                          style: const TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Do you want to save this as a new entry anyway?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'cancel'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text(
                      'NO, CANCEL',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'new'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green[100],
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text(
                      'YES, SAVE NEW',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );

            // Handle user choice
            // ✅ FIXED: Handle user choice
            if (result == 'cancel') {
              // User cancelled - stop save operation
              return;
            } else if (result == 'new') {
              // ✅ User confirmed to save as new entry - CONTINUE WITH SAVE
              // Do nothing here, just continue with the save process below
              print('✅ User confirmed to save duplicate entry - proceeding with save');
            } else if (result != null && result.startsWith('overwrite:')) {
              // Get the MOI ID to overwrite
              final moiIdToOverwrite = result.split(':')[1];

              // Mark this temp entry to overwrite the existing one
              entry['overwrite_id'] = moiIdToOverwrite;
            }
          }
        } catch (e) {
          print('Error checking similar entry: $e');
        }
      }


      bool isFinalSave = _groupedMois.isNotEmpty;

      if (isFinalSave) {
        // ✅ GROUPED ENTRIES SAVE MODE

        // Final save validation
        if (_groupedMois.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please add at least one entry to MOI Details before saving!'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        String phoneNumber = '';
        if (_groupedMois.isNotEmpty) {
          phoneNumber = _groupedMois[0]['phone'] ?? '';
        }

        print('📞 Phone number for global update check: $phoneNumber');
        print('📊 Auto-filled data: $_autoFilledData');
        print('🔄 Has auto-filled data changed: ${_hasAutoFilledDataChanged()}');

        if (phoneNumber.isNotEmpty &&
            phoneNumber.length == 10 &&
            _hasAutoFilledDataChanged()) {
          print(
              '🔔 Auto-filled data has changed! Showing global update dialog...');
          final shouldUpdateAll = await _showGlobalUpdateConfirmation(
              phoneNumber);
          if (shouldUpdateAll) {
            print('✅ User chose to update all entries');
            await _updateAllEntriesWithPhoneNumber(phoneNumber);
            print('✅ Global update completed');
          } else {
            print('❌ User chose to update only this entry');
          }
          // Reset auto-filled data after handling
          _autoFilledData = null;
        } else {
          print('⏭️ Skipping global update check - conditions not met');
        }

        // ✅ NEW: Check if single entry with OTHERS payment method
        bool isSingleEntryWithOthers = _groupedMois.length == 1 &&
            _groupedMois[0]['payment_method'] == 'OTHERS';

        // ✅ CHANGE: Only validate denomination if payment method is CASH AND not single OTHERS entry AND not skipping denomination
        if (_paymentMethod == 'CASH' && !isSingleEntryWithOthers &&
            !_skipDenomination) {
          int denomTotal = _getTotalAmount();

          // Calculate total from MOI Details
          int totalGroupAmount = 0;
          for (var entry in _groupedMois) {
            var amount = entry['amount'];
            if (amount is int) {
              totalGroupAmount += amount;
            } else if (amount is double) {
              totalGroupAmount += amount.toInt();
            } else if (amount != null) {
              totalGroupAmount += int.tryParse(amount.toString()) ?? 0;
            }
          }

          await _loadPreviewSerialNo();

          // Denomination is MANDATORY for CASH (when not skipping)
          if (denomTotal == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Please enter denomination details before saving!'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          if (totalGroupAmount != denomTotal) {
            int difference = totalGroupAmount - denomTotal;
            String message = difference > 0
                ? 'MOI Details total is ₹$totalGroupAmount but denomination is ₹$denomTotal. ₹${difference
                .abs()} is missing!'
                : 'MOI Details total is ₹$totalGroupAmount but denomination is ₹$denomTotal. ₹${difference
                .abs()} is extra!';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }

          for (var row in _denomRows) {
            int count = int.tryParse(row['countController'].text) ?? 0;
            int? denom = row['selectedDenom'];

            if (count < 0 && denom != null) {
              int available = await _getAvailableBalance(denom);

              if (count.abs() > available) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '₹$denom: Insufficient balance. Available: $available, Requested: ${count
                            .abs()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
                return;
              }
            }
          }
        }
        for (var entry in _groupedMois) {
          // Skip if this is an existing entry being edited
          if (entry['is_temp'] != true) continue;

          // Build check data for this entry
          String villageName = entry['village_name'] ?? '';
          int amount = 0;
          var amountValue = entry['amount'];
          if (amountValue is int) {
            amount = amountValue;
          } else if (amountValue is double) {
            amount = amountValue.toInt();
          } else if (amountValue != null) {
            amount = int.tryParse(amountValue.toString()) ?? 0;
          }

          String person1Name = '';
          String person1Job = '';
          if (entry['persons'] != null) {
            List<dynamic> personsList = entry['persons'] as List;
            if (personsList.isNotEmpty) {
              person1Name = personsList[0]['name'] ?? '';
              person1Job = personsList[0]['job'] ?? '';
            }
          }

          // Query database for matching entries
          final response = await _supabase
              .from('mois')
              .select('*')
              .eq('event_id', _eventId!)
              .eq('is_deleted', false);

          List<Map<String, dynamic>> matchingEntries = [];

          for (var dbEntry in response) {
            // Check village name (case-insensitive)
            String entryVillage = dbEntry['village_name'] ?? '';
            if (entryVillage.toLowerCase() != villageName.toLowerCase())
              continue;

            // Check amount
            int entryAmount = 0;
            var entryAmountValue = dbEntry['amount'];
            if (entryAmountValue is int) {
              entryAmount = entryAmountValue;
            } else if (entryAmountValue is double) {
              entryAmount = entryAmountValue.toInt();
            } else if (entryAmountValue is num) {
              entryAmount = entryAmountValue.toInt();
            }
            if (entryAmount != amount) continue;

            // Check person 1 name and job
            if (dbEntry['persons'] != null) {
              List<dynamic> personsList = dbEntry['persons'] as List;
              if (personsList.isNotEmpty) {
                var p1 = personsList[0];
                String entryP1Name = p1['name'] ?? '';
                String entryP1Job = p1['job'] ?? '';

                if (entryP1Name.toLowerCase() != person1Name.toLowerCase())
                  continue;

                if (person1Job.isNotEmpty &&
                    entryP1Job.toLowerCase() != person1Job.toLowerCase())
                  continue;
              }
            }

            // All fields match
            matchingEntries.add(dbEntry);
          }

          // If duplicates found, show warning dialog
          if (matchingEntries.isNotEmpty) {
            final shouldProceed = await _showDuplicateWarningDialog(
              matchingEntries,
              entry,
            );

            if (!shouldProceed) {
              // User chose to cancel - stop the save operation
              return;
            }
          }
        }
        try {
          List<String> savedMoiIds = [];
          String? firstSavedMoiId; // ✅ ADD THIS to track first entry

          // ✅ Save all temp entries using RPC
          for (int i = 0; i < _groupedMois.length; i++) {
            var entry = _groupedMois[i];

            if (entry['is_temp'] == true) {
              // ✅ CHECK: Should we overwrite an existing entry?
              if (entry.containsKey('overwrite_id')) {
                // OVERWRITE MODE: Update existing entry instead of creating new
                final moiIdToOverwrite = entry['overwrite_id'];

                print('🔄 Overwriting existing entry: $moiIdToOverwrite');

                List<Map<String, dynamic>>? personsData;
                if (entry['persons'] != null &&
                    (entry['persons'] as List).isNotEmpty) {
                  personsData =
                  List<Map<String, dynamic>>.from(entry['persons']);
                }

                // Fetch current data for old_data
                final currentData = await _supabase
                    .from('mois')
                    .select('*')
                    .eq('id', moiIdToOverwrite)
                    .single();

                // Update the existing entry
                final moiData = {
                  'amount': entry['amount'],
                  'payment_method': _paymentMethod,
                  'persons': personsData,
                  'village_name': entry['village_name'],
                  'living_place': entry['living_place'],
                  'phone': entry['phone'],
                  'is_uncle': entry['is_uncle'] ?? false,
                  'notes': entry['notes'],
                  'updated_at': DateTime.now().toIso8601String(),
                  'old_data': currentData,
                };

                await _supabase
                    .from('mois')
                    .update(moiData)
                    .eq('id', moiIdToOverwrite);

                // Update local list with overwritten data
                setState(() {
                  _groupedMois[i] = {
                    ...entry,
                    'id': moiIdToOverwrite,
                    'serial_no': currentData['serial_no'],
                    'is_temp': false,
                  };
                });

                print('✅ Overwritten entry: $moiIdToOverwrite');
              } else {
                // NORMAL NEW ENTRY MODE: Use RPC
                print('🔒 Saving temp entry ${i + 1}/${_groupedMois
                    .length} with group_id: $_currentGroupId');

                List<Map<String, dynamic>>? personsData;
                if (entry['persons'] != null &&
                    (entry['persons'] as List).isNotEmpty) {
                  personsData =
                  List<Map<String, dynamic>>.from(entry['persons']);
                }

                int? groupIdToPass;
                if (i == 0 && entry['is_temp'] == true) {
                  groupIdToPass = null;
                } else {
                  groupIdToPass = _currentGroupId;
                }

                final response = await _supabase.rpc(
                    'insert_moi_safe', params: {
                  'p_event_id': _eventId,
                  'p_operator_id': _operatorId,
                  'p_amount': entry['amount'],
                  'p_payment_method': _paymentMethod,
                  'p_persons': personsData,
                  'p_village_name': entry['village_name'],
                  'p_living_place': entry['living_place'],
                  'p_phone': entry['phone'],
                  'p_is_uncle': entry['is_uncle'] ?? false,
                  'p_notes': entry['notes'],
                  'p_group_id': groupIdToPass,
                });

                String newMoiId = response['id'];
                int actualSerialNo = response['serial_no'];
                int actualGroupId = response['group_id'];

                if (firstSavedMoiId == null) {
                  firstSavedMoiId = newMoiId;
                  print('📌 First saved MOI ID: $firstSavedMoiId');
                }

                if (i == 0) {
                  _currentGroupId = actualGroupId;
                }

                setState(() {
                  _groupedMois[i] = {
                    ...entry,
                    'id': newMoiId,
                    'serial_no': actualSerialNo,
                    'group_id': actualGroupId,
                    'is_temp': false,
                  };
                });

                print(
                    '✅ Temp entry saved: $newMoiId with serial: $actualSerialNo, group: $actualGroupId');
              }
            } else {
              // ✅ EXISTING ENTRY (already in DB)
              if (entry['is_modified'] == true) {
                final currentData = await _supabase
                    .from('mois')
                    .select('*')
                    .eq('id', entry['id'])
                    .single();

                // ✅ Store only editable fields in old_data
                final oldDataToStore = {
                  'village_name': currentData['village_name'],
                  'living_place': currentData['living_place'],
                  'amount': currentData['amount'],
                  'persons': currentData['persons'],
                  'phone': currentData['phone'],
                  'notes': currentData['notes'],
                  'payment_method': currentData['payment_method'],
                  'is_uncle': currentData['is_uncle'],
                  'updated_at': currentData['updated_at'],
                  'old_data': currentData['old_data'], // Preserve the chain
                };


                final moiData = {
                  'event_id': _eventId,
                  'operator_id': _operatorId,
                  'serial_no': entry['serial_no'],
                  'amount': entry['amount'],
                  'payment_method': _paymentMethod,
                  'persons': entry['persons'],
                  'village_name': entry['village_name'],
                  'living_place': entry['living_place'],
                  'phone': entry['phone'],
                  'is_uncle': entry['is_uncle'] ?? false,
                  'notes': entry['notes'],
                  'group_id': _currentGroupId,
                  'updated_at': DateTime.now().toIso8601String(),
                  'old_data': oldDataToStore,
                };

                await _supabase
                    .from('mois')
                    .update(moiData)
                    .eq('id', entry['id']);


                savedMoiIds.add(entry['id']);
                print('✅ Modified entry updated: ${entry['id']}');
              } else {
                savedMoiIds.add(entry['id']);
                print('✅ Unmodified entry: ${entry['id']}');
              }
            }
          }

          // ✅ Refresh preview serial after saving
          await _loadPreviewSerialNo();

// ✅ CRITICAL FIX: Save denominations using firstSavedMoiId (real DB ID)
          if (_paymentMethod == 'CASH' && !_skipDenomination &&
              firstSavedMoiId != null) {
            print(
                '💾 Saving denominations for group using first entry: $firstSavedMoiId');
            await _saveDenominationsForGroup(firstSavedMoiId);
          } else if (_paymentMethod == 'CASH' && !_skipDenomination &&
              _groupedMois.isNotEmpty) {
            // Fallback: use first entry's ID from grouped list
            print(
                '💾 Saving denominations using fallback: ${_groupedMois[0]['id']}');
            await _saveDenominationsForGroup(_groupedMois[0]['id']);
          }

// ✅ NEW: Check if skip_print is true
          if (_skipPrint) {
            if (mounted) {
              await _clearFormCompletely();
              _phoneFocusNode.requestFocus();
              setState(() => _isLoading = false);

            }
            return; // Exit without generating receipt
          }

          // ✅ Check if group has only one entry
          String? receiptType;
          if (_groupedMois.length == 1) {
            // ✅ CRITICAL FIX: Save the temp entry FIRST before generating receipt
            var entry = _groupedMois[0];

            // Only save if it's a temp entry (not already in DB)
            if (entry['is_temp'] == true) {
              List<Map<String, dynamic>>? personsData;
              if (entry['persons'] != null &&
                  (entry['persons'] as List).isNotEmpty) {
                personsData = List<Map<String, dynamic>>.from(entry['persons']);
              }

              final response = await _supabase.rpc('insert_moi_safe', params: {
                'p_event_id': _eventId,
                'p_operator_id': _operatorId,
                'p_amount': entry['amount'],
                'p_payment_method': _paymentMethod,
                'p_persons': personsData,
                'p_village_name': entry['village_name'],
                'p_living_place': entry['living_place'],
                'p_phone': entry['phone'],
                'p_is_uncle': entry['is_uncle'] ?? false,
                'p_notes': entry['notes'],
                'p_group_id': null,
              });

              String newMoiId = response['id'];
              int actualSerialNo = response['serial_no'];
              int actualGroupId = response['group_id'];

              // Update the entry with real DB data
              setState(() {
                _groupedMois[0] = {
                  ...entry,
                  'id': newMoiId,
                  'serial_no': actualSerialNo,
                  'group_id': actualGroupId,
                  'is_temp': false,
                };
                _currentGroupId = actualGroupId;
              });

              entry = _groupedMois[0]; // Update reference
              print(
                  '✅ Single temp entry saved: $newMoiId with serial: $actualSerialNo');
            }

            // ✅ Save denominations if CASH and not skipping
            if (_paymentMethod == 'CASH' && !_skipDenomination) {
              await _saveDenominationsForGroup(entry['id']);
            }

            // Now generate receipt
            setState(() => _isLoading = true);

            try {
              final operatorName = await _getOperatorName();
              final eventDetails = await _getEventDetails(); // Already exists

// ADD THIS - fetch event title, type name, venue
              final eventResponse = await _supabase
                  .from('events')
                  .select('title, venue, event_types(name)')
                  .eq('id', _eventId!)
                  .single();

              String? eventTitle = eventResponse['title'];
              String? venue = eventResponse['venue'];
              String? eventFor = eventResponse['event_for'];
              String? eventTypeName = eventResponse['event_types']?['name'];

              // ✅ Build denominations from current form (same as group receipt) - only if not skipping
              Map<int, int>? denominations;
              if (_paymentMethod == 'CASH' && !_skipDenomination) {
                denominations = {
                  500: 0,
                  200: 0,
                  100: 0,
                  50: 0,
                  20: 0,
                  10: 0,
                  5: 0,
                  1: 0,
                };

                for (var row in _denomRows) {
                  int? denom = row['selectedDenom'];
                  int count = int.tryParse(row['countController'].text) ?? 0;
                  if (denom != null && count != 0) {
                    denominations[denom] = (denominations[denom] ?? 0) + count;
                  }
                }

                // Check if we have any non-zero denominations
                bool hasNonZeroDenoms =
                denominations.values.any((count) => count != 0);
                if (!hasNonZeroDenoms) {
                  denominations = null;
                }
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Generating receipt...'),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 1),
                  ),
                );
              }

              // Parse persons data
              String? person1Name;
              String? person1Job;
              String? person2Details;
              if (entry['persons'] != null) {
                List<dynamic> personsList = entry['persons'] as List;
                if (personsList.isNotEmpty) {
                  person1Name = personsList[0]['name'];
                  person1Job = personsList[0]['job'];
                }
                if (personsList.length > 1) {
                  person2Details = personsList[1]['details'];
                }
              }

              // ✅ FIX: Get amount correctly from entry
              int entryAmount = 0;
              var amountValue = entry['amount'];
              if (amountValue is int) {
                entryAmount = amountValue;
              } else if (amountValue is double) {
                entryAmount = amountValue.toInt();
              } else if (amountValue != null) {
                entryAmount = int.tryParse(amountValue.toString()) ?? 0;
              }


              // ✅ Generate and print in background (async, won't block UI)
              await _generateAndPrintReceipt(
                serialNo: entry['serial_no'],
                operatorName: operatorName,
                eventDate: eventDetails['event_date'],
                eventTime: eventDetails['event_time'],
                villageName: entry['village_name'],
                livingPlace: entry['living_place'],
                person1Name: entry['persons'] != null && (entry['persons'] as List).isNotEmpty
                    ? entry['persons'][0]['name'] : null,
                person1Job: entry['persons'] != null && (entry['persons'] as List).isNotEmpty
                    ? entry['persons'][0]['job'] : null,
                person2Details: entry['persons'] != null && (entry['persons'] as List).length > 1
                    ? entry['persons'][1]['details'] : null,
                phone: entry['phone'],
                notes: entry['notes'],
                amount: entryAmount,
                paymentMethod: entry['payment_method'] ?? 'CASH',
                denominations: denominations,
                customerName: _customerName,
                city: _city,
                customerPhone: _customerPhone,
                isUncle: entry['is_uncle'] ?? false,
                eventTitle: eventTitle,
                eventFor: eventFor,
                eventTypeName: eventTypeName,
                venue: venue,
              );

              // ✅ Don't return early - let receipt print first
              if (mounted) {
                await _clearFormCompletely();
                _phoneFocusNode.requestFocus();
                setState(() => _isPrinting = false);
                if (_isCollectionDetailsEditPage) {
                  Navigator.pop(context);  // Return to collection details
                  _isCollectionDetailsEditPage = false;
                }
              }

              return; // ✅ Exit immediately, don't wait for printing



            } catch (e) {
              print('Error generating single receipt: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } finally {
              setState(() => _isLoading = false);
            }
            return; // ✅ Exit early, don't show dialog
          } else {
            // Show receipt type selection dialog for multiple entries
            if (mounted) {
              receiptType = await showDialog<String>(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    AlertDialog(
                      title: const Text(
                        'Generate Receipt',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      content: const Text(
                        'How would you like to generate the receipts?',
                        style: TextStyle(fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'single'),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.blue[50],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: const Text(
                            'Single Receipt',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'group'),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.green[50],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: const Text(
                            'Group Receipt',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'cancel'),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
              );
            }
          }

          if (receiptType == null || receiptType == 'cancel') {
            // User cancelled, just clear form
            await _clearFormCompletely();
            _phoneFocusNode.requestFocus();
            setState(() => _isLoading = false);

            if (_isCollectionDetailsEditPage) {
              Navigator.pop(context);  // Return to collection details
              _isCollectionDetailsEditPage = false;
            }

            return;
          }

// ✅ SAVE _groupedMois data BEFORE clearing (we need it for receipt generation)
          List<Map<String, dynamic>> savedGroupedMois = List.from(_groupedMois);

// ✅ CLEAR FORM IMMEDIATELY AFTER USER SELECTS RECEIPT TYPE
          await _clearFormCompletely();
          await _loadPreviewSerialNo();

          if (_isCollectionDetailsEditPage) {
            _isCollectionDetailsEditPage = false;
            Navigator.pop(context);
            // Continue with receipt generation in background (don't return yet)
          }

// ✅ Generate receipts based on type
          try {
            final operatorName = await _getOperatorName();
            final eventDetails = await _getEventDetails();

            final eventResponse = await _supabase
                .from('events')
                .select('title, venue, event_types(name)')
                .eq('id', _eventId!)
                .single();

            String? eventTitle = eventResponse['title'];
            String? venue = eventResponse['venue'];
            String? eventFor = eventResponse['event_for'];
            String? eventTypeName = eventResponse['event_types']?['name'];

            if (receiptType == 'group') {
              // Generate consolidated group receipt
              double totalAmount = 0.0;
              Map<int, int> totalDenominations = {
                500: 0, 200: 0, 100: 0, 50: 0, 20: 0, 10: 0, 5: 0, 1: 0,
              };

              for (var entry in savedGroupedMois) {
                var amountValue = entry['amount'];
                if (amountValue is int) {
                  totalAmount += amountValue.toDouble();
                } else if (amountValue is double) {
                  totalAmount += amountValue;
                } else if (amountValue is num) {
                  totalAmount += amountValue.toDouble();
                }

                if (entry['payment_method'] == 'CASH') {
                  final denoms = await _getDenominations(entry['id']);
                  if (denoms != null) {
                    denoms.forEach((denom, count) {
                      totalDenominations[denom] = (totalDenominations[denom] ?? 0) + count;
                    });
                  }
                }
              }

              final result = await MoiReceiptGenerator.generateGroupMoiReceiptWithImage(
                context: context,
                groupId: savedGroupedMois[0]['group_id'],
                operatorName: operatorName,
                eventDate: eventDetails['event_date'],
                eventTime: eventDetails['event_time'],
                groupEntries: savedGroupedMois,
                totalAmount: totalAmount,
                totalDenominations: totalDenominations.values.any((v) => v > 0) ? totalDenominations : null,
                customerName: _customerName,
                city: _city,
                customerPhone: _customerPhone,
                eventTitle: eventTitle,
                eventFor: eventFor,
                eventTypeName: eventTypeName,
                venue: venue,
              );

              if (result != null && mounted) {
                final printerService = ThermalPrinterService();
                await printerService.connectAndPrintImage(context, result['imageBytes']);
                // await printerService.connectAndPrintImage(context, result['imageBytes']);

                // Send to all WhatsApp numbers
                List<String> phoneNumbers = [];
                for (var entry in savedGroupedMois) {
                  String? phone = entry['phone'];
                  if (phone != null && phone.isNotEmpty) {
                    phoneNumbers.add(phone);
                  }
                }

                //if (phoneNumbers.isNotEmpty) {
                  await _sendReceiptToWhatsApp(
                      result['pdf'],
                      'mois',
                      phoneNumbers: phoneNumbers,
                      receiptNo: savedGroupedMois[0]['group_id']
                  );
                }
             // }
            }else if (receiptType == 'single') {
              // ✅ For split group receipts
              List<Map<String, dynamic>> entriesWithDenoms = [];
              for (var entry in savedGroupedMois) {
                Map<String, dynamic> entryData = Map.from(entry);
                if (entry['payment_method'] == 'CASH') {
                  entryData['denominations'] = await _getDenominations(entry['id']);
                }
                entriesWithDenoms.add(entryData);
              }

              // Generate split receipts with images
              final receiptsWithImages = await MoiReceiptGenerator.generateSplitGroupReceiptsWithImages(
                context: context,
                operatorName: operatorName,
                eventDate: eventDetails['event_date'],
                eventTime: eventDetails['event_time'],
                groupEntries: entriesWithDenoms,
                customerName: _customerName,
                city: _city,
                customerPhone: _customerPhone,
                eventTitle: eventTitle,
                eventFor: eventFor,
                eventTypeName: eventTypeName,
                venue: venue,
              );

              if (receiptsWithImages.isNotEmpty && mounted) {
                final printerService = ThermalPrinterService();

                for (int i = 0; i < receiptsWithImages.length; i++) {
                  final receipt = receiptsWithImages[i];

                  await printerService.connectAndPrintImage(context, receipt['imageBytes']);

                  if (i < entriesWithDenoms.length) {
                    String? phone = entriesWithDenoms[i]['phone'];
                    // ✅ ALWAYS send to backend (even if no phone)
                    await _sendReceiptToWhatsApp(
                        receipt['pdf'],
                        'mois',
                        phoneNumbers: phone != null && phone.isNotEmpty ? [phone] : [],
                        receiptNo: entriesWithDenoms[i]['serial_no']
                    );
                  }


                }
              }
            }
          } catch (e) {
            print('Error generating receipts: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } finally {
            if (mounted) {
              _phoneFocusNode.requestFocus();
              setState(() => _isLoading = false);
            }
          }

          if (mounted) {
            await _clearFormCompletely();
            _phoneFocusNode.requestFocus();
            setState(() => _isLoading = false);
          }
        } catch (e) {
          print('Error saving grouped entries: $e');
          if (mounted) {
            NetworkUtils.handleError(
              context,
              e,
              onRetry: _handleSaveAndPrint,
              customMessage: 'Error saving grouped entries',
            );
          }
        }
        return;
      }

      // ✅ SINGLE ENTRY MODE (not grouped)

      // Add in _handleGroup() after line 900:
      if (_villageController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Village name is mandatory!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_person1Field1Controller.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Person 1 name is mandatory!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

// The amount validation already exists, keep it

      // Single entry mode validation
      bool hasValidPerson = _person1Field1Controller.text
          .trim()
          .isNotEmpty ||
          _person2Controller.text
              .trim()
              .isNotEmpty;

      if (!hasValidPerson) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please add at least one person with a name')),
        );
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      String enteredAmountText = _amountController.text.trim();
      if (enteredAmountText.isEmpty || int.tryParse(enteredAmountText) == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Amount is mandatory!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ✅ Only validate denomination if CASH and not skipping
      if (_paymentMethod == 'CASH' && !_skipDenomination) {
        int enteredAmount = int.tryParse(enteredAmountText) ?? 0;
        int denomTotal = _getTotalAmount();

        if (denomTotal == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter denomination details')),
          );
          return;
        }

        if (denomTotal != enteredAmount) {
          int difference = enteredAmount - denomTotal;
          String message = difference > 0
              ? 'Amount is ₹$enteredAmount but denomination is ₹$denomTotal. ₹${difference
              .abs()} is missing!'
              : 'Amount is ₹$enteredAmount but denomination is ₹$denomTotal. ₹${difference
              .abs()} is extra!';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
      }
      final existingEntries = await _checkExistingEntry();

      if (existingEntries.isNotEmpty) {
        final shouldProceed = await _showExistingEntryDialog(existingEntries);

        if (!shouldProceed) {
          // User chose not to proceed - exit
          return;
        }
      }


      final similarCheckResult = await _checkSimilarEntryBeforeSave();

      if (similarCheckResult == 'cancel') {
        // User cancelled - do nothing
        return;
      } else if (similarCheckResult == 'new') {
        // User wants to create new entry - just return to form
        // Form already has data, they can modify it
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please modify the entry to make it different from the existing one'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      } else if (similarCheckResult != null &&
          similarCheckResult.startsWith('overwrite:')) {
        // Extract the MOI ID to overwrite
        final moiIdToOverwrite = similarCheckResult.split(':')[1];

        // Set edit mode to overwrite
        setState(() {
          _isEditMode = true;
          _editingMoiId = moiIdToOverwrite;
        });

        // Continue with save (will update the existing entry)
      }


      // Save single entry
      try {
        String? moiId = await _saveMoi(null, forceUpdate: _isEditMode);

        // After successful save, add this check:
        if (_skipPrint) {
          // Don't generate receipt, just show success and clear
          if (mounted) {

            await _clearFormCompletely();
            _phoneFocusNode.requestFocus();
            setState(() => _isLoading = false);
          }

          if (_isCollectionDetailsEditPage) {
            Navigator.pop(context);  // Return to collection details
            _isCollectionDetailsEditPage = false;
          }
          return; // Exit without generating receipt
        }

        // ✅ Generate receipt after saving (only if not skipping)
        if (moiId != null && mounted) {
          final operatorName = await _getOperatorName();
          final eventDetails = await _getEventDetails(); // Already exists

// ADD THIS - fetch event title, type name, venue
          final eventResponse = await _supabase
              .from('events')
              .select('title, venue, event_types(name)')
              .eq('id', _eventId!)
              .single();

          String? eventTitle = eventResponse['title'];
          String? venue = eventResponse['venue'];
          String? eventFor = eventResponse['event_for'];
          String? eventTypeName = eventResponse['event_types']?['name'];

          // ✅ Build denominations from current form (only if not skipping)
          Map<int, int>? denominations;
          if (_paymentMethod == 'CASH' && !_skipDenomination) {
            print('🎯 Payment method is CASH, building denominations...');
            print('🎯 Number of _denomRows: ${_denomRows.length}');

            denominations = {
              500: 0,
              200: 0,
              100: 0,
              50: 0,
              20: 0,
              10: 0,
              5: 0,
              1: 0,
            };

            for (var row in _denomRows) {
              int? denom = row['selectedDenom'];
              int count = int.tryParse(row['countController'].text) ?? 0;
              print('🎯 Row: denom=$denom, count=$count');
              if (denom != null && count != 0) {
                denominations[denom] = (denominations[denom] ?? 0) + count;
              }
            }

            print('🔍 Denominations BEFORE validation: $denominations');

            // ✅ CRITICAL: Check if we have any non-zero denominations
            bool hasNonZeroDenoms =
            denominations.values.any((count) => count != 0);
            print('🔍 Has non-zero denominations: $hasNonZeroDenoms');

            if (!hasNonZeroDenoms) {
              print(
                  '⚠️ WARNING: All denominations are zero in Save&Print! Setting to null.');
              denominations = null;
            } else {
              print('✅ Valid denominations found: $denominations');
            }
          }

          print(
              '🔍 FINAL denominations being passed to receipt generator: $denominations');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Generating receipt...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 1),
            ),
          );

          print('🎯 About to call generateSingleMoiReceipt with:');
          print('   - paymentMethod: $_paymentMethod');
          print('   - denominations: $denominations');

          final result = await MoiReceiptGenerator
              .generateSingleMoiReceiptWithImage(
            context: context,
            serialNo: _serialNo!,
            operatorName: operatorName,
            eventDate: eventDetails['event_date'],
            eventTime: eventDetails['event_time'],
            villageName: _villageController.text.trim(),
            livingPlace: _livingPlaceController.text.trim(),
            person1Name: _person1Field1Controller.text.trim(),
            person1Job: _person1Field2Controller.text.trim(),
            person2Details: _person2Controller.text.trim(),
            phone: _phoneController.text.trim(),
            notes: _notesController.text.trim(),
            // ✅ ALREADY CORRECT
            amount: _paymentMethod == 'CASH'
                ? _getTotalAmount()
                : int.tryParse(_amountController.text) ?? 0,
            paymentMethod: _paymentMethod,
            denominations: denominations,
            customerName: _customerName,
            city: _city,
            customerPhone: _customerPhone,
            isUncle: _isUncle,
            eventTitle: eventTitle,
            eventFor: eventFor,
            eventTypeName: eventTypeName,
            venue: venue,
          );

          // ✅ Print in background
          await _generateAndPrintReceipt(
            serialNo: _serialNo!,
            operatorName: operatorName,
            eventDate: eventDetails['event_date'],
            eventTime: eventDetails['event_time'],
            villageName: _villageController.text.trim(),
            livingPlace: _livingPlaceController.text.trim(),
            person1Name: _person1Field1Controller.text.trim(),
            person1Job: _person1Field2Controller.text.trim(),
            person2Details: _person2Controller.text.trim(),
            phone: _phoneController.text.trim(),
            notes: _notesController.text.trim(),
            amount: _paymentMethod == 'CASH'
                ? _getTotalAmount()
                : int.tryParse(_amountController.text) ?? 0,
            paymentMethod: _paymentMethod,
            denominations: denominations,
            customerName: _customerName,
            city: _city,
            customerPhone: _customerPhone,
            isUncle: _isUncle,
            eventTitle: eventTitle,
            eventFor: eventFor,
            eventTypeName: eventTypeName,
            venue: venue,
          );

          if (mounted) {
            await _clearFormCompletely();
            _phoneFocusNode.requestFocus();
            setState(() => _isPrinting = false);
            if (_isCollectionDetailsEditPage) {
              Navigator.pop(context);  // Return to collection details
              _isCollectionDetailsEditPage = false;
            }
          }
        }
      }catch (e) {
        print('Error saving: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          NetworkUtils.handleError(
            context,
            e,
            onRetry: _handleSaveAndPrint,
            customMessage: 'Error saving MOI',
          );
        }
      } finally {
        // ✅ IMPORTANT: Always reset loading at the end
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('❌ Error in _handleSaveAndPrint: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _handleSaveAndPrint,
          customMessage: 'Error saving MOI',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ NEW: Background receipt generation and printing
  Future<void> _generateAndPrintReceipt({
    required int serialNo,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    String? villageName,
    String? livingPlace,
    String? person1Name,
    String? person1Job,
    String? person2Details,
    String? phone,
    String? notes,
    required int amount,
    required String paymentMethod,
    Map<int, int>? denominations,
    String? customerName,
    String? city,
    String? customerPhone,
    required bool isUncle,
    String? eventTitle,
    String? eventFor,
    String? eventTypeName,
    String? venue,
  }) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🖨️ Printing...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }

      // ✅ STEP 1: Generate HTML once
      final logoBase64 = await MoiReceiptGenerator.getLogoBase64();
      final fontBase64 = await MoiReceiptGenerator.getFontBase64();

      final htmlContent = paymentMethod == 'CASH'
          ? MoiReceiptGenerator.generateSingleMoiHtml(
        serialNo: serialNo,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: villageName,
        livingPlace: livingPlace,
        person1Name: person1Name,
        person1Job: person1Job,
        person2Details: person2Details,
        phone: phone,
        amount: amount,
        paymentMethod: paymentMethod,
        denominations: denominations,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
        isUncle: isUncle,
        eventTitle: eventTitle,
        eventFor: eventFor,
        eventTypeName: eventTypeName,
        venue: venue,
        notes: notes,
      )
          : MoiReceiptGenerator.generateSingleMoiHtmlOthers(
        serialNo: serialNo,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: villageName,
        livingPlace: livingPlace,
        person1Name: person1Name,
        person1Job: person1Job,
        notes: notes,
        person2Details: person2Details,
        phone: phone,
        amount: amount,
        paymentMethod: paymentMethod,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
        isUncle: isUncle,
        eventTitle: eventTitle,
        eventFor: eventFor,
        eventTypeName: eventTypeName,
        venue: venue,
      );

      // ✅ STEP 2: Generate image for printing (FAST)
      print('🖨️ Generating image for thermal printer...');
      final imageBytes = await MoiReceiptGenerator.generateReceiptImageOnly(
        htmlContent: htmlContent,
      );

      if (imageBytes != null && mounted) {
        // ✅ STEP 3: Print immediately (NO PDF conversion)
        print('🖨️ Sending to thermal printer...');
        final printerService = ThermalPrinterService();
        await printerService.connectAndPrintImage(context, imageBytes);

        print('✅ Print job sent to thermal printer');

// ✅ STEP 4: Generate PDF in background (NO DELAY before this)
        unawaited(_generatePdfForCloud(
          htmlContent: htmlContent,
          serialNo: serialNo,
          phone: phone,
        ).catchError((e) {
          print('❌ Background PDF generation error: $e');
        }));
      } else {
        throw Exception('Failed to generate receipt image');
      }
    } catch (e) {
      print('❌ Error in _generateAndPrintReceipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Print error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }




// ✅ NEW: Background PDF generation for cloud storage
  Future<void> _generatePdfForCloud({
    required String htmlContent,
    required int serialNo,
    String? phone,
  }) async {
    try {
      print('☁️ Generating PDF for cloud storage in background...');

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'moi_single_${serialNo}_$timestamp.pdf';
      final filePath = '${output.path}/$fileName';

      File? pdfFile;
      bool pdfGenerated = false;

      HeadlessInAppWebView? headlessWebView;

      headlessWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: htmlContent),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useHybridComposition: true,
        ),
        initialSize: Size(302, 800),
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 1500));

            final contentHeight = await controller.evaluateJavascript(
                source: "document.body.scrollHeight"
            );

            int height = 800;
            if (contentHeight != null) {
              height = int.tryParse(contentHeight.toString()) ?? 800;
            }

            await headlessWebView?.setSize(Size(302, height.toDouble()));
            await Future.delayed(const Duration(milliseconds: 500));

            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              final pdfWidth = 80 * PdfPageFormat.mm;
              final pdfHeight = (height / 302) * pdfWidth;

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat(pdfWidth, pdfHeight, marginAll: 0),
                  build: (pw.Context context) {
                    return pw.Image(image, fit: pw.BoxFit.fill);
                  },
                ),
              );

              final file = File(filePath);
              await file.writeAsBytes(await pdf.save());
              pdfFile = file;
              pdfGenerated = true;
              print('✅ PDF generated for cloud: $filePath');
            }
          } catch (e) {
            print('❌ Error generating PDF: $e');
          } finally {
            if (headlessWebView != null) {
              await headlessWebView.dispose();
            }
          }
        },
      );

      await headlessWebView.run();

      // Wait for PDF generation
      int attempts = 0;
      while (attempts < 30 && !pdfGenerated) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (pdfGenerated) break;
        attempts++;
      }

      // ✅ Send to cloud if PDF was generated
      if (pdfFile != null) {
        await _sendReceiptToWhatsApp(
          pdfFile!,
          'mois',
          phoneNumbers: phone != null && phone.isNotEmpty ? [phone] : [],
          receiptNo: serialNo,
        );
        print('✅ PDF sent to cloud storage');
      }
    } catch (e) {
      print('❌ Error in background PDF generation: $e');
    }
  }

  Future<void> _generateSplitGroupReceipts() async {
    setState(() => _isLoading = true);

    try {
      final operatorName = await _getOperatorName();
      final eventDetails = await _getEventDetails();

      final eventResponse = await _supabase
          .from('events')
          .select('title, venue, event_types(name)')
          .eq('id', _eventId!)
          .single();

      String? eventTitle = eventResponse['title'];
      String? venue = eventResponse['venue'];
      String? eventFor = eventResponse['event_for'];
      String? eventTypeName = eventResponse['event_types']?['name'];

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generating ${_groupedMois.length} receipts...'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // Prepare entries with denominations
      List<Map<String, dynamic>> entriesWithDenoms = [];
      for (var entry in _groupedMois) {
        Map<String, dynamic> entryData = Map.from(entry);
        if (entry['payment_method'] == 'CASH') {
          entryData['denominations'] = await _getDenominations(entry['id']);
        }
        entriesWithDenoms.add(entryData);
      }

      final logoBase64 = await MoiReceiptGenerator.getLogoBase64();
      final fontBase64 = await MoiReceiptGenerator.getFontBase64();

      // ✅ Generate and print each receipt (FAST path)
      final printerService = ThermalPrinterService();

      for (int i = 0; i < entriesWithDenoms.length; i++) {
        final entry = entriesWithDenoms[i];

        // Parse persons data
        String? person1Name;
        String? person1Job;
        String? person2Details;
        if (entry['persons'] != null) {
          List<dynamic> personsList = entry['persons'] as List;
          if (personsList.isNotEmpty) {
            person1Name = personsList[0]['name'];
            person1Job = personsList[0]['job'];
          }
          if (personsList.length > 1) {
            person2Details = personsList[1]['details'];
          }
        }

        int entryAmount = 0;
        var amountValue = entry['amount'];
        if (amountValue is int) {
          entryAmount = amountValue;
        } else if (amountValue is double) {
          entryAmount = amountValue.toInt();
        } else if (amountValue != null) {
          entryAmount = int.tryParse(amountValue.toString()) ?? 0;
        }

        // ✅ STEP 1: Generate HTML for this entry
        final htmlContent = entry['payment_method'] == 'CASH'
            ? MoiReceiptGenerator.generateSingleMoiHtml(
          serialNo: entry['serial_no'],
          operatorName: operatorName,
          eventDate: eventDetails['event_date'],
          eventTime: eventDetails['event_time'],
          villageName: entry['village_name'],
          livingPlace: entry['living_place'],
          person1Name: person1Name,
          person1Job: person1Job,
          person2Details: person2Details,
          phone: entry['phone'],
          amount: entryAmount,
          paymentMethod: entry['payment_method'],
          denominations: entry['denominations'],
          customerName: _customerName,
          city: _city,
          customerPhone: _customerPhone,
          logoBase64: logoBase64,
          fontBase64: fontBase64,
          isUncle: entry['is_uncle'] ?? false,
          eventTitle: eventTitle,
          eventFor: eventFor,
          eventTypeName: eventTypeName,
          venue: venue,
          notes: entry['notes'],
        )
            : MoiReceiptGenerator.generateSingleMoiHtmlOthers(
          serialNo: entry['serial_no'],
          operatorName: operatorName,
          eventDate: eventDetails['event_date'],
          eventTime: eventDetails['event_time'],
          villageName: entry['village_name'],
          livingPlace: entry['living_place'],
          person1Name: person1Name,
          person1Job: person1Job,
          person2Details: person2Details,
          phone: entry['phone'],
          amount: entryAmount,
          paymentMethod: entry['payment_method'],
          customerName: _customerName,
          city: _city,
          customerPhone: _customerPhone,
          logoBase64: logoBase64,
          fontBase64: fontBase64,
          isUncle: entry['is_uncle'] ?? false,
          eventTitle: eventTitle,
          eventFor: eventFor,
          eventTypeName: eventTypeName,
          venue: venue,
          notes: entry['notes'],
        );

        // ✅ STEP 2: Generate image for printing (FAST)
        print('🖨️ Generating SPLIT receipt ${i + 1}/${entriesWithDenoms.length}...');
        final imageBytes = await MoiReceiptGenerator.generateSplitReceiptImageOnly(
          htmlContent: htmlContent,
        );

        if (imageBytes != null && mounted) {
          // ✅ STEP 3: Print immediately
          await printerService.connectAndPrintImage(context, imageBytes);
          print('✅ SPLIT receipt ${i + 1} printed');

          // ✅ STEP 4: Generate PDF in background (PARALLEL)
          _generateSplitPdfForCloud(
            htmlContent: htmlContent,
            serialNo: entry['serial_no'],
            phone: entry['phone'],
          ).catchError((e) {
            print('❌ Background SPLIT PDF ${i + 1} error: $e');
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${entriesWithDenoms.length} receipts printed'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error generating split receipts: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _generateSplitGroupReceipts,
          customMessage: 'Error generating receipts',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ NEW: Background PDF generation for SPLIT receipts
  Future<void> _generateSplitPdfForCloud({
    required String htmlContent,
    required int serialNo,
    String? phone,
  }) async {
    try {
      print('☁️ Generating SPLIT PDF for serial $serialNo in background...');

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'moi_split_${serialNo}_$timestamp.pdf';
      final filePath = '${output.path}/$fileName';

      File? pdfFile;
      bool pdfGenerated = false;

      HeadlessInAppWebView? headlessWebView;

      headlessWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: htmlContent),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useHybridComposition: true,
        ),
        initialSize: Size(302, 800),
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 1500));

            final contentHeight = await controller.evaluateJavascript(
                source: "document.body.scrollHeight"
            );

            int height = 800;
            if (contentHeight != null) {
              height = int.tryParse(contentHeight.toString()) ?? 800;
            }

            await headlessWebView?.setSize(Size(302, height.toDouble()));
            await Future.delayed(const Duration(milliseconds: 500));

            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              final pdfWidth = 80 * PdfPageFormat.mm;
              final pdfHeight = (height / 302) * pdfWidth;

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat(pdfWidth, pdfHeight, marginAll: 0),
                  build: (pw.Context context) {
                    return pw.Image(image, fit: pw.BoxFit.fill);
                  },
                ),
              );

              final file = File(filePath);
              await file.writeAsBytes(await pdf.save());
              pdfFile = file;
              pdfGenerated = true;
              print('✅ SPLIT PDF generated for serial $serialNo');
            }
          } catch (e) {
            print('❌ Error generating SPLIT PDF for serial $serialNo: $e');
          } finally {
            if (headlessWebView != null) {
              await headlessWebView.dispose();
            }
          }
        },
      );

      await headlessWebView.run();

      int attempts = 0;
      while (attempts < 30 && !pdfGenerated) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (pdfGenerated) break;
        attempts++;
      }

      // ✅ Send to cloud if PDF was generated
      if (pdfFile != null) {
        await _sendReceiptToWhatsApp(
          pdfFile!,
          'mois',
          phoneNumbers: phone != null && phone.isNotEmpty ? [phone] : [],
          receiptNo: serialNo,
        );
        print('✅ SPLIT PDF for serial $serialNo sent to cloud');
      }
    } catch (e) {
      print('❌ Error in background SPLIT PDF generation for serial $serialNo: $e');
    }
  }

  Future<bool> _showDuplicateWarningDialog(
      List<Map<String, dynamic>> existingEntries,
      Map<String, dynamic> currentEntry) async {

    String serialNumbers = existingEntries.map((e) => 'O${e['serial_no']}').join(', ');

    // Build current entry details
    String currentEntryDetails = '';
    currentEntryDetails += '📍 Village: ${currentEntry['village_name'] ?? 'N/A'}\n';

    if (currentEntry['persons'] != null) {
      List<dynamic> personsList = currentEntry['persons'] as List;
      if (personsList.isNotEmpty) {
        currentEntryDetails += '\n👤 Person 1:\n';
        currentEntryDetails += '  Name: ${personsList[0]['name'] ?? 'N/A'}\n';
        currentEntryDetails += '  Job: ${personsList[0]['job'] ?? 'N/A'}\n';
      }
    }

    currentEntryDetails += '\n💰 Amount: ₹${currentEntry['amount']}\n';

    // Build existing entry details
    String existingEntryDetails = '';
    if (existingEntries.isNotEmpty) {
      var entry = existingEntries[0];

      existingEntryDetails += '📍 Village: ${entry['village_name'] ?? 'N/A'}\n';
      existingEntryDetails += '🏙️ Living Place: ${entry['living_place'] ?? 'N/A'}\n';
      existingEntryDetails += '📞 Phone: ${entry['phone'] ?? 'N/A'}\n';
      existingEntryDetails += '💰 Amount: ₹${entry['amount']}\n';
      existingEntryDetails += '💳 Payment: ${entry['payment_method'] ?? 'N/A'}\n';

      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          var p1 = personsList[0];
          existingEntryDetails += '\n👤 Person 1:\n';
          existingEntryDetails += '  Name: ${p1['name'] ?? 'N/A'}\n';
          existingEntryDetails += '  Job: ${p1['job'] ?? 'N/A'}\n';
        }
      }
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '⚠️ Duplicate Entry Found!',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existingEntries.length == 1
                    ? 'This entry already exists in Serial No: $serialNumbers'
                    : 'This entry already exists in ${existingEntries.length} records: $serialNumbers',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Matching Fields:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.red),
                    ),
                    SizedBox(height: 4),
                    Text('• Village Name', style: TextStyle(fontSize: 11)),
                    Text('• Amount', style: TextStyle(fontSize: 11)),
                    Text('• Person 1 Name', style: TextStyle(fontSize: 11)),
                    Text('• Person 1 Job', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Current Entry:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 8),
              Text(
                currentEntryDetails,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Existing Entry in Database:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 8),
              Text(
                existingEntryDetails,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Do you want to save this entry anyway?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'SAVE ANYWAY',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<String?> _checkSimilarEntryBeforeSave() async {
    try {
      // Get current form values
      String villageName = _villageController.text.trim().replaceAll(' ', '');
      String person1Name = _person1Field1Controller.text.trim().replaceAll(' ', '');
      String person1Job = _person1Field2Controller.text.trim();
      String person2Details = _person2Controller.text.trim();

      if (villageName.isEmpty || person1Name.isEmpty) {
        return null;
      }

      // Query database for similar entries in THIS event
      final response = await _supabase
          .from('mois')
          .select('*')
          .eq('event_id', _eventId!)
          .eq('is_deleted', false);

      // Find matching entry
      Map<String, dynamic>? matchingEntry;

      for (var entry in response) {
        if (_isEditMode && _editingMoiId != null && entry['id'] == _editingMoiId) {
          continue;
        }

        String entryVillage = (entry['village_name'] ?? '').trim().toLowerCase();
        if (entryVillage != villageName.toLowerCase()) continue;

        if (entry['persons'] != null) {
          List<dynamic> personsList = entry['persons'] as List;

          if (personsList.isNotEmpty) {
            String entryP1Name = (personsList[0]['name'] ?? '').trim().toLowerCase();
            String entryP1Job = (personsList[0]['job'] ?? '').trim().toLowerCase();

            if (entryP1Name != person1Name.toLowerCase()) continue;
            if (person1Job.isNotEmpty && entryP1Job != person1Job.toLowerCase()) continue;
          } else {
            continue;
          }

          if (person2Details.isNotEmpty && personsList.length > 1) {
            String entryP2Details = (personsList[1]['details'] ?? '').trim().toLowerCase();
            if (entryP2Details.isNotEmpty && entryP2Details != person2Details.toLowerCase()) {
              continue;
            }
          }
        } else {
          continue;
        }

        matchingEntry = entry;
        break;
      }

      if (matchingEntry == null) {
        return null;
      }

      // ✅ Build FULL existing entry details
      String existingEntryDetails = '';
      existingEntryDetails += '📍 Village: ${matchingEntry['village_name'] ?? 'N/A'}\n';
      existingEntryDetails += '🏙️ Living Place: ${matchingEntry['living_place'] ?? 'N/A'}\n';
      existingEntryDetails += '📞 Phone: ${matchingEntry['phone'] ?? 'N/A'}\n';
      existingEntryDetails += '💰 Amount: ₹${matchingEntry['amount']}\n';
      existingEntryDetails += '💳 Payment: ${matchingEntry['payment_method'] ?? 'N/A'}\n';
      existingEntryDetails += '👤 Uncle: ${(matchingEntry['is_uncle'] ?? false) ? 'Yes' : 'No'}\n';

      if (matchingEntry['persons'] != null) {
        List<dynamic> personsList = matchingEntry['persons'] as List;
        if (personsList.isNotEmpty) {
          var p1 = personsList[0];
          existingEntryDetails += '\n👤 Person 1:\n';
          existingEntryDetails += '  Name: ${p1['name'] ?? 'N/A'}\n';
          existingEntryDetails += '  Job: ${p1['job'] ?? 'N/A'}\n';
        }
        if (personsList.length > 1) {
          var p2 = personsList[1];
          existingEntryDetails += '\n👤 Person 2:\n';
          existingEntryDetails += '  Details: ${p2['details'] ?? 'N/A'}\n';
        }
      }

      if (matchingEntry['notes'] != null && matchingEntry['notes'].toString().isNotEmpty) {
        existingEntryDetails += '\n📝 Notes: ${matchingEntry['notes']}\n';
      }

      // ✅ FIXED: Get serial number safely
      final serialNo = matchingEntry['serial_no'] ?? 0;

      // ✅ Show dialog with 2 options only (REMOVED OVERWRITE)
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text(
            '⚠️ Similar Entry Found!',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'An entry with the same Village, Person 1 Name, and Job already exists in Serial No: O$serialNo',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Existing Entry Details:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      decoration: TextDecoration.underline),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    existingEntryDetails,
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Do you want to save this as a new entry anyway?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red[100],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'NO, CANCEL',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'new'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.green[100],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'YES, SAVE NEW',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      );

      return result;
    } catch (e) {
      print('Error checking similar entry: $e');
      return null;
    }
  }

  Future<void> _generateConsolidatedGroupReceipt() async {
    setState(() => _isLoading = true);

    try {
      final operatorName = await _getOperatorName();
      final eventDetails = await _getEventDetails();

      final eventResponse = await _supabase
          .from('events')
          .select('title, venue, event_types(name)')
          .eq('id', _eventId!)
          .single();

      String? eventTitle = eventResponse['title'];
      String? venue = eventResponse['venue'];
      String? eventFor = eventResponse['event_for'];
      String? eventTypeName = eventResponse['event_types']?['name'];

      double totalAmount = 0.0;
      Map<int, int> totalDenominations = {
        500: 0, 200: 0, 100: 0, 50: 0, 20: 0, 10: 0, 5: 0, 1: 0,
      };

      for (var entry in _groupedMois) {
        var amountValue = entry['amount'];
        if (amountValue is int) {
          totalAmount += amountValue.toDouble();
        } else if (amountValue is double) {
          totalAmount += amountValue;
        } else if (amountValue is num) {
          totalAmount += amountValue.toDouble();
        }

        if (entry['payment_method'] == 'CASH') {
          final denoms = await _getDenominations(entry['id']);
          if (denoms != null) {
            denoms.forEach((denom, count) {
              totalDenominations[denom] = (totalDenominations[denom] ?? 0) + count;
            });
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating group receipt...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }

      // ✅ STEP 1: Generate HTML once (reused for both paths)
      final logoBase64 = await MoiReceiptGenerator.getLogoBase64();
      final fontBase64 = await MoiReceiptGenerator.getFontBase64();

      final htmlContent = MoiReceiptGenerator.generateGroupMoiHtml(
        groupId: _currentGroupId!,
        operatorName: operatorName,
        eventDate: eventDetails['event_date'],
        eventTime: eventDetails['event_time'],
        groupEntries: _groupedMois,
        totalAmount: totalAmount,
        totalDenominations: totalDenominations.values.any((v) => v > 0) ? totalDenominations : null,
        customerName: _customerName,
        city: _city,
        customerPhone: _customerPhone,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
        eventTitle: eventTitle,
        eventFor: eventFor,
        eventTypeName: eventTypeName,
        venue: venue,
      );

      // ✅ STEP 2: Generate image for printing (FAST)
      print('🖨️ Generating GROUP image for thermal printer...');
      final imageBytes = await MoiReceiptGenerator.generateGroupReceiptImageOnly(
        htmlContent: htmlContent,
      );

      if (imageBytes != null && mounted) {
        // ✅ STEP 3: Print immediately (NO PDF conversion)
        print('🖨️ Sending GROUP receipt to thermal printer...');
        final printerService = ThermalPrinterService();
        await printerService.connectAndPrintImage(context, imageBytes);
        print('✅ GROUP print job sent to thermal printer');

        // ✅ STEP 4: Generate PDF in background for cloud storage (PARALLEL)
        _generateGroupPdfForCloud(
          htmlContent: htmlContent,
          groupId: _currentGroupId!,
        ).catchError((e) {
          print('❌ Background GROUP PDF generation error: $e');
        });
      } else {
        throw Exception('Failed to generate group receipt image');
      }
    } catch (e) {
      print('Error generating group receipt: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _generateConsolidatedGroupReceipt,
          customMessage: 'Error generating group receipt',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ NEW: Background PDF generation for GROUP receipts
  Future<void> _generateGroupPdfForCloud({
    required String htmlContent,
    required int groupId,
  }) async {
    try {
      print('☁️ Generating GROUP PDF for cloud storage in background...');

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'moi_group_${groupId}_$timestamp.pdf';
      final filePath = '${output.path}/$fileName';

      File? pdfFile;
      bool pdfGenerated = false;

      HeadlessInAppWebView? headlessWebView;

      headlessWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: htmlContent),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useHybridComposition: true,
        ),
        initialSize: Size(302, 800),
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 1500));

            final contentHeight = await controller.evaluateJavascript(
                source: "document.body.scrollHeight"
            );

            int height = 800;
            if (contentHeight != null) {
              height = int.tryParse(contentHeight.toString()) ?? 800;
            }

            await headlessWebView?.setSize(Size(302, height.toDouble()));
            await Future.delayed(const Duration(milliseconds: 500));

            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              final pdfWidth = 80 * PdfPageFormat.mm;
              final pdfHeight = (height / 302) * pdfWidth;

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat(pdfWidth, pdfHeight, marginAll: 0),
                  build: (pw.Context context) {
                    return pw.Image(image, fit: pw.BoxFit.fill);
                  },
                ),
              );

              final file = File(filePath);
              await file.writeAsBytes(await pdf.save());
              pdfFile = file;
              pdfGenerated = true;
              print('✅ GROUP PDF generated for cloud: $filePath');
            }
          } catch (e) {
            print('❌ Error generating GROUP PDF: $e');
          } finally {
            if (headlessWebView != null) {
              await headlessWebView.dispose();
            }
          }
        },
      );

      await headlessWebView.run();

      int attempts = 0;
      while (attempts < 30 && !pdfGenerated) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (pdfGenerated) break;
        attempts++;
      }

      // ✅ Send to cloud if PDF was generated
      if (pdfFile != null) {
        // Collect all phone numbers from group
        List<String> phoneNumbers = [];
        for (var entry in _groupedMois) {
          String? phone = entry['phone'];
          if (phone != null && phone.isNotEmpty) {
            phoneNumbers.add(phone);
          }
        }

        await _sendReceiptToWhatsApp(
          pdfFile!,
          'mois',
          phoneNumbers: phoneNumbers,
          receiptNo: groupId,
        );
        print('✅ GROUP PDF sent to cloud storage');
      }
    } catch (e) {
      print('❌ Error in background GROUP PDF generation: $e');
    }
  }

  Future<void> _saveDenominationsForGroup(String firstMoiId) async {
    // Build denomination data from rows
    Map<String, dynamic> denomData = {
      'moi_id': firstMoiId,
      'event_id': _eventId!,
      'operator_id': _operatorId!,
      'denom_500': 0,
      'denom_200': 0,
      'denom_100': 0,
      'denom_50': 0,
      'denom_20': 0,
      'denom_10': 0,
      'denom_5': 0,
      'denom_1': 0,
    };

    // Accumulate counts
    for (var row in _denomRows) {
      int? denom = row['selectedDenom'];
      int count = int.tryParse(row['countController'].text) ?? 0;

      if (denom != null && count != 0) {
        denomData['denom_$denom'] = (denomData['denom_$denom'] as int) + count;
      }
    }

    // Save denomination (linked to first MOI entry)
    await _supabase.from('moi_denominations').upsert(denomData);
  }

  bool _hasFormData() {
    // ✅ FIX: Check ALL input fields properly
    return _phoneController.text.trim().isNotEmpty ||
        _villageController.text.trim().isNotEmpty ||
        _livingPlaceController.text.trim().isNotEmpty ||
        _notesController.text.trim().isNotEmpty ||
        _person1Field1Controller.text.trim().isNotEmpty ||
        _person1Field2Controller.text.trim().isNotEmpty ||
        _person2Controller.text.trim().isNotEmpty ||
        _amountController.text.trim().isNotEmpty;
  }

  bool _hasNoChanges() {
    if (_originalData == null) {
      print('❌ _originalData is null');
      return false;
    }

    if (!_isEditMode) {
      print('❌ Not in edit mode');
      return false;
    }

    print('🔍 Checking for changes...');
    print('Original data: $_originalData');

    bool phoneChanged =
        (_originalData!['phone'] ?? '') != _phoneController.text.trim();
    print(
        'Phone changed: $phoneChanged (${_originalData!['phone']} vs ${_phoneController.text.trim()})');

    bool villageChanged = (_originalData!['village_name'] ?? '') !=
        _villageController.text.trim();
    print(
        'Village changed: $villageChanged (${_originalData!['village_name']} vs ${_villageController.text.trim()})');

    bool livingPlaceChanged = (_originalData!['living_place'] ?? '') !=
        _livingPlaceController.text.trim();
    print(
        'Living place changed: $livingPlaceChanged (${_originalData!['living_place']} vs ${_livingPlaceController.text.trim()})');

    bool notesChanged =
        (_originalData!['notes'] ?? '') != _notesController.text.trim();
    print('Notes changed: $notesChanged');

    bool paymentMethodChanged =
        _originalData!['payment_method'] != _paymentMethod;
    print('Payment method changed: $paymentMethodChanged');

    bool isUncleChanged = (_originalData!['is_uncle'] ?? false) != _isUncle;
    print('Uncle changed: $isUncleChanged');

    var originalAmount = _originalData!['amount'];
    int currentAmount = int.tryParse(_amountController.text) ?? 0;
    bool amountChanged = originalAmount != currentAmount;
    print('Amount changed: $amountChanged ($originalAmount vs $currentAmount)');

    bool personsChanged = false;
    if (_originalData!['persons'] != null) {
      List<dynamic> originalPersons = _originalData!['persons'] as List;

      String currentP1Name = _person1Field1Controller.text.trim();
      String currentP1Job = _person1Field2Controller.text.trim();
      String currentP2Details = _person2Controller.text.trim();

      String origP1Name = '';
      String origP1Job = '';
      String origP2Details = '';

      if (originalPersons.isNotEmpty) {
        origP1Name = originalPersons[0]['name'] ?? '';
        origP1Job = originalPersons[0]['job'] ?? '';
      }

      if (originalPersons.length > 1) {
        origP2Details = originalPersons[1]['details'] ?? '';
      }

      personsChanged = currentP1Name != origP1Name ||
          currentP1Job != origP1Job ||
          currentP2Details != origP2Details;

      print(
          'Person 1 name changed: ${currentP1Name != origP1Name} ($origP1Name vs $currentP1Name)');
      print(
          'Person 1 job changed: ${currentP1Job != origP1Job} ($origP1Job vs $currentP1Job)');
      print(
          'Person 2 details changed: ${currentP2Details != origP2Details} ($origP2Details vs $currentP2Details)');
    } else {
      personsChanged = _person1Field1Controller.text.trim().isNotEmpty ||
          _person1Field2Controller.text.trim().isNotEmpty ||
          _person2Controller.text.trim().isNotEmpty;
      print('Persons changed (no original): $personsChanged');
    }

    bool hasNoChanges = !phoneChanged &&
        !villageChanged &&
        !livingPlaceChanged &&
        !notesChanged &&
        !paymentMethodChanged &&
        !isUncleChanged &&
        !amountChanged &&
        !personsChanged;

    print('✅ Final result - Has NO changes: $hasNoChanges');

    // Return true if NO changes detected
    return hasNoChanges;
  }

  // Update the _validateForm() method
  Future<bool> _validateForm() async {
    /// ✅ Check if we have grouped entries (final save mode)
    bool isFinalSave = _groupedMois.isNotEmpty;

    if (isFinalSave) {
      // ✅ FINAL SAVE VALIDATION - Only check MOI Details and Denomination

      // 1. Check if MOI Details has at least one entry
      if (_groupedMois.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please add at least one entry to MOI Details before saving!'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      // 2. ✅ CHANGE: Check denomination only if CASH payment (not Cheque/Advance/UPI)
      if (_paymentMethod == 'CASH') {
        int denomTotal = _getTotalAmount();

        // Calculate total from MOI Details
        int totalGroupAmount = 0;
        for (var entry in _groupedMois) {
          var amount = entry['amount'];
          if (amount is int) {
            totalGroupAmount += amount;
          } else if (amount is double) {
            totalGroupAmount += amount.toInt();
          } else if (amount != null) {
            totalGroupAmount += int.tryParse(amount.toString()) ?? 0;
          }
        }

        // Denomination is MANDATORY for CASH
        if (denomTotal == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter denomination details before saving!'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }

        // Validate denomination matches group total
        if (totalGroupAmount != denomTotal) {
          int difference = totalGroupAmount - denomTotal;
          String message = difference > 0
              ? 'Group total is ₹$totalGroupAmount but denomination is ₹$denomTotal. ₹${difference.abs()} is missing!'
              : 'Group total is ₹$totalGroupAmount but denomination is ₹$denomTotal. ₹${difference.abs()} is extra!';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          return false;
        }

        // Validate negative denominations
        for (var row in _denomRows) {
          int count = int.tryParse(row['countController'].text) ?? 0;
          int? denom = row['selectedDenom'];

          if (count < 0 && denom != null) {
            int available = await _getAvailableBalance(denom);

            if (count.abs() > available) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '₹$denom: Insufficient balance. Available: $available, Requested: ${count.abs()}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
              return false;
            }
          }
        }
      }

      return true; // ✅ Final save validation passed
    }

    // ✅ GROUPING VALIDATION - Only check person name and amount

    // 1. Check at least one person has a name
    bool hasValidPerson = _person1Field1Controller.text.trim().isNotEmpty ||
        _person2Controller.text.trim().isNotEmpty;

    if (!hasValidPerson) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one person with a name')),
      );
      if (mounted) setState(() => _isLoading = false);
      return false;
    }

    // 2. Phone validation (optional, only if entered)
    String phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isNotEmpty) {
      if (phoneNumber.length != 10 ||
          !RegExp(r'^\d{10}$').hasMatch(phoneNumber)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Phone number must be exactly 10 digits or leave it empty!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }
    }

    // 3. Amount validation - mandatory for grouping
    String enteredAmountText = _amountController.text.trim();
    if (enteredAmountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount is mandatory! Please enter the amount.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    int enteredAmount = int.tryParse(enteredAmountText) ?? 0;
    if (enteredAmount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount cannot be zero!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    return true; // ✅ Grouping validation passed
  }

  Future<void> _clearFormForNextEntry() async {

    _phoneController.clear();
    _villageController.clear();
    _livingPlaceController.clear();
    _notesController.clear();
    _amountController.clear();

    _person1Field1Controller.clear();
    _person1Field2Controller.clear();
    _person2Controller.clear();

    // ✅ DON'T clear denominations - keep them intact
    // ✅ DON'T clear _denomRows
    // ✅ DON'T clear _currentGroupId or _groupedMois

    setState(() {
      // ✅ NEW: Set payment method to locked method if in group mode
      if (_lockedPaymentMethod != null) {
        _paymentMethod = _lockedPaymentMethod!;
      } else {
        _paymentMethod = 'CASH';
      }
      _isUncle = false;
      // _isEditMode = false;
      _editingMoiId = null;
      _originalData = null;
    });
  }

  Future<void> _clearFormCompletely() async {
    await _loadPreviewSerialNo();

    _phoneController.clear();
    _villageController.clear();
    _livingPlaceController.clear();
    _notesController.clear();
    _amountController.clear();

    _person1Field1Controller.clear();
    _person1Field2Controller.clear();
    _person2Controller.clear();

    // ✅ Clear denomination rows completely
    for (var row in _denomRows) {
      row['countController'].dispose();
      if (row.containsKey('denomController')) {
        row['denomController'].dispose();
      }
    }
    _denomRows.clear();
    _initializeDenominations();

    setState(() {
      _paymentMethod = 'CASH';
      _isUncle = false;
      _isEditMode = false;
      _editingMoiId = null;
      _originalData = null;
      _currentGroupId = null;
      _groupedMois.clear();
      _lockedPaymentMethod = null; // Add this line
    });
  }

  void _handleAddEntry() async {
    await _clearFormForNextEntry(); // ✅ Uses the version that keeps denominations
    _phoneFocusNode.requestFocus();
  }

  void _handleClear() async {
    setState(() {
      _phoneController.clear();
      _villageController.clear();
      _livingPlaceController.clear();
      _notesController.clear();
      _amountController.clear();
      _person1Field1Controller.clear();
      _person1Field2Controller.clear();
      _person2Controller.clear();

      for (var row in _denomRows) {
        row['countController'].dispose();
      }
      _denomRows.clear();
      _initializeDenominations();

      _paymentMethod = 'CASH';
      _isUncle = false;
      _currentGroupId = null;
      _groupedMois.clear();
      _isEditMode = false;
      _editingMoiId = null;
      _originalData = null;
      _lockedPaymentMethod = null; // Add this line
    });
    await _loadPreviewSerialNo();
    _phoneFocusNode.requestFocus(); // ✅ ADD THIS LINE
  }

  // First, add this helper function to convert numbers to words at the top of your class (after the state variables)

  String _numberToWords(int number) {
    if (number == 0) return 'Zero';

    final ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine'
    ];
    final teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen'
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety'
    ];

    String convertHundreds(int n) {
      if (n == 0) return '';
      if (n < 10) return ones[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) {
        int tensDigit = n ~/ 10;
        int onesDigit = n % 10;
        return '${tens[tensDigit]} ${ones[onesDigit]}'.trim();
      }
      int hundreds = n ~/ 100;
      int remainder = n % 100;
      return '${ones[hundreds]} Hundred ${convertHundreds(remainder)}'.trim();
    }

    if (number < 0) return 'Minus ${_numberToWords(-number)}';
    if (number < 1000) return convertHundreds(number);

    // Handle thousands
    if (number < 100000) {
      int thousands = number ~/ 1000;
      int remainder = number % 1000;
      String result = '${convertHundreds(thousands)} Thousand';
      if (remainder > 0) result += ' ${convertHundreds(remainder)}';
      return result.trim();
    }

    // Handle lakhs
    if (number < 10000000) {
      int lakhs = number ~/ 100000;
      int remainder = number % 100000;
      String result = '${convertHundreds(lakhs)} Lakh';
      if (remainder >= 1000) {
        int thousands = remainder ~/ 1000;
        int finalRemainder = remainder % 1000;
        result += ' ${convertHundreds(thousands)} Thousand';
        if (finalRemainder > 0) result += ' ${convertHundreds(finalRemainder)}';
      } else if (remainder > 0) {
        result += ' ${convertHundreds(remainder)}';
      }
      return result.trim();
    }

    // Handle crores
    int crores = number ~/ 10000000;
    int remainder = number % 10000000;
    String result = '${convertHundreds(crores)} Crore';

    if (remainder >= 100000) {
      int lakhs = remainder ~/ 100000;
      int finalRemainder = remainder % 100000;
      result += ' ${convertHundreds(lakhs)} Lakh';
      if (finalRemainder >= 1000) {
        int thousands = finalRemainder ~/ 1000;
        int lastRemainder = finalRemainder % 1000;
        result += ' ${convertHundreds(thousands)} Thousand';
        if (lastRemainder > 0) result += ' ${convertHundreds(lastRemainder)}';
      } else if (finalRemainder > 0) {
        result += ' ${convertHundreds(finalRemainder)}';
      }
    } else if (remainder > 0) {
      if (remainder >= 1000) {
        int thousands = remainder ~/ 1000;
        int lastRemainder = remainder % 1000;
        result += ' ${convertHundreds(thousands)} Thousand';
        if (lastRemainder > 0) result += ' ${convertHundreds(lastRemainder)}';
      } else {
        result += ' ${convertHundreds(remainder)}';
      }
    }

    return result.trim();
  }

  String _getPersonsDisplay(dynamic persons) {
    if (persons == null) return 'No name';
    try {
      List<dynamic> personsList = persons as List;
      if (personsList.isEmpty) return 'No name';

      List<String> names = [];
      for (var person in personsList) {
        if (person['name'] != null && person['name'].toString().isNotEmpty) {
          names.add(person['name']);
        } else if (person['details'] != null &&
            person['details'].toString().isNotEmpty) {
          // For person 2, extract first part before comma
          String details = person['details'];
          String firstName = details.split(',')[0].trim();
          names.add(firstName);
        }
      }
      return names.isEmpty ? 'No name' : names.join(', ');
    } catch (e) {
      return 'No name';
    }
  }

  Future<String> _getOperatorName() async {
    try {
      final response = await _supabase
          .from('users')
          .select('full_name')
          .eq('id', _operatorId!)
          .single();

      return response['full_name'] ?? 'Operator';
    } catch (e) {
      print('Error fetching operator name: $e');
      return 'Operator';
    }
  }

  Future<Map<String, dynamic>> _getEventDetails() async {
    try {
      final response = await _supabase
          .from('events')
          .select('event_date, event_time')
          .eq('id', _eventId!)
          .single();

      DateTime eventDate = DateTime.parse(response['event_date']);

      TimeOfDay eventTime = TimeOfDay.now();
      if (response['event_time'] != null) {
        final timeParts = response['event_time'].split(':');
        eventTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }

      return {
        'event_date': eventDate,
        'event_time': eventTime,
      };
    } catch (e) {
      print('Error fetching event details: $e');
      return {
        'event_date': DateTime.now(),
        'event_time': TimeOfDay.now(),
      };
    }
  }

  Future<Map<int, int>?> _getDenominations(String moiId) async {
    try {
      final response = await _supabase
          .from('moi_denominations')
          .select('*')
          .eq('moi_id', moiId)
          .maybeSingle();

      if (response != null) {
        return {
          500: response['denom_500'] ?? 0,
          200: response['denom_200'] ?? 0,
          100: response['denom_100'] ?? 0,
          50: response['denom_50'] ?? 0,
          20: response['denom_20'] ?? 0,
          10: response['denom_10'] ?? 0,
          5: response['denom_5'] ?? 0,
          1: response['denom_1'] ?? 0,
        };
      }
      return null;
    } catch (e) {
      print('Error loading denominations: $e');
      return null;
    }
  }

  Future<void> _handleGenerateSingleReceipt() async {
    print('🎯 _handleGenerateSingleReceipt called');

    if (!await _validateForm()) return;

    setState(() => _isLoading = true);

    try {
      print('🎯 Payment method: $_paymentMethod');
      print('🎯 Is edit mode: $_isEditMode');
      print('🎯 Editing MOI ID: $_editingMoiId');
      print('🎯 Current group ID: $_currentGroupId');

      String? moiId = _editingMoiId;
      if (moiId == null) {
        moiId = await _saveMoi(_currentGroupId, forceUpdate: false);
        if (moiId == null) {
          throw Exception('Failed to save MOI');
        }
      }

      final operatorName = await _getOperatorName();
      final eventDetails = await _getEventDetails();  // Already exists

// ADD THIS - fetch event title, type name, venue
      final eventResponse = await _supabase
          .from('events')
          .select('title, venue, event_types(name)')
          .eq('id', _eventId!)
          .single();

      String? eventTitle = eventResponse['title'];
      String? venue = eventResponse['venue'];
      String? eventFor = eventResponse['event_for'];
      String? eventTypeName = eventResponse['event_types']?['name'];

      print('🎯 Before denomination check - Payment method: $_paymentMethod');

      Map<int, int>? denominations;
      if (_paymentMethod == 'CASH') {
        print('🎯 Inside CASH denomination block');
        print('🎯 Building denominations from form (_denomRows)');
        print('🎯 Number of denom rows: ${_denomRows.length}');

        denominations = {
          500: 0,
          200: 0,
          100: 0,
          50: 0,
          20: 0,
          10: 0,
          5: 0,
          1: 0,
        };

        for (var row in _denomRows) {
          int? denom = row['selectedDenom'];
          int count = int.tryParse(row['countController'].text) ?? 0;

          print('🎯 Processing row: denom=$denom, count=$count');

          if (denom != null && count != 0) {
            denominations[denom] = (denominations[denom] ?? 0) + count;
          }
        }

        print('✅ Denominations built from form: $denominations');

        // ✅ CRITICAL: Check if denominations map has any non-zero values
        bool hasNonZeroDenoms = denominations.values.any((count) => count != 0);
        print('🔍 Has non-zero denominations: $hasNonZeroDenoms');

        if (!hasNonZeroDenoms) {
          print('⚠️ WARNING: All denominations are zero!');
          denominations = null; // Don't pass empty denominations
        }
      } else {
        print('🎯 Payment method is NOT CASH: $_paymentMethod');
      }

      print('🔍 Final denominations being passed to receipt generator: $denominations');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating receipt...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      print('🎯 About to call generateSingleMoiReceipt with:');
      print('   - paymentMethod: $_paymentMethod');
      print('   - denominations: $denominations');

      final file = await MoiReceiptGenerator.generateSingleMoiReceipt(
        context: context,
        serialNo: _serialNo!,
        operatorName: operatorName,
        eventDate: eventDetails['event_date'],
        eventTime: eventDetails['event_time'],
        villageName: _villageController.text.trim(),
        livingPlace: _livingPlaceController.text.trim(),
        person1Name: _person1Field1Controller.text.trim(),
        notes: _notesController.text.trim(),
        person1Job: _person1Field2Controller.text.trim(),
        person2Details: _person2Controller.text.trim(),
        phone: _phoneController.text.trim(),
        amount: _paymentMethod == 'CASH'
            ? _getTotalAmount()
            : int.tryParse(_amountController.text) ?? 0,
        paymentMethod: _paymentMethod,
        denominations: denominations,
        customerName: _customerName,
        city: _city,
        customerPhone: _customerPhone,
        isUncle: _isUncle,
        eventTitle: eventTitle,
        eventFor: eventFor,
        eventTypeName: eventTypeName,
        venue: venue,
      );

      if (file != null && mounted) {
        print('🎯 Single receipt generated, attempting to print...');

        // ✅ Print using thermal printer
        final printerService = ThermalPrinterService();
        await printerService.connectAndPrint(context, file);
        // await printerService.connectAndPrint(context, file);

        // ✅ Send to WhatsApp
        String? phoneNumber = _phoneController.text.trim();
        if (phoneNumber.isNotEmpty) {
          print('🎯 Sending receipt to WhatsApp: $phoneNumber');
          await _sendReceiptToWhatsApp(
              file,
              'mois',
              phoneNumbers: [phoneNumber],
              receiptNo: _serialNo
          );
        }
      } else {
        throw Exception('Failed to generate receipt');
      }
    } catch (e) {
      print('❌ Error in _handleGenerateSingleReceipt: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _handleGenerateSingleReceipt,
          customMessage: 'Error generating receipt',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ STEP 1: Replace the _sendReceiptToWhatsApp method (around line 1950)
// Delete the old method and replace with this:


// ✅ FIXED: Updated _sendReceiptToWhatsApp method to accept phone numbers
// Replace the existing _sendReceiptToWhatsApp method (around line 1950) with this:

  Future<void> _sendReceiptToWhatsApp(File pdfFile, String receiptType, {List<String>? phoneNumbers, int? receiptNo}) async {
    try {
      print('📱 ========== WHATSAPP SEND STARTED ==========');
      print('📱 Event ID: $_eventId');
      print('📱 Receipt Type: $receiptType');
      print('📱 PDF Path: ${pdfFile.path}');
      print('📱 Phone Numbers to send: $phoneNumbers');

      // Step 1: Get skip_whatsapp flag from events table
      print('📱 Fetching event details from database...');
      final eventResponse = await _supabase
          .from('events')
          .select('skip_whatsapp')
          .eq('id', _eventId!)
          .single();

      print('📱 Event Response: $eventResponse');

      bool skipWhatsApp = eventResponse['skip_whatsapp'] ?? false;
      print('📱 skip_whatsapp from DB: $skipWhatsApp');

      // ✅ CRITICAL: Always store in backend, control WhatsApp sending via to_whatsapp parameter
      String toWhatsApp = (!skipWhatsApp).toString(); // "true" = send to WhatsApp, "false" = skip WhatsApp

      // Step 2: Validate and clean phone numbers
      List<String> validPhones = [];
      if (phoneNumbers != null && phoneNumbers.isNotEmpty) {
        for (String phoneNum in phoneNumbers) {
          String cleanedPhone = phoneNum.replaceAll(RegExp(r'\D'), '');
          if (cleanedPhone.isEmpty) continue;

          if (cleanedPhone.length == 10) {
            cleanedPhone = '91$cleanedPhone'; // Add India country code
            validPhones.add(cleanedPhone);
          }
        }
      }

      print('📱 Valid phone numbers: $validPhones');
      print('📱 to_whatsapp parameter: $toWhatsApp');

      // ✅ CRITICAL CHANGE: ALWAYS send to backend (even with no phone numbers)
      int successCount = 0;
      int failCount = 0;

      // ✅ If no phone numbers, send once with empty phone to store in backend
      List<String> phonesToProcess = validPhones.isEmpty ? [''] : validPhones;

      for (String cleanedPhone in phonesToProcess) {
        try {
          print('📤 Sending to backend${cleanedPhone.isNotEmpty ? " for: $cleanedPhone" : " (no phone - backend storage only)"}');

          var request = http.MultipartRequest(
            'POST',
            Uri.parse('https://agmwcgxssorjwiinpknr.supabase.co/functions/v1/receipts_handler'),
          );

          // Add authorization header
          final session = _supabase.auth.currentSession;
          if (session != null) {
            request.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }

          // Add form fields
          request.fields['event_id'] = _eventId!;
          request.fields['phone_number'] = cleanedPhone; // ✅ Can be empty string
          request.fields['to_whatsapp'] = toWhatsApp; // ✅ Backend decides whether to send WhatsApp
          request.fields['receipt_type'] = receiptType;
          request.fields['receipt_no'] = receiptNo?.toString() ?? '';

          // Add PDF file
          var pdfMultipart = await http.MultipartFile.fromPath(
            'pdf',
            pdfFile.path,
            filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
          request.files.add(pdfMultipart);

          // Send request
          final streamedResponse = await request.send();
          final responseBody = await streamedResponse.stream.bytesToString();

          if (streamedResponse.statusCode == 200) {
            print('✅ SUCCESS: Receipt stored in backend${cleanedPhone.isNotEmpty ? " for $cleanedPhone" : ""}');
            successCount++;
          } else {
            print('❌ FAILED: Receipt not stored (${streamedResponse.statusCode})');
            print('Response: $responseBody');
            failCount++;
          }
        } catch (e) {
          print('❌ ERROR sending${cleanedPhone.isNotEmpty ? " for $cleanedPhone" : ""}: $e');
          failCount++;
        }
      }

      // Show final status
      if (mounted) {
        if (successCount > 0) {
          String message;
          if (skipWhatsApp) {
            message = '✅ Receipt saved to backend (WhatsApp skipped)';
          } else {
            message = validPhones.isEmpty
                ? '✅ Receipt saved to backend'
                : '✅ Receipt sent to $successCount number(s)${failCount > 0 ? ', $failCount failed' : ''}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to save receipt to backend'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      print('📱 ========== SUMMARY ==========');
      print('📱 Success: $successCount');
      print('📱 Failed: $failCount');
      print('📱 Skip WhatsApp: $skipWhatsApp');
      print('📱 ==============================');

    } catch (e, stackTrace) {
      print('❌ ========== EXCEPTION ==========');
      print('❌ Error sending receipt to backend: $e');
      print('❌ Stack trace: $stackTrace');
      print('❌ ================================');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Backend error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<int> _getAvailableBalance(int denomination) async {
    try {
      if (_eventId == null) return 0;

      // Step 1: Get collected from MOI (CASH only)
      final moiData = await _supabase.from('moi_denominations').select('''
          denom_$denomination,
          mois!moi_denominations_moi_id_fkey (
            payment_method,
            is_deleted
          )
        ''').eq('event_id', _eventId!);

      int collected = 0;
      for (var entry in moiData) {
        final moi = entry['mois'];
        if (moi != null &&
            moi['payment_method'] == 'CASH' &&
            moi['is_deleted'] == false) {
          collected += (entry['denom_$denomination'] ?? 0) as int;
        }
      }

      // Step 2: Get withdrawn
      final withdrawalData = await _supabase.from('cash_withdrawals').select('''
          cash_withdrawal_denominations (
            denom_$denomination
          )
        ''').eq('event_id', _eventId!);

      int withdrawn = 0;
      for (var withdrawal in withdrawalData) {
        final denomData = withdrawal['cash_withdrawal_denominations'];
        if (denomData != null) {
          withdrawn += (denomData['denom_$denomination'] ?? 0) as int;
        }
      }

      // Step 3: Get exchanged (net)
      final exchangeData = await _supabase.from('cash_exchanges').select('''
          cash_exchange_denominations (
            denom_$denomination
          )
        ''').eq('event_id', _eventId!);

      int exchanged = 0;
      for (var exchange in exchangeData) {
        final denomData = exchange['cash_exchange_denominations'];
        if (denomData != null) {
          exchanged += (denomData['denom_$denomination'] ?? 0) as int;
        }
      }

      // Available = Collected - Withdrawn + Exchanged
      return collected - withdrawn + exchanged;
    } catch (e) {
      print('Error getting available balance: $e');
      return 0;
    }
  }

  Future<void> _handleGenerateGroupReceipt() async {
    if (_groupedMois.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No grouped entries to generate receipt'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final receiptType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Group Receipt'),
        content: const Text('How would you like to generate the receipts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'consolidated'),
            child: const Text('One Group Receipt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'split'),
            child: const Text('Individual Receipts'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (receiptType == null) return;

    setState(() => _isLoading = true);

    try {
      final operatorName = await _getOperatorName();
      final eventDetails = await _getEventDetails();  // Already exists

// ADD THIS - fetch event title, type name, venue
      final eventResponse = await _supabase
          .from('events')
          .select('title, venue, event_types(name)')
          .eq('id', _eventId!)
          .single();

      String? eventTitle = eventResponse['title'];
      String? venue = eventResponse['venue'];
      String? eventFor = eventResponse['event_for'];
      String? eventTypeName = eventResponse['event_types']?['name'];


      if (receiptType == 'consolidated') {
        double totalAmount = 0.0;
        Map<int, int> totalDenominations = {
          500: 0,
          200: 0,
          100: 0,
          50: 0,
          20: 0,
          10: 0,
          5: 0,
          1: 0,
        };

        for (var entry in _groupedMois) {
          var amountValue = entry['amount'];
          if (amountValue is int) {
            totalAmount += amountValue.toDouble();
          } else if (amountValue is double) {
            totalAmount += amountValue;
          } else if (amountValue is num) {
            totalAmount += amountValue.toDouble();
          }

          if (entry['payment_method'] == 'CASH') {
            final denoms = await _getDenominations(entry['id']);
            if (denoms != null) {
              denoms.forEach((denom, count) {
                totalDenominations[denom] =
                    (totalDenominations[denom] ?? 0) + count;
              });
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Generating group receipt...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // ✅ STEP 4: Update _generateConsolidatedGroupReceipt method (around line 1420)

        final file = await MoiReceiptGenerator.generateGroupMoiReceipt(
          context: context,
          groupId: _currentGroupId!,
          operatorName: operatorName,
          eventDate: eventDetails['event_date'],
          eventTime: eventDetails['event_time'],
          groupEntries: _groupedMois,
          totalAmount: totalAmount,
          totalDenominations: totalDenominations.values.any((v) => v > 0)
              ? totalDenominations
              : null,
          customerName: _customerName,
          city: _city,
          customerPhone: _customerPhone,
          eventTitle: eventTitle,
          eventFor: eventFor,
          eventTypeName: eventTypeName,
          venue: venue,
        );

        if (file != null && mounted) {
          // ✅ Print to thermal printer
          // This should actually be generateGroupMoiReceiptWithImage
          final result = await MoiReceiptGenerator.generateGroupMoiReceiptWithImage(
            context: context,
            groupId: _currentGroupId!,
            operatorName: operatorName,
            eventDate: eventDetails['event_date'],
            eventTime: eventDetails['event_time'],
            groupEntries: _groupedMois,
            totalAmount: totalAmount,
            totalDenominations: totalDenominations.values.any((v) => v > 0)
                ? totalDenominations
                : null,
            customerName: _customerName,
            city: _city,
            customerPhone: _customerPhone,
            eventTitle: eventTitle,
            eventFor: eventFor,
            eventTypeName: eventTypeName,
            venue: venue,
          );
          if (result != null) {
            final printerService = ThermalPrinterService();
            await printerService.connectAndPrintImage(context, result['imageBytes']);
            // await printerService.connectAndPrintImage(context, result['imageBytes']);
          }

          // Send to all WhatsApp numbers
          List<String> phoneNumbers = [];
          for (var entry in _groupedMois) {
            String? phone = entry['phone'];
            if (phone != null && phone.isNotEmpty) {
              phoneNumbers.add(phone);
            }
          }

          if (phoneNumbers.isNotEmpty) {
            await _sendReceiptToWhatsApp(file, 'mois', phoneNumbers: phoneNumbers, receiptNo: _currentGroupId);
          }
        }else {
          throw Exception('Failed to generate group receipt');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generating ${_groupedMois.length} receipts...'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        List<Map<String, dynamic>> entriesWithDenoms = [];
        for (var entry in _groupedMois) {
          Map<String, dynamic> entryData = Map.from(entry);
          if (entry['payment_method'] == 'CASH') {
            entryData['denominations'] = await _getDenominations(entry['id']);
          }
          entriesWithDenoms.add(entryData);
        }

        final files = await MoiReceiptGenerator.generateSplitGroupReceipts(
          context: context,
          operatorName: operatorName,
          eventDate: eventDetails['event_date'],
          eventTime: eventDetails['event_time'],
          groupEntries: entriesWithDenoms,
          customerName: _customerName,
          city: _city,
          customerPhone: _customerPhone,
          eventTitle: eventTitle,
          eventFor: eventFor,
          eventTypeName: eventTypeName,
          venue: venue,
        );

        if (files.isNotEmpty && mounted) {
          final printerService = ThermalPrinterService();

          // Print each receipt
          for (int i = 0; i < files.length; i++) {
            await printerService.connectAndPrint(context, files[i]);
            // await printerService.connectAndPrint(context, files[i]);

            // Send to WhatsApp
            if (i < entriesWithDenoms.length) {
              String? phone = entriesWithDenoms[i]['phone'];
              if (phone != null && phone.isNotEmpty) {
                await _sendReceiptToWhatsApp(
                    files[i],
                    'mois',
                    phoneNumbers: [phone],
                    receiptNo: entriesWithDenoms[i]['serial_no']
                );
              }
            }
          }
        }
        else {
          throw Exception('Failed to generate receipts');
        }
      }
    } catch (e) {
      print('Error in _handleGenerateGroupReceipt: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _handleGenerateGroupReceipt,
          customMessage: 'Error generating group receipt',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ FIX 3: Update build method to hide denomination section when skip_denomination is true
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Ctrl+S
          if (event.logicalKey == LogicalKeyboardKey.keyS &&
              HardwareKeyboard.instance.isControlPressed) {
            _handleSaveAndPrint();
            return KeyEventResult.handled;
          }

          // Ctrl+Enter
          if (event.logicalKey == LogicalKeyboardKey.enter &&
              HardwareKeyboard.instance.isControlPressed) {
            _handleGroup();
            return KeyEventResult.handled;
          }

          // Ctrl+Z → Move to village for next entry (after filling denomination)
          if (event.logicalKey == LogicalKeyboardKey.keyZ &&
              HardwareKeyboard.instance.isControlPressed) {
            FocusScope.of(context).requestFocus(_villageFocusNode);
            return KeyEventResult.handled;
          }

          // ✅ FIX: Only allow Ctrl+D if NOT skipping denomination
          if (event.logicalKey == LogicalKeyboardKey.keyD &&
              HardwareKeyboard.instance.isControlPressed &&
              !_skipDenomination) {
            if (_denomRows.isNotEmpty) {
              FocusScope.of(context).requestFocus(_firstDenomFocusNode);
            }
            return KeyEventResult.handled;
          }

          // Ctrl+Delete
          if (event.logicalKey == LogicalKeyboardKey.delete &&
              HardwareKeyboard.instance.isControlPressed) {
            _handleClear();
            return KeyEventResult.handled;
          }

          // Ctrl+A (Add Entry)
          if (event.logicalKey == LogicalKeyboardKey.keyA &&
              HardwareKeyboard.instance.isControlPressed) {
            if (_currentGroupId != null) {
              _handleAddEntry();
              return KeyEventResult.handled;
            }
          }

          // Ctrl+P (Generate receipt) - ✅ FIX: Only if NOT skipping print
          if (event.logicalKey == LogicalKeyboardKey.keyP &&
              HardwareKeyboard.instance.isControlPressed &&
              !_skipPrint) {
            if (_currentGroupId != null && _groupedMois.isNotEmpty) {
              _handleGenerateGroupReceipt();
            } else if (_currentGroupId == null &&
                (_isEditMode || _hasFormData())) {
              _handleGenerateSingleReceipt();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Form(                    // ✅ ADD THIS
        key: _formKey,                // ✅ ADD THIS
        child: Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              _isEditMode ? 'Edit MOI' : 'Collect Moi',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Stack(
            children: [
              GestureDetector(              // ← ADD THIS
                  onTap: () {
                    setState(() {
                      _villageSuggestions = [];
                      _showVillageSuggestions = false;
                      _jobSuggestions = [];
                      _showJobSuggestions = false;
                    });
                    FocusScope.of(context).unfocus();
                  },
                  child: SingleChildScrollView(   // ← SAME LINE, now wrapped
                    padding: const EdgeInsets.all(12),
                    child: Column(
                  children: [
                    _buildSerialAndPaymentHeader(),
                    const SizedBox(height: 12),
                    // ... phone number field ...
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Search Mobile Number',
                            style:
                            TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            textInputAction: TextInputAction.next,   // ADD
                            onSubmitted: (_) => FocusScope.of(context).requestFocus(_villageFocusNode), // ADD
                            keyboardType:
                            TextInputType.number, // ✅ CHANGE from phone to number
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly, // ✅ ADD THIS - Only digits allowed
                            ],
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Search Mobile Number',
                              contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              isDense: true,
                              counterText: '', // Hide character counter
                            ),
                            onChanged: (value) {
                              // Auto-fill when 10 digits are entered
                              if (value.length == 10 && !_isEditMode) {
                                _autoFillFromPhoneNumber(value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildVillageAndLivingPlace(),
                    const SizedBox(height: 12),
                    _buildPerson1Fields(),
                    const SizedBox(height: 12),
                    _buildPerson2Field(),
                    const SizedBox(height: 12),
                    _buildTextField('Notes', _notesController, maxLines: 2),
                    const SizedBox(height: 12),
                    _buildAmountField(),
                    const SizedBox(height: 12),

                    // MOI Details
                    if (_groupedMois.isNotEmpty) _buildMoiDetails(),
                    const SizedBox(height: 12),

                    // ✅ FIX: Only show denomination if NOT skipping AND payment is CASH
                    if (_paymentMethod == 'CASH' && !_skipDenomination) _buildDenominations(),
                    const SizedBox(height: 12),
                    if (_paymentMethod == 'CASH' && !_skipDenomination) _buildAmountSummary(),
                    const SizedBox(height: 12),

                    _buildActionButtons(),
                  ],
                ),
              ),
              ),
              // ✅ NEW: Loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 4,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSerialAndPaymentHeader() {
    // ✅ NEW: Check if payment method is locked
    bool isPaymentMethodLocked = _lockedPaymentMethod != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Serial No.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text(
                  'O${_serialNo?.toString() ?? '0'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Uncle',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Checkbox(
                value: _isUncle,
                onChanged: (value) {
                  setState(() {
                    _isUncle = value ?? false;
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Cheque / Advance / UPI',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Checkbox(
                      value: _paymentMethod == 'OTHERS',
                      onChanged: isPaymentMethodLocked ? null : (value) {
                        setState(() {
                          _paymentMethod = value == true ? 'OTHERS' : 'CASH';
                          if (_paymentMethod == 'OTHERS') {
                            for (var row in _denomRows) {
                              row['countController'].clear();
                            }
                          }
                        });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              // ✅ Lock indicator - now smaller and outside the Flexible
              if (isPaymentMethodLocked)
                Container(
                  margin: const EdgeInsets.only(left: 2),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    border: Border.all(color: Colors.orange, width: 1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Icon(Icons.lock, size: 14, color: Colors.orange[900]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            focusNode: _notesFocusNode,                      // ADD
            textInputAction: TextInputAction.next,            // ADD
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_amountFocusNode), // ADD
            maxLines: maxLines,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: label,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVillageAndLivingPlace() {
    // Village text field height: isDense + padding ≈ 40px, label above ≈ 18px + 6px gap = 64px total
    // Dropdown top offset = label(18) + gap(6) + field(40) = 64
    const double _dropdownTopOffset = 64.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Village Name',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                  CompositedTransformTarget(
                    link: _villageLayerLink,
                    child: TextFormField(
                        controller: _villageController,
                        focusNode: _villageFocusNode,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Village name is required';
                          }
                          return null;
                        },
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        onFieldSubmitted: (_) {
                          if (!_showVillageSuggestions) {
                            FocusScope.of(context).requestFocus(_livingPlaceFocusNode);
                          }
                        },
                        onChanged: (value) {
                          if (value.trim().isEmpty) {
                            setState(() {
                              _villageSuggestions = [];
                              _showVillageSuggestions = false;
                              _villageHighlightIndex = -1;
                            });
                            _removeVillageOverlay();
                          } else {
                            _loadVillageSuggestions(value);
                          }
                        },
                        onTap: () {
                          if (_villageController.text.isNotEmpty) {
                            _loadVillageSuggestions(_villageController.text);
                          }
                        },
                      ),
                  ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Living City',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _livingPlaceController,
                        focusNode: _livingPlaceFocusNode,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_person1NameFocusNode),
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
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
  }

  // Replace _buildPerson1Fields():
  Widget _buildPerson1Fields() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Init, Name 1',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _person1Field1Controller,
            focusNode: _person1NameFocusNode,                // ADD
            textInputAction: TextInputAction.next,            // ADD
            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_person1JobFocusNode), // ADD
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'e.g., init, name',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          // Job field with autocomplete
          TextFormField(
            controller: _person1Field2Controller,
            focusNode: _person1JobFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (value) {
              // Save new job to DB when user presses next/done
              if (value.trim().isNotEmpty) {
                _saveNewJobToDatabase(value.trim());
              }
              setState(() {
                _jobSuggestions = [];
                _showJobSuggestions = false;
                _jobHighlightIndex = -1;
              });
              FocusScope.of(context).requestFocus(_person2FocusNode);
            },
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'e.g., education, job',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            onChanged: (value) {
              if (value.trim().isEmpty) {
                setState(() {
                  _jobSuggestions = [];
                  _showJobSuggestions = false;
                  _jobHighlightIndex = -1;
                });
              } else {
                _loadJobSuggestions(value);
              }
            },
            onTap: () {
              if (_person1Field2Controller.text.isNotEmpty) {
                _loadJobSuggestions(_person1Field2Controller.text);
              }
            },
          ),
          if (_showJobSuggestions)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              width: double.infinity,  // ← extends full width
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.blue, width: 1.5),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4)
                ],
              ),
              child: Scrollbar(
                thumbVisibility: true,
                controller: _jobScrollController,
                child: ListView.builder(
                  controller: _jobScrollController,
                  shrinkWrap: true,
                  itemCount: _jobSuggestions.length,
                  itemBuilder: (context, index) {
                  final isHighlighted = index == _jobHighlightIndex;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _person1Field2Controller.text = _jobSuggestions[index];
                        _person1Field2Controller.selection =
                            TextSelection.fromPosition(TextPosition(
                                offset: _person1Field2Controller.text.length));
                        _jobSuggestions = [];
                        _showJobSuggestions = false;
                        _jobHighlightIndex = -1;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? Colors.blue[100]
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                              color: Colors.grey[200]!, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isHighlighted)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.chevron_right,
                                  size: 14, color: Colors.blue),
                            ),
                          Expanded(
                            child: Text(
                              _jobSuggestions[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isHighlighted
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isHighlighted
                                    ? Colors.blue[900]
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPerson2Field() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Init, Name 2, Education, Job',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _person2Controller,
            focusNode: _person2FocusNode,                    // ADD
            textInputAction: TextInputAction.next,            // ADD
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_notesFocusNode), // ADD
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g., init, name, education, job',
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // Update the _buildAmountField() widget
  Widget _buildAmountField() {
    int amount = int.tryParse(_amountController.text) ?? 0;
    String amountInWords = amount > 0 ? _numberToWords(amount) : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Amount',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2)),
            child: TextFormField(
              controller: _amountController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Amount is required';
                }
                if (int.tryParse(value) == 0) {
                  return 'Amount cannot be zero';
                }
                return null;
              },
              focusNode: _amountFocusNode,
              textInputAction: TextInputAction.next,            // ADD
              onFieldSubmitted: (_) {                           // ADD
                if (_paymentMethod == 'CASH' && !_skipDenomination) {
                  FocusScope.of(context).requestFocus(_firstDenomFocusNode);
                }
              },
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')), // Only digits and optional minus at start
              ],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {}); // Rebuild to update amount in words
              },
            ),
          ),
          if (amountInWords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$amountInWords ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDenominations() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Denomination',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._denomRows.asMap().entries.map((entry) {
            int index = entry.key;
            var row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildDenomRow(row, index),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDenomRow(Map<String, dynamic> row, int index) {
    final controller = row['countController'] as TextEditingController;
    final selectedDenom = row['selectedDenom'];

    if (!row.containsKey('denomController')) {
      row['denomController'] = TextEditingController(
          text: selectedDenom != null ? selectedDenom.toString() : '');
    }
    final denomController = row['denomController'] as TextEditingController;

    int count = int.tryParse(controller.text) ?? 0;
    int total = (selectedDenom ?? 0) * count;

    // Check if we need to show availability
    bool showAvailability = count < 0 && selectedDenom != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 80,
              height: 35,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.white,
              ),
              child: TextField(
                controller: denomController,
                focusNode: index == 0 ? _firstDenomFocusNode : null,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // Only digits (no minus for denomination)
                ],
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  prefixText: '₹',
                  prefixStyle:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  hintText: '0',
                ),
                onChanged: (value) {
                  if (value.isEmpty) {
                    setState(() {
                      row['selectedDenom'] = null;
                    });
                    return;
                  }

                  int? typedValue = int.tryParse(value);
                  if (typedValue == null) return;

                  List<int> validDenoms = [1, 5, 10, 20, 50, 100, 200, 500];

                  // ✅ FIXED: Check if the typed value exactly matches a valid denomination
                  if (!validDenoms.contains(typedValue)) {
                    // Only show error if user has finished typing (not while typing "200")
                    // Check if the current value could potentially become a valid denomination
                    bool couldBeValid = validDenoms
                        .any((denom) => denom.toString().startsWith(value));

                    if (!couldBeValid) {
                      denomController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Only ₹1, ₹5, ₹10, ₹20, ₹50, ₹100, ₹200, ₹500 allowed'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      setState(() {
                        row['selectedDenom'] = null;
                      });
                      return;
                    }
                    // If could be valid (e.g., typed "2" which could become "20" or "200"), don't set yet
                    return;
                  }

                  setState(() {
                    row['selectedDenom'] = typedValue;
                  });
                },
              ),
            ),
            const SizedBox(width: 6),
            const Text('×',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2)),
                child: TextField(
                  controller: controller,
                  // focusNode: index == 0 ? _firstDenomFocusNode : null,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
                  ],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text('=',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Container(
              width: 90,
              height: 35,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.grey[200],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    total.toString(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Availability indicator (only for negative counts)
        if (showAvailability)
          FutureBuilder<int>(
            future: _getAvailableBalance(selectedDenom!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 2, left: 90),
                  child: SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(strokeWidth: 1),
                  ),
                );
              }

              int available = snapshot.data ?? 0;
              bool isSufficient = available.abs() >= count.abs();

              return Padding(
                padding: const EdgeInsets.only(top: 2, left: 90),
                child: Text(
                  'Available: $available',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSufficient ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // Update the _buildAmountSummary() widget
  Widget _buildAmountSummary() {
    int totalAmount = _getTotalAmount(); // Now safe with null check
    String amountInWords = totalAmount > 0 ? _numberToWords(totalAmount) : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Count: ${_getTotalCount()}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                Text('Total Amount: ₹$totalAmount',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (amountInWords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$amountInWords Rupees',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoiDetails() {
    // ✅ Calculate totals
    int totalCount = _groupedMois.length;
    int totalAmount = 0;

    for (var entry in _groupedMois) {
      var amount = entry['amount'];
      if (amount is int) {
        totalAmount += amount;
      } else if (amount is double) {
        totalAmount += amount.toInt();
      } else if (amount != null) {
        totalAmount += int.tryParse(amount.toString()) ?? 0;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Moi Details',
                    style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                if (_currentGroupId != null)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Group ID - $_currentGroupId',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                  ),
              ],
            ),
          ),

          // List of entries
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            child: _groupedMois.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Grouped entries will appear here...',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
                : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(10),
                itemCount: _groupedMois.length,
                separatorBuilder: (context, index) => const Divider(
                    color: Colors.black, thickness: 1, height: 12),
                itemBuilder: (context, index) {
                  final moi = _groupedMois[index];
                  final isCurrentlyEditing = _editingMoiId == moi['id'];

                  var amountValue = moi['amount'];
                  int displayAmount = 0;
                  if (amountValue is int) {
                    displayAmount = amountValue;
                  } else if (amountValue is double) {
                    displayAmount = amountValue.toInt();
                  } else if (amountValue != null) {
                    displayAmount = int.tryParse(amountValue.toString()) ?? 0;
                  }

                  return Dismissible(
                    key: Key('${moi['id']}_$index'),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      if (moi['is_temp'] != true) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '❌ Cannot delete saved entries. This entry is already saved in the database.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                        return false;
                      }
                      if (_isEditMode) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '❌ Cannot delete entry while in edit mode.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                        return false;
                      } else {
                        return await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => AlertDialog(
                            title: const Text(
                              '🗑️ Delete Entry',
                              style: TextStyle(
                                  color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Do you want to delete this entry from the group?',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Text('Serial No: O${moi['serial_no']}'),
                                Text('Name: ${_getPersonsDisplay(moi['persons'])}'),
                                if (moi['village_name'] != null)
                                  Text('Village: ${moi['village_name']}'),
                                Text('Amount: ₹$displayAmount'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.grey[200],
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                ),
                                child: const Text(
                                  'CANCEL',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.red[100],
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                ),
                                child: const Text(
                                  'DELETE',
                                  style: TextStyle(
                                      color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    onDismissed: (direction) async {
                      final moiToDelete = Map<String, dynamic>.from(moi);
                      await _handleDeleteFromGroup(moiToDelete);
                    },
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      child: const Icon(Icons.delete, color: Colors.white, size: 30),
                    ),
                    secondaryBackground: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white, size: 30),
                    ),
                    // ✅ CHANGED: Replace InkWell with GestureDetector for long press
                    child: GestureDetector(
                      onLongPress: () {
                        // Only load on long press (3 seconds)
                        _loadGroupedEntryForEdit(moi);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isCurrentlyEditing
                              ? Colors.blue.shade50
                              : (moi['is_temp'] == true
                              ? Colors.yellow[50]
                              : Colors.transparent),
                          border: isCurrentlyEditing
                              ? Border.all(color: Colors.blue, width: 2)
                              : (moi['is_temp'] == true
                              ? Border.all(color: Colors.orange, width: 1)
                              : null),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getPersonsDisplay(moi['persons']),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: isCurrentlyEditing
                                          ? Colors.blue
                                          : Colors.black,
                                    ),
                                  ),
                                  if (moi['village_name'] != null)
                                    Text(
                                      moi['village_name'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isCurrentlyEditing
                                            ? Colors.blue.shade700
                                            : Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isCurrentlyEditing)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'EDITING',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            Text(
                              '₹$displayAmount',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isCurrentlyEditing
                                    ? Colors.blue
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
            ),
          ),

          // ✅ NEW: Total Count and Total Amount at bottom
          if (_groupedMois.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: const Border(
                    top: BorderSide(color: Colors.black, width: 2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Count: $totalCount',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    'Total Amount: ₹$totalAmount',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteFromGroup(Map<String, dynamic> moi) async {
    try {
      // ✅ Step 1: Check if this is the first entry (linked to denominations)
      bool isFirstEntry =
          _groupedMois.isNotEmpty && _groupedMois[0]['id'] == moi['id'];
      String? oldDenomMoiId = isFirstEntry ? moi['id'] : null;

      // If temporary entry, just remove from list
      if (moi['is_temp'] == true) {
        setState(() {
          _groupedMois.removeWhere((entry) => entry['id'] == moi['id']);

          // If no more entries, clear group
          if (_groupedMois.isEmpty) {
            _lockedPaymentMethod = null; // ✅ Unlock payment method
            _currentGroupId = null;
          }
        });

        if (_editingMoiId == moi['id']) {
          setState(() {
            _isEditMode = false;
            _editingMoiId = null;
            _originalData = null;
          });
          await _clearFormForNextEntry();
        }
        return;
      }

      // ✅ Step 2: If deleting first entry, we need to transfer denominations to next entry
      if (isFirstEntry && _groupedMois.length > 1) {
        // Get the denomination data before deletion
        final denomResponse = await _supabase
            .from('moi_denominations')
            .select('*')
            .eq('moi_id', oldDenomMoiId!)
            .maybeSingle();

        if (denomResponse != null) {
          // Find the second entry (which will become the new first)
          var secondEntry = _groupedMois[1];
          String newDenomMoiId = secondEntry['id'];

          // Only transfer if second entry is NOT a temp entry
          if (secondEntry['is_temp'] != true) {
            // Update denomination table to link to new MOI ID
            await _supabase
                .from('moi_denominations')
                .update({'moi_id': newDenomMoiId}).eq('moi_id', oldDenomMoiId);

            print(
                '✅ Transferred denominations from $oldDenomMoiId to $newDenomMoiId');
          }
        }
      }

      // ✅ Step 3: Mark entry as deleted in database
      await _supabase.from('mois').update({
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', moi['id']);

      // ✅ Step 4: Remove from local list
      setState(() {
        _groupedMois.removeWhere((entry) => entry['id'] == moi['id']);

        // If no more entries, clear group and denominations
        if (_groupedMois.isEmpty) {
          _currentGroupId = null;
          _lockedPaymentMethod = null;
          for (var row in _denomRows) {
            row['countController'].clear();
          }
        }
      });

      // ✅ Step 5: Reload denominations if we still have entries
      if (_groupedMois.isNotEmpty && _paymentMethod == 'CASH') {
        // Reload denominations from the new first entry
        await _loadDenominations(_groupedMois[0]['id']);
      }

      if (_editingMoiId == moi['id']) {
        setState(() {
          _isEditMode = false;
          _editingMoiId = null;
          _originalData = null;
        });
        await _clearFormForNextEntry();
      }

    } catch (e) {
      print('Error deleting entry: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: () => _handleDeleteFromGroup(moi),
          customMessage: 'Error deleting entry',
        );
      }
    }
  }

  // Replace the _buildActionButtons method (around line 3800)
  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                    color: Colors.green,
                    border: Border.all(color: Colors.black, width: 2)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleSaveAndPrint,
                    child: Center(
                      child: Text(
                        _skipPrint ? 'Save' : 'Save & Print',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                    color: Colors.blue,
                    border: Border.all(color: Colors.black, width: 2)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleGroup,
                    child: const Center(
                      child: Text(
                        'Group',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_currentGroupId != null) ...[
          Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(
                color: Colors.purple,
                border: Border.all(color: Colors.black, width: 2)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleAddEntry,
                child: const Center(
                  child: Text(
                    'ADD ENTRY',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ✅ UPDATED: Clear button with long press (3 seconds)
        GestureDetector(
          onLongPressStart: (_) {
            setState(() {
              _isClearPressed = true;
              _clearPressProgress = 0.0;
            });
            _startClearProgress();
          },
          onLongPressEnd: (_) {
            setState(() {
              _isClearPressed = false;
              _clearPressProgress = 0.0;
            });
          },
          child: Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(
                color: Colors.orange,
                border: Border.all(color: Colors.black, width: 2)),
            child: Stack(
              children: [
                // Progress indicator
                if (_isClearPressed)
                  Positioned.fill(
                    child: LinearProgressIndicator(
                      value: _clearPressProgress,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[300]!),
                    ),
                  ),
                // Text
                Center(
                  child: Text(
                    _isClearPressed
                        ? 'Hold to Clear (${(3 - (_clearPressProgress * 3)).toInt()}s)'
                        : 'Clear',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Add this new method to handle clear progress
  void _startClearProgress() async {
    const totalDuration = Duration(seconds: 3);
    const updateInterval = Duration(milliseconds: 50);
    final steps = totalDuration.inMilliseconds ~/ updateInterval.inMilliseconds;

    for (int i = 0; i <= steps; i++) {
      if (!_isClearPressed) break;

      await Future.delayed(updateInterval);

      if (!mounted) break;

      setState(() {
        _clearPressProgress = i / steps;
      });

      // If reached 100%, execute clear
      if (_clearPressProgress >= 1.0 && _isClearPressed) {
        _handleClear();
        setState(() {
          _isClearPressed = false;
          _clearPressProgress = 0.0;
        });
        break;
      }
    }
  }

  @override
  void dispose() {
    _removeVillageOverlay();
    _villageScrollController.dispose();
    _jobScrollController.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose(); // ✅ ADD THIS
    _villageFocusNode.dispose();        // ADD
    _livingPlaceFocusNode.dispose();    // ADD
    _person1NameFocusNode.dispose();    // ADD
    _person1JobFocusNode.dispose();     // ADD
    _person2FocusNode.dispose();        // ADD
    _notesFocusNode.dispose();          // ADD
    _amountFocusNode.dispose(); // ✅ ADD
    _firstDenomFocusNode.dispose(); // ✅ ADD
    _villageController.dispose();
    _livingPlaceController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _person1Field1Controller.dispose();
    _person1Field2Controller.dispose();
    _person2Controller.dispose();

    for (var row in _denomRows) {
      row['countController'].dispose();
      if (row.containsKey('denomController')) {
        row['denomController'].dispose();
      }
    }
    super.dispose();
  }
}