-- ============================================================================
-- VocabGame — Seed Content
-- Paste this into Supabase → SQL Editor → New Query → Run
-- Creates 4 collections with 3 units each (120 words total)
-- ============================================================================

-- ─── Collection 1: Daily Life (ESL, A1) ───────────────────────────────

INSERT INTO collections (id, title, short_title, description, category, difficulty, cover_emoji, cover_color, total_units, is_published)
VALUES ('c0000001-0001-4000-8000-000000000001', 'Everyday English', 'Daily Life', 'Essential words for daily conversations and routines', 'esl', 'A1', '🏠', '#3B82F6', 3, true);

-- Unit 1: Around the House
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000001-0001-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'Around the House', 1, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000001-0001-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'kitchen', 'oshxona', 'My mother is cooking in the kitchen.', 'noun', 'A1', 1),
('a0000001-0001-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'bedroom', 'yotoqxona', 'I sleep in my bedroom every night.', 'noun', 'A1', 2),
('a0000001-0001-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'window', 'deraza', 'Please open the window, it is hot.', 'noun', 'A1', 3),
('a0000001-0001-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'door', 'eshik', 'Someone is knocking on the door.', 'noun', 'A1', 4),
('a0000001-0001-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'furniture', 'mebel', 'We bought new furniture for the living room.', 'noun', 'A1', 5),
('a0000001-0001-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'clean', 'tozalamoq', 'I clean my room every Saturday morning.', 'verb', 'A1', 6),
('a0000001-0001-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'comfortable', 'qulay', 'This sofa is very comfortable.', 'adjective', 'A1', 7),
('a0000001-0001-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'quiet', 'tinch, sokin', 'Our neighborhood is quiet at night.', 'adjective', 'A1', 8),
('a0000001-0001-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'upstairs', 'yuqori qavatda', 'My sister lives upstairs in the second floor room.', 'adverb', 'A1', 9),
('a0000001-0001-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'neighbor', 'qo''shni', 'Our neighbor has a beautiful garden.', 'noun', 'A1', 10);

-- Unit 2: Food & Meals
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000001-0002-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'Food & Meals', 2, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000001-0002-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'breakfast', 'nonushta', 'I eat breakfast at seven every morning.', 'noun', 'A1', 1),
('a0000001-0002-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'lunch', 'tushlik', 'We have lunch at school at noon.', 'noun', 'A1', 2),
('a0000001-0002-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'dinner', 'kechki ovqat', 'The whole family eats dinner together.', 'noun', 'A1', 3),
('a0000001-0002-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'delicious', 'mazali', 'This soup is really delicious.', 'adjective', 'A1', 4),
('a0000001-0002-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'hungry', 'och', 'I am very hungry after playing football.', 'adjective', 'A1', 5),
('a0000001-0002-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'thirsty', 'chanqagan', 'Can I have some water? I am thirsty.', 'adjective', 'A1', 6),
('a0000001-0002-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'recipe', 'retsept', 'My grandmother has a secret recipe for plov.', 'noun', 'A1', 7),
('a0000001-0002-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'prepare', 'tayyorlamoq', 'She prepares meals for six people daily.', 'verb', 'A1', 8),
('a0000001-0002-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'taste', 'tatib ko''rmoq', 'Would you like to taste this cake?', 'verb', 'A1', 9),
('a0000001-0002-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'fresh', 'yangi, toza', 'The bread is fresh from the bakery.', 'adjective', 'A1', 10);

-- Unit 3: Family & Relationships
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000001-0003-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'Family & Relationships', 3, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000001-0003-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'parents', 'ota-ona', 'My parents work very hard to support us.', 'noun', 'A1', 1),
('a0000001-0003-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'sibling', 'aka-uka, opa-singil', 'I have three siblings: two brothers and one sister.', 'noun', 'A1', 2),
('a0000001-0003-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'cousin', 'amakivachcha', 'My cousin lives in Samarkand.', 'noun', 'A1', 3),
('a0000001-0003-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'grandparents', 'buvi-bobilar', 'I visit my grandparents every weekend.', 'noun', 'A1', 4),
('a0000001-0003-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'married', 'turmush qurgan', 'My older brother got married last summer.', 'adjective', 'A1', 5),
('a0000001-0003-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'friendship', 'do''stlik', 'True friendship lasts forever.', 'noun', 'A1', 6),
('a0000001-0003-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'respect', 'hurmat qilmoq', 'We should always respect our elders.', 'verb', 'A1', 7),
('a0000001-0003-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'celebrate', 'nishonlamoq', 'We celebrate Navruz with the whole family.', 'verb', 'A1', 8),
('a0000001-0003-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'together', 'birga', 'We always study together in the library.', 'adverb', 'A1', 9),
('a0000001-0003-4000-8000-000000000001', 'c0000001-0001-4000-8000-000000000001', 'generation', 'avlod', 'Each generation has its own challenges.', 'noun', 'A1', 10);

-- ─── Collection 2: Animal Farm (Fiction, B1) ──────────────────────────

INSERT INTO collections (id, title, short_title, description, category, difficulty, cover_emoji, cover_color, total_units, is_published)
VALUES ('c0000002-0001-4000-8000-000000000001', 'Animal Farm by George Orwell', 'Animal Farm', 'Vocabulary from the classic political allegory', 'fiction', 'B1', '🐷', '#16A34A', 3, true);

-- Unit 1: The Revolution Begins
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000002-0001-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'The Revolution Begins', 1, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000002-0001-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'rebellion', 'qo''zg''olon', 'The animals planned a rebellion against the farmer.', 'noun', 'B1', 1),
('a0000002-0001-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'tyrant', 'zolim', 'The farmer was a cruel tyrant who starved the animals.', 'noun', 'B1', 2),
('a0000002-0001-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'overthrow', 'ag''darmoq', 'The animals decided to overthrow the human masters.', 'verb', 'B1', 3),
('a0000002-0001-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'comrade', 'o''rtoq', 'All animals are comrades in the struggle for freedom.', 'noun', 'B1', 4),
('a0000002-0001-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'equality', 'tenglik', 'They believed in equality for all animals.', 'noun', 'B1', 5),
('a0000002-0001-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'harvest', 'hosil yig''moq', 'The animals worked together to harvest the wheat.', 'verb', 'B1', 6),
('a0000002-0001-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'courage', 'jasorat', 'It took great courage to stand up against injustice.', 'noun', 'B1', 7),
('a0000002-0001-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'inspire', 'ilhomlantirmoq', 'Old Major inspired the animals with his speech.', 'verb', 'B1', 8),
('a0000002-0001-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'loyal', 'sodiq', 'Boxer was the most loyal and hardworking horse.', 'adjective', 'B1', 9),
('a0000002-0001-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'anthem', 'madhiya', 'They sang the anthem of the revolution every morning.', 'noun', 'B1', 10);

-- Unit 2: Power & Corruption
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000002-0002-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'Power & Corruption', 2, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000002-0002-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'propaganda', 'tashviqot', 'Squealer spread propaganda to control the animals.', 'noun', 'B1', 1),
('a0000002-0002-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'manipulate', 'boshqarmoq', 'The pigs learned to manipulate the truth.', 'verb', 'B1', 2),
('a0000002-0002-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'privilege', 'imtiyoz', 'The pigs gave themselves special privileges.', 'noun', 'B1', 3),
('a0000002-0002-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'deceive', 'aldamoq', 'Napoleon tried to deceive the other animals.', 'verb', 'B1', 4),
('a0000002-0002-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'obedient', 'itoatkor', 'The sheep were the most obedient followers.', 'adjective', 'B1', 5),
('a0000002-0002-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'sacrifice', 'qurbonlik', 'Boxer made the greatest sacrifice for the farm.', 'noun', 'B1', 6),
('a0000002-0002-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'betray', 'xiyonat qilmoq', 'The leaders chose to betray their own principles.', 'verb', 'B1', 7),
('a0000002-0002-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'suspicious', 'shubhali', 'Some animals became suspicious of Napoleon.', 'adjective', 'B1', 8),
('a0000002-0002-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'authority', 'hokimiyat', 'Napoleon seized all authority on the farm.', 'noun', 'B1', 9),
('a0000002-0002-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'gradually', 'asta-sekin', 'The commandments were gradually changed over time.', 'adverb', 'B1', 10);

-- Unit 3: Society & Rules
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000002-0003-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'Society & Rules', 3, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000002-0003-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'commandment', 'qoida, amr', 'The seven commandments were painted on the barn wall.', 'noun', 'B1', 1),
('a0000002-0003-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'abolish', 'bekor qilmoq', 'They voted to abolish the old traditions.', 'verb', 'B1', 2),
('a0000002-0003-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'constitution', 'konstitutsiya', 'Every fair society needs a strong constitution.', 'noun', 'B1', 3),
('a0000002-0003-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'debate', 'munozara', 'The animals held a debate about the windmill plan.', 'noun', 'B1', 4),
('a0000002-0003-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'exile', 'surgun qilmoq', 'Snowball was sent into exile after the power struggle.', 'verb', 'B1', 5),
('a0000002-0003-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'justify', 'oqlamoq', 'Squealer could justify any decision the pigs made.', 'verb', 'B1', 6),
('a0000002-0003-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'freedom', 'erkinlik', 'The dream of freedom slowly faded away.', 'noun', 'B1', 7),
('a0000002-0003-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'oppression', 'zulm', 'The animals escaped one form of oppression only to face another.', 'noun', 'B1', 8),
('a0000002-0003-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'inevitable', 'muqarrar', 'The collapse of their ideals felt inevitable.', 'adjective', 'B1', 9),
('a0000002-0003-4000-8000-000000000001', 'c0000002-0001-4000-8000-000000000001', 'resemble', 'o''xshamoq', 'In the end, the pigs began to resemble the humans.', 'verb', 'B1', 10);

-- ─── Collection 3: Travel & Tourism (ESL, A2) ────────────────────────

INSERT INTO collections (id, title, short_title, description, category, difficulty, cover_emoji, cover_color, total_units, is_published)
VALUES ('c0000003-0001-4000-8000-000000000001', 'Travel & Tourism', 'Travel', 'Essential vocabulary for traveling abroad', 'esl', 'A2', '✈️', '#EF4444', 3, true);

-- Unit 1: At the Airport
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000003-0001-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'At the Airport', 1, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000003-0001-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'departure', 'jo''nab ketish', 'The departure time is eight in the morning.', 'noun', 'A2', 1),
('a0000003-0001-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'arrival', 'kelish', 'Check the arrival board for your flight.', 'noun', 'A2', 2),
('a0000003-0001-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'passport', 'pasport', 'Do not forget to bring your passport to the airport.', 'noun', 'A2', 3),
('a0000003-0001-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'luggage', 'yuk, bagaj', 'My luggage is too heavy for the carry-on limit.', 'noun', 'A2', 4),
('a0000003-0001-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'boarding pass', 'chiptani ko''rsatish', 'Please show your boarding pass at the gate.', 'phrase', 'A2', 5),
('a0000003-0001-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'delay', 'kechikish', 'There is a two-hour delay because of the weather.', 'noun', 'A2', 6),
('a0000003-0001-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'gate', 'darvoza, geyit', 'Go to gate twelve for your flight to Istanbul.', 'noun', 'A2', 7),
('a0000003-0001-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'announce', 'e''lon qilmoq', 'They will announce the boarding time soon.', 'verb', 'A2', 8),
('a0000003-0001-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'fasten', 'bog''lamoq', 'Please fasten your seatbelt before takeoff.', 'verb', 'A2', 9),
('a0000003-0001-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'customs', 'bojxona', 'You must go through customs when you arrive.', 'noun', 'A2', 10);

-- Unit 2: At the Hotel
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000003-0002-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'At the Hotel', 2, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000003-0002-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'reservation', 'bron qilish', 'I have a reservation under the name Karimov.', 'noun', 'A2', 1),
('a0000003-0002-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'check in', 'ro''yxatdan o''tmoq', 'We need to check in before three o''clock.', 'phrase', 'A2', 2),
('a0000003-0002-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'receptionist', 'qabul xodimi', 'The receptionist gave us the room key.', 'noun', 'A2', 3),
('a0000003-0002-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'available', 'bo''sh, mavjud', 'Are there any rooms available for tonight?', 'adjective', 'A2', 4),
('a0000003-0002-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'complain', 'shikoyat qilmoq', 'We had to complain about the noisy room.', 'verb', 'A2', 5),
('a0000003-0002-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'amenities', 'qulayliklar', 'The hotel has good amenities like a pool and gym.', 'noun', 'A2', 6),
('a0000003-0002-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'checkout', 'chiqish', 'Checkout time is at eleven in the morning.', 'noun', 'A2', 7),
('a0000003-0002-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'recommend', 'tavsiya qilmoq', 'Can you recommend a good restaurant nearby?', 'verb', 'A2', 8),
('a0000003-0002-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'view', 'manzara', 'Our room has a beautiful view of the sea.', 'noun', 'A2', 9),
('a0000003-0002-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'tip', 'choy puli', 'It is polite to leave a tip for good service.', 'noun', 'A2', 10);

-- Unit 3: Getting Around
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000003-0003-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'Getting Around', 3, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000003-0003-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'destination', 'manzil', 'What is your final destination?', 'noun', 'A2', 1),
('a0000003-0003-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'direction', 'yo''nalish', 'Can you give me directions to the museum?', 'noun', 'A2', 2),
('a0000003-0003-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'pedestrian', 'piyoda', 'This street is only for pedestrians.', 'noun', 'A2', 3),
('a0000003-0003-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'intersection', 'choraha', 'Turn left at the next intersection.', 'noun', 'A2', 4),
('a0000003-0003-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'landmark', 'diqqatga sazovor joy', 'The Registan is the most famous landmark in Samarkand.', 'noun', 'A2', 5),
('a0000003-0003-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'straight', 'to''g''ri', 'Go straight for two blocks, then turn right.', 'adverb', 'A2', 6),
('a0000003-0003-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'convenient', 'qulay', 'The metro is the most convenient way to travel.', 'adjective', 'A2', 7),
('a0000003-0003-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'currency', 'valyuta', 'You can exchange currency at the airport.', 'noun', 'A2', 8),
('a0000003-0003-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'souvenir', 'esdalik sovg''a', 'I bought a souvenir for my family back home.', 'noun', 'A2', 9),
('a0000003-0003-4000-8000-000000000001', 'c0000003-0001-4000-8000-000000000001', 'explore', 'o''rganmoq, kashf qilmoq', 'We spent the day exploring the old city.', 'verb', 'A2', 10);

-- ─── Collection 4: Academic Essentials (Academic, B1) ─────────────────

INSERT INTO collections (id, title, short_title, description, category, difficulty, cover_emoji, cover_color, total_units, is_published)
VALUES ('c0000004-0001-4000-8000-000000000001', 'Academic Essentials', 'Academic', 'Key vocabulary for school and university success', 'academic', 'B1', '🎓', '#8B5CF6', 3, true);

-- Unit 1: Research & Study
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000004-0001-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'Research & Study', 1, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000004-0001-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'research', 'tadqiqot', 'The students conducted research on climate change.', 'noun', 'B1', 1),
('a0000004-0001-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'hypothesis', 'gipoteza', 'A good experiment starts with a clear hypothesis.', 'noun', 'B1', 2),
('a0000004-0001-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'analyze', 'tahlil qilmoq', 'We need to analyze the data before drawing conclusions.', 'verb', 'B1', 3),
('a0000004-0001-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'conclude', 'xulosa qilmoq', 'The scientists concluded that the theory was correct.', 'verb', 'B1', 4),
('a0000004-0001-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'evidence', 'dalil', 'There is strong evidence to support this claim.', 'noun', 'B1', 5),
('a0000004-0001-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'significant', 'muhim, sezilarli', 'The results showed a significant improvement.', 'adjective', 'B1', 6),
('a0000004-0001-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'method', 'usul', 'Which method did you use for the experiment?', 'noun', 'B1', 7),
('a0000004-0001-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'theory', 'nazariya', 'Einstein developed the theory of relativity.', 'noun', 'B1', 8),
('a0000004-0001-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'evaluate', 'baholamoq', 'Teachers evaluate student progress every semester.', 'verb', 'B1', 9),
('a0000004-0001-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'relevant', 'tegishli', 'Please include only relevant information in your essay.', 'adjective', 'B1', 10);

-- Unit 2: Writing & Communication
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000004-0002-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'Writing & Communication', 2, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000004-0002-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'paragraph', 'paragraf, xatboshi', 'Each paragraph should have one main idea.', 'noun', 'B1', 1),
('a0000004-0002-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'argue', 'bahslashmoq', 'The author argues that education changes lives.', 'verb', 'B1', 2),
('a0000004-0002-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'summarize', 'xulosa qilmoq', 'Please summarize the article in three sentences.', 'verb', 'B1', 3),
('a0000004-0002-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'persuade', 'ishontirmoq', 'A good essay should persuade the reader.', 'verb', 'B1', 4),
('a0000004-0002-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'reference', 'havola, manba', 'You must include a reference list at the end.', 'noun', 'B1', 5),
('a0000004-0002-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'coherent', 'izchil, mantiqiy', 'Your essay must be clear and coherent.', 'adjective', 'B1', 6),
('a0000004-0002-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'draft', 'qoralama', 'Always write a first draft before editing.', 'noun', 'B1', 7),
('a0000004-0002-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'revise', 'qayta ko''rib chiqmoq', 'You should revise your work before submitting.', 'verb', 'B1', 8),
('a0000004-0002-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'clarify', 'aniqlashtirmoq', 'Could you please clarify your question?', 'verb', 'B1', 9),
('a0000004-0002-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'accurate', 'aniq, to''g''ri', 'Make sure your quotes are accurate.', 'adjective', 'B1', 10);

-- Unit 3: Critical Thinking
INSERT INTO units (id, collection_id, title, unit_number, word_count)
VALUES ('a0000004-0003-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'Critical Thinking', 3, 10);

INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES
('a0000004-0003-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'perspective', 'nuqtai nazar', 'Try to see the problem from a different perspective.', 'noun', 'B1', 1),
('a0000004-0003-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'assumption', 'taxmin', 'Do not make assumptions without checking the facts.', 'noun', 'B1', 2),
('a0000004-0003-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'bias', 'tarafkashlik', 'A good journalist should avoid bias in their reports.', 'noun', 'B1', 3),
('a0000004-0003-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'contradict', 'qarama-qarshi bo''lmoq', 'The new data seems to contradict the old results.', 'verb', 'B1', 4),
('a0000004-0003-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'distinguish', 'farqlamoq', 'Learn to distinguish facts from opinions.', 'verb', 'B1', 5),
('a0000004-0003-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'implication', 'oqibat', 'Think about the implications of your decision.', 'noun', 'B1', 6),
('a0000004-0003-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'interpret', 'izohlash, sharhlash', 'Students interpret the poem in different ways.', 'verb', 'B1', 7),
('a0000004-0003-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'logical', 'mantiqiy', 'Your argument must follow a logical structure.', 'adjective', 'B1', 8),
('a0000004-0003-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'objective', 'xolis', 'A scientist must remain objective during research.', 'adjective', 'B1', 9),
('a0000004-0003-4000-8000-000000000001', 'c0000004-0001-4000-8000-000000000001', 'valid', 'to''g''ri, asosli', 'Is this a valid reason to miss the exam?', 'adjective', 'B1', 10);

-- ─── Update collection total_units counts ──────────────────────────────
UPDATE collections SET total_units = (SELECT COUNT(*) FROM units WHERE collection_id = collections.id);
