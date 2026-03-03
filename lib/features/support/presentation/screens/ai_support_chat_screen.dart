import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/support/data/services/ai_support_service.dart';

class AiSupportChatScreen extends StatefulWidget {
  const AiSupportChatScreen({super.key});

  @override
  State<AiSupportChatScreen> createState() => _AiSupportChatScreenState();
}

class _AiSupportChatScreenState extends State<AiSupportChatScreen>
    with TickerProviderStateMixin {
  final _service = AiSupportService.instance;
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _showQuickTopics = true;
  bool _showTicketForm = false;

  // Ticket form fields
  final _ticketSubjectCtrl = TextEditingController();
  final _ticketDescCtrl = TextEditingController();
  final _ticketEmailCtrl = TextEditingController();
  String _ticketCategory = 'Bug Report';

  @override
  void initState() {
    super.initState();
    // Bot greeting
    _addBotMessage(_service.greeting);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _ticketSubjectCtrl.dispose();
    _ticketDescCtrl.dispose();
    _ticketEmailCtrl.dispose();
    super.dispose();
  }

  void _addBotMessage(String text, {AiAction action = AiAction.none, String? followUp}) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      if (followUp != null) {
        _messages.add(_ChatMessage(
          text: followUp,
          isUser: false,
          timestamp: DateTime.now(),
          isFollowUp: true,
        ));
      }
      if (action == AiAction.showTicketForm) {
        _showTicketForm = true;
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();

    setState(() {
      _messages.add(_ChatMessage(
        text: text.trim(),
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
      _showQuickTopics = false;
    });
    _scrollToBottom();

    final response = await _service.getResponse(text.trim());

    if (!mounted) return;
    setState(() => _isTyping = false);
    _addBotMessage(
      response.message,
      action: response.action,
      followUp: response.followUp,
    );
  }

  Future<void> _submitTicket() async {
    final subject = _ticketSubjectCtrl.text.trim();
    final desc = _ticketDescCtrl.text.trim();
    final email = _ticketEmailCtrl.text.trim();

    if (subject.isEmpty || desc.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all fields'),
          backgroundColor: BmbColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid email address'),
          backgroundColor: BmbColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isTyping = true);

    // Build chat history for context
    final history = _messages
        .map((m) => '${m.isUser ? "User" : "Bot"}: ${m.text}')
        .toList();

    final ticketId = await _service.submitTicket(
      subject: subject,
      description: desc,
      userEmail: email,
      category: _ticketCategory,
      chatHistory: history,
    );

    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _showTicketForm = false;
    });

    _ticketSubjectCtrl.clear();
    _ticketDescCtrl.clear();
    _ticketEmailCtrl.clear();

    _addBotMessage(
      'Your ticket has been submitted!\n\n'
      'Ticket ID: $ticketId\n'
      'Category: $_ticketCategory\n\n'
      'Our tech team at tech@backmybracket.com will review your issue and '
      'respond to $email within 24 hours. Save your ticket ID for reference.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildChatArea()),
              if (_showTicketForm) _buildTicketForm(),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: BmbColors.borderColor.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          // Bot avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [BmbColors.blue, BmbColors.blue.withValues(alpha: 0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: BmbColors.blue.withValues(alpha: 0.3), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.support_agent, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BMB Support',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: BmbColors.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Online 24/7',
                        style: TextStyle(
                            color: BmbColors.successGreen,
                            fontSize: 12,
                            fontWeight: BmbFontWeights.medium)),
                  ],
                ),
              ],
            ),
          ),
          // Ticket history button
          IconButton(
            icon: const Icon(Icons.receipt_long, color: BmbColors.textSecondary, size: 22),
            tooltip: 'My Tickets',
            onPressed: _showTicketHistory,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CHAT AREA
  // ═══════════════════════════════════════════════════════════════
  Widget _buildChatArea() {
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Quick Topics
        if (_showQuickTopics) ...[
          _buildQuickTopics(),
          const SizedBox(height: 16),
        ],
        // Messages
        ..._messages.map(_buildMessageBubble),
        // Typing indicator
        if (_isTyping) _buildTypingIndicator(),
        // Escalate button after suggest-ticket action
        if (_messages.isNotEmpty &&
            !_showTicketForm &&
            _messages.last.text.contains('tech support ticket'))
          _buildEscalateButton(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildQuickTopics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Quick Topics',
              style: TextStyle(
                  color: BmbColors.textSecondary,
                  fontSize: 13,
                  fontWeight: BmbFontWeights.semiBold)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AiSupportService.quickTopics.map((topic) {
            return GestureDetector(
              onTap: () => _sendMessage(topic),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    BmbColors.blue.withValues(alpha: 0.12),
                    BmbColors.blue.withValues(alpha: 0.06),
                  ]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
                ),
                child: Text(topic,
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 13,
                        fontWeight: BmbFontWeights.medium)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: EdgeInsets.only(
        bottom: msg.isFollowUp ? 6 : 12,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && !msg.isFollowUp) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [BmbColors.blue, BmbColors.blue.withValues(alpha: 0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ] else if (!isUser && msg.isFollowUp) ...[
            const SizedBox(width: 36),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(colors: [BmbColors.blue, BmbColors.blue.withValues(alpha: 0.85)])
                    : BmbColors.cardGradient,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: BmbColors.borderColor.withValues(alpha: 0.5), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? BmbColors.blue : BmbColors.deepNavy).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.text,
                      style: TextStyle(
                          color: isUser ? Colors.white : BmbColors.textPrimary,
                          fontSize: 14,
                          height: 1.45)),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _formatTime(msg.timestamp),
                      style: TextStyle(
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.6)
                            : BmbColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [BmbColors.blue, BmbColors.blue.withValues(alpha: 0.7)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: BmbColors.cardGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: BmbColors.borderColor.withValues(alpha: 0.5), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BouncingDot(delay: 0),
                const SizedBox(width: 4),
                _BouncingDot(delay: 150),
                const SizedBox(width: 4),
                _BouncingDot(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscalateButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 36),
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() => _showTicketForm = true);
          _scrollToBottom();
        },
        icon: const Icon(Icons.email, size: 16),
        label: const Text('Create Tech Support Ticket'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TICKET FORM
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTicketForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFFF6B35).withValues(alpha: 0.08),
          BmbColors.cardGradientStart,
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.confirmation_number, color: Color(0xFFFF6B35), size: 20),
              const SizedBox(width: 8),
              Text('Tech Support Ticket',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 15,
                      fontWeight: BmbFontWeights.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showTicketForm = false),
                child: Icon(Icons.close, color: BmbColors.textTertiary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Our tech team will respond within 24 hours',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
          const SizedBox(height: 16),
          // Category dropdown
          _buildFormLabel('Category'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: BmbColors.deepNavy.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BmbColors.borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _ticketCategory,
                isExpanded: true,
                dropdownColor: BmbColors.midNavy,
                style: TextStyle(color: BmbColors.textPrimary, fontSize: 14),
                icon: const Icon(Icons.arrow_drop_down, color: BmbColors.textSecondary),
                items: AiSupportService.ticketCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _ticketCategory = v ?? _ticketCategory),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Subject
          _buildFormLabel('Subject'),
          const SizedBox(height: 6),
          _buildTextField(_ticketSubjectCtrl, 'Brief description of the issue'),
          const SizedBox(height: 12),
          // Description
          _buildFormLabel('Describe your issue'),
          const SizedBox(height: 6),
          _buildTextField(_ticketDescCtrl, 'Please include as much detail as possible...',
              maxLines: 4),
          const SizedBox(height: 12),
          // Email
          _buildFormLabel('Your email'),
          const SizedBox(height: 6),
          _buildTextField(_ticketEmailCtrl, 'we\'ll respond to this email',
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitTicket,
              icon: const Icon(Icons.send, size: 18),
              label: Text('Submit Ticket',
                  style: TextStyle(fontSize: 14, fontWeight: BmbFontWeights.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormLabel(String label) {
    return Text(label,
        style: TextStyle(
            color: BmbColors.textSecondary,
            fontSize: 12,
            fontWeight: BmbFontWeights.semiBold));
  }

  Widget _buildTextField(TextEditingController ctrl, String hint,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: BmbColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 13),
        filled: true,
        fillColor: BmbColors.deepNavy.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: BmbColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: BmbColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BmbColors.blue, width: 1.5),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  INPUT BAR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: BmbColors.borderColor.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: BmbColors.midNavy,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BmbColors.borderColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      focusNode: _inputFocus,
                      style: TextStyle(color: BmbColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type your question...',
                        hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_inputCtrl.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [BmbColors.blue, BmbColors.blue.withValues(alpha: 0.8)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: BmbColors.blue.withValues(alpha: 0.3), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TICKET HISTORY MODAL
  // ═══════════════════════════════════════════════════════════════
  void _showTicketHistory() {
    final tickets = _service.tickets;
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BmbColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('My Support Tickets',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 18,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay')),
            const SizedBox(height: 16),
            if (tickets.isEmpty) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          color: BmbColors.textTertiary, size: 48),
                      const SizedBox(height: 12),
                      Text('No tickets yet',
                          style: TextStyle(
                              color: BmbColors.textTertiary, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Your support tickets will appear here',
                          style: TextStyle(
                              color: BmbColors.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ...tickets.map((t) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: BmbColors.cardGradient,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: BmbColors.borderColor.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(t.status).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(t.status.name.toUpperCase(),
                                  style: TextStyle(
                                      color: _statusColor(t.status),
                                      fontSize: 10,
                                      fontWeight: BmbFontWeights.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text(t.id,
                                style: TextStyle(
                                    color: BmbColors.textTertiary,
                                    fontSize: 11)),
                            const Spacer(),
                            Text(_formatDate(t.createdAt),
                                style: TextStyle(
                                    color: BmbColors.textTertiary,
                                    fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(t.subject,
                            style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 14,
                                fontWeight: BmbFontWeights.semiBold)),
                        const SizedBox(height: 4),
                        Text(t.category,
                            style: TextStyle(
                                color: BmbColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return BmbColors.blue;
      case TicketStatus.inProgress:
        return BmbColors.gold;
      case TicketStatus.resolved:
        return BmbColors.successGreen;
      case TicketStatus.closed:
        return BmbColors.textTertiary;
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final hh = h == 0 ? 12 : h;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ampm';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

// ═══════════════════════════════════════════════════════════════
//  MODELS
// ═══════════════════════════════════════════════════════════════
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isFollowUp;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isFollowUp = false,
  });
}

// ═══════════════════════════════════════════════════════════════
//  BOUNCING DOT — typing indicator animation
// ═══════════════════════════════════════════════════════════════
class _BouncingDot extends StatefulWidget {
  final int delay;
  const _BouncingDot({required this.delay});
  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: BmbColors.blue.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
