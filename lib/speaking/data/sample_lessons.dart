import '../models/speaking_models.dart';

/// Hardcoded sample lessons for English→Uzbek speaking practice.
///
/// These use the user's existing vocabulary patterns (English↔Uzbek)
/// and provide starter content at A1/A2 level.
class SampleLessons {
  SampleLessons._();

  static List<SpeakingLesson> get all => [_greetings, _dailyObjects, _atTheMarket, _restaurant];

  // ─── Lesson 1: Basic Greetings ──────────────────────────────────

  static const _greetings = SpeakingLesson(
    id: 'lesson_greetings',
    title: 'Basic Greetings',
    language: 'English',
    languageCode: 'en-US',
    cefrLevel: CEFRLevel.a1,
    topic: 'Greeting people in English',
    goal: 'Learner can greet someone and introduce themselves in English',
    estimatedMinutes: 5,
    xpReward: 50,
    steps: [
      LessonStep(
        id: 'greet_1',
        type: StepType.listenAndRepeat,
        instruction: 'Listen and repeat this greeting:',
        targetPhrase: 'Hello, how are you?',
        hints: ['Start with "Hello"', 'Then add "how are you?"'],
      ),
      LessonStep(
        id: 'greet_2',
        type: StepType.promptResponse,
        instruction: 'Introduce yourself:',
        promptQuestion: 'Say your name using "My name is..."',
        expectedKeywords: ['my', 'name', 'is'],
        grammarFocus: 'My name is + name',
        hints: ['Say "My name is" and then your name'],
      ),
      LessonStep(
        id: 'greet_3',
        type: StepType.readAndSpeak,
        instruction: 'Read this phrase out loud:',
        targetPhrase: 'Nice to meet you!',
        acceptableVariants: ['Nice to meet you', 'Pleased to meet you'],
      ),
      LessonStep(
        id: 'greet_4',
        type: StepType.promptResponse,
        instruction: 'Answer the question:',
        promptQuestion: "Hello! What is your name?",
        expectedKeywords: ['my', 'name', 'is'],
        grammarFocus: 'Subject + verb + complement',
        hints: ['Start with "My name is..."'],
      ),
      LessonStep(
        id: 'greet_5',
        type: StepType.fillTheGap,
        instruction: 'Fill in the missing word:',
        targetPhrase: 'Good ___, how are you today?',
        expectedKeywords: ['morning', 'afternoon', 'evening'],
        hints: ['Think about a time of day'],
      ),
      LessonStep(
        id: 'greet_6',
        type: StepType.promptResponse,
        instruction: 'Answer the question:',
        promptQuestion: 'How are you doing today?',
        expectedKeywords: ['fine', 'good', 'great', 'well', 'okay'],
        hints: ['You can say "I am fine" or "I am good"'],
      ),
    ],
  );

  // ─── Lesson 2: Daily Objects ────────────────────────────────────

  static const _dailyObjects = SpeakingLesson(
    id: 'lesson_daily_objects',
    title: 'Daily Objects',
    language: 'English',
    languageCode: 'en-US',
    cefrLevel: CEFRLevel.a1,
    topic: 'Naming common daily objects in English',
    goal: 'Learner can name and describe everyday items they use',
    estimatedMinutes: 6,
    xpReward: 60,
    steps: [
      LessonStep(
        id: 'obj_1',
        type: StepType.listenAndRepeat,
        instruction: 'Listen and repeat:',
        targetPhrase: 'This is a book.',
        hints: ['Say "This is" then the object'],
      ),
      LessonStep(
        id: 'obj_2',
        type: StepType.listenAndRepeat,
        instruction: 'Listen and repeat:',
        targetPhrase: 'I have a pen and a notebook.',
        hints: ['Name two objects you carry'],
      ),
      LessonStep(
        id: 'obj_3',
        type: StepType.readAndSpeak,
        instruction: 'Read this sentence out loud:',
        targetPhrase: 'The water is on the table.',
        acceptableVariants: ['Water is on the table', 'The water is on table'],
      ),
      LessonStep(
        id: 'obj_4',
        type: StepType.promptResponse,
        instruction: 'Answer the question:',
        promptQuestion: 'What do you see on your desk?',
        expectedKeywords: ['book', 'pen', 'phone', 'computer', 'water', 'cup', 'paper'],
        hints: ['Name things you can see: "I see a..."'],
      ),
      LessonStep(
        id: 'obj_5',
        type: StepType.fillTheGap,
        instruction: 'Fill in the missing word:',
        targetPhrase: 'I need a ___ to write my homework.',
        expectedKeywords: ['pen', 'pencil'],
        hints: ['What writing tool do you use?'],
      ),
      LessonStep(
        id: 'obj_6',
        type: StepType.readAndSpeak,
        instruction: 'Say this sentence:',
        targetPhrase: 'Can I borrow your pencil, please?',
        acceptableVariants: ['Can I borrow your pencil please', 'May I borrow your pencil'],
      ),
    ],
  );

