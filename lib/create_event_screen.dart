import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class CreateEventScreen extends StatefulWidget {
  @override
  _CreateEventScreenState createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  final Color primaryBlue = const Color(0xFF1976D2);

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxAttendeesController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();

  final _startDateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endDateController = TextEditingController();
  final _endTimeController = TextEditingController();

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  bool _isLoading = false;

  Future<void> _pickDate(TextEditingController controller, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(TextEditingController controller, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.format(context);
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String startDateTime =
        "${_startDateController.text} ${_formatTime(_startTime!)}:00";
    String endDateTime =
        "${_endDateController.text} ${_formatTime(_endTime!)}:00";

    final result = await ApiService.createEvent(
      title: _titleController.text,
      description: _descriptionController.text,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      location: _locationController.text,
      maxAttendees: int.parse(_maxAttendeesController.text),
      price: int.parse(_priceController.text),
      category: _categoryController.text,
      imageUrl: _imageUrlController.text,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Success'),
          content: Text('Event created successfully!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: Text('OK', style: TextStyle(color: primaryBlue)),
            ),
          ],
        ),
      );
    } else {
      String errorMessage = result['message'] ?? 'Failed to create event';
      if (result['errors'] != null) {
        errorMessage += '\n\nDetails:\n';
        (result['errors'] as Map).forEach((key, value) {
          errorMessage += "$key: ${value.join(', ')}\n";
        });
      }
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: primaryBlue)),
            ),
          ],
        ),
      );
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        Text('Create Event', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            _buildTextField(_titleController, 'Title', Icons.event),
            _buildTextField(_descriptionController, 'Description',
                Icons.description,
                maxLines: 3),
            _buildDateTimePicker(_startDateController, _startTimeController,
                'Start Date', 'Start Time', true),
            _buildDateTimePicker(_endDateController, _endTimeController,
                'End Date', 'End Time', false),
            _buildTextField(
                _locationController, 'Location', Icons.location_on),
            _buildTextField(_maxAttendeesController, 'Max Attendees',
                Icons.people,
                keyboardType: TextInputType.number),
            _buildTextField(_priceController, 'Price', Icons.attach_money,
                keyboardType: TextInputType.number),
            _buildTextField(_categoryController, 'Category', Icons.category),
            _buildTextField(
                _imageUrlController, 'Image URL', Icons.image_outlined),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16), // ✅ padding lebih luas
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _handleSubmit,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                'Create Event',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryBlue),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) =>
        (value == null || value.isEmpty) ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildDateTimePicker(
      TextEditingController dateController,
      TextEditingController timeController,
      String dateLabel,
      String timeLabel,
      bool isStart) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(dateController, isStart),
            child: AbsorbPointer(
              child: _buildTextField(
                  dateController, dateLabel, Icons.calendar_today),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickTime(timeController, isStart),
            child: AbsorbPointer(
              child: _buildTextField(
                  timeController, timeLabel, Icons.access_time),
            ),
          ),
        ),
      ],
    );
  }
}
