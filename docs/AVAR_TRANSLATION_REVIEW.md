# Avar UI Translation Review

**Статус: проверено носителем аварского языка (2026-08-02), правки
применены.** Принятые исправления: «Гьоркьоб бакӀ» для клавиши пробела
(и производные формы в настройках), «Цебе бачине» вместо диалектного
«Давам», «Жиги» вместо «Жеги», «Хирияв!» вместо «Жан!». Открытый вопрос
для подтверждения: «Жиги» — у Гимбатова словарная форма «жеги»;
просим подтвердить выбранное написание.

Конвенция палочки (принято): везде, где текст видит пользователь —
клавиши, подсказки, настройки, вставляемый текст — используется
заглавная палочка `Ӏ` (U+04C0). Внутреннее хранилище и поиск работают
в канонической строчной форме `ӏ` (U+04CF); преобразование выполняется
на границе отображения и на границе записи, поэтому все запросы
работают одинаково.

Просьба к рецензенту: проверьте естественность, падежи/классные
показатели и краткость (это подписи на клавишах и в настройках).
Колонка «Комментарий» отмечает места, где мы сомневаемся.

## 1. Интерфейс клавиатуры и настроек

| # | Где используется | English | Русский | Аварский (текущий) | Комментарий |
|---|---|---|---|---|---|
| 1 | KeyboardLayout.swift — space key | Space | Пробел | **Гьоркьоб бакӀ** | reviewer's native term for the space bar (бакӀ = место); adopted |
| 2 | KeyboardLayout.swift — return key (default) | Return | Ввод | **Ввод** | Russian loan, as on the system Russian keyboard; suggest a native alternative if one is idiomatic |
| 3 | KeyboardLayout.swift — return key (Go) | Go | Перейти | **Ине** | ине = идти |
| 4 | KeyboardLayout.swift — return key (Send) | Send | Отправить | **БитӀизе** | битӏизе = отправить, послать |
| 5 | KeyboardLayout.swift — return key (Done) | Done | Готово | **ЛъугӀана** | лъугӏизе = закончиться; past «лъугӏана» = готово/закончилось |
| 6 | KeyboardLayout.swift — return key (Next) | Next | Далее / Следующий | **Хадусеб** | хадусеб = следующий |
| 7 | KeyboardLayout.swift — return key (Continue) | Continue | Продолжить | **Цебе бачине** | reviewer: «давам» — скорее диалект; принято «Цебе бачине» (цебе = вперёд, бачине = вести) |
| 8 | KeyboardLayout.swift — return key (Join) | Join | Подключиться / Войти | **Лъугьине** | лъугьине = войти |
| 9 | KeyboardLayout.swift — return key (Route) | Route | Маршрут | **Нух** | нух = дорога, путь |
| 10 | KeyboardLayout.swift — return key (Emergency) | Emergency call | Экстренный вызов | **Кумекалъе ахӀи** | кумек = помощь; ахӏи = зов, призыв (на помощь) |
| 11 | KeyboardView.swift — suggestion delete bar | Delete “word”? | Стереть «слово»? | **“…” гилдизеищ?** | гилдизе = удалить + вопросительная частица -ищ; please check the interrogative form |
| 12 | KeyboardView.swift — delete bar, cancel | No | Нет | **Гуро** |  |
| 13 | KeyboardView.swift — delete bar, confirm | Delete | Стереть | **Гилдизе** |  |
| 14 | KeyboardView.swift — emoji pane section | Recents | Недавние | **Ахирисел** | ахирисеб = последний, plural |
| 15 | SettingsPanelView — header back button | Back | Назад | **Нахъе** | нахъе = назад |
| 16 | SettingsPanelView — header close | Keyboard | Клавиатура | **Клавиатура** | loan, unchanged |
| 17 | SettingsPanelView — home caption | AVAR KEYBOARD | АВАРСКАЯ КЛАВИАТУРА | **АВАР КЛАВИАТУРА** | unchanged from earlier pass |
| 18 | SettingsPanelView — home title | Settings | Настройки | **Рекъезабиял** | рекъезабизе = настроить, приладить; masdar plural |
| 19 | SettingsPanelView — page title | Typing | Ввод / Набор | **Хъвай** | masdar of хъвазе = писать |
| 20 | SettingsPanelView — page title | Theme | Тема | **Тема** | loan, unchanged |
| 21 | SettingsPanelView — page title | Dictionary | Словарь | **Словарь** | «словарь» is a Gimbatov headword; no native equivalent found |
| 22 | SettingsPanelView — page title | About the keyboard | О клавиатуре | **Клавиатураялъул хӀакъалъулъ** | хӏакъалъулъ = о, про |
| 23 | SettingsPanelView — section label | Suggestions — | Подсказки — | **Малълъиял —** | малълъи = наставление, совет (подсказка) |
| 24 | SettingsPanelView — toggle | Word suggestions | Подсказки слов | **РагӀабазул малълъиял** |  |
| 25 | SettingsPanelView — toggle | Next-word suggestion | Подсказка следующего слова | **Хадусеб рагӀиялъул малълъи** |  |
| 26 | SettingsPanelView — toggle | Space after accepting a suggestion | Пробел после подсказки | **Малълъиялда хадуб пробел** | -да хадуб = после |
| 27 | SettingsPanelView — section label | Keys | Клавиши | **Клавишаби** | loan + Avar plural -би |
| 28 | SettingsPanelView — toggle | Double space types a period | Двойной пробел — точка | **КӀиго пробел — тӀанкӀ** | кӏиго = два; тӏанкӏ = точка |
| 29 | SettingsPanelView — toggle | Cursor control with the space bar | Курсор пробелом | **Гьоркьоб бакӀалъул курсор** | reviewer's form (genitive -алъул); adopted |
| 30 | SettingsPanelView — toggle | Show «авар» on the space bar | «авар» на пробеле | **Гьоркьоб бакӀалда «авар»** | reviewer's form (superessive -алда); adopted |
| 31 | SettingsPanelView — section label | Learning — | Обучение — | **Лъазаби —** | лъазабизе = выучить, узнать |
| 32 | SettingsPanelView — learning speed | Fast | Быстро | **Хехаб** | хехаб = быстрый |
| 33 | SettingsPanelView — learning speed subtitle | 1 time · | 1 раз · | **1 нухалъ ·** | нухалъ = раз (also 3/5) |
| 34 | SettingsPanelView — learning speed | Normal | Обычно | **ГӀадатаб** | гӏадатаб = обычный |
| 35 | SettingsPanelView — learning speed | Conservative (slow) | Медленно | **Хьадараб** | хьадараб = медленный (Gimbatov) |
| 36 | SettingsPanelView — section label | Extra letters (Ӏ, кь, къ…) — | Дополнительные буквы — | **БатӀиял хӀарпал (Ӏ, кь, къ…) —** | батӏияб = особый; хӏарп = буква — please suggest better if unnatural |
| 37 | SettingsPanelView — callout delay | Short pause | Короткая пауза | **Къокъаб лъалхъи** | къокъаб = короткий; лъалхъи = передышка, пауза |
| 38 | SettingsPanelView — callout delay | Normal pause | Обычная пауза | **ГӀадатаб лъалхъи** |  |
| 39 | SettingsPanelView — callout delay | Long pause | Долгая пауза | **Халатаб лъалхъи** | халатаб = длинный, долгий |
| 40 | SettingsPanelView — theme | System | Системная | **Системаялъул** | genitive of система |
| 41 | SettingsPanelView — theme | Light | Светлая | **КанчӀаб** | канчӏаб = светлый |
| 42 | SettingsPanelView — theme | Dark | Тёмная | **БецӀаб** | бецӏаб = тёмный |
| 43 | SettingsPanelView — dictionary counter | learned words | выученные слова | **лъазарурал рагӀаби** | participle of лъазабизе + р-class plural — please verify the participle form |
| 44 | SettingsPanelView — dictionary empty state | No words yet | Слов пока нет | **Жиги рагӀаби гьечӀо** | reviewer's spelling; Gimbatov lists «жеги» — просьба подтвердить |
| 45 | SettingsPanelView — dictionary action | Delete all learned words | Стереть все выученные слова | **Киналго лъазарурал рагӀаби гилдизе** | киналго = все |
| 46 | SettingsPanelView — confirm sheet title | Delete all learned words? | Стереть все выученные слова? | **Киналго лъазарурал рагӀаби гилдизеищ?** | interrogative -ищ — please verify |
| 47 | SettingsPanelView — confirm sheet button | Delete | Стереть | **Гилдизе** |  |
| 48 | SettingsPanelView — confirm sheet button | No | Нет | **Гуро** |  |
| 49 | SettingsPanelView — about page | Avar keyboard | Аварская клавиатура | **Авар клавиатура** | unchanged from earlier pass |
| 50 | SettingsPanelView — about page | Version 1.0.0 · LekiTech | Версия 1.0.0 · LekiTech | **Версия 1.0.0 · LekiTech** | Russian kept deliberately |
| 51 | EmojiData.swift — category | Smileys & people | Смайлы и люди | **Гьурмал ва гӀадамал** | гьумер = лицо (pl. гьурмал); гӏадамал = люди |
| 52 | EmojiData.swift — category | Nature | Природа | **ТӀабигӀат** |  |
| 53 | EmojiData.swift — category | Food | Еда | **Квен** | квен = пища, еда |
| 54 | EmojiData.swift — category | Activities | Активности / Игры | **ХӀаял** | хӏай = игра, plural |
| 55 | EmojiData.swift — category | Travel | Путешествия | **Сапар** |  |
| 56 | EmojiData.swift — category | Objects | Предметы | **Жал** | жо = вещь (pl. жал) — very short; please confirm it reads naturally |
| 57 | EmojiData.swift — category | Symbols | Символы | **ГӀаламатал** | гӏаламат = знак; alternative: keep loan «Символал» |
| 58 | EmojiData.swift — category | Flags | Флаги | **Байрахъал** | байрахъ = флаг, знамя |