  // ─── Lesson 3: At the Market ────────────────────────────────────

  static const _atTheMarket = SpeakingLesson(
    id: 'lesson_market',
    title: 'At the Market',
    language: 'English',
    languageCode: 'en-US',
    cefrLevel: CEFRLevel.a2,
    topic: 'Buying food at a market or shop',
    goal: 'Learner can ask for items and prices at a market',
    estimatedMinutes: 7,
    xpReward: 70,
    steps: [
      LessonStep(
        id: 'market_1',
        type: StepType.listenAndRepeat,
        instruction: 'Listen and repeat:',
        targetPhrase: 'How much does this cost?',
        hints: ['Start with "How much"'],
      ),
      LessonStep(
        id: 'market_2',
        type: StepType.readAndSpeak,
        instruction: 'Read this sentence out loud:',
        targetPhrase: 'I would like two kilos of apples, please.',
        acceptableVariants: [
          'I would like 2 kilos of apples please',
          'I want two kilos of apples',
          'Can I have two kilos of apples',
        ],
      ),
      LessonStep(
        id: 'market_3',
        type: StepType.promptResponse,
        instruction: 'The shopkeeper asks you:',
        promptQuestion: 'What would you like to buy today?',
        expectedKeywords: ['like', 'want', 'buy', 'need', 'please'],
        grammarFocus: 'I would like / I want + noun',
        hints: ['Say "I would like..." and name a food item'],
      ),
      LessonStep(
        id: 'market_4',
        type: StepType.fillTheGap,
        instruction: 'Fill in the missing word:',
        targetPhrase: 'Can I ___ some fresh bread?',
        expectedKeywords: ['have', 'buy', 'get'],
      ),
      LessonStep(
        id: 'market_5',
        type: StepType.listenAndRepeat,
        instruction: 'Listen and repeat:',
        targetPhrase: 'Do you have any fresh vegetables?',
        hints: ['Ask about vegetables at the market'],
      ),
      LessonStep(
        id: 'market_6',
        type: StepType.promptResponse,
        instruction: 'The shopkeeper says "That will be five dollars." What do you say?',
        promptQuestion: 'That will be five dollars.',
        expectedKeywords: ['thank', 'thanks', 'here', 'change', 'receipt'],
        hints: ['You can say "Here you go" or "Thank you"'],
      ),
      LessonStep(
        id: 'market_7',
        type: StepType.readAndSpeak,
        instruction: 'Say goodbye to the shopkeeper:',
        targetPhrase: 'Thank you very much! Have a nice day!',
        acceptableVariants: [
          'Thank you! Have a nice day',
          'Thanks! Have a good day',
          'Thank you very much',
        ],
      ),
    ],
  );

  // ─── Lesson 4: At the Restaurant ────────────────────────────────

  static const _restaurant = SpeakingLesson(
    id: 'lesson_restaurant',
    title: 'At the Restaurant',
    language: 'English',
    languageCode: 'en-US',
    cefrLevel: CEFRLevel.a2,
    topic: 'Ordering food at a restaurant',
    goal: 'Learner can comfortably order food interactively and answer the waiter\'s questions dynamically',
    estimatedMinutes: 7,
    xpReward: 100,
    steps: [
      LessonStep(
        id: 'rest_1',
        type: StepType.freeConversation,
        instruction: 'Have a conversation with the waiter to order lunch.',
        targetPhrase: 'a friendly and accommodating waiter at a bustling American diner', // Persona
        promptQuestion: 'The customer just sat down. Welcome them and ask what they want to drink. They want to order a burger.', // Scenario
      ),
    ],
  );
}
