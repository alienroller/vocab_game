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

  /// Call this once at app startup.
  static void registerAll() {
    register('coffee_6', _coffeeShopConv);
    register('doc_6', _doctorsOfficeConv);
    register('cl_6', _clothesShoppingConv);
    register('ho_6', _hotelBookingConv);
    register('int_6', _jobInterviewConv);
    register('air_6', _airportLostLuggageConv);
    register('cs_6', _customerServiceConv);
    register('bm_6', _businessMeetingConv);
    register('hc_6', _hotelComplaintConv);
    register('ne_6', _networkingConv);
    register('ng_6', _negotiationConv);
    register('si_6', _seniorInterviewConv);
  }

  // ═══════════════════════════════════════════════════════════════════
  // A1 — Coffee Shop
  // ═══════════════════════════════════════════════════════════════════

  static const _coffeeShopConv = ScriptedConversation(
    scenarioTitle: "Ordering Coffee at Sam's Café",
    aiPersonaDescription:
        "You're at Sam's Café on a quiet Tuesday morning. The barista is friendly and in a chatty mood.",
    nodes: [
      ConversationNode(
        id: 'greet',
        aiUtterance:
            "Good morning! Welcome to Sam's. What can I get started for you?",
        acceptableKeywords: [
          'coffee', 'tea', 'latte', 'cappuccino', 'espresso', 'mocha',
          'americano', 'water', 'juice', 'have', 'like', 'please',
        ],
        hint: 'Name a drink. Try: "Can I have a latte, please?"',
        nextNodeId: 'size',
        feedbackOnSuccess: "Nice order! Let's nail down the size next.",
        feedbackOnFail:
            "Just name any drink with 'please'. Try: \"Can I have a coffee, please?\"",
      ),
      ConversationNode(
        id: 'size',
        aiUtterance: "Great choice. What size — small, medium, or large?",
        acceptableKeywords: ['small', 'medium', 'large', 'regular', 'please', "i'll", 'have', 'take'],
        hint: 'Pick a size. Try: "Medium, please."',
        nextNodeId: 'heretogo',
        feedbackOnSuccess: "Got it — coming right up.",
        feedbackOnFail: "Just say a size. For example: 'Medium, please.'",
      ),
      ConversationNode(
        id: 'heretogo',
        aiUtterance: "Is that for here or to go?",
        acceptableKeywords: ['here', 'go', 'take', 'stay', 'eat', 'drink', 'in', 'out'],
        hint: '"For here" means you stay. "To go" means you leave with it.',
        nextNodeId: 'extras',
        feedbackOnSuccess: "Perfect. Let me ring that up.",
        feedbackOnFail: "Just say 'for here' or 'to go'.",
      ),
      ConversationNode(
        id: 'extras',
        aiUtterance:
            "Would you like anything else — maybe a pastry or a muffin?",
        acceptableKeywords: [
          'no', 'yes', 'thanks', 'thank', 'just', 'only', 'muffin',
          'pastry', 'cookie', 'good', 'that\'s', 'thats', 'all',
        ],
        hint: 'Say "No, thanks" or add something like "a muffin, please".',
        nextNodeId: 'pay',
        feedbackOnSuccess: "Alright, that's everything.",
        feedbackOnFail: "Just answer yes or no. Try: \"No, thanks.\"",
      ),
      ConversationNode(
        id: 'pay',
        aiUtterance: "That'll be four fifty. How are you paying?",
        acceptableKeywords: ['card', 'cash', 'credit', 'debit', 'pay', 'apple', 'phone', 'here'],
        hint: 'Name a payment method. Try: "Card, please."',
        nextNodeId: 'goodbye',
        feedbackOnSuccess: "Tap whenever you're ready. Thank you!",
        feedbackOnFail: "Just say 'card' or 'cash'.",
      ),
      ConversationNode(
        id: 'goodbye',
        aiUtterance: "Have a wonderful day! Come back soon.",
        acceptableKeywords: ['thank', 'thanks', 'you', 'bye', 'take', 'care', 'too', 'you too'],
        hint: 'Close warmly. Try: "Thanks, you too!"',
        nextNodeId: null,
        feedbackOnSuccess: "🎉 You ordered coffee fluently in English. Well done!",
        feedbackOnFail: "Just thank them. Try: \"Thanks, you too!\"",
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // A2 — Doctor's Office
  // ═══════════════════════════════════════════════════════════════════

  static const _doctorsOfficeConv = ScriptedConversation(
    scenarioTitle: "Visiting Dr. Reyes",
    aiPersonaDescription:
        "Dr. Reyes is a calm, thorough family doctor. She'll ask you a few questions and suggest a treatment plan.",
    nodes: [
      ConversationNode(
        id: 'greeting',
        aiUtterance:
            "Good afternoon. Come on in and have a seat. So, what brings you in today?",
        acceptableKeywords: [
          'have', 'feel', 'hurts', 'headache', 'stomach', 'throat',
          'fever', 'cough', 'tired', 'sick', 'pain', 'cold',
        ],
        hint: 'Describe how you feel. Try: "I have a terrible headache."',
        nextNodeId: 'duration',
        feedbackOnSuccess: "Thanks for telling me. Let me ask a few follow-ups.",
        feedbackOnFail: "Describe your symptom. Try: \"I have a ___.\"",
      ),
      ConversationNode(
        id: 'duration',
        aiUtterance: "How long have you been feeling this way?",
        acceptableKeywords: [
          'since', 'for', 'days', 'day', 'week', 'yesterday', 'morning',
          'night', 'been', 'feeling', 'about', 'couple',
        ],
        hint: 'Use "since" + time, or "for" + duration. Try: "Since yesterday."',
        nextNodeId: 'severity',
        feedbackOnSuccess: "Okay — and how severe is it?",
        feedbackOnFail: "Give a timeframe. Try: \"For two days\" or \"Since Monday\".",
      ),
      ConversationNode(
        id: 'severity',
        aiUtterance:
            "On a scale of one to ten, how would you rate the pain?",
        acceptableKeywords: [
          'about', 'around', 'maybe', 'probably', 'six', 'seven',
          'eight', 'five', 'four', 'nine', 'three', 'ten',
        ],
        hint: 'Answer with a number. Try: "About a six."',
        nextNodeId: 'medication',
        feedbackOnSuccess: "Thanks. That helps me understand.",
        feedbackOnFail: "Give me a number. Try: \"About a six.\"",
      ),
      ConversationNode(
        id: 'medication',
        aiUtterance:
            "Have you taken any medication or tried anything for it?",
        acceptableKeywords: [
          'yes', 'no', 'took', 'tried', 'nothing', 'ibuprofen', 'water',
          'rest', 'aspirin', 'pill', 'tea', 'slept',
        ],
        hint: 'Answer yes/no + what you tried. Try: "Yes, I took some ibuprofen."',
        nextNodeId: 'plan',
        feedbackOnSuccess: "Good to know. Here's what I'd suggest.",
        feedbackOnFail: "Simple answer: yes or no. Try: \"No, I haven't.\"",
      ),
      ConversationNode(
        id: 'plan',
        aiUtterance:
            "I'd like you to rest, drink lots of water, and take this medication twice a day. Does that make sense?",
        acceptableKeywords: [
          'yes', 'okay', 'understand', 'got', 'sure', 'thank', 'thanks',
          'makes', 'sense', 'clear', 'alright',
        ],
        hint: 'Confirm you understand. Try: "Yes, that makes sense."',
        nextNodeId: 'close',
        feedbackOnSuccess: "Great. Any final questions before you go?",
        feedbackOnFail:
            "Confirm with: \"Yes, I understand\" or \"Could you repeat that?\"",
      ),
      ConversationNode(
        id: 'close',
        aiUtterance:
            "Alright then. Take care of yourself and come back if it doesn't improve in a few days.",
        acceptableKeywords: [
          'thank', 'thanks', 'will', 'bye', 'appreciate', 'doctor', 'you', 'take',
        ],
        hint: 'Thank the doctor. Try: "Thank you so much, doctor."',
        nextNodeId: null,
        feedbackOnSuccess:
            "🎉 You described symptoms clearly and understood the plan. Excellent!",
        feedbackOnFail: "Just thank her. Try: \"Thank you, doctor.\"",
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // A2 — Clothes Shopping
  // ═══════════════════════════════════════════════════════════════════

  static const _clothesShoppingConv = ScriptedConversation(
    scenarioTitle: "Shopping at Maya's Boutique",
    aiPersonaDescription:
        "Maya is a friendly sales associate. She's patient and helpful — perfect for practicing shopping language.",
    nodes: [
      ConversationNode(
        id: 'greet',
        aiUtterance:
            "Hi there! Welcome in. Let me know if you need any help today.",
        acceptableKeywords: [
          'looking', 'for', 'jacket', 'shirt', 'dress', 'pants', 'shoes',
          'thanks', 'just', 'need', 'help', 'find',
        ],
        hint: 'Say what you want. Try: "I\'m looking for a jacket."',
        nextNodeId: 'color',
        feedbackOnSuccess: "A jacket, got it! Anything specific in mind?",
        feedbackOnFail:
            "Tell her what you want. Try: \"I'm looking for a ___.\"",
      ),
      ConversationNode(
        id: 'color',
        aiUtterance: "What color are you thinking of?",
        acceptableKeywords: [
          'blue', 'red', 'black', 'white', 'green', 'gray', 'grey',
          'brown', 'navy', 'dark', 'light', 'something',
        ],
        hint: 'Name any color. Try: "Something in black, maybe?"',
        nextNodeId: 'size',
        feedbackOnSuccess: "Lovely. Let me check the size next.",
        feedbackOnFail: "Just say a color. Try: \"Black\" or \"Something dark.\"",
      ),
      ConversationNode(
        id: 'size',
        aiUtterance: "And what size are you usually?",
        acceptableKeywords: [
          'small', 'medium', 'large', 'usually', "i'm", 'am', 'size',
          'xs', 'xl', 'extra',
        ],
        hint: 'Give a size. Try: "I\'m usually a medium."',
        nextNodeId: 'tryon',
        feedbackOnSuccess: "Perfect. Let me grab one for you.",
        feedbackOnFail: "Just say a size. Try: \"Medium.\"",
      ),
      ConversationNode(
        id: 'tryon',
        aiUtterance:
            "Here you go. The fitting room is just over there — want to try it on?",
        acceptableKeywords: [
          'yes', 'sure', 'try', 'it', 'on', 'please', 'thanks',
          'thank', 'love', 'to',
        ],
        hint: 'Accept the offer. Try: "Yes, I\'d love to try it on."',
        nextNodeId: 'fit',
        feedbackOnSuccess: "Take your time — let me know how it fits.",
        feedbackOnFail: "Just say yes. Try: \"Sure, thanks!\"",
      ),
      ConversationNode(
        id: 'fit',
        aiUtterance: "So, how does it fit?",
        acceptableKeywords: [
          'fits', 'perfect', 'perfectly', 'good', 'great', 'tight', 'loose',
          'bit', 'big', 'small', 'comfortable', 'nice',
        ],
        hint: 'Describe the fit. Try: "It fits perfectly!"',
        nextNodeId: 'decide',
        feedbackOnSuccess: "Glad to hear it looks good.",
        feedbackOnFail:
            "Describe how it fits. Try: \"Perfect\" or \"A bit too tight.\"",
      ),
      ConversationNode(
        id: 'decide',
        aiUtterance: "Would you like to take it today?",
        acceptableKeywords: [
          "i'll", 'take', 'it', 'yes', 'no', 'think', 'about',
          'maybe', 'later', 'buy', 'thanks', 'sure',
        ],
        hint: 'Decide: take it, or pass politely. Try: "I\'ll take it!"',
        nextNodeId: 'close',
        feedbackOnSuccess: "Wonderful — let me ring that up.",
        feedbackOnFail:
            "Say yes or no. Try: \"I'll take it\" or \"Let me think about it.\"",
      ),
      ConversationNode(
        id: 'close',
        aiUtterance:
            "Here's your bag. Enjoy it, and have a great rest of your day!",
        acceptableKeywords: ['thank', 'thanks', 'you', 'bye', 'care', 'day', 'too'],
        hint: 'Close warmly. Try: "Thanks so much, you too!"',
        nextNodeId: null,
        feedbackOnSuccess:
            "🎉 You navigated a shopping trip entirely in English. Fantastic!",
        feedbackOnFail: "Just thank her. Try: \"Thanks, you too!\"",
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // A2 — Hotel Booking
  // ═══════════════════════════════════════════════════════════════════

  static const _hotelBookingConv = ScriptedConversation(
    scenarioTitle: "Booking a Room at the Seaside Inn",
    aiPersonaDescription:
        "Tom is a friendly receptionist at the Seaside Inn. He'll help you book a room over the phone.",
    nodes: [
      ConversationNode(
        id: 'greet',
        aiUtterance:
            "Thank you for calling the Seaside Inn. This is Tom — how can I help?",
        acceptableKeywords: [
          'like', 'book', 'reserve', 'room', 'reservation', 'night',
          'want', 'stay', 'would',
        ],
        hint: 'State your purpose. Try: "I\'d like to book a room, please."',
        nextNodeId: 'dates',
        feedbackOnSuccess: "Of course, happy to help. Let me grab a few details.",
        feedbackOnFail:
            "Start with: \"I'd like to book a room.\"",
      ),
      ConversationNode(
        id: 'dates',
        aiUtterance: "What dates did you have in mind?",
        acceptableKeywords: [
          'from', 'to', 'until', 'check', 'in', 'out', 'friday',
          'saturday', 'weekend', 'next', 'night', 'nights',
        ],
        hint: 'Give dates or days. Try: "From Friday to Sunday."',
        nextNodeId: 'type',
        feedbackOnSuccess: "Let me check availability for those dates.",
        feedbackOnFail: "Tell him the dates. Try: \"From Friday to Sunday.\"",
      ),
      ConversationNode(
        id: 'type',
        aiUtterance:
            "Were you looking for a single, double, or something larger?",
        acceptableKeywords: [
          'single', 'double', 'twin', 'suite', 'family', 'one', 'two',
          'room', 'please',
        ],
        hint: 'Name a room type. Try: "A double, please."',
        nextNodeId: 'breakfast',
        feedbackOnSuccess: "Double room — got it.",
        feedbackOnFail: "Just name a type. Try: \"Single\" or \"Double.\"",
      ),
      ConversationNode(
        id: 'breakfast',
        aiUtterance: "Would you like to include breakfast?",
        acceptableKeywords: [
          'yes', 'no', 'please', 'thanks', 'include', 'sure',
          'how', 'much', 'cost',
        ],
        hint: 'Yes or no works. Or ask: "How much extra is it?"',
        nextNodeId: 'view',
        feedbackOnSuccess: "Alright, noted.",
        feedbackOnFail: "Just say yes or no. Try: \"Yes, please.\"",
      ),
      ConversationNode(
        id: 'view',
        aiUtterance:
            "We have a sea view available for a small supplement. Interested?",
        acceptableKeywords: [
          'yes', 'no', 'sea', 'view', 'please', 'sure', 'thanks',
          'lovely', 'perfect', 'sounds',
        ],
        hint: 'Decide. Try: "Yes, please — I\'d love a sea view."',
        nextNodeId: 'confirm',
        feedbackOnSuccess: "Excellent choice.",
        feedbackOnFail: "Yes or no — both are fine.",
      ),
      ConversationNode(
        id: 'confirm',
        aiUtterance:
            "So that's a double room with breakfast and a sea view. Shall I confirm the booking?",
        acceptableKeywords: [
          'yes', 'please', 'confirm', 'great', 'perfect', 'sounds',
          'good', 'book', 'thanks',
        ],
        hint: 'Confirm clearly. Try: "Yes, please confirm it."',
        nextNodeId: 'close',
        feedbackOnSuccess: "Perfect. You're all set.",
        feedbackOnFail: "Just say: \"Yes, please.\"",
      ),
      ConversationNode(
        id: 'close',
        aiUtterance:
            "You'll get a confirmation email shortly. We'll see you soon!",
        acceptableKeywords: ['thank', 'thanks', 'you', 'bye', 'see', 'soon'],
        hint: 'Thank him. Try: "Thanks so much, see you soon!"',
        nextNodeId: null,
        feedbackOnSuccess:
            "🎉 You handled a full hotel booking in English with ease!",
        feedbackOnFail: "Close with: \"Thank you very much!\"",
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // B1 — Job Interview
  // ═══════════════════════════════════════════════════════════════════

  static const _jobInterviewConv = ScriptedConversation(
    scenarioTitle: "Junior Analyst Interview with Dana",
    aiPersonaDescription:
        "Dana is a hiring manager. She's friendly but thorough — expect a mix of background and scenario questions.",
    nodes: [
      ConversationNode(
        id: 'intro',
        aiUtterance:
            "Thanks for coming in. Let's start with a quick intro — tell me a bit about yourself.",
        acceptableKeywords: [
          'my', 'name', 'work', 'experience', 'years', 'currently',
          'studied', 'graduated', "i'm", 'background',
        ],
        hint: 'Give a 2–3 sentence intro. Try: "I\'m ___, currently working as ___."',
        nextNodeId: 'interest',
        feedbackOnSuccess: "Thanks — that's a clear intro.",
        feedbackOnFail:
            "Name + current role. Try: \"I'm ___ and I work as ___.\"",
      ),
      ConversationNode(
        id: 'interest',
        aiUtterance: "So why are you interested in this position?",
        acceptableKeywords: [
          'interested', 'because', 'mission', 'company', 'excited',
          'grow', 'challenge', 'values', 'culture', 'team',
        ],
        hint: 'Mention the company, not salary. Try: "I\'m drawn to your mission."',
        nextNodeId: 'strength',
        feedbackOnSuccess: "Good — I appreciate the thoughtful answer.",
        feedbackOnFail:
            "Give a real reason tied to the company. Try: \"I admire your ___.\"",
      ),
      ConversationNode(
        id: 'strength',
        aiUtterance: "What would you say is your biggest strength?",
        acceptableKeywords: [
          'strength', 'good', 'at', 'detail', 'teamwork', 'communication',
          'analytical', 'organized', 'problem', 'solving',
        ],
        hint: 'Name one concrete strength. Try: "Attention to detail."',
        nextNodeId: 'weakness',
        feedbackOnSuccess: "Useful — thanks.",
        feedbackOnFail: "Pick one strength. Try: \"I'm very organized.\"",
      ),
      ConversationNode(
        id: 'weakness',
        aiUtterance:
            "And what's something you're working to improve in yourself?",
        acceptableKeywords: [
          'improve', 'working', 'on', 'struggle', 'learning', 'better',
          'used', 'to', 'tend', 'still',
        ],
        hint: 'Pick something real. Try: "I\'m working on public speaking."',
        nextNodeId: 'scenario',
        feedbackOnSuccess: "I like that you're self-aware.",
        feedbackOnFail:
            "Give an honest area. Try: \"I'm working on ___.\"",
      ),
      ConversationNode(
        id: 'scenario',
        aiUtterance:
            "Tell me about a time you disagreed with a teammate. How did you handle it?",
        acceptableKeywords: [
          'once', 'when', 'disagreed', 'listened', 'talked', 'suggested',
          'explained', 'discussed', 'agreed', 'compromise', 'solution',
        ],
        hint: 'Use past tense. Structure: situation → action → outcome.',
        nextNodeId: 'questions',
        feedbackOnSuccess: "Thanks for sharing that.",
        feedbackOnFail:
            "Tell a short story with past tense verbs. Try: \"Once, I ___\".",
      ),
      ConversationNode(
        id: 'questions',
        aiUtterance: "What questions do you have for me about the role?",
        acceptableKeywords: [
          'question', 'ask', 'wonder', 'curious', 'team', 'day',
          'like', 'success', 'project', 'how',
        ],
        hint: 'Always have a question ready. Try: "What does success look like in this role?"',
        nextNodeId: 'close',
        feedbackOnSuccess: "That's a great question.",
        feedbackOnFail:
            "Ask something. Try: \"Can you tell me about the team?\"",
      ),
      ConversationNode(
        id: 'close',
        aiUtterance:
            "Thanks for your time today. We'll be in touch within the week.",
        acceptableKeywords: [
          'thank', 'thanks', 'you', 'enjoyed', 'appreciate', 'forward', 'hearing',
        ],
        hint: 'Close professionally. Try: "Thanks so much — I look forward to hearing from you."',
        nextNodeId: null,
        feedbackOnSuccess:
            "🎉 You handled a real job interview in English. Impressive!",
        feedbackOnFail:
            "End with: \"Thank you — I look forward to hearing from you.\"",
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // B1 — Airport Lost Luggage
  // ═══════════════════════════════════════════════════════════════════

  static const _airportLostLuggageConv = ScriptedConversation(
    scenarioTitle: "Reporting Lost Luggage at the Airport",
    aiPersonaDescription:
        "Alex is an airline service agent. He's apologetic and efficient — expect practical questions.",
    nodes: [
      ConversationNode(
        id: 'open',
        aiUtterance:
            "Good evening. I see you've been waiting — what seems to be the problem?",
        acceptableKeywords: [
          'bag', 'suitcase', 'luggage', "didn't", 'did', 'not', 'arrive',
          'missing', 'lost', 'came', 'through',
        ],
        hint: 'State the issue. Try: "My suitcase didn\'t arrive on my flight."',
        nextNodeId: 'flight',
        feedbackOnSuccess: "I'm very sorry to hear that. Let's track it down.",
        feedbackOnFail:
            "State the problem: \"My bag didn't arrive.\"",
      ),
      ConversationNode(
        id: 'flight',
        aiUtterance: "Can you give me your flight number?",
        acceptableKeywords: [
          'flight', 'number', 'was', 'yes', 'let', 'me', 'check',
          'boarding', 'pass',
        ],
        hint: 'Read it off your boarding pass. Try: "It was flight 442 from Istanbul."',
        nextNodeId: 'describe',
        feedbackOnSuccess: "Got it. Now about the bag itself.",
        feedbackOnFail:
            "Give a flight identifier. Try: \"Flight 442.\"",
      ),
      ConversationNode(
        id: 'describe',
        aiUtterance: "Could you describe your suitcase for me?",
        acceptableKeywords: [
          'black', 'blue', 'red', 'gray', 'grey', 'medium', 'large',
          'small', 'hard', 'soft', 'shell', 'wheels',
        ],
        hint: 'Size + color + material. Try: "A medium black hard-shell with wheels."',
        nextNodeId: 'marker',
        feedbackOnSuccess: "Clear description. Anything distinctive?",
        feedbackOnFail:
            "Give size + color. Try: \"Medium-sized and black.\"",
      ),
      ConversationNode(
        id: 'marker',
        aiUtterance: "Is there anything on it that would help us identify it?",
        acceptableKeywords: [
          'yes', 'no', 'ribbon', 'tag', 'sticker', 'name', 'label',
          'strap', 'initials', 'mark',
        ],
        hint: 'Mention any unique marker. Try: "Yes, a red ribbon on the handle."',
        nextNodeId: 'contents',
        feedbackOnSuccess: "That'll help us spot it.",
        feedbackOnFail:
            "Any tag or ribbon? Try: \"Yes, a tag with my name.\"",
      ),
      ConversationNode(
        id: 'contents',
        aiUtterance:
            "Is there anything valuable or urgent inside I should know about?",
        acceptableKeywords: [
          'yes', 'no', 'clothes', 'medication', 'laptop', 'documents',
          'important', 'just', 'mostly', 'nothing',
        ],
        hint: 'Mention anything urgent. Try: "Yes — my medication is in there."',
        nextNodeId: 'timeline',
        feedbackOnSuccess: "Noted. We'll prioritize accordingly.",
        feedbackOnFail:
            "Answer with contents. Try: \"Mostly clothes, but also medication.\"",
      ),
      ConversationNode(
        id: 'timeline',
        aiUtterance:
            "We should locate it within 24 hours. Where should we deliver it?",
        acceptableKeywords: [
          'hotel', 'address', 'home', 'staying', 'phone', 'text',
          'deliver', 'bring', 'send',
        ],
        hint: 'Name a delivery address. Try: "My hotel, the Grand Plaza."',
        nextNodeId: 'close',
        feedbackOnSuccess: "We'll contact you as soon as it's located.",
        feedbackOnFail:
            "Give a delivery location. Try: \"Deliver it to my hotel.\"",
      ),
      ConversationNode(
        id: 'close',
        aiUtterance:
            "Again, I apologize for the inconvenience. We'll be in touch soon.",
        acceptableKeywords: [
          'thank', 'thanks', 'appreciate', 'understand', 'hope', 'soon', 'you',
        ],
        hint: 'Close civilly. Try: "Thanks — I appreciate your help."',
        nextNodeId: null,
        feedbackOnSuccess:
            "🎉 You handled a stressful travel problem clearly in English!",
        feedbackOnFail:
            "Close with: \"Thank you for your help.\"",
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // B1 — Customer Service Call
  // ═══════════════════════════════════════════════════════════════════

  static const _customerServiceConv = ScriptedConversation(
    scenarioTitle: "Resolving an Order Issue with Riverton Support",
    aiPersonaDescription:
        "Marcus is a service agent at Riverton. He's courteous and methodical — stay calm, be clear.",
    nodes: [
      ConversationNode(
        id: 'open',
        aiUtterance:
            "Hi, thanks for calling Riverton Support. This is Marcus — how can I help you today?",
        acceptableKeywords: [
          'calling', 'about', 'issue', 'problem', 'order', 'package',
          'delivery', 'item', 'received', 'arrived',
        ],
        hint: 'State the reason. Try: "I\'m calling about a problem with my order."',
        nextNodeId: 'details',
        feedbackOnSuccess: "I'm sorry to hear that. Let me pull up your account.",
        feedbackOnFail:
            "Start with: \"I'm calling about ___.\"",
      ),
      ConversationNode(
        id: 'details',
        aiUtterance: "Can you describe the problem in a bit more detail?",
        acceptableKeywords: [
          'arrived', 'damaged', 'broken', 'missing', 'wrong', 'late',
          'never', "didn't", 'box', 'package', 'item',
        ],
        hint: 'Be specific. Try: "The package arrived damaged yesterday."',
        nextNodeId: 'order',
        feedbackOnSuccess: "Understood. Let me look up the details.",
        feedbackOnFail:
            "Describe what went wrong. Try: \"It arrived damaged.\"",
      ),
      ConversationNode(
        id: 'order',
        aiUtterance: "Do you happen to have your order number handy?",
        acceptableKeywords: [
          'yes', 'no', 'let', 'me', 'check', 'moment', 'number', 'email',
          'here', 'find',
        ],
        hint: 'Yes with the number, or ask for a moment. Try: "Yes, one moment."',
        nextNodeId: 'fix',
        feedbackOnSuccess: "Thanks — I found your order.",
        feedbackOnFail:
            "Answer yes or no. Try: \"Yes, let me check my email.\"",
      ),
      ConversationNode(
        id: 'fix',
        aiUtterance:
            "I can offer you a full refund or send a replacement. Which would you prefer?",
        acceptableKeywords: [
          'refund', 'replacement', 'prefer', 'like', 'take', 'rather',
          'please', 'send', 'money', 'back',
        ],
        hint: 'Pick one. Try: "I\'d prefer a replacement, please."',
        nextNodeId: 'timeline',
        feedbackOnSuccess: "Got it — I'll set that up right away.",
        feedbackOnFail:
            "Choose one. Try: \"A refund, please.\"",
      ),
      ConversationNode(
        id: 'timeline',
        aiUtterance: "When would be a good time to expect the replacement?",
        acceptableKeywords: [
          'soon', 'when', 'long', 'possible', 'how', 'days',
          'week', 'quickly', 'urgent',
        ],
        hint: 'Ask about timing. Try: "How long will it take?"',
        nextNodeId: 'close',
        feedbackOnSuccess: "It should arrive within three business days.",
        feedbackOnFail:
            "Ask about timing. Try: \"When can I expect it?\"",
      ),
      ConversationNode(
        id: 'close',
        aiUtterance: "Is there anything else I can help you with today?",
        acceptableKeywords: [
          'no', "that's", 'thats', 'all', 'thank', 'thanks', 'appreciate', 'good',
        ],
        hint: 'Wrap up politely. Try: "No, that\'s all. Thank you so much."',
        nextNodeId: null,
        feedbackOnSuccess:
            "🎉 You turned a complaint into a clean resolution. Great call!",
        feedbackOnFail: "Close with: \"No, that's all. Thank you.\"",
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // B2 — Business Meeting
  // ═══════════════════════════════════════════════════════════════════

  static const _businessMeetingConv = ScriptedConversation(
    scenarioTitle: "Timeline Concern with Priya",
    aiPersonaDescription:
        "Priya is your manager — experienced, thoughtful, and open to pushback when it's well-reasoned.",
    nodes: [
      ConversationNode(
        id: 'open',
        aiUtterance:
            "Alright, everyone's here. Before we start — anything you want to flag up front?",
        acceptableKeywords: [
          'raise', 'concern', 'flag', 'bring', 'up', 'mention',
          'timeline', 'schedule', 'wanted', 'share',
        ],
        hint: 'Raise it early. Try: "Yes — I\'d like to raise a concern about the timeline."',
        nextNodeId: 'specifics',
        feedbackOnSuccess: "Okay, I'm listening. Walk me through it.",
        feedbackOnFail:
            "Open with: \"I'd like to raise a concern about ___.\"",
      ),
      ConversationNode(
        id: 'specifics',
        aiUtterance: "What specifically is giving you pause?",
        acceptableKeywords: [
          'data', 'because', 'estimate', 'shows', 'based', 'sprint',
          'capacity', 'team', 'aggressive', 'tight', 'risk',
        ],
        hint: 'Ground it in data. Try: "Based on the last sprint, we\'re at capacity."',
        nextNodeId: 'proposal',
        feedbackOnSuccess: "Okay — that's a valid concern.",
        feedbackOnFail:
            "Support with data. Try: \"Based on ___, the timeline looks tight.\"",
      ),
      ConversationNode(
        id: 'proposal',
        aiUtterance: "So what would you propose instead?",
        acceptableKeywords: [
          'propose', 'suggest', 'could', 'add', 'week', 'phase',
          'scope', 'reduce', 'extend', 'alternative', 'approach',
        ],
        hint: 'Offer a specific alternative. Try: "I\'d propose adding a week to phase two."',
        nextNodeId: 'tradeoff',
        feedbackOnSuccess: "Interesting. Let me think about the tradeoffs.",
        feedbackOnFail:
            "Be concrete. Try: \"I'd propose extending the deadline by a week.\"",
      ),
      ConversationNode(
        id: 'tradeoff',
        aiUtterance:
            "But that could delay the launch. How do you see us handling that?",
        acceptableKeywords: [
          'could', 'might', 'could', 'communicate', 'stakeholders', 'prioritize',
          'trade', 'quality', 'instead', 'scope',
        ],
        hint: 'Address the tradeoff directly. Try: "We could prioritize scope over deadline."',
        nextNodeId: 'agree',
        feedbackOnSuccess: "That's a reasonable framing.",
        feedbackOnFail:
            "Name the tradeoff. Try: \"We could reduce scope instead.\"",
      ),
      ConversationNode(
        id: 'agree',
        aiUtterance:
            "Alright, I think there's something here. Let's take a week and re-plan — does that work?",
        acceptableKeywords: [
          'yes', 'works', 'sounds', 'good', 'great', 'agree', 'perfect',
          'appreciate', 'thanks',
        ],
        hint: 'Confirm and thank. Try: "Yes, that works — thanks for hearing me out."',
        nextNodeId: 'close',
        feedbackOnSuccess: "Good. I'll loop in the rest of the team.",
        feedbackOnFail: "Agree clearly. Try: \"Yes, that sounds good.\"",
      ),
      ConversationNode(
        id: 'close',
        aiUtterance:
            "Thanks for bringing this up. I appreciate when people speak up early.",
        acceptableKeywords: [
          'thank', 'thanks', 'you', 'appreciate', 'hearing', 'course', 'of',
        ],
        hint: 'Close graciously. Try: "Thanks for listening."',
        nextNodeId: null,
        feedbackOnSuccess:
            "🎉 You raised a tough concern professionally and got results!",
        feedbackOnFail: "End with: \"Thanks for hearing me out.\"",
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // B2 — Hotel Complaint
  // ═══════════════════════════════════════════════════════════════════

  static const _hotelComplaintConv = ScriptedConversation(
    scenarioTitle: "A Problem at the Grand Harbor Hotel",
    aiPersonaDescription:
        "Rosa is the duty manager. She's professional, solution-oriented, and values long-term guests.",
    nodes: [
      ConversationNode(
        id: 'open',
        aiUtterance:
            "Good evening. How can I help you tonight?",
        acceptableKeywords: [
          'afraid', 'complaint', 'issue', 'problem', 'concern', 'about',
          'room', 'need', 'talk', 'speak',
        ],
        hint: 'Open politely but firmly. Try: "I\'m afraid I have a complaint about my room."',
        nextNodeId: 'detail',
        feedbackOnSuccess: "I'm sorry to hear that. Tell me what's happened.",
        feedbackOnFail:
            "Open with: \"I'm afraid I have a complaint.\"",
      ),
      ConversationNode(
        id: 'detail',
        aiUtterance: "Could you tell me exactly what the issue is?",
        acceptableKeywords: [
          'air', 'conditioning', 'broken', 'working', 'hot', 'noise',
          'since', 'arrived', 'last', 'night', 'heating',
        ],
        hint: 'Specifics + timeline. Try: "The AC has been broken since last night."',
        nextNodeId: 'impact',
        feedbackOnSuccess: "I understand. That's clearly frustrating.",
        feedbackOnFail:
            "Name what's wrong + how long. Try: \"The ___ has been broken since ___.\"",
      ),
      ConversationNode(
        id: 'impact',
        aiUtterance: "And how has that affected your stay?",
        acceptableKeywords: [
          "couldn't", 'cant', 'sleep', 'uncomfortable', 'missed',
          'affected', 'tired', 'hot', 'terrible', 'expected',
        ],
        hint: 'Explain real impact. Try: "I couldn\'t sleep and I\'m exhausted today."',
        nextNodeId: 'expectation',
        feedbackOnSuccess: "I completely understand. That's not acceptable.",
        feedbackOnFail:
            "Explain real-world impact. Try: \"I couldn't sleep properly.\"",
      ),
      ConversationNode(
        id: 'expectation',
        aiUtterance: "How would you like us to make this right?",
        acceptableKeywords: [
          'would', 'like', 'appreciate', 'refund', 'partial', 'night',
          'compensation', 'discount', 'room', 'change', 'upgrade',
        ],
        hint: 'Be specific. Try: "I\'d appreciate a refund for last night."',
        nextNodeId: 'offer',
        feedbackOnSuccess: "I hear you — let me see what I can do.",
        feedbackOnFail:
            "Name a specific remedy. Try: \"A partial refund would help.\"",
      ),
      ConversationNode(
        id: 'offer',
        aiUtterance:
            "I can offer a free night's credit and move you to a suite now. Does that work?",
        acceptableKeywords: [
          'yes', 'works', 'appreciate', 'reasonable', 'fair', 'thank',
          'sounds', 'good', 'accept', 'perfect',
        ],
        hint: 'Accept gracefully. Try: "Yes, that sounds fair. Thank you."',
        nextNodeId: 'close',
        feedbackOnSuccess:
            "I'm glad. Let me call someone to help with your things.",
        feedbackOnFail: "Accept or counter. Try: \"Yes, that works.\"",
      ),
      ConversationNode(
        id: 'close',
        aiUtterance:
            "Once again, I'm sorry for the trouble. We'll take great care of you tonight.",
        acceptableKeywords: [
          'thank', 'thanks', 'you', 'appreciate', 'time', 'help', 'kindness',
        ],
        hint: 'Close with grace. Try: "Thank you for handling this so quickly."',
        nextNodeId: null,
        feedbackOnSuccess:
            "🎉 You complained effectively and got a great outcome. Polished work!",
        feedbackOnFail: "End with: \"Thank you for your help.\"",
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // B2 — Networking Event
  // ═══════════════════════════════════════════════════════════════════

  static const _networkingConv = ScriptedConversation(
    scenarioTitle: "Meeting Jordan at a Tech Networking Event",
    aiPersonaDescription:
        "Jordan is a senior engineer — curious, direct, and interested in building real connections.",
    nodes: [
      ConversationNode(
        id: 'open',
        aiUtterance:
            "Hey — Jordan. I don't think we've met. What do you do?",
        acceptableKeywords: [
          'work', 'in', 'as', 'for', 'company', 'field', 'industry',
          'engineer', 'marketing', 'data', 'designer', 'product',
        ],
        hint: 'One-sentence intro. Try: "I work in data science for a healthcare startup."',
        nextNodeId: 'interest',
        feedbackOnSuccess: "Oh, interesting — cool field.",
        feedbackOnFail:
            "Keep it short. Try: \"I work in ___ at ___.\"",
      ),
      ConversationNode(
        id: 'interest',
        aiUtterance: "What brought you to this event tonight?",
        acceptableKeywords: [
          'hoping', 'meet', 'learn', 'interesting', 'invited',
          'curious', 'network', 'speakers', 'brought',
        ],
        hint: 'Show curiosity. Try: "I was hoping to meet people from other fields."',
        nextNodeId: 'their_work',
        feedbackOnSuccess: "That's a great reason. Same, honestly.",
        feedbackOnFail:
            "Give a reason. Try: \"I was hoping to meet people in ___.\"",
      ),
      ConversationNode(
        id: 'their_work',
        aiUtterance:
            "I'm in infrastructure — honestly pretty dry, but I love it. Have any questions about that world?",
        acceptableKeywords: [
          'what', 'how', 'tell', 'me', 'sounds', 'interesting',
          'work', 'like', 'typical', 'curious', 'day',
        ],
        hint: 'Ask a follow-up. Try: "What does a typical day look like for you?"',
        nextNodeId: 'common',
        feedbackOnSuccess: "Happy to share. It's actually fascinating.",
        feedbackOnFail:
            "Ask one question. Try: \"What does your day look like?\"",
      ),
      ConversationNode(
        id: 'common',
        aiUtterance:
            "Funnily enough, we both work with data pipelines just from different angles. Have you dealt with similar challenges?",
        acceptableKeywords: [
          'yes', 'actually', 'similar', 'different', 'interesting', 'experience',
          'challenge', 'worked', 'data', 'pipeline',
        ],
        hint: 'Find common ground. Try: "Yes, actually — we deal with that too."',
        nextNodeId: 'followup',
        feedbackOnSuccess: "Huh, small world. We should talk more.",
        feedbackOnFail:
            "Connect back. Try: \"Yes, we've had similar challenges.\"",
      ),
      ConversationNode(
        id: 'followup',
        aiUtterance:
            "I'd love to continue this conversation. Want to grab a coffee sometime?",
        acceptableKeywords: [
          'yes', 'love', 'sure', 'absolutely', 'card', 'linkedin',
          'email', 'send', 'me', 'connect', 'would',
        ],
        hint: 'Accept enthusiastically. Try: "Yes, I\'d love that. Here\'s my card."',
        nextNodeId: 'close',
        feedbackOnSuccess: "Great — I'll shoot you an email next week.",
        feedbackOnFail:
            "Accept the offer. Try: \"Absolutely — let me grab your info.\"",
      ),
      ConversationNode(
        id: 'close',
        aiUtterance:
            "Alright, I'll let you mingle. Good meeting you — really glad we ran into each other.",
        acceptableKeywords: [
          'same', 'likewise', 'you', 'too', 'bye', 'good', 'meeting',
          'talk', 'soon', 'pleasure',
        ],
        hint: 'Reciprocate warmly. Try: "Likewise — really glad we met."',
        nextNodeId: null,
        feedbackOnSuccess:
            "🎉 You built a real professional connection in English. Well done!",
        feedbackOnFail:
            "Match their warmth. Try: \"Likewise — good meeting you.\"",
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // C1 — Negotiation
  // ═══════════════════════════════════════════════════════════════════

  static const _negotiationConv = ScriptedConversation(
    scenarioTitle: "Vendor Contract Negotiation with Samira",
    aiPersonaDescription:
        "Samira is a procurement director — sharp, fair, and willing to trade. Both sides want this deal.",
    nodes: [
      ConversationNode(
        id: 'open',
        aiUtterance:
            "Thanks for coming in. Before we get into specifics — what's your opening position?",
        acceptableKeywords: [
          'genuinely', 'think', 'common', 'ground', 'win', 'hope',
          'arrive', 'constructive', 'both', 'sides', 'value',
        ],
        hint: 'Set a constructive tone. Try: "I genuinely think we can find common ground here."',
        nextNodeId: 'price',
        feedbackOnSuccess: "I appreciate the constructive tone. Let's dig in.",
        feedbackOnFail:
            "Open warmly. Try: \"I think there's room for common ground.\"",
      ),
      ConversationNode(
        id: 'price',
        aiUtterance: "We're looking at around twelve percent lower than your proposal. Thoughts?",
        acceptableKeywords: [
          'willing', 'move', 'provided', 'however', 'consider',
          'flexibility', 'terms', 'depends', 'trade',
        ],
        hint: 'Don\'t concede cleanly — trade. Try: "We could move, provided you meet us on delivery."',
        nextNodeId: 'push',
        feedbackOnSuccess: "Interesting. Tell me more about what you'd need.",
        feedbackOnFail:
            "Condition every concession. Try: \"We could move, provided ___.\"",
      ),
      ConversationNode(
        id: 'push',
        aiUtterance: "And what's the biggest thing you'd need from us?",
        acceptableKeywords: [
          'need', 'require', 'delivery', 'payment', 'terms', 'schedule',
          'commitment', 'volume', 'extended',
        ],
        hint: 'Name one clear ask. Try: "We\'d need a commitment on delivery within three weeks."',
        nextNodeId: 'limit',
        feedbackOnSuccess: "Okay — that's workable.",
        feedbackOnFail:
            "Be specific. Try: \"We'd need ___ in return.\"",
      ),
      ConversationNode(
        id: 'limit',
        aiUtterance:
            "One last thing — we'd need exclusivity in the region for a year.",
        acceptableKeywords: [
          'deal', 'breaker', 'afraid', "can't", 'cannot', 'possible',
          'unfortunately', 'however', 'flexible', 'six', 'months',
        ],
        hint: 'Push back firmly but politely. Try: "Exclusivity for a year is a deal-breaker, I\'m afraid."',
        nextNodeId: 'counter',
        feedbackOnSuccess: "I thought you might say that. What could you do?",
        feedbackOnFail:
            "Draw a line politely. Try: \"That's a deal-breaker, I'm afraid.\"",
      ),
      ConversationNode(
        id: 'counter',
        aiUtterance: "Alright — meet me halfway. What's your counter?",
        acceptableKeywords: [
          'offer', 'propose', 'could', 'consider', 'six', 'months',
          'quarter', 'partial', 'instead', 'review',
        ],
        hint: 'Offer a compromise. Try: "Six months of exclusivity with a review clause."',
        nextNodeId: 'close',
        feedbackOnSuccess: "That could work. Let me take it to my team.",
        feedbackOnFail:
            "Offer a middle. Try: \"We could do six months with a review.\"",
      ),
      ConversationNode(
        id: 'close',
        aiUtterance:
            "I think we have the bones of a deal. Should we put this in writing?",
        acceptableKeywords: [
          'yes', 'sounds', 'good', 'agreed', 'writing', 'draft',
          'next', 'steps', 'appreciate', 'send',
        ],
        hint: 'Confirm and name a next step. Try: "Yes — let\'s get a draft by Friday."',
        nextNodeId: null,
        feedbackOnSuccess:
            "🎉 You negotiated professionally, held your line, and built trust. Masterful!",
        feedbackOnFail: "Close concretely. Try: \"Yes — send me a draft.\"",
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // C1 — Senior Interview
  // ═══════════════════════════════════════════════════════════════════

  static const _seniorInterviewConv = ScriptedConversation(
    scenarioTitle: "Head of Product Interview with Eleanor (CEO)",
    aiPersonaDescription:
        "Eleanor is the CEO — incisive, warm, and deeply curious about leadership thinking. This is the final round.",
    nodes: [
      ConversationNode(
        id: 'open',
        aiUtterance:
            "So glad we finally got to meet. Take me through your career arc — the shape of it, not the details.",
        acceptableKeywords: [
          'started', 'led', 'built', 'grew', 'moved', 'managed', 'team',
          'company', 'scaled', 'learned', 'arc', 'journey',
        ],
        hint: 'Give the shape, not the resume. Try: "I started in engineering, moved to product, and have led teams of ___."',
        nextNodeId: 'philosophy',
        feedbackOnSuccess: "That's a coherent arc. I like it.",
        feedbackOnFail:
            "Summarize the trajectory. Try: \"I started in ___, then moved to ___.\"",
      ),
      ConversationNode(
        id: 'philosophy',
        aiUtterance: "How do you think about leadership?",
        acceptableKeywords: [
          'philosophy', 'centers', 'trust', 'accountability', 'believe',
          'team', 'autonomy', 'clarity', 'servant', 'enabling',
        ],
        hint: 'State a clear principle. Try: "My philosophy centers on trust and shared accountability."',
        nextNodeId: 'failure',
        feedbackOnSuccess: "I appreciate clarity on that.",
        feedbackOnFail:
            "Name a core value. Try: \"I believe strongly in ___.\"",
      ),
      ConversationNode(
        id: 'failure',
        aiUtterance:
            "Tell me about a real failure — something that actually hurt. What did you take from it?",
        acceptableKeywords: [
          'failed', 'failure', 'learned', 'taught', 'realized',
          'would', 'differently', 'since', 'approach', 'now',
        ],
        hint: 'Pick a real one. Arc: situation → failure → lesson → integration.',
        nextNodeId: 'vision',
        feedbackOnSuccess:
            "That took courage to share. Thank you.",
        feedbackOnFail:
            "Tell a real story. Try: \"Once I ___, and I learned ___.\"",
      ),
      ConversationNode(
        id: 'vision',
        aiUtterance:
            "What excites you about our company specifically?",
        acceptableKeywords: [
          'drawn', 'excited', 'mission', 'long', 'term', 'thinking',
          'values', 'opportunity', 'because', 'culture', 'team',
        ],
        hint: 'Connect to values. Try: "I\'m drawn to organizations that value long-term thinking."',
        nextNodeId: 'hard',
        feedbackOnSuccess:
            "Good — I like that you did your homework.",
        feedbackOnFail:
            "Connect to what makes the company distinctive. Try: \"I'm drawn to your ___.\"",
      ),
      ConversationNode(
        id: 'hard',
        aiUtterance:
            "What's the hardest part of the role that you're worried about?",
        acceptableKeywords: [
          'honestly', 'challenge', 'worry', 'unfamiliar', 'stretch',
          'learn', 'navigate', 'scaling', 'transition',
        ],
        hint: 'Be honest, not evasive. Try: "Honestly, scaling culture at this size."',
        nextNodeId: 'close',
        feedbackOnSuccess:
            "Honest and self-aware. That's what I was hoping to hear.",
        feedbackOnFail:
            "Don't dodge. Try: \"Honestly, ___ would be a stretch.\"",
      ),
      ConversationNode(
        id: 'close',
        aiUtterance:
            "I've enjoyed this. We'll be in touch within the week with a decision.",
        acceptableKeywords: [
          'thank', 'appreciate', 'enjoyed', 'conversation', 'look',
          'forward', 'hearing', 'opportunity',
        ],
        hint: 'Match her register. Try: "Thank you — I\'ve really enjoyed this conversation."',
        nextNodeId: null,
        feedbackOnSuccess:
            "🎉 You handled a CEO-level interview with depth and composure. Outstanding!",
        feedbackOnFail:
            "Close with warmth. Try: \"Thank you, I've really enjoyed this.\"",
      ),
    ],
  );
}