## 2. Подписи к стикерам (только метаданные, в приложении не отображаются)

| # | Стикер | English | Русский | Аварский (текущий) | Комментарий |
|---|---|---|---|---|---|
| 1 | `salam` | Hello! | Салам!/Привет! | **Салам!** | universal greeting, unchanged |
| 2 | `thanks` | Thank you! | Спасибо! | **Баркала!** |  |
| 3 | `sweetheart` | Sweetheart! | Дорогой! / Джан! | **Хирияв!** | reviewer: «хирияв» (м.р.) / «хирияй» (ж.р.) обычны у аварцев; принята мужская форма, как и в `loveyou` |
| 4 | `great` | Great! | Отлично! | **ЛъикӀ буго!** | «хорошо есть» |
| 5 | `yes` | Yes | Да / Конечно | **Гьай-гьай!** | = конечно; plain «У» felt too short for a sticker — please verify |
| 6 | `no` | No | Нет | **ГьечӀо!** |  |
| 7 | `howareyou` | How are you? | Как дела? | **Иш кин бугеб?** | «как дело?» — please verify idiom |
| 8 | `loveyou` | I love you | Я тебя люблю | **Дие мун вокьула** | masculine addressee; feminine variant «Дие мун йокьула» — sticker can only carry one |
| 9 | `sorry` | Sorry / Forgive me | Прости | **ТӀаса лъугьа!** | imperative of тӏаса лъугьине = прощать |
| 10 | `bravo` | Bravo! / Well done! | Молодец! | **БахӀарчи!** | бахӏарчи = герой, молодец — please verify usage |
| 11 | `congrats` | Congratulations! | Поздравляю! | **Баркула!** | from баркизе = поздравлять |
| 12 | `welcome` | Welcome! | Добро пожаловать! | **ЛъикӀ щварал!** | plural addressee — please verify form |
| 13 | `comehere` | Come here! | Иди сюда! | **ВачӀа!** | masculine addressee (в-class) |
| 14 | `morning` | Good morning! | Доброе утро! | **ВорчӀами!** | Gimbatov: «с добрым утром, здравствуй» |
| 15 | `angry` | Enough! | Хватит! | **ГӀела!** | from гӏезе — please verify |
| 16 | `goodnight` | Good night! | Спокойной ночи! | **Сордо лъикӀ!** | сордо = ночь |
| 17 | `prayer` | Amen! | Аминь! | **Амин!** | unchanged |
| 18 | `lezginka` | Dance! | Танцуй! | **Кьурде!** | imperative of кьурдизе = плясать |
| 19 | `khinkal` | Bon appétit! | Приятного аппетита! | **Бисмилла!** | customary before a meal — please confirm it suits the sticker |
| 20 | `avarflag` | The Avars | Аварцы | **МагӀарулал** | Avar self-designation |

