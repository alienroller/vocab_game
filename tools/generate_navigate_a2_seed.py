"""
Parse Navigate_A2_Vocabulary_Uzbek.md and generate a Supabase SQL seed file.
"""
import re
import os

MD_PATH = os.path.join(os.path.dirname(__file__), '..', 'Navigate_A2_Vocabulary_Uzbek.md')
OUT_PATH = os.path.join(os.path.dirname(__file__), 'seed_navigate_a2.sql')

COLLECTION_ID = 'c0000005-0001-4000-8000-000000000001'

# Map abbreviations from the markdown to DB word_type values
POS_MAP = {
    'adj': 'adjective',
    'adv': 'adverb',
    'conj': 'phrase',      # no 'conjunction' in DB enum, map to phrase
    'n': 'noun',
    'n pl': 'noun',
    'pl': 'noun',
    'phr': 'phrase',
    'phr v': 'phrase',
    'prep': 'phrase',       # prepositions mapped to phrase
    'pron': 'noun',         # pronouns mapped to noun
    'v': 'verb',
}

def escape_sql(s):
    """Escape single quotes for SQL."""
    return s.replace("'", "''")

def parse_markdown(path):
    """Parse the markdown file and return a list of units, each with words."""
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    units = []
    # Split by unit headers
    unit_blocks = re.split(r'##\s+A2 Wordlist Unit (\d+)', content)
    
    # unit_blocks: ['header stuff', '1', 'unit1 content', '2', 'unit2 content', ...]
    i = 1
    while i < len(unit_blocks):
        unit_num = int(unit_blocks[i])
        unit_content = unit_blocks[i + 1]
        
        words = []
        # Parse table rows (skip header and separator)
        lines = unit_content.strip().split('\n')
        for line in lines:
            line = line.strip()
            if not line.startswith('|'):
                continue
            # Skip header rows
            if 'Word' in line and 'Part of Speech' in line:
                continue
            if re.match(r'^\|[-\s|]+\|$', line):
                continue
            
            # Parse table row
            cells = [c.strip() for c in line.split('|')]
            # Remove empty first/last from split
            cells = [c for c in cells if c != '']
            
            if len(cells) >= 4:
                word = cells[0].strip()
                pos_raw = cells[1].strip()
                pronunciation = cells[2].strip()
                translation = cells[3].strip()
                
                # Map POS
                pos = POS_MAP.get(pos_raw, 'phrase')
                
                words.append({
                    'word': word,
                    'pos': pos,
                    'pronunciation': pronunciation,
                    'translation': translation,
                })
        
        units.append({
            'unit_number': unit_num,
            'title': f'Unit {unit_num}',
            'words': words,
        })
        i += 2
    
    return units

def generate_sql(units, out_path):
    """Generate the SQL seed file."""
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write('-- ============================================================================\n')
        f.write('-- VocabGame — Navigate A2 Seed Content\n')
        f.write('-- Paste this into Supabase → SQL Editor → New Query → Run\n')
        f.write(f'-- Creates 1 collection with {len(units)} units ({sum(len(u["words"]) for u in units)} words total)\n')
        f.write('-- ============================================================================\n\n')

        # Collection
        f.write('-- ─── Collection: Navigate A2 ──────────────────────────────────────────\n\n')
        f.write("INSERT INTO collections (id, title, short_title, description, category, difficulty, cover_emoji, cover_color, total_units, is_published)\n")
        f.write(f"VALUES ('{COLLECTION_ID}', 'Navigate A2', 'Navigate A2', 'A2-level vocabulary from the Navigate coursebook with Uzbek translations', 'esl', 'A2', '📘', '#0EA5E9', {len(units)}, true);\n\n")

        # Units and words
        for unit in units:
            un = unit['unit_number']
            unit_id = f'a0000005-{un:04d}-4000-8000-000000000001'
            word_count = len(unit['words'])
            
            f.write(f'-- Unit {un} ({word_count} words)\n')
            f.write(f"INSERT INTO units (id, collection_id, title, unit_number, word_count)\n")
            f.write(f"VALUES ('{unit_id}', '{COLLECTION_ID}', '{escape_sql(unit['title'])}', {un}, {word_count});\n\n")
            
            f.write(f"INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES\n")
            
            word_lines = []
            for idx, w in enumerate(unit['words'], 1):
                word_esc = escape_sql(w['word'])
                trans_esc = escape_sql(w['translation'])
                # Generate a simple example sentence
                example = generate_example(w['word'], w['translation'], w['pos'])
                example_esc = escape_sql(example)
                pos = w['pos']
                
                word_lines.append(
                    f"('{unit_id}', '{COLLECTION_ID}', '{word_esc}', '{trans_esc}', '{example_esc}', '{pos}', 'A2', {idx})"
                )
            
            f.write(',\n'.join(word_lines))
            f.write(';\n\n')

        # Update counts
        f.write('-- ─── Update collection total_units counts ──────────────────────────────\n')
        f.write(f"UPDATE collections SET total_units = (SELECT COUNT(*) FROM units WHERE collection_id = '{COLLECTION_ID}') WHERE id = '{COLLECTION_ID}';\n")

    print(f'Generated {out_path}')
    print(f'  {len(units)} units')
    print(f'  {sum(len(u["words"]) for u in units)} total words')
    for u in units:
        print(f'  Unit {u["unit_number"]}: {len(u["words"])} words')


