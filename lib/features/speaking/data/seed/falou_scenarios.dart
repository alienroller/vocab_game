import '../../domain/models/speaking_exercise.dart';
import '../../domain/models/speaking_phrase.dart';
import '../../domain/models/speaking_scenario.dart';

/// Static Falou-style content for v1. Swap for Supabase-backed loader later.
///
/// Each scenario follows the same pedagogical arc:
///   for each phrase: listen → listen_repeat → word_breakdown
///   then: recall challenge on all phrases in shuffled order.
class FalouScenarios {
  FalouScenarios._();

  static List<SpeakingScenario> all = [
    // A1
    _greetings,
    _classroom,
    _directions,
    _weather,
    _bus,
    _market,
    // A2
    _cafe,
    _airport,
    _taxi,
    _hotel,
    _restaurant,
    _clothes,
    _pharmacy,
    _phone,
    _plans,
    // B1
    _doctor,
    _interview,
    _bank,
    _post,
    _hobbies,
    _family,
    // B2
    _meeting,
    _complaint,
    _negotiate,
    // C1
    _news,
  ];

  static SpeakingScenario? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ─── Greetings (A1) ────────────────────────────────────────────────

  static final _greetingsPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'greet_hello',
      l2Text: 'Hello, how are you?',
      l1Text: 'Salom, yaxshimisiz?',
      phonetic: 'he-loh, haw aar yoo?',
    ),
    const SpeakingPhrase(
      id: 'greet_name',
      l2Text: "What's your name?",
      l1Text: 'Ismingiz nima?',
      phonetic: 'wats yor naym?',
    ),
    const SpeakingPhrase(
      id: 'greet_from',
      l2Text: 'Where are you from?',
      l1Text: 'Qayerdansiz?',
      phonetic: 'wair aar yoo from?',
    ),
    const SpeakingPhrase(
      id: 'greet_nice',
      l2Text: 'Nice to meet you.',
      l1Text: 'Tanishganimdan xursandman.',
      phonetic: 'nays too meet yoo.',
    ),
  ];

  static SpeakingScenario get _greetings => SpeakingScenario(
        id: 'greetings',
        titleEn: 'Meeting a classmate',
        titleUz: 'Sinfdosh bilan tanishuv',
        contextEn: "You're meeting a new classmate. Introduce yourself.",
        contextUz: 'Yangi sinfdosh bilan tanishyapsiz. O‘zingizni tanishtiring.',
        emoji: '👋',
        estimatedMinutes: 4,
        cefr: FalouCefr.a1,
        xpReward: 40,
        phrases: _greetingsPhrases,
        exercises: _buildExercises('greet', _greetingsPhrases),
      );

  // ─── Classroom (A1) ────────────────────────────────────────────────

  static final _classroomPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'class_repeat',
      l2Text: 'Can you repeat, please?',
      l1Text: 'Iltimos, qaytaring.',
      phonetic: 'kan yoo ree-peet, pleez?',
    ),
    const SpeakingPhrase(
      id: 'class_mean',
      l2Text: 'What does this word mean?',
      l1Text: 'Bu so‘z nimani anglatadi?',
      phonetic: 'wat duz this werd meen?',
    ),
    const SpeakingPhrase(
      id: 'class_spell',
      l2Text: 'How do you spell it?',
      l1Text: 'Uni qanday yoziladi?',
      phonetic: 'haw doo yoo spel it?',
    ),
    const SpeakingPhrase(
      id: 'class_slow',
      l2Text: 'Can you speak slowly?',
      l1Text: 'Sekinroq gapira olasizmi?',
      phonetic: 'kan yoo speek sloh-lee?',
    ),
  ];

  static SpeakingScenario get _classroom => SpeakingScenario(
        id: 'classroom',
        titleEn: 'Asking the teacher',
        titleUz: 'O‘qituvchidan so‘rash',
        contextEn:
            "You didn't catch what the teacher said. Ask politely for help.",
        contextUz: 'Siz o‘qituvchini eshitmadingiz. Iltimos bilan so‘rang.',
        emoji: '🎒',
        estimatedMinutes: 4,
        cefr: FalouCefr.a1,
        xpReward: 40,
        phrases: _classroomPhrases,
        exercises: _buildExercises('class', _classroomPhrases),
      );

  // ─── Café (A2) ─────────────────────────────────────────────────────

  static final _cafePhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'cafe_coffee',
      l2Text: 'A coffee, please.',
      l1Text: 'Bitta kofe, iltimos.',
      phonetic: 'uh kof-fee, pleez.',
    ),
    const SpeakingPhrase(
      id: 'cafe_how_much',
      l2Text: 'How much is it?',
      l1Text: 'Bu qancha turadi?',
      phonetic: 'haw much iz it?',
    ),
    const SpeakingPhrase(
      id: 'cafe_card',
      l2Text: 'Can I pay by card?',
      l1Text: 'Karta orqali to‘lasam bo‘ladimi?',
      phonetic: 'kan ay pay bay kard?',
    ),
    const SpeakingPhrase(
      id: 'cafe_thanks',
      l2Text: 'Thank you very much.',
      l1Text: 'Katta rahmat.',
      phonetic: 'thank yoo veh-ree much.',
    ),
  ];

  static SpeakingScenario get _cafe => SpeakingScenario(
        id: 'cafe',
        titleEn: 'Ordering at a café',
        titleUz: 'Kafeda buyurtma berish',
        contextEn: "You're at a café. Order a coffee and pay at the counter.",
        contextUz: 'Siz kafedasiz. Kofe buyurting va hisob-kitob qiling.',
        emoji: '☕',
        estimatedMinutes: 5,
        cefr: FalouCefr.a2,
        xpReward: 50,
        phrases: _cafePhrases,
        exercises: _buildExercises('cafe', _cafePhrases),
      );

  // ─── Asking for directions (A1) ────────────────────────────────────

  static final _directionsPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'dir_where',
      l2Text: 'Excuse me, where is the station?',
      l1Text: 'Kechirasiz, bekat qayerda?',
      phonetic: 'ek-skyooz mee, wair iz the stay-shun?',
    ),
    const SpeakingPhrase(
      id: 'dir_far',
      l2Text: 'Is it far from here?',
      l1Text: 'Bu yerdan uzoqmi?',
      phonetic: 'iz it faar from heer?',
    ),
    const SpeakingPhrase(
      id: 'dir_straight',
      l2Text: 'Go straight, please.',
      l1Text: 'To‘g‘riga yuring, iltimos.',
      phonetic: 'goh strayt, pleez.',
    ),
    const SpeakingPhrase(
      id: 'dir_left',
      l2Text: 'Turn left at the corner.',
      l1Text: 'Burilishda chapga buriling.',
      phonetic: 'turn left at the kor-ner.',
    ),
  ];

  static SpeakingScenario get _directions => SpeakingScenario(
        id: 'directions',
        titleEn: 'Asking for directions',
        titleUz: 'Yo‘l so‘rash',
        contextEn: "You're lost in a new city. Ask a local for help.",
        contextUz: 'Siz yangi shaharda adashib qoldingiz. Mahalliy aholidan yordam so‘rang.',
        emoji: '🗺️',
        estimatedMinutes: 4,
        cefr: FalouCefr.a1,
        xpReward: 40,
        phrases: _directionsPhrases,
        exercises: _buildExercises('dir', _directionsPhrases),
      );

  // ─── Weather small talk (A1) ───────────────────────────────────────

  static final _weatherPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'weath_beautiful',
      l2Text: "It's a beautiful day.",
      l1Text: 'Bugun ajoyib kun.',
      phonetic: 'its uh byoo-tee-ful day.',
    ),
    const SpeakingPhrase(
      id: 'weath_cold',
      l2Text: "It's very cold today.",
      l1Text: 'Bugun juda sovuq.',
      phonetic: 'its veh-ree kohld too-day.',
    ),
    const SpeakingPhrase(
      id: 'weath_rain',
      l2Text: 'Do you think it will rain?',
      l1Text: 'Sizningcha, yomg‘ir yog‘adimi?',
      phonetic: 'doo yoo think it wil rayn?',
    ),
    const SpeakingPhrase(
      id: 'weath_sunny',
      l2Text: 'I love sunny weather.',
      l1Text: 'Men quyoshli ob-havoni yoqtiraman.',
      phonetic: 'ay luhv suh-nee weh-ther.',
    ),
  ];

  static SpeakingScenario get _weather => SpeakingScenario(
        id: 'weather',
        titleEn: 'Small talk about weather',
        titleUz: 'Ob-havo haqida suhbat',
        contextEn: "You're waiting with a stranger. Break the silence.",
        contextUz: 'Notanish odam bilan kutyapsiz. Suhbatni boshlang.',
        emoji: '☀️',
        estimatedMinutes: 4,
        cefr: FalouCefr.a1,
        xpReward: 40,
        phrases: _weatherPhrases,
        exercises: _buildExercises('weath', _weatherPhrases),
      );

  // ─── Public transport (A1) ─────────────────────────────────────────

  static final _busPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'bus_center',
      l2Text: 'Does this bus go to the center?',
      l1Text: 'Bu avtobus markazga boradimi?',
      phonetic: 'duz this buhs goh too the sen-ter?',
    ),
    const SpeakingPhrase(
      id: 'bus_ticket',
      l2Text: 'How much is a ticket?',
      l1Text: 'Chipta qancha turadi?',
      phonetic: 'haw much iz uh tih-ket?',
    ),
    const SpeakingPhrase(
      id: 'bus_stop',
      l2Text: 'Where is the next stop?',
      l1Text: 'Keyingi bekat qayerda?',
      phonetic: 'wair iz the nekst stop?',
    ),
    const SpeakingPhrase(
      id: 'bus_off',
      l2Text: 'I need to get off here.',
      l1Text: 'Men bu yerda tushishim kerak.',
      phonetic: 'ay need too get off heer.',
    ),
  ];

  static SpeakingScenario get _bus => SpeakingScenario(
        id: 'bus',
        titleEn: 'Riding the bus',
        titleUz: 'Avtobusda yurish',
        contextEn: "You're taking a bus for the first time. Ask the driver.",
        contextUz: 'Birinchi marta avtobusga chiqyapsiz. Haydovchidan so‘rang.',
        emoji: '🚌',
        estimatedMinutes: 4,
        cefr: FalouCefr.a1,
        xpReward: 40,
        phrases: _busPhrases,
        exercises: _buildExercises('bus', _busPhrases),
      );

  // ─── Market / grocery (A1) ─────────────────────────────────────────

  static final _marketPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'mkt_cost',
      l2Text: 'How much does this cost?',
      l1Text: 'Bu qancha turadi?',
      phonetic: 'haw much duz this kost?',
    ),
    const SpeakingPhrase(
      id: 'mkt_kilos',
      l2Text: 'Can you give me two kilos?',
      l1Text: 'Ikki kilo bera olasizmi?',
      phonetic: 'kan yoo giv mee too kee-lohz?',
    ),
    const SpeakingPhrase(
      id: 'mkt_expensive',
      l2Text: "That's too expensive.",
      l1Text: 'Bu juda qimmat.',
      phonetic: 'thats too ek-spen-siv.',
    ),
    const SpeakingPhrase(
      id: 'mkt_take',
      l2Text: "I'll take it, thank you.",
      l1Text: 'Men olaman, rahmat.',
      phonetic: 'ayl tayk it, thank yoo.',
    ),
  ];

  static SpeakingScenario get _market => SpeakingScenario(
        id: 'market',
        titleEn: 'At the market',
        titleUz: 'Bozorda',
        contextEn: "You're buying fruit at a local market. Bargain politely.",
        contextUz: 'Bozordan meva olyapsiz. Iltimos bilan bahslashing.',
        emoji: '🛒',
        estimatedMinutes: 4,
        cefr: FalouCefr.a1,
        xpReward: 40,
        phrases: _marketPhrases,
        exercises: _buildExercises('mkt', _marketPhrases),
      );

  // ─── Airport check-in (A2) ─────────────────────────────────────────

  static final _airportPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'air_checkin',
      l2Text: "I'd like to check in, please.",
      l1Text: 'Iltimos, ro‘yxatdan o‘tmoqchiman.',
      phonetic: 'ayd layk too chek in, pleez.',
    ),
    const SpeakingPhrase(
      id: 'air_passport',
      l2Text: 'Here is my passport.',
      l1Text: 'Mana pasportim.',
      phonetic: 'heer iz may pas-port.',
    ),
    const SpeakingPhrase(
      id: 'air_suitcase',
      l2Text: 'I have one suitcase.',
      l1Text: 'Menda bitta jomadon bor.',
      phonetic: 'ay hav wuhn soot-kays.',
    ),
    const SpeakingPhrase(
      id: 'air_gate',
      l2Text: 'Where is the gate?',
      l1Text: 'Chiqish qayerda?',
      phonetic: 'wair iz the gayt?',
    ),
  ];

  static SpeakingScenario get _airport => SpeakingScenario(
        id: 'airport',
        titleEn: 'Checking in at the airport',
        titleUz: 'Aeroportda ro‘yxatdan o‘tish',
        contextEn: "You're flying out today. Handle the check-in desk.",
        contextUz: 'Bugun uchishingiz kerak. Ro‘yxat stolida gaplashing.',
        emoji: '🛫',
        estimatedMinutes: 5,
        cefr: FalouCefr.a2,
        xpReward: 50,
        phrases: _airportPhrases,
        exercises: _buildExercises('air', _airportPhrases),
      );

  // ─── Taxi ride (A2) ────────────────────────────────────────────────

  static final _taxiPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'taxi_airport',
      l2Text: 'Take me to the airport, please.',
      l1Text: 'Meni aeroportga olib boring, iltimos.',
      phonetic: 'tayk mee too the air-port, pleez.',
    ),
    const SpeakingPhrase(
      id: 'taxi_time',
      l2Text: 'How long will it take?',
      l1Text: 'Qancha vaqt ketadi?',
      phonetic: 'haw long wil it tayk?',
    ),
    const SpeakingPhrase(
      id: 'taxi_stop',
      l2Text: 'Please stop here.',
      l1Text: 'Iltimos, shu yerda to‘xtang.',
      phonetic: 'pleez stop heer.',
    ),
    const SpeakingPhrase(
      id: 'taxi_change',
      l2Text: 'Keep the change.',
      l1Text: 'Qaytimi sizga.',
      phonetic: 'keep the chaynj.',
    ),
  ];

  static SpeakingScenario get _taxi => SpeakingScenario(
        id: 'taxi',
        titleEn: 'Taking a taxi',
        titleUz: 'Taksida yurish',
        contextEn: "You've ordered a cab. Give the driver clear directions.",
        contextUz: 'Siz taksi chaqirdingiz. Haydovchiga aniq ko‘rsatma bering.',
        emoji: '🚕',
        estimatedMinutes: 4,
        cefr: FalouCefr.a2,
        xpReward: 50,
        phrases: _taxiPhrases,
        exercises: _buildExercises('taxi', _taxiPhrases),
      );

  // ─── Hotel reception (A2) ──────────────────────────────────────────

  static final _hotelPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'hotel_reservation',
      l2Text: 'I have a reservation.',
      l1Text: 'Menda bron bor.',
      phonetic: 'ay hav uh reh-zer-vay-shun.',
    ),
    const SpeakingPhrase(
      id: 'hotel_wifi',
      l2Text: 'Could I have the Wi-Fi password?',
      l1Text: 'Wi-Fi parolini bera olasizmi?',
      phonetic: 'kood ay hav the way-fay pass-word?',
    ),
    const SpeakingPhrase(
      id: 'hotel_breakfast',
      l2Text: 'What time is breakfast?',
      l1Text: 'Nonushta soat nechchida?',
      phonetic: 'wat taym iz brek-fust?',
    ),
    const SpeakingPhrase(
      id: 'hotel_late',
      l2Text: 'Can I check out later?',
      l1Text: 'Keyinroq chiqsam bo‘ladimi?',
      phonetic: 'kan ay chek owt lay-ter?',
    ),
  ];

  static SpeakingScenario get _hotel => SpeakingScenario(
        id: 'hotel',
        titleEn: 'At the hotel reception',
        titleUz: 'Mehmonxona qabulida',
        contextEn: 'You just arrived at your hotel. Check in smoothly.',
        contextUz: 'Siz endi mehmonxonaga keldingiz. Xonaga joylashib oling.',
        emoji: '🏨',
        estimatedMinutes: 5,
        cefr: FalouCefr.a2,
        xpReward: 50,
        phrases: _hotelPhrases,
        exercises: _buildExercises('hotel', _hotelPhrases),
      );

  // ─── Restaurant (A2) ───────────────────────────────────────────────

  static final _restaurantPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'rest_table',
      l2Text: 'A table for two, please.',
      l1Text: 'Ikki kishiga stol, iltimos.',
      phonetic: 'uh tay-bul for too, pleez.',
    ),
    const SpeakingPhrase(
      id: 'rest_menu',
      l2Text: 'Could we see the menu?',
      l1Text: 'Menyuni ko‘rsak bo‘ladimi?',
      phonetic: 'kood wee see the men-yoo?',
    ),
    const SpeakingPhrase(
      id: 'rest_chicken',
      l2Text: "I'd like the chicken, please.",
      l1Text: 'Iltimos, men tovuq olaman.',
      phonetic: 'ayd layk the chih-ken, pleez.',
    ),
    const SpeakingPhrase(
      id: 'rest_bill',
      l2Text: 'The bill, please.',
      l1Text: 'Iltimos, hisobni keltiring.',
      phonetic: 'the bil, pleez.',
    ),
  ];

  static SpeakingScenario get _restaurant => SpeakingScenario(
        id: 'restaurant',
        titleEn: 'Dinner at a restaurant',
        titleUz: 'Restoranda kechki ovqat',
        contextEn: "You're out for dinner. Order for two and pay at the end.",
        contextUz: 'Siz kechki ovqatga chiqdingiz. Ikki kishiga buyurtma bering.',
        emoji: '🍽️',
        estimatedMinutes: 5,
        cefr: FalouCefr.a2,
        xpReward: 50,
        phrases: _restaurantPhrases,
        exercises: _buildExercises('rest', _restaurantPhrases),
      );

  // ─── Clothes shopping (A2) ─────────────────────────────────────────

  static final _clothesPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'cloth_try',
      l2Text: 'Can I try this on?',
      l1Text: 'Buni kiyib ko‘rsam bo‘ladimi?',
      phonetic: 'kan ay tray this on?',
    ),
    const SpeakingPhrase(
      id: 'cloth_size',
      l2Text: 'Do you have a bigger size?',
      l1Text: 'Kattaroq o‘lcham bormi?',
      phonetic: 'doo yoo hav uh big-er sayz?',
    ),
    const SpeakingPhrase(
      id: 'cloth_fit',
      l2Text: 'It fits perfectly.',
      l1Text: 'Menga juda to‘g‘ri keladi.',
      phonetic: 'it fits per-fekt-lee.',
    ),
    const SpeakingPhrase(
      id: 'cloth_take',
      l2Text: "I'll take this one.",
      l1Text: 'Men shuni olaman.',
      phonetic: 'ayl tayk this wuhn.',
    ),
  ];

  static SpeakingScenario get _clothes => SpeakingScenario(
        id: 'clothes',
        titleEn: 'Shopping for clothes',
        titleUz: 'Kiyim sotib olish',
        contextEn: "You're trying on a shirt. Talk to the shop assistant.",
        contextUz: 'Siz ko‘ylak kiyib ko‘ryapsiz. Sotuvchi bilan gaplashing.',
        emoji: '👕',
        estimatedMinutes: 5,
        cefr: FalouCefr.a2,
        xpReward: 50,
        phrases: _clothesPhrases,
        exercises: _buildExercises('cloth', _clothesPhrases),
      );

  // ─── Pharmacy (A2) ─────────────────────────────────────────────────

  static final _pharmacyPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'pharm_headache',
      l2Text: 'I have a headache.',
      l1Text: 'Boshim og‘riyapti.',
      phonetic: 'ay hav uh hed-ayk.',
    ),
    const SpeakingPhrase(
      id: 'pharm_cough',
      l2Text: 'Do you have something for a cough?',
      l1Text: 'Yo‘talga biror narsa bormi?',
      phonetic: 'doo yoo hav sum-thing for uh kof?',
    ),
    const SpeakingPhrase(
      id: 'pharm_times',
      l2Text: 'How many times a day?',
      l1Text: 'Kuniga necha marta?',
      phonetic: 'haw meh-nee taymz uh day?',
    ),
    const SpeakingPhrase(
      id: 'pharm_rx',
      l2Text: 'Do I need a prescription?',
      l1Text: 'Retsept kerakmi?',
      phonetic: 'doo ay need uh prih-skrip-shun?',
    ),
  ];

  static SpeakingScenario get _pharmacy => SpeakingScenario(
        id: 'pharmacy',
        titleEn: 'At the pharmacy',
        titleUz: 'Dorixonada',
        contextEn: "You're not feeling well. Ask the pharmacist for help.",
        contextUz: 'Siz o‘zingizni yomon his qilyapsiz. Dorixonachidan yordam so‘rang.',
        emoji: '💊',
        estimatedMinutes: 4,
        cefr: FalouCefr.a2,
        xpReward: 50,
        phrases: _pharmacyPhrases,
        exercises: _buildExercises('pharm', _pharmacyPhrases),
      );

  // ─── Phone call basics (A2) ────────────────────────────────────────

  static final _phonePhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'phone_hello',
      l2Text: 'Hello, can I speak to Sarah?',
      l1Text: 'Salom, Sara bilan gaplashsam bo‘ladimi?',
      phonetic: 'he-loh, kan ay speek too seh-ruh?',
    ),
    const SpeakingPhrase(
      id: 'phone_who',
      l2Text: 'Who is calling, please?',
      l1Text: 'Iltimos, kim qo‘ng‘iroq qilyapti?',
      phonetic: 'hoo iz kaw-ling, pleez?',
    ),
    const SpeakingPhrase(
      id: 'phone_back',
      l2Text: 'Could you call back later?',
      l1Text: 'Keyinroq qo‘ng‘iroq qila olasizmi?',
      phonetic: 'kood yoo kawl bak lay-ter?',
    ),
    const SpeakingPhrase(
      id: 'phone_message',
      l2Text: "I'll leave a message.",
      l1Text: 'Men xabar qoldiraman.',
      phonetic: 'ayl leev uh meh-saj.',
    ),
  ];

  static SpeakingScenario get _phone => SpeakingScenario(
        id: 'phone',
        titleEn: 'Phone call basics',
        titleUz: 'Telefon qo‘ng‘irog‘i',
        contextEn: "You're calling a friend's workplace. Handle the receptionist.",
        contextUz: 'Do‘stingizning ish joyiga qo‘ng‘iroq qilyapsiz. Kotiba bilan gaplashing.',
        emoji: '📞',
        estimatedMinutes: 5,
        cefr: FalouCefr.a2,
        xpReward: 50,
        phrases: _phonePhrases,
        exercises: _buildExercises('phone', _phonePhrases),
      );

  // ─── Making plans with a friend (A2) ───────────────────────────────

  static final _plansPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'plans_free',
      l2Text: 'Are you free tonight?',
      l1Text: 'Bugun kechqurun bo‘shmisiz?',
      phonetic: 'aar yoo free too-nayt?',
    ),
    const SpeakingPhrase(
      id: 'plans_movie',
      l2Text: "Let's watch a movie.",
      l1Text: 'Keling, kino ko‘raylik.',
      phonetic: 'lets woch uh moo-vee.',
    ),
    const SpeakingPhrase(
      id: 'plans_meet',
      l2Text: 'What time should we meet?',
      l1Text: 'Soat nechchida uchrashamiz?',
      phonetic: 'wat taym shood wee meet?',
    ),
    const SpeakingPhrase(
      id: 'plans_seven',
      l2Text: 'See you at seven.',
      l1Text: 'Soat yettida ko‘rishamiz.',
      phonetic: 'see yoo at seh-vun.',
    ),
  ];

  static SpeakingScenario get _plans => SpeakingScenario(
        id: 'plans',
        titleEn: 'Making plans with a friend',
        titleUz: 'Do‘st bilan reja tuzish',
        contextEn: 'You want to hang out tonight. Text or call a friend.',
        contextUz: 'Bugun kechqurun do‘stingiz bilan vaqt o‘tkazmoqchisiz.',
        emoji: '🎬',
        estimatedMinutes: 4,
        cefr: FalouCefr.a2,
        xpReward: 50,
        phrases: _plansPhrases,
        exercises: _buildExercises('plans', _plansPhrases),
      );

  // ─── Doctor visit (B1) ─────────────────────────────────────────────

  static final _doctorPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'doc_unwell',
      l2Text: "I haven't been feeling well.",
      l1Text: 'O‘zimni yaxshi his qilmayapman.',
      phonetic: 'ay hav-ent bin fee-ling wel.',
    ),
    const SpeakingPhrase(
      id: 'doc_started',
      l2Text: 'It started a few days ago.',
      l1Text: 'Bu bir necha kun oldin boshlangan.',
      phonetic: 'it star-ted uh fyoo dayz uh-goh.',
    ),
    const SpeakingPhrase(
      id: 'doc_serious',
      l2Text: 'Is it serious, doctor?',
      l1Text: 'Bu jiddiymi, doktor?',
      phonetic: 'iz it seer-ee-us, dok-ter?',
    ),
    const SpeakingPhrase(
      id: 'doc_thanks',
      l2Text: 'Thank you for your help.',
      l1Text: 'Yordamingiz uchun rahmat.',
      phonetic: 'thank yoo for yor help.',
    ),
  ];

  static SpeakingScenario get _doctor => SpeakingScenario(
        id: 'doctor',
        titleEn: 'Visiting the doctor',
        titleUz: 'Shifokor huzurida',
        contextEn: "You're not well and need to describe your symptoms.",
        contextUz: 'Siz kasalsiz va shikoyatlaringizni tushuntirishingiz kerak.',
        emoji: '🩺',
        estimatedMinutes: 5,
        cefr: FalouCefr.b1,
        xpReward: 60,
        phrases: _doctorPhrases,
        exercises: _buildExercises('doc', _doctorPhrases),
      );

  // ─── Job interview basics (B1) ─────────────────────────────────────

  static final _interviewPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'intv_about',
      l2Text: 'Tell me about yourself, please.',
      l1Text: 'Iltimos, o‘zingiz haqingizda gapiring.',
      phonetic: 'tel mee uh-bowt yor-self, pleez.',
    ),
    const SpeakingPhrase(
      id: 'intv_why',
      l2Text: 'Why do you want this job?',
      l1Text: 'Nega bu ishni xohlaysiz?',
      phonetic: 'way doo yoo wont this job?',
    ),
    const SpeakingPhrase(
      id: 'intv_exp',
      l2Text: 'I have three years of experience.',
      l1Text: 'Menda uch yillik tajriba bor.',
      phonetic: 'ay hav three yirz uv ik-speer-ee-ens.',
    ),
    const SpeakingPhrase(
      id: 'intv_start',
      l2Text: 'When can you start?',
      l1Text: 'Qachon boshlay olasiz?',
      phonetic: 'wen kan yoo start?',
    ),
  ];

  static SpeakingScenario get _interview => SpeakingScenario(
        id: 'interview',
        titleEn: 'Job interview',
        titleUz: 'Ish suhbati',
        contextEn: "You're interviewing for your first English-speaking role.",
        contextUz: 'Siz ingliz tilidagi birinchi ish suhbatidasiz.',
        emoji: '💼',
        estimatedMinutes: 6,
        cefr: FalouCefr.b1,
        xpReward: 60,
        phrases: _interviewPhrases,
        exercises: _buildExercises('intv', _interviewPhrases),
      );

  // ─── Opening a bank account (B1) ───────────────────────────────────

  static final _bankPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'bank_open',
      l2Text: "I'd like to open an account.",
      l1Text: 'Men hisob ochmoqchiman.',
      phonetic: 'ayd layk too oh-pun uhn uh-kownt.',
    ),
    const SpeakingPhrase(
      id: 'bank_docs',
      l2Text: 'What documents do I need?',
      l1Text: 'Qanday hujjatlar kerak?',
      phonetic: 'wat dok-yoo-ments doo ay need?',
    ),
    const SpeakingPhrase(
      id: 'bank_fee',
      l2Text: 'Is there a monthly fee?',
      l1Text: 'Oylik to‘lov bormi?',
      phonetic: 'iz thair uh munth-lee fee?',
    ),
    const SpeakingPhrase(
      id: 'bank_explain',
      l2Text: 'Could you explain that again?',
      l1Text: 'Iltimos, yana tushuntira olasizmi?',
      phonetic: 'kood yoo ek-splayn that uh-gen?',
    ),
  ];

  static SpeakingScenario get _bank => SpeakingScenario(
        id: 'bank',
        titleEn: 'At the bank',
        titleUz: 'Bankda',
        contextEn: 'You want to open your first account abroad.',
        contextUz: 'Chet elda birinchi hisob ochmoqchisiz.',
        emoji: '🏦',
        estimatedMinutes: 5,
        cefr: FalouCefr.b1,
        xpReward: 60,
        phrases: _bankPhrases,
        exercises: _buildExercises('bank', _bankPhrases),
      );

  // ─── Post office (B1) ──────────────────────────────────────────────

  static final _postPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'post_send',
      l2Text: "I'd like to send this package.",
      l1Text: 'Men shu posilkani jo‘natmoqchiman.',
      phonetic: 'ayd layk too send this pak-aj.',
    ),
    const SpeakingPhrase(
      id: 'post_time',
      l2Text: 'How long will delivery take?',
      l1Text: 'Yetkazib berish qancha vaqt oladi?',
      phonetic: 'haw long wil dee-liv-er-ee tayk?',
    ),
    const SpeakingPhrase(
      id: 'post_track',
      l2Text: 'Can I track it online?',
      l1Text: 'Uni onlayn kuzatsam bo‘ladimi?',
      phonetic: 'kan ay trak it on-layn?',
    ),
    const SpeakingPhrase(
      id: 'post_envelope',
      l2Text: 'I need an envelope, please.',
      l1Text: 'Iltimos, menga konvert kerak.',
      phonetic: 'ay need uhn en-vuh-lohp, pleez.',
    ),
  ];

  static SpeakingScenario get _post => SpeakingScenario(
        id: 'post',
        titleEn: 'Sending a package',
        titleUz: 'Posilka jo‘natish',
        contextEn: "You're mailing a gift home. Handle the post office clerk.",
        contextUz: 'Uyga sovg‘a jo‘natyapsiz. Pochta xodimi bilan gaplashing.',
        emoji: '📦',
        estimatedMinutes: 5,
        cefr: FalouCefr.b1,
        xpReward: 60,
        phrases: _postPhrases,
        exercises: _buildExercises('post', _postPhrases),
      );

  // ─── Talking about hobbies (B1) ────────────────────────────────────

  static final _hobbiesPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'hob_free',
      l2Text: 'What do you do in your free time?',
      l1Text: 'Bo‘sh vaqtingizda nima qilasiz?',
      phonetic: 'wat doo yoo doo in yor free taym?',
    ),
    const SpeakingPhrase(
      id: 'hob_enjoy',
      l2Text: 'I enjoy reading and hiking.',
      l1Text: 'Men kitob o‘qish va sayohat qilishni yaxshi ko‘raman.',
      phonetic: 'ay en-joy ree-ding and hay-king.',
    ),
    const SpeakingPhrase(
      id: 'hob_into',
      l2Text: 'How did you get into that?',
      l1Text: 'Qanday qilib bunga qiziqib qoldingiz?',
      phonetic: 'haw did yoo get in-too that?',
    ),
    const SpeakingPhrase(
      id: 'hob_together',
      l2Text: 'We should do it together sometime.',
      l1Text: 'Qachondir birga qilaylik.',
      phonetic: 'wee shood doo it too-geh-ther sum-taym.',
    ),
  ];

  static SpeakingScenario get _hobbies => SpeakingScenario(
        id: 'hobbies',
        titleEn: 'Talking about hobbies',
        titleUz: 'Sevimli mashg‘ulotlar haqida',
        contextEn: "You're chatting with someone new. Share what you enjoy.",
        contextUz: 'Yangi tanishingiz bilan suhbatlashyapsiz. Qiziqishlaringizni ayting.',
        emoji: '🎨',
        estimatedMinutes: 5,
        cefr: FalouCefr.b1,
        xpReward: 60,
        phrases: _hobbiesPhrases,
        exercises: _buildExercises('hob', _hobbiesPhrases),
      );

  // ─── Describing your family (B1) ───────────────────────────────────

  static final _familyPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'fam_big',
      l2Text: 'I come from a big family.',
      l1Text: 'Men katta oiladanman.',
      phonetic: 'ay kum from uh big fa-mi-lee.',
    ),
    const SpeakingPhrase(
      id: 'fam_tashkent',
      l2Text: 'My parents live in Tashkent.',
      l1Text: 'Ota-onam Toshkentda yashaydi.',
      phonetic: 'may pair-ents liv in tash-kent.',
    ),
    const SpeakingPhrase(
      id: 'fam_brother',
      l2Text: 'I have an older brother.',
      l1Text: 'Mening katta akam bor.',
      phonetic: 'ay hav uhn ohl-der bruh-ther.',
    ),
    const SpeakingPhrase(
      id: 'fam_close',
      l2Text: "We're very close.",
      l1Text: 'Biz juda yaqinmiz.',
      phonetic: 'weer veh-ree klohs.',
    ),
  ];

  static SpeakingScenario get _family => SpeakingScenario(
        id: 'family',
        titleEn: 'Talking about your family',
        titleUz: 'Oila haqida gapirish',
        contextEn: 'Someone asks about your family. Paint a warm picture.',
        contextUz: 'Sizdan oila haqida so‘rashdi. Iliq suhbat qiling.',
        emoji: '👨‍👩‍👧',
        estimatedMinutes: 5,
        cefr: FalouCefr.b1,
        xpReward: 60,
        phrases: _familyPhrases,
        exercises: _buildExercises('fam', _familyPhrases),
      );

  // ─── Business meeting (B2) ─────────────────────────────────────────

  static final _meetingPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'mtg_start',
      l2Text: "Let's get started with the agenda.",
      l1Text: 'Kun tartibi bilan boshlaylik.',
      phonetic: 'lets get star-ted with the uh-jen-duh.',
    ),
    const SpeakingPhrase(
      id: 'mtg_circle',
      l2Text: 'Could we circle back to that?',
      l1Text: 'Bunga yana qaytsak bo‘ladimi?',
      phonetic: 'kood wee sir-kul bak too that?',
    ),
    const SpeakingPhrase(
      id: 'mtg_add',
      l2Text: "I'd like to add one thing.",
      l1Text: 'Men bitta narsa qo‘shmoqchiman.',
      phonetic: 'ayd layk too ad wuhn thing.',
    ),
    const SpeakingPhrase(
      id: 'mtg_followup',
      l2Text: "Let's follow up by email.",
      l1Text: 'Elektron pochta orqali davom ettiraylik.',
      phonetic: 'lets fol-oh up bay ee-mayl.',
    ),
  ];

  static SpeakingScenario get _meeting => SpeakingScenario(
        id: 'meeting',
        titleEn: 'Business meeting',
        titleUz: 'Ish yig‘ilishi',
        contextEn: "You're leading a quick status meeting in English.",
        contextUz: 'Siz ingliz tilida qisqa yig‘ilish olib borayapsiz.',
        emoji: '📊',
        estimatedMinutes: 6,
        cefr: FalouCefr.b2,
        xpReward: 70,
        phrases: _meetingPhrases,
        exercises: _buildExercises('mtg', _meetingPhrases),
      );

  // ─── Making a complaint (B2) ───────────────────────────────────────

  static final _complaintPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'cmpl_make',
      l2Text: "I'd like to make a complaint.",
      l1Text: 'Men shikoyat qilmoqchiman.',
      phonetic: 'ayd layk too mayk uh kum-playnt.',
    ),
    const SpeakingPhrase(
      id: 'cmpl_order',
      l2Text: "This isn't what I ordered.",
      l1Text: 'Bu men buyurtma bergan narsa emas.',
      phonetic: 'this iz-ent wat ay or-derd.',
    ),
    const SpeakingPhrase(
      id: 'cmpl_manager',
      l2Text: 'Could I speak to the manager?',
      l1Text: 'Menejer bilan gaplashsam bo‘ladimi?',
      phonetic: 'kood ay speek too the man-a-jer?',
    ),
    const SpeakingPhrase(
      id: 'cmpl_refund',
      l2Text: "I'd appreciate a refund.",
      l1Text: 'Pulni qaytarib olsam minnatdor bo‘laman.',
      phonetic: 'ayd uh-pree-shee-ayt uh ree-fund.',
    ),
  ];

  static SpeakingScenario get _complaint => SpeakingScenario(
        id: 'complaint',
        titleEn: 'Making a complaint',
        titleUz: 'Shikoyat qilish',
        contextEn: 'Your order is wrong. Complain firmly but politely.',
        contextUz: 'Buyurtmangiz noto‘g‘ri kelgan. Jahl chiqarmasdan e‘tiroz bildiring.',
        emoji: '😤',
        estimatedMinutes: 5,
        cefr: FalouCefr.b2,
        xpReward: 70,
        phrases: _complaintPhrases,
        exercises: _buildExercises('cmpl', _complaintPhrases),
      );

  // ─── Negotiating (B2) ──────────────────────────────────────────────

  static final _negotiatePhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'neg_room',
      l2Text: 'Is there any room on the price?',
      l1Text: 'Narxni pastga tushirsa bo‘ladimi?',
      phonetic: 'iz thair eh-nee room on the prays?',
    ),
    const SpeakingPhrase(
      id: 'neg_lower',
      l2Text: 'I was hoping for something lower.',
      l1Text: 'Men pastroq narsaga umid qilgandim.',
      phonetic: 'ay wuz hoh-ping for sum-thing loh-er.',
    ),
    const SpeakingPhrase(
      id: 'neg_halfway',
      l2Text: 'Would you meet me halfway?',
      l1Text: 'Yarmi yo‘lda uchrasholmaymizmi?',
      phonetic: 'wood yoo meet mee haf-way?',
    ),
    const SpeakingPhrase(
      id: 'neg_works',
      l2Text: 'That works for me.',
      l1Text: 'Men uchun maqul.',
      phonetic: 'that werks for mee.',
    ),
  ];

  static SpeakingScenario get _negotiate => SpeakingScenario(
        id: 'negotiate',
        titleEn: 'Negotiating a deal',
        titleUz: 'Narx bo‘yicha kelishuv',
        contextEn: "You're closing a deal. Haggle without losing the room.",
        contextUz: 'Siz kelishuv tuzayapsiz. Hurmatni yo‘qotmasdan narxni kelishing.',
        emoji: '🤝',
        estimatedMinutes: 6,
        cefr: FalouCefr.b2,
        xpReward: 70,
        phrases: _negotiatePhrases,
        exercises: _buildExercises('neg', _negotiatePhrases),
      );

  // ─── Discussing current events (C1) ────────────────────────────────

  static final _newsPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'news_catch',
      l2Text: 'Did you catch the news this morning?',
      l1Text: 'Bugun ertalabki yangiliklarni ko‘rdingizmi?',
      phonetic: 'did yoo kach the nyooz this mor-ning?',
    ),
    const SpeakingPhrase(
      id: 'news_complicated',
      l2Text: "It's a complicated situation.",
      l1Text: 'Bu murakkab vaziyat.',
      phonetic: 'its uh kom-pluh-kay-ted si-choo-ay-shun.',
    ),
    const SpeakingPhrase(
      id: 'news_unsure',
      l2Text: "I'm not sure what to make of it.",
      l1Text: 'Uni qanday tushunishni bilmayman.',
      phonetic: 'aym not shoor wat too mayk uv it.',
    ),
    const SpeakingPhrase(
      id: 'news_source',
      l2Text: 'Where are you getting your information?',
      l1Text: 'Ma‘lumotlarni qayerdan olyapsiz?',
      phonetic: 'wair aar yoo ge-ting yor in-for-may-shun?',
    ),
  ];

  static SpeakingScenario get _news => SpeakingScenario(
        id: 'news',
        titleEn: 'Discussing current events',
        titleUz: 'Yangiliklar haqida suhbat',
        contextEn: "A colleague brings up today's headlines. Weigh in thoughtfully.",
        contextUz: 'Hamkasbingiz yangiliklardan gap ochdi. Fikringizni bildiring.',
        emoji: '📰',
        estimatedMinutes: 7,
        cefr: FalouCefr.c1,
        xpReward: 80,
        phrases: _newsPhrases,
        exercises: _buildExercises('news', _newsPhrases),
      );

  // ─── Exercise arc builder ──────────────────────────────────────────

  /// For each phrase: listen → listen_repeat → word_breakdown,
  /// followed by a recall exercise per phrase in original order.
  /// Keeping recall order stable (not shuffled) for v1 — shuffle
  /// can be introduced once content lands and variety matters more.
  static List<SpeakingExercise> _buildExercises(
    String prefix,
    List<SpeakingPhrase> phrases,
  ) {
    final out = <SpeakingExercise>[];
    for (var i = 0; i < phrases.length; i++) {
      final p = phrases[i];
      out.add(ListenExercise(id: '${prefix}_listen_$i', phrase: p));
      out.add(ListenRepeatExercise(id: '${prefix}_lr_$i', phrase: p));
      out.add(WordBreakdownExercise(id: '${prefix}_wb_$i', phrase: p));
    }
    for (var i = 0; i < phrases.length; i++) {
      out.add(RecallExercise(
        id: '${prefix}_recall_$i',
        phrase: phrases[i],
      ));
    }
    return out;
  }
}
