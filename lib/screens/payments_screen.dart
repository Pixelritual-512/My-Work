import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/student_model.dart';
import '../../models/payment_model.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  DateTime _selectedDate = DateTime.now();

  String get _selectedMonth => DateFormat('yyyy-MM').format(_selectedDate);

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      helpText: 'SELECT MONTH (Day ignored)',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final db = DatabaseService(uid: user!.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectMonth(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Month: ${DateFormat('MMMM yyyy').format(_selectedDate)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Student>>(
              stream: db.studentsStream,
              builder: (context, studentSnapshot) {
                if (studentSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!studentSnapshot.hasData || studentSnapshot.data!.isEmpty) {
                  return const Center(child: Text('No members found.'));
                }

                final students = studentSnapshot.data!;

                return StreamBuilder<List<Payment>>(
                  stream: db.getPaymentsStream(_selectedMonth),
                  builder: (context, paymentSnapshot) {
                    if (paymentSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final payments = paymentSnapshot.data ?? [];
                    final paymentMap = {
                      for (var p in payments) p.studentId: p
                    };

                    // Calculate totals
                    int fullyPaidCount = 0;
                    double totalCollected = 0;
                    double totalPending = 0;

                    for (var s in students) {
                      final p = paymentMap[ s.id];
                      final fee = s.monthlyFee;
                      final paidAmt = p?.paidAmount ?? 0;
                      
                      totalCollected += paidAmt;
                      if (paidAmt >= fee) {
                        fullyPaidCount++;
                      } else {
                        // Max ensures we don't show negative pending if they overpaid
                        totalPending += (fee - paidAmt) > 0 ? (fee - paidAmt) : 0;
                      }
                    }

                    return Column(
                      children: [
                        // Summary Card
                        Card(
                          margin: const EdgeInsets.all(16),
                          color: Theme.of(context).cardColor,
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '₹${totalCollected.toInt()}',
                                      style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const Text('Collected'),
                                  ],
                                ),
                                Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
                                Column(
                                  children: [
                                    Text(
                                      '₹${totalPending.toInt()}',
                                      style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const Text('Pending'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // List
                        Expanded(
                          child: ListView.builder(
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final student = students[index];
                              final payment = paymentMap[student.id];
                              final paidAmt = payment?.paidAmount ?? 0;
                              final fee = student.monthlyFee;
                              final isPaid = paidAmt >= fee;
                              final remaining = (fee - paidAmt) > 0 ? (fee - paidAmt) : 0;

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isPaid
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                    child: Icon(
                                      isPaid ? Icons.check : Icons.access_time,
                                      color: isPaid ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                  title: Text(student.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Fee: ₹${fee.toInt()}'),
                                      RichText(
                                        text: TextSpan(
                                          style: DefaultTextStyle.of(context).style,
                                          children: [
                                            TextSpan(
                                              text: 'Paid: ₹${paidAmt.toInt()}  ',
                                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                            ),
                                            if (remaining > 0)
                                              TextSpan(
                                                text: 'Rem: ₹${remaining.toInt()}',
                                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (remaining > 0 && student.mobileNumber.isNotEmpty) ...[
                                         IconButton(
                                          icon: const Icon(Icons.phone, color: Colors.green),
                                          onPressed: () => _makeCall(student.mobileNumber),
                                          tooltip: 'Call',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.message, color: Colors.teal),
                                          onPressed: () => _openWhatsApp(
                                            student.mobileNumber, 
                                            'Hello ${student.name}, your payment of ₹${remaining.toInt()} is remaining for $_selectedMonth.',
                                          ),
                                          tooltip: 'WhatsApp Reminder',
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade50,
                                          foregroundColor: Colors.blue.shade700,
                                        ),
                                        onPressed: () => _showPaymentDialog(
                                          context, 
                                          db, 
                                          student, 
                                          payment,
                                        ),
                                        child: const Text('UPDATE'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, DatabaseService db, Student student, Payment? payment) {
    final fee = student.monthlyFee;
    final currentPaid = payment?.paidAmount ?? 0;
    final controller = TextEditingController(text: currentPaid.toInt().toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payment: ${student.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Monthly Fee: ₹${fee.toInt()}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Amount Paid (Updated)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the total amount paid so far this month.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              final newAmount = double.tryParse(controller.text.trim()) ?? currentPaid;
              db.markPayment(
                student.id,
                _selectedMonth,
                fee,
                newAmount,
              );
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }


  Future<void> _makeCall(String number) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: number,
    );
    if (!await launchUrl(launchUri)) {
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch call')));
      }
    }
  }

  Future<void> _openWhatsApp(String number, String message) async {
    if (number.isEmpty) return;
    var cleanNumber = number.replaceAll(RegExp(r'\D'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }
    
    final Uri launchUri = Uri.parse('https://wa.me/$cleanNumber?text=${Uri.encodeComponent(message)}');
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
      }
    }
  }
}
