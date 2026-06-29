import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../services/gemini_service.dart';
import '../widgets/aurora_background.dart';

class GeminiChatScreen extends StatefulWidget {
  const GeminiChatScreen({super.key});
  @override
  State<GeminiChatScreen> createState() => _GeminiChatScreenState();
}

class _GeminiChatScreenState extends State<GeminiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  String _buildFamilyContext(FamilyProvider fp) {
    final buf = StringBuffer();
    buf.writeln('=== DONNEES FAMILLE ===');
    buf.writeln('Nombre d enfants : ${fp.children.length}');
    for (final child in fp.children) {
      buf.writeln('');
      buf.writeln('Enfant : ${child.name}');
      buf.writeln('  Points : ${child.points}');
      buf.writeln('  Niveau : ' + child.levelTitle);
      final punishments = fp.punishments.where((p) => p.childId == child.id && !p.isCompleted).toList();
      buf.writeln('  Punitions actives : ${punishments.length}');
      for (final p in punishments) {
        buf.writeln('    - ${p.text} (${p.completedLines}/${p.totalLines} lignes)');
      }
      final immunities = fp.immunities.where((i) => i.childId == child.id && i.isActive).toList();
      buf.writeln('  Immunites disponibles : ${immunities.length}');
      for (final i in immunities) {
        buf.writeln('    - ${i.reason} (${i.availableLines} lignes dispo)');
      }
    }
    buf.writeln('');
    buf.writeln('=== TRIBUNAL ===');
    final activeCases = fp.activeTribunalCases;
    buf.writeln('Affaires en cours : ${activeCases.length}');
    for (final tc in activeCases) {
      final plaintiff = fp.getChild(tc.plaintiffId)?.name ?? '?';
      final accused = fp.getChild(tc.accusedId)?.name ?? '?';
      buf.writeln('  - ${tc.title} (${plaintiff} vs ${accused}) - ${tc.statusLabel}');
    }
    buf.writeln('');
    buf.writeln('=== HISTORIQUE RECENT ===');
    final recentHistory = fp.history.take(10).toList();
    for (final h in recentHistory) {
      final child = fp.getChild(h.childId)?.name ?? '?';
      buf.writeln('  - $child : ${h.reason} (${h.points > 0 ? '+' : ''}${h.points} pts)');
    }
    return buf.toString();
  }

  Future<void> _sendMessage(FamilyProvider fp) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _scrollToBottom();
    final context_data = _buildFamilyContext(fp);
    final response = await GeminiService.chatFamilyAssistant(
      message: text,
      familyContext: context_data,
      history: _messages.sublist(0, _messages.length - 1),
    );
    setState(() {
      _messages.add({'role': 'assistant', 'content': response});
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        return AuroraBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.cyan, Colors.purple]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assistant Familial', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('IA Gemini', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                  ],
                ),
              ]),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white54),
                  onPressed: () => setState(() => _messages.clear()),
                ),
              ],
            ),
            body: Column(
              children: [
                if (_messages.isEmpty)
                  Expanded(child: _buildWelcome(fp)),
                if (_messages.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) return _buildTyping();
                        final msg = _messages[index];
                        return _buildMessage(msg['role']!, msg['content']!);
                      },
                    ),
                  ),
                if (_isLoading && _messages.isEmpty)
                  const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.cyanAccent))),
                _buildInput(fp),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcome(FamilyProvider fp) {
    final suggestions = [
      'Qui a le plus de points ?',
      'Quelles punitions sont en cours ?',
      'Resume le tribunal de cette semaine',
      'Qui peut utiliser ses immunites ?',
      'Donne moi un rapport complet de la famille',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.cyan, Colors.purple]),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Assistant Familial IA', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Je connais toutes les donnees de ta famille.\nPose-moi n importe quelle question !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
          const SizedBox(height: 32),
          const Align(alignment: Alignment.centerLeft,
            child: Text('Suggestions :', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          ...suggestions.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                _controller.text = s;
                _sendMessage(fp);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 16),
                  const SizedBox(width: 10),
                  Text(s, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildMessage(String role, String content) {
    final isUser = role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.cyan, Colors.purple]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                  ? const LinearGradient(colors: [Colors.purple, Colors.deepPurple])
                  : null,
                color: isUser ? null : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.cyan, Colors.purple]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text('...', style: TextStyle(color: Colors.cyanAccent, fontSize: 18, letterSpacing: 4)),
        ),
      ],
    );
  }

  Widget _buildInput(FamilyProvider fp) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Pose ta question...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(fp),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(fp),
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.cyan, Colors.purple]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