## 2а. Добавлено после проверки (ожидает вашей оценки)

Новая настройка «раскладка» (выбор 3-рядной / 4-рядной клавиатуры):

| # | Где используется | English | Русский | Аварский (текущий) | Комментарий |
|---|---|---|---|---|---|
| a1 | SettingsPanelView — section label | Layout — | Раскладка — | **Раскладка —** | русское заимствование, как «Тема»; предложите аварское слово, если есть естественное |
| a2 | SettingsPanelView — radio row | 3 rows | 3 ряда | **3 мухъ** | мухъ = линия, полоса (Гимбатов); правильна ли форма после числительного? |
| a3 | SettingsPanelView — radio row | 4 rows | 4 ряда | **4 мухъ** | как выше |

## 3. Оставлено без перевода (намеренно)

- «Ввод», «Тема», «Словарь», «Клавиатура», «Клавишаби», «курсор»,
  «Системаялъул», «Версия…» — русские заимствования, привычные в современном
  аварском интерфейсе. «Пробел» остаётся только для символа пробела (строки
  26 и 28); сама клавиша называется «Гьоркьоб бакӀ» по правке рецензента.
- Название приложения по-русски («Аварская клавиатура») — ждёт решения по
  родному названию (напр. «МагӀарул клавиатура»).