def generate_example(word, translation, pos):
    """Generate a contextual example sentence for the word."""
    w = word.lower()
    
    # Verb examples
    if pos == 'verb':
        examples = {
            'communicate': 'She can communicate well in three languages.',
            'introduce': 'Let me introduce you to my classmates.',
            'agree (with)': 'I agree with your idea completely.',
            'ask (for)': 'You can ask for help if you need it.',
            'go': 'We go to school by bus every day.',
            'listen': 'Please listen carefully to the instructions.',
            'pay': 'I need to pay for my bus ticket.',
            'read': 'She likes to read books before bedtime.',
            'rise': 'The sun will rise at six o''clock tomorrow.',
            'start': 'Classes start at nine in the morning.',
            'stop': 'The bus will stop at the next station.',
            'think (about)': 'I often think about my future career.',
            'wait': 'Please wait here for a few minutes.',
            'wake up': 'I wake up at seven every morning.',
            'work': 'My father works in a hospital.',
            'earn': 'She earns a good salary as a teacher.',
            'fix': 'He can fix almost any electronic device.',
            'forget': 'Do not forget to bring your homework.',
            'believe': 'I believe you can pass the exam.',
            'call': 'I will call you after lunch.',
            'change': 'She wants to change her hairstyle.',
            'collect': 'My brother likes to collect stamps.',
            'copy': 'Please do not copy your friend''s answers.',
            'decide': 'We need to decide where to eat dinner.',
            'finish': 'I always finish my homework before playing.',
            'like': 'I like playing football with my friends.',
            'live': 'We live in a small apartment in the city.',
            'look': 'Look at that beautiful sunset over the mountain.',
            'love': 'I love spending time with my family.',
            'move': 'We plan to move to a new apartment next month.',
            'notice': 'Did you notice the new painting on the wall?',
            'open': 'Please open your books to page forty-five.',
            'play': 'The children play in the park after school.',
            'post': 'I need to post this letter to my grandmother.',
            'prepare': 'Let me prepare everything for the meeting.',
            'receive': 'She was happy to receive a letter from her friend.',
            'return': 'I need to return these library books today.',
            'shout': 'Please do not shout in the library.',
            'study': 'He studies English every evening after dinner.',
            'talk': 'We can talk about this problem later.',
            'thank': 'I want to thank you for your help.',
            'use': 'You can use my computer if you need.',
            'want': 'I want to learn to play the guitar.',
            'watch': 'We watch a movie together every Friday.',
            'ban': 'The school decided to ban mobile phones.',
            'borrow': 'Can I borrow your dictionary for a moment?',
            'bring': 'Please bring your notebook to class.',
            'come': 'Come to my house after school today.',
            'cycle': 'I cycle to school when the weather is nice.',
            'do': 'I do my homework right after school.',
            'drink': 'You should drink more water every day.',
            'eat': 'We eat lunch in the school canteen.',
            'jog': 'She jogs in the park every morning.',
            'learn': 'He wants to learn a new language this year.',
            'lend': 'Could you lend me your pen for a minute?',
            'lose': 'I do not want to lose my new phone.',
            'reduce': 'We should reduce the amount of plastic we use.',
            'ride': 'She can ride a bicycle very well.',
            'run': 'He runs five kilometers every morning.',
            'sleep': 'I usually sleep eight hours every night.',
            'swim': 'Can you swim across the river?',
            'take': 'Take your umbrella, it might rain today.',
            'trek': 'We plan to trek through the mountains next week.',
            'walk': 'I walk to school because I live nearby.',
            'win': 'Our team wants to win the football match.',
            'rent': 'We rent our apartment from a local family.',
            'hold': 'Please hold the door open for me.',
            'lie': 'She likes to lie on the beach in summer.',
            'miss': 'I really miss my friends from my old school.',
            'get': 'I get up early every weekday morning.',
            'bake': 'My mother likes to bake bread on weekends.',
            'boil': 'Please boil some water for tea.',
            'chop': 'Chop the onions into small pieces.',
            'fry': 'We fry the eggs in olive oil every morning.',
            'mix': 'Mix the flour and sugar together in a bowl.',
            'roast': 'We roast chicken for special family dinners.',
            'blow': 'The wind blows very strongly in winter.',
            'freeze': 'The river begins to freeze in December.',
            'shine': 'The sun shines brightly on summer days.',
            'survive': 'It is hard to survive in the desert without water.',
            'award': 'The school will award the best students.',
            'celebrate': 'We celebrate Navruz with the whole family.',
            'focus': 'You need to focus on your studies.',
            'help': 'Can you help me carry these bags?',
            'improve': 'She wants to improve her English skills.',
            'organize': 'Let us organize a charity event this month.',
            'paint': 'We can paint the walls a new color.',
            'plant': 'We plan to plant trees in the park.',
            'repair': 'He can repair old furniture very well.',
            'teach': 'She teaches math at the local school.',
            'bark': 'The dog barks loudly at night.',
            'fail': 'If you do not study, you might fail the exam.',
            'clap': 'The audience began to clap after the performance.',
            'prefer': 'I prefer tea to coffee in the morning.',
            'star': 'She stars in the school play every year.',
        }
        if w in examples:
            return examples[w]
        return f'It is important to {w} in everyday life.'
    
    # Adjective examples
    if pos == 'adjective':
        examples = {
            'dangerous': 'Swimming in the river can be dangerous.',
            'dirty': 'Please wash your dirty clothes in the machine.',
            'free': 'The concert tickets are free for students.',
            'hungry': 'The children felt hungry after playing all day.',
            'late': 'Please do not be late for the meeting.',
            'noisy': 'The street outside is very noisy during the day.',
            'perfect': 'She speaks English with perfect pronunciation.',
            'scientific': 'They used scientific methods to test the idea.',
            'tired': 'I am very tired after a long day at school.',
            'calm': 'The sea was calm and beautiful that morning.',
            'clever': 'She is a very clever student in our class.',
            'important': 'It is important to eat a healthy breakfast.',
            'lonely': 'He felt lonely after moving to a new city.',
            'lucky': 'You are lucky to have such a kind family.',
            'retired': 'My grandfather is retired but still very active.',
            'silent': 'The library should always be silent.',
            'unusual': 'It is unusual to see snow in April here.',
            'well-paid': 'She has a well-paid job at a big company.',
            'big': 'We live in a big house near the park.',
            'cheap': 'The food at that restaurant is cheap and good.',
            'clean': 'Keep your room clean and tidy every day.',
            'easy': 'This math problem is easy to solve.',
            'expensive': 'That new phone is too expensive for me.',
            'fantastic': 'We had a fantastic holiday by the seaside.',
            'lazy': 'My cat is very lazy and sleeps all day.',
            'light': 'The room is light and airy with big windows.',
            'messy': 'His desk is always messy with papers everywhere.',
            'old': 'The old building in the center is a museum.',
            'old-fashioned': 'Her grandmother wears old-fashioned clothes.',
            'organized': 'She is very organized with her school notes.',
            'terrible': 'The weather was terrible during our holiday.',
            'tidy': 'Please keep your bedroom tidy at all times.',
            'ugly': 'The old factory was an ugly building in the city.',
            'boring': 'The movie was so boring that I fell asleep.',
            'careful': 'Be careful when you cross the busy road.',
            'clear': 'The sky is clear and blue today.',
            'correct': 'Make sure all your answers are correct.',
            'disappointed': 'She was disappointed with her exam results.',
            'good': 'She is a good student who studies every day.',
            'great': 'We had a great time at the birthday party.',
            'heavy': 'This suitcase is too heavy to carry alone.',
            'poor': 'The quality of this shirt is very poor.',
            'quiet': 'The park is quiet and peaceful in the morning.',
            'serious': 'This is a serious matter we need to discuss.',
            'simple': 'The instructions are simple and easy to follow.',
            'slow': 'The old computer is very slow at loading pages.',
            'strong': 'You need strong arms to carry those boxes.',
            'virtual': 'We had a virtual meeting with our teacher.',
            'worth': 'This book is worth reading for everyone.',
            'interesting': 'The science lesson today was very interesting.',
            'modern': 'They live in a modern apartment in the city.',
            'naughty': 'The naughty child drew pictures on the wall.',
            'popular': 'Football is the most popular sport in our school.',
            'successful': 'She became a successful businesswoman.',
            'fit': 'She stays fit by exercising every morning.',
            'healthy': 'Eating vegetables helps you stay healthy.',
            'local': 'We shop at the local market every Saturday.',
            'physical': 'Physical exercise is good for your health.',
            'violent': 'Violent storms caused damage to many houses.',
            'air-conditioned': 'The classroom is air-conditioned and comfortable.',
            'amazing': 'The view from the mountain was truly amazing.',
            'colourful': 'The market is full of colourful fruits and fabrics.',
            'delicious': 'The homemade soup was absolutely delicious.',
            'ready-made': 'She bought a ready-made salad for lunch.',
            'sweet': 'These grapes are very sweet and juicy.',
            'unhealthy': 'Eating too much fast food is unhealthy.',
            'wonderful': 'It was a wonderful day at the beach.',
            'busy': 'The city center is very busy on weekends.',
            'close': 'She has a close relationship with her sister.',
            'cloudy': 'It is cloudy today, so bring an umbrella.',
            'crazy': 'That was a crazy idea but it worked perfectly.',
            'deep': 'The lake is very deep in the middle.',
            'dry': 'The summer was hot and dry this year.',
            'foggy': 'Be careful driving on foggy mornings.',
            'freezing': 'It is freezing outside, wear a warm coat.',
            'high': 'The mountain is very high and covered in snow.',
            'hot': 'It gets very hot in Uzbekistan during summer.',
            'icy': 'The roads are icy and dangerous in winter.',
            'large': 'They have a large garden behind their house.',
            'low': 'The temperature was very low last night.',
            'mild': 'The weather is mild and pleasant in spring.',
            'rainy': 'It is a rainy day so stay inside.',
            'sandy': 'The beach has a long sandy shore.',
            'snowy': 'The mountains look beautiful on snowy days.',
            'sunny': 'It is a sunny day, perfect for a picnic.',
            'tropical': 'The island has a hot tropical climate.',
            'warm': 'Put on a warm jacket before going outside.',
            'wet': 'My shoes got wet from walking in the rain.',
            'windy': 'It is too windy to fly a kite today.',
            'awful': 'The food at that restaurant was awful.',
            'brilliant': 'She had a brilliant idea for the project.',
            'common': 'Rain is very common in England.',
            'crucial': 'Good nutrition is crucial for growing children.',
            'delighted': 'She was delighted to receive the good news.',
            'elderly': 'We should always help elderly people.',
            'excellent': 'He received an excellent grade on his exam.',
            'homeless': 'The charity helps homeless people in winter.',
            'huge': 'They built a huge shopping center downtown.',
            'lovely': 'What a lovely garden you have!',
            'massive': 'The concert attracted a massive crowd.',
            'scared': 'She was scared of the dark when she was young.',
            'tiny': 'The baby was holding a tiny toy in her hand.',
            'worried': 'Her parents were worried about the exam results.',
            'autistic': 'The school has special programs for autistic children.',
            'blind': 'She has been blind since birth but plays piano beautifully.',
            'deaf': 'He is deaf but communicates well using sign language.',
            'favourite': 'My favourite colour is blue.',
            'scary': 'That was the scariest movie I have ever watched.',
        }
        if w in examples:
            return examples[w]
        return f'The situation was quite {w} for everyone.'
    
    # Noun examples
    if pos == 'noun':
        examples = {
            'artist': 'The artist painted a beautiful picture of the city.',
            'aunt': 'My aunt always brings gifts when she visits.',
            'boss': 'Her boss praised her work at the meeting.',
            'brother': 'My brother is two years older than me.',
            'child': 'Every child deserves a good education.',
            'children': 'The children play together in the schoolyard.',
            'country': 'Uzbekistan is a beautiful country in Central Asia.',
            'cousin': 'My cousin studies medicine at the university.',
            'daughter': 'Their daughter is the top student in her class.',
            'designer': 'The designer created a beautiful new dress.',
            'father': 'My father teaches me to ride a bicycle.',
            'granddaughter': 'She reads bedtime stories to her granddaughter.',
            'grandfather': 'My grandfather tells amazing stories about the past.',
            'grandmother': 'My grandmother makes the best plov in the family.',
            'grandson': 'He takes his grandson to the park every weekend.',
            'husband': 'Her husband works as a doctor at the hospital.',
            'mother': 'My mother cooks delicious food every day.',
            'nationality': 'What is your nationality and where are you from?',
            'neighbour': 'Our neighbour has a beautiful flower garden.',
            'nephew': 'My nephew just started going to school this year.',
            'niece': 'I bought a birthday present for my niece.',
            'restaurant': 'There is a new restaurant near our house.',
            'saxophone': 'He plays the saxophone in the school band.',
            'sister': 'My sister and I go to the same school.',
            'son': 'Their son won first place in the competition.',
            'stepfather': 'Her stepfather is kind and caring to the family.',
            'supermarket': 'We buy our groceries at the supermarket.',
            'twin': 'The twins look exactly the same.',
            'uncle': 'My uncle lives in Tashkent and visits us often.',
            'wife': 'His wife is a talented musician.',
            'astronaut': 'The astronaut traveled to the space station.',
            'beach': 'We spent the whole day at the beach.',
            'breakfast': 'I had cereal and toast for breakfast.',
            'canteen': 'Students eat lunch in the school canteen.',
            'cereal': 'He has cereal with milk for breakfast.',
            'class': 'Our English class starts at ten in the morning.',
            'discount': 'You can get a ten percent discount with this card.',
            'expert': 'She is an expert in computer science.',
            'eyesight': 'Reading in the dark is bad for your eyesight.',
            'idea': 'She had a great idea for the school project.',
            'journey': 'The journey from Tashkent to Bukhara takes four hours.',
            'lab': 'We do science experiments in the lab.',
            'meeting': 'The meeting will start at three o''clock.',
            'penguin': 'We saw a penguin at the zoo yesterday.',
            'physics': 'She wants to study physics at university.',
            'plan': 'What is your plan for the summer holiday?',
            'professor': 'The professor gave an interesting lecture today.',
            'reply': 'I am waiting for a reply to my email.',
            'sandwich': 'I made a cheese sandwich for lunch.',
            'scientist': 'The scientist discovered a new type of plant.',
            'seal': 'We saw a seal swimming in the cold water.',
            'shop': 'There is a small shop at the corner of our street.',
            'shower': 'I take a shower every morning before school.',
            'sickness': 'The sickness kept him in bed for a week.',
            'soup': 'My grandmother makes the best tomato soup.',
            'space': 'Scientists explore space using powerful telescopes.',
            'spacesuit': 'Astronauts wear a spacesuit outside the spacecraft.',
            'title': 'What is the title of your favorite book?',
            'toast': 'I like toast with jam for breakfast.',
            'trainee': 'The company hired three new trainees this month.',
            'volcano': 'The volcano erupted with a loud explosion.',
            'wall': 'There is a world map hanging on the wall.',
            'zoology': 'She studies zoology because she loves animals.',
            'money': 'He is saving money to buy a new bicycle.',
            'salary': 'Teachers deserve a higher salary for their work.',
            'ticket': 'I bought a ticket for the concert next week.',
            'tower': 'The old tower is the tallest building in town.',
            'uniform': 'Students wear a uniform to school every day.',
            'winner': 'The winner of the race got a gold medal.',
            'piano': 'She practices piano for an hour every day.',
            'magazine': 'I read an interesting article in a magazine.',
            'internet': 'We use the internet for research and communication.',
            'forest': 'We went for a long walk through the forest.',
            'factory': 'The factory produces cars and trucks.',
            'company': 'She works for a large technology company.',
            'airport': 'We arrived at the airport two hours before the flight.',
            'armchair': 'Grandpa sits in his favourite armchair every evening.',
            'bank': 'I need to go to the bank to open an account.',
            'bathroom': 'The bathroom is at the end of the hallway.',
            'bed': 'I go to bed at ten o''clock every night.',
            'bedroom': 'My bedroom has a large window facing the garden.',
            'building': 'The new building has twenty floors.',
            'campsite': 'We set up our tent at the campsite.',
            'capital': 'Tashkent is the capital of Uzbekistan.',
            'carpet': 'The carpet in the living room is very soft.',
            'cinema': 'Let us go to the cinema this weekend.',
            'cooker': 'She bought a new cooker for the kitchen.',
            'furniture': 'We need new furniture for the living room.',
            'garage': 'My father parks his car in the garage.',
            'museum': 'We visited the history museum on our school trip.',
            'palace': 'The palace was built over five hundred years ago.',
            'passport': 'You need a passport to travel to other countries.',
            'table': 'Please set the table for dinner.',
            'temple': 'The ancient temple attracts many tourists.',
            'theatre': 'We went to the theatre to see a play.',
            'toilet': 'Excuse me, where is the toilet please?',
            'tour': 'We took a tour of the old city.',
            'tourist': 'The city attracts millions of tourists every year.',
            'town': 'Our town is small but very beautiful.',
            'window': 'She looked out of the window at the snow.',
            'market': 'The market sells fresh fruits and vegetables.',
            'library': 'I borrow books from the library every week.',
            'mine': 'The old gold mine is now a tourist attraction.',
            'opal': 'She wore a necklace with a beautiful opal stone.',
            'scarf': 'She wrapped a warm scarf around her neck.',
            'shelf': 'Please put the books back on the shelf.',
            'sink': 'Wash your hands at the kitchen sink.',
            'cash': 'I prefer to pay with cash instead of a card.',
            'coat': 'Put on your coat before going outside.',
            'dress': 'She bought a beautiful dress for the party.',
            'hat': 'He always wears a hat when it is sunny.',
            'hoodie': 'He wore a blue hoodie to school today.',
            'information': 'Can you give me some information about the course?',
            'jacket': 'She put on her jacket because it was cold.',
            'jewellery': 'She inherited beautiful jewellery from her grandmother.',
            'meat': 'We buy fresh meat from the butcher every week.',
            'postcard': 'I sent a postcard to my friend from holiday.',
            'receipt': 'Keep the receipt in case you need to return it.',
            'suit': 'He wore a dark suit to the interview.',
            'tie': 'My father wears a tie to work every day.',
            'umbrella': 'Take an umbrella, it looks like rain.',
            'value': 'This watch has great sentimental value to me.',
            'wedding': 'They had a beautiful wedding ceremony last summer.',
            'classroom': 'Our classroom has thirty desks and a whiteboard.',
            'founder': 'The founder of the company started with nothing.',
            'label': 'Check the label for the washing instructions.',
            'product': 'This is our most popular product.',
            'sculpture': 'There is a beautiful sculpture in the city center.',
            'app': 'I downloaded a new language learning app.',
            'basketball': 'He plays basketball every afternoon.',
            'bucket': 'Fill the bucket with water for washing the car.',
            'football': 'Football is the most popular sport in the world.',
            'gadget': 'He loves buying the latest electronic gadgets.',
            'gym': 'I go to the gym three times a week.',
            'habit': 'Reading before bed is a good habit.',
            'hero': 'The firefighter was a hero for saving the family.',
            'judo': 'She has a black belt in judo.',
            'lift': 'Let us take the lift to the fifth floor.',
            'lightning': 'The lightning lit up the dark sky.',
            'marathon': 'She trained hard to run her first marathon.',
            'mayor': 'The mayor opened the new sports center.',
            'opinion': 'Everyone has a different opinion on this topic.',
            'progress': 'She is making great progress in her English.',
            'research': 'The research team published their findings.',
            'routine': 'My morning routine starts with a cup of tea.',
            'studio': 'The artist works in a small studio downtown.',
            'subtitle': 'I watch movies with subtitles to learn English.',
            'tennis': 'She plays tennis at the club every Saturday.',
            'thunderstorm': 'The thunderstorm lasted for over two hours.',
            'yoga': 'She practices yoga every morning for relaxation.',
            'apartment': 'They moved into a new apartment last month.',
            'bike': 'I ride my bike to school every day.',
            'bus': 'The bus arrives at our stop at eight thirty.',
            'car': 'My father drives his car to work every day.',
            'countryside': 'We spent the weekend in the countryside.',
            'culture': 'Uzbek culture is rich in art and traditions.',
            'dinner': 'We have dinner together as a family.',
            'employee': 'The company has over five hundred employees.',
            'environment': 'We must protect the environment for future generations.',
            'group': 'Our study group meets every Wednesday.',
            'guide': 'The tour guide showed us around the old city.',
            'helmet': 'Always wear a helmet when riding a bicycle.',
            'map': 'We used a map to find our way around the city.',
            'mountain': 'The mountains are covered with snow in winter.',
            'passenger': 'Each passenger must show their ticket.',
            'platform': 'The train departs from platform number three.',
            'queue': 'There was a long queue at the ticket office.',
            'railway': 'The railway connects all the major cities.',
            'rainforest': 'The Amazon rainforest is home to many animals.',
            'ruins': 'We explored the ancient ruins of the old city.',
            'sunrise': 'We woke up early to watch the sunrise.',
            'taxi': 'We took a taxi from the airport to the hotel.',
            'tradition': 'It is a tradition to eat plov on special occasions.',
            'train': 'The train from Tashkent arrives at noon.',
            'beef': 'We had beef stew for dinner last night.',
            'bowl': 'She put the soup in a large bowl.',
            'bread': 'Fresh bread from the bakery smells wonderful.',
            'castle': 'The old castle stands on top of the hill.',
            'chicken': 'We had grilled chicken with rice for lunch.',
            'cube': 'Cut the cheese into small cubes.',
            'fork': 'Please put a knife and fork on each plate.',
            'fruit': 'Eating fresh fruit every day is very healthy.',
            'honey': 'I like to put honey in my tea.',
            'ingredient': 'The main ingredient in plov is rice.',
            'jam': 'She spread strawberry jam on her toast.',
            'kettle': 'The kettle is boiling, shall I make tea?',
            'knife': 'Be careful with that sharp knife.',
            'lemon': 'Add a slice of lemon to your tea.',
            'lemonade': 'Cold lemonade is perfect on a hot day.',
            'microwave': 'Heat the food in the microwave for two minutes.',
            'mushroom': 'We added mushrooms to the pasta sauce.',
            'noodles': 'We had noodles with vegetables for lunch.',
            'olive': 'She put olives and cheese on the salad.',
            'oven': 'Bake the cake in the oven for thirty minutes.',
            'pasta': 'She cooked pasta with tomato sauce for dinner.',
            'pear': 'There is a pear tree in our garden.',
            'plate': 'Please put the food on a clean plate.',
            'rice': 'Rice is a staple food in many countries.',
            'salad': 'I had a fresh vegetable salad for lunch.',
            'saucepan': 'Heat the milk slowly in a saucepan.',
            'secret': 'The recipe is a family secret.',
            'spoon': 'Stir the soup with a wooden spoon.',
            'starter': 'We had soup as a starter before the main course.',
            'survey': 'We conducted a survey about eating habits.',
            'sweetcorn': 'She added sweetcorn to the chicken salad.',
            'vegetable': 'You should eat more fresh vegetables.',
            'view': 'The view from the top of the hill was amazing.',
            'yoghurt': 'I eat yoghurt with fruit for breakfast.',
            'accent': 'She speaks English with a lovely British accent.',
            'camp': 'We set up camp near the river.',
            'climate': 'The climate in Uzbekistan is continental.',
            'coast': 'They spent their holiday on the coast.',
            'compass': 'Use a compass to find which direction is north.',
            'desert': 'The Kyzylkum is a vast desert in Uzbekistan.',
            'east': 'The sun rises in the east every morning.',
            'equipment': 'We packed all the equipment for the camping trip.',
            'island': 'They traveled to a tropical island for vacation.',
            'jungle': 'Many exotic animals live in the jungle.',
            'lake': 'We went swimming in the lake last summer.',
            'lighter': 'He used a lighter to start the campfire.',
            'north': 'The cold wind comes from the north.',
            'oasis': 'The travelers were relieved to find an oasis.',
            'rain': 'The rain fell heavily all afternoon.',
            'river': 'The river flows through the center of the city.',
            'score': 'What was the final score of the match?',
            'sleeper': 'She is a light sleeper and wakes up easily.',
            'snow': 'The children played in the snow all morning.',
            'south': 'Birds fly south for the winter.',
            'storm': 'The storm knocked down several trees.',
            'stove': 'She heated the soup on the old stove.',
            'survival': 'Survival in the desert requires water and shelter.',
            'temperature': 'The temperature dropped below zero last night.',
            'tent': 'We put up our tent near the lake.',
            'thunder': 'The thunder scared the little children.',
            'torch': 'Use a torch to see in the dark tunnel.',
            'traffic': 'There is always heavy traffic during rush hour.',
            'waterfall': 'The waterfall was the most beautiful sight on our trip.',
            'weather': 'The weather is very hot today.',
            'west': 'The sun sets in the west.',
            'worker': 'The construction workers built the bridge in six months.',
            'charity': 'She donates money to charity every month.',
            'coach': 'The football coach trains the team every day.',
            'community': 'Our community organizes events for families.',
            'dietician': 'The dietician recommended eating more fruit.',
            'individual': 'Each individual has unique talents.',
            'maximum': 'The maximum number of students per class is thirty.',
            'member': 'She became a member of the tennis club.',
            'player': 'He is the best player on the football team.',
            'resident': 'Residents of the building share a garden.',
            'soil': 'Good soil is necessary for growing vegetables.',
            'tax': 'Everyone must pay tax to the government.',
            'team': 'Our school team won the regional competition.',
            'acrobat': 'The acrobat performed amazing tricks on the tightrope.',
            'album': 'The band released a new album last month.',
            'animation': 'Modern animation films use advanced technology.',
            'band': 'The school band performed at the concert.',
            'circus': 'The children loved watching the circus performers.',
            'collection': 'He has a large collection of old coins.',
            'comedy': 'We watched a funny comedy at the cinema.',
            'concert': 'The concert was sold out within minutes.',
            'drama': 'She loves watching drama films.',
            'drum': 'He plays the drum in the school band.',
            'experience': 'Traveling gives you a lot of new experience.',
            'future': 'She wants to become a doctor in the future.',
            'gallery': 'We visited the art gallery downtown.',
            'helicopter': 'The helicopter landed on the hospital roof.',
            'illness': 'She missed school because of a serious illness.',
            'independence': 'Uzbekistan celebrates independence day on September 1st.',
            'instrument': 'She can play three different musical instruments.',
            'lesson': 'The piano lesson starts at four o''clock.',
            'musical': 'We went to see a musical at the theatre.',
            'opera': 'The opera performance was absolutely stunning.',
            'prize': 'She won first prize in the art competition.',
            'stage': 'The singer walked onto the stage to great applause.',
            'surprise': 'The birthday party was a lovely surprise.',
        }
        if w in examples:
            return examples[w]
        return f'The {w} was very interesting to see.'

    # Phrase / adverb / other
    examples = {
        'feel well': 'I do not feel well today, I have a headache.',
        'get up': 'I get up at six thirty every morning.',
        'go clubbing': 'Young people like to go clubbing on weekends.',
        'half past': 'The bus leaves at half past eight.',
        'have dinner': 'We have dinner at seven o''clock.',
        'have lunch': 'We have lunch in the school canteen.',
        'quarter past': 'It is quarter past nine, class is starting.',
        'quarter to': 'The meeting starts at quarter to three.',
        'watch a film': 'We like to watch a film on Friday evenings.',
        'watch TV': 'I watch TV for one hour after dinner.',
        'work freelance': 'She decided to work freelance as a designer.',
        'work long hours': 'Doctors often work long hours at the hospital.',
        'free time': 'In my free time, I like reading books.',
        'fresh air': 'Go outside and get some fresh air.',
        'body clock': 'Your body clock tells you when to sleep.',
        'sleeping bag': 'I packed my sleeping bag for the camping trip.',
        'student card': 'Show your student card for a discount.',
        'public transport': 'We use public transport to get around the city.',
        'business management': 'He studies business management at university.',
        'car mechanic': 'The car mechanic fixed our engine quickly.',
        'family name': 'What is your family name?',
        'last name': 'Please write your last name on the form.',
        'brother-in-law': 'My brother-in-law works in a bank.',
        'booking form': 'Please fill in the booking form to reserve a room.',
        'bookshop': 'I found a great novel at the bookshop.',
        'dining room': 'We eat breakfast in the dining room.',
        'dishwasher': 'Put the dirty plates in the dishwasher.',
        'flat': 'They moved into a new flat last month.',
        'fridge': 'Put the milk back in the fridge.',
        'hairdresser\'s': 'I need to go to the hairdresser''s for a haircut.',
        'hospital': 'She was taken to the hospital after the accident.',
        'housemate': 'My housemate is very tidy and organized.',
        'in front of': 'The bus stop is in front of the school.',
        'instructions': 'Read the instructions carefully before you start.',
        'kitchen': 'Mom is cooking in the kitchen.',
        'launderette': 'I wash my clothes at the launderette nearby.',
        'living room': 'We watch TV together in the living room.',
        'next to': 'The bank is next to the post office.',
        'on': 'The book is on the table.',
        'opposite': 'The school is opposite the park.',
        'post office': 'I need to go to the post office to send a parcel.',
        'railway station': 'Meet me at the railway station at noon.',
        'studio flat': 'She rents a small studio flat in the city.',
        'swimming pool': 'The hotel has a large swimming pool.',
        'tourist information centre': 'Visit the tourist information centre for maps.',
        'above': 'The clock is above the door.',
        'behind': 'The garden is behind the house.',
        'between': 'The cafe is between the bank and the bookshop.',
        'under': 'The cat is sleeping under the table.',
        'underground': 'The underground station is two blocks away.',
        'baker\'s': 'I buy bread at the baker''s every morning.',
        'butcher\'s': 'We get our meat from the butcher''s.',
        'button': 'Press the green button to start the machine.',
        'changing room': 'You can try on clothes in the changing room.',
        'designer shoes': 'She bought expensive designer shoes for the party.',
        'gloves': 'Wear gloves to keep your hands warm.',
        'jeans': 'He wore blue jeans and a white shirt.',
        'newsagent\'s': 'I buy the newspaper at the newsagent''s.',
        'online': 'You can buy tickets online now.',
        'rainwater': 'They collect rainwater for the garden.',
        'reading glasses': 'She cannot read without her reading glasses.',
        'sales': 'The sales start next week with big discounts.',
        'shopping centre': 'The new shopping centre has over fifty stores.',
        'shorts': 'He wears shorts when the weather is hot.',
        'skirt': 'She wore a blue skirt to the party.',
        'socks': 'I need to buy some new socks.',
        'trainers': 'He bought new trainers for the gym.',
        'trousers': 'These trousers are too long for me.',
        'T-shirt': 'She wore a red T-shirt with blue jeans.',
        'vending machine': 'I bought a drink from the vending machine.',
        'a bit': 'I am a bit tired after the long walk.',
        'ice skater': 'The ice skater performed a graceful spin.',
        'modern art': 'The gallery displays modern art from local artists.',
        'action film': 'We watched an exciting action film last night.',
        'horror film': 'I do not like watching horror films at night.',
        'love story': 'The movie was a beautiful love story.',
        'romantic film': 'She enjoys watching romantic films.',
        'science fiction film': 'The science fiction film had amazing special effects.',
        'black and white': 'The old photograph was in black and white.',
        'hang on': 'Hang on a minute while I find my keys.',
        'painting lesson': 'She takes a painting lesson every Saturday.',
        'music festival': 'We attended a music festival in the park.',
        'go fishing': 'My grandfather likes to go fishing at the lake.',
        'paper clip': 'Use a paper clip to hold the pages together.',
        'city break': 'We took a short city break to Istanbul.',
        'street life': 'The street life in the old town is very vibrant.',
        'text message': 'She sent me a text message about the meeting.',
        'art gallery': 'We visited the art gallery on Sunday.',
        'guest house': 'We stayed at a lovely guest house by the coast.',
        'seat belt': 'Always fasten your seat belt in the car.',
        'main course': 'For the main course we had grilled fish.',
        'food processor': 'Use a food processor to blend the ingredients.',
        'frying pan': 'Heat some oil in the frying pan.',
        'takeaway food': 'We ordered takeaway food for dinner tonight.',
        'weather forecast': 'The weather forecast says it will rain tomorrow.',
        'first-aid kit': 'Always carry a first-aid kit when hiking.',
        'hard worker': 'She is a hard worker and never gives up.',
        'look after': 'She looks after her younger siblings every day.',
        'get around': 'The best way to get around the city is by metro.',
        'woke up (past simple of wake up)': 'She woke up early to study for the exam.',
        'alone': 'She does not like walking home alone at night.',
        'outside': 'The children are playing outside in the garden.',
        'again': 'Please say that again, I did not hear you.',
        'inside': 'It is raining, let us stay inside today.',
        'later': 'I will call you later this evening.',
        'part-time': 'She works part-time at a local cafe.',
        'carefully': 'Please drive carefully on the icy roads.',
        'clearly': 'Please speak clearly so everyone can hear you.',
        'correctly': 'She answered all the questions correctly.',
        'dangerously': 'He was driving dangerously fast on the highway.',
        'quietly': 'She quietly closed the door so no one would hear.',
        'slowly': 'The old man walked slowly down the street.',
        'well': 'She speaks English very well.',
        'quite': 'The exam was quite difficult for most students.',
        'really': 'I really enjoyed the concert last night.',
        'very': 'She is very happy with her new school.',
        'annually': 'The festival takes place annually in September.',
        'constantly': 'She is constantly checking her phone for messages.',
        'place of work': 'The office is her main place of work.',
        'office worker': 'She works as an office worker in the city center.',
        'bus driver': 'The bus driver greeted the passengers with a smile.',
        'police officer': 'The police officer helped the lost tourist.',
        'sightseeing': 'We spent the day sightseeing in the old town.',
        'tip': 'Here is a useful tip for learning vocabulary.',
    }
    
    # Try exact match
    if w in examples:
        return examples[w]
    
    # Fallback for remaining words
    pos_specific = {
        'adjective': f'The weather today is quite {word.lower()}.',
        'adverb': f'She {word.lower()} completed all her tasks.',
        'verb': f'They {word.lower()} every day without fail.',
        'noun': f'The {word.lower()} is very important in daily life.',
        'phrase': f'We often use the phrase {word.lower()} in class.',
    }
    
    # Handle past tense verb forms
    if '(past' in w.lower():
        base = word.split('(')[0].strip()
        return f'She {base} to school yesterday morning.'

    return pos_specific.get(pos, f'The {word.lower()} was very useful.')


if __name__ == '__main__':
    units = parse_markdown(MD_PATH)
    generate_sql(units, OUT_PATH)
