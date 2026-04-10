/// One node in a scripted conversation tree.
/// Represents a single AI utterance and the criteria for the user's response.
class ConversationNode {
  /// Unique identifier within this conversation.
  final String id;

  /// What the AI "says" — shown in the chat bubble and spoken via TTS.
  final String aiUtterance;

  /// Any ONE of these keywords in the user's response = pass.
  /// Use simple, unambiguous words. The evaluator does fuzzy matching,
  /// so slight ASR errors are tolerated.
  final List<String> acceptableKeywords;

  /// Shown to the user when they fail this turn (after attempt 2+).
  final String? hint;

  /// ID of the next node to advance to after this turn is passed.
  /// null = this is the final node; conversation ends after this turn.
  final String? nextNodeId;

  /// Feedback shown on pass.
  final String feedbackOnSuccess;

  /// Feedback shown on fail.
  final String feedbackOnFail;

  const ConversationNode({
    required this.id,
    required this.aiUtterance,
    required this.acceptableKeywords,
    this.hint,
    this.nextNodeId,
    required this.feedbackOnSuccess,
    required this.feedbackOnFail,
  });

  bool get isLastNode => nextNodeId == null;
}

/// A complete scripted conversation for one [LessonStep] of type [StepType.freeConversation].
/// Contains an ordered list of [ConversationNode]s.
class ScriptedConversation {
  final String scenarioTitle;
  final String aiPersonaDescription; // Shown to user so they know who they're talking to
  final List<ConversationNode> nodes;

  const ScriptedConversation({
    required this.scenarioTitle,
    required this.aiPersonaDescription,
    required this.nodes,
  });

  /// Get a node by its ID. Returns null if not found.
  ConversationNode? getNode(String id) {
    try {
      return nodes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get the first node (opening AI utterance).
  ConversationNode get firstNode => nodes.first;

  /// Get the node that comes after [currentId]. Returns null if at end.
  ConversationNode? getNextNode(String currentId) {
    final current = getNode(currentId);
    if (current == null || current.nextNodeId == null) return null;
    return getNode(current.nextNodeId!);
  }
}

/// Registry of all scripted conversations, keyed by [LessonStep.id].
/// When [EvaluationEngine] sees a [StepType.freeConversation] step,
/// it looks up the script here by step ID.
class ScriptedConversationRegistry {
  static final Map<String, ScriptedConversation> _scripts = {};

  static void register(String stepId, ScriptedConversation script) {
    _scripts[stepId] = script;
  }

  static ScriptedConversation? get(String stepId) => _scripts[stepId];

  /// Call this once at app startup (e.g., in main.dart or in
  /// SpeakingLessonScreen.initState before any evaluation).
  static void registerAll() {
    // Restaurant lesson - step id must match exactly what's in sample_lessons.dart
    register('restaurant_conv_1', _restaurantConversation);
    // Add more scripts here as you add more free conversation lessons
  }

  // ─── Scripted Conversations ───────────────────────────────────

  static const _restaurantConversation = ScriptedConversation(
    scenarioTitle: "Ordering Food at a Diner",
    aiPersonaDescription: "You are talking to a friendly waiter at Joe's Diner.",
    nodes: [
      ConversationNode(
        id: 'greet',
        aiUtterance:
            "Hi there! Welcome to Joe's Diner. What can I get for you today?",
        acceptableKeywords: [
          'like', 'want', 'order', 'have', 'get', 'please',
          'burger', 'pizza', 'sandwich', 'salad', 'soup', 'pasta',
        ],
        hint: 'Try saying: "I\'d like to order a burger, please."',
        nextNodeId: 'drink',
        feedbackOnSuccess: "Great order! The waiter understood you perfectly.",
        feedbackOnFail:
            "Tell the waiter what food you want. Try: \"I'd like a...\"",
      ),
      ConversationNode(
        id: 'drink',
        aiUtterance:
            "Excellent choice! And what would you like to drink with that?",
        acceptableKeywords: [
          'water', 'juice', 'coffee', 'tea', 'coke', 'soda',
          'drink', 'beer', 'lemonade', 'milk', 'yes', 'no',
        ],
        hint: 'Try saying: "I\'ll have a coffee, please."',
        nextNodeId: 'check',
        feedbackOnSuccess: "Perfect! Your drink order is placed.",
        feedbackOnFail:
            "Name a drink. For example: water, coffee, juice, or soda.",
      ),
      ConversationNode(
        id: 'check',
        aiUtterance:
            "Wonderful! Is there anything else I can get for you today?",
        acceptableKeywords: [
          'no', "that's", 'all', 'thank', 'thanks', 'good',
          'nothing', 'fine', 'yes', 'also', 'check', 'bill',
        ],
        hint: 'Try saying: "No, that\'s all. Thank you!"',
        nextNodeId: null, // Last node — conversation ends
        feedbackOnSuccess:
            "🎉 Great job! You ordered your meal successfully in English!",
        feedbackOnFail:
            "Say yes or no. Try: \"No, that's all. Thank you!\"",
      ),
    ],
  );
}
