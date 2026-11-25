// mCASTING — langues des voix : catalogue (code ISO 639-1, nom natif, nom anglais, phrases d'extrait) et langues de chaque moteur.
// Une langue n'est proposée que si un modèle installé sait la dire ; l'interface de l'appli reste, elle, en 4 langues.
import Foundation
import NaturalLanguage

/// Langue d'une voix, identifiée par son code ISO 639-1 (« fr », « de », « ja »…). Encodée en simple chaîne (compatible 1.x).
public struct Lang: RawRepresentable, Codable, Hashable, Identifiable, Comparable {
    public let rawValue: String
    /// Code connu du catalogue seulement (sinon nil).
    public init?(rawValue: String) {
        let c = rawValue.lowercased().trimmingCharacters(in: .whitespaces)
        guard Languages.info[c] != nil else { return nil }
        self.rawValue = c
    }
    public init(from d: Decoder) throws {
        let s = try d.singleValueContainer().decode(String.self)
        self = Lang(rawValue: s) ?? .fr
    }
    public func encode(to e: Encoder) throws { var c = e.singleValueContainer(); try c.encode(rawValue) }
    public var id: String { rawValue }
    public static func < (a: Lang, b: Lang) -> Bool { a.order < b.order }

    public static let fr = Lang(rawValue: "fr")!
    public static let en = Lang(rawValue: "en")!
    /// Toutes les langues connues, dans l'ordre d'affichage.
    public static var allCases: [Lang] { Languages.order.compactMap { Lang(rawValue: $0) } }

    var order: Int { Languages.order.firstIndex(of: rawValue) ?? 999 }
    var info: Languages.Info { Languages.info[rawValue]! }
    /// Nom dans la langue elle-même (« Deutsch », « 日本語 »).
    public var native: String { info.native }
    /// Nom anglais (« German ») : sert aux recettes VoiceDesign.
    public var english: String { info.english }
    /// Nom dans la langue de l'interface (« allemand »), fourni par macOS.
    public var localized: String { Locale.current.localizedString(forLanguageCode: rawValue).map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? english }
    /// Code attendu par Qwen3-TTS (« german »).
    public var qwen: String { english.lowercased() }
    /// Code Kokoro (une lettre), nil si Kokoro ne parle pas cette langue.
    public var kokoro: String? { ["en": "a", "fr": "f", "es": "e", "it": "i", "pt": "p", "ja": "j", "zh": "z", "hi": "h"][rawValue] }
    /// Phrases d'extrait : la première se présente (« je m'appelle %@ »), la seconde est inquiète.
    public var samples: [String] { info.samples }
    /// Langue préférée du système si elle est connue, sinon l'anglais.
    public static var system: Lang { Locale.preferredLanguages.lazy.compactMap { Lang(rawValue: String($0.prefix(2))) }.first ?? .en }
}

public enum Languages {
    /// Langue d'un texte (transcription d'un extrait à cloner), si la détection est sûre et que Qwen3 la parle.
    /// Un extrait français enregistré comme « anglais » faisait divaguer le modèle (clone de Hoagie, 25/11/2026).
    public static func detect(_ text: String) -> Lang? {
        let r = NLLanguageRecognizer(); r.processString(text)
        guard let (code, p) = r.languageHypotheses(withMaximum: 1).first, p >= 0.8 else { return nil }
        let c = String(code.rawValue.prefix(2))
        return qwen3.contains(c) ? Lang(rawValue: c) : nil
    }

    struct Info { let native: String; let english: String; let samples: [String] }

    /// Langues de Qwen3-TTS (VoiceDesign, Base) : celles de la bibliothèque.
    public static let qwen3 = ["fr", "en", "de", "es", "it", "pt", "ru", "zh", "ja", "ko"]
    /// Chatterbox multilingue v3.
    public static let chatterbox = ["ar", "da", "de", "el", "en", "es", "fi", "fr", "he", "hi", "it", "ja", "ko", "ms", "nl", "no", "pl", "pt", "ru", "sv", "sw", "tr", "zh"]
    /// Fish Audio Drama 3.
    public static let fish = ["en", "zh", "ja", "ko", "fr", "de", "es", "ar", "ru", "nl", "it", "pl", "pt"]

    static let order = ["fr", "en", "de", "es", "it", "pt", "ru", "zh", "ja", "ko", "ar", "hi", "nl", "pl", "tr", "sv", "da", "no", "fi", "el", "he", "ms", "sw"]

    static let info: [String: Info] = [
        "fr": .init(native: "Français", english: "French", samples: [
            "Bonjour, je m'appelle %@. Il fait beau ce matin, mais je crois qu'un orage arrive avant ce soir.",
            "Attendez, vous avez entendu ça ? Quelqu'un marche derrière la porte, et je ne suis pas rassuré du tout."]),
        "en": .init(native: "English", english: "English", samples: [
            "Hello, my name is %@. It's a lovely morning, but I think a storm is coming before tonight.",
            "Wait, did you hear that? Someone is walking behind the door, and I'm not reassured at all."]),
        "de": .init(native: "Deutsch", english: "German", samples: [
            "Hallo, ich heiße %@. Heute Morgen ist es schön, aber ich glaube, vor heute Abend zieht ein Gewitter auf.",
            "Warte, hast du das gehört? Jemand geht hinter der Tür, und mir ist gar nicht wohl dabei."]),
        "es": .init(native: "Español", english: "Spanish", samples: [
            "Hola, me llamo %@. Hace buen tiempo esta mañana, pero creo que llegará una tormenta antes de esta noche.",
            "Espera, ¿has oído eso? Alguien camina detrás de la puerta, y no estoy nada tranquilo."]),
        "it": .init(native: "Italiano", english: "Italian", samples: [
            "Ciao, mi chiamo %@. Stamattina è una bella giornata, ma credo che arriverà un temporale prima di stasera.",
            "Aspetta, hai sentito? Qualcuno cammina dietro la porta, e non sono per niente tranquillo."]),
        "pt": .init(native: "Português", english: "Portuguese", samples: [
            "Olá, meu nome é %@. A manhã está linda, mas acho que uma tempestade vai chegar antes da noite.",
            "Espera, você ouviu isso? Tem alguém andando atrás da porta, e eu não estou nada tranquilo."]),
        "ru": .init(native: "Русский", english: "Russian", samples: [
            "Здравствуйте, меня зовут %@. Сегодня утром прекрасная погода, но, кажется, к вечеру начнётся гроза.",
            "Подождите, вы это слышали? Кто-то ходит за дверью, и мне совсем не по себе."]),
        "zh": .init(native: "中文", english: "Chinese", samples: [
            "你好，我叫%@。今天早上天气很好，但我觉得今晚之前会有一场暴风雨。",
            "等等，你听到了吗？门后面有人在走动，我一点也不放心。"]),
        "ja": .init(native: "日本語", english: "Japanese", samples: [
            "こんにちは、%@です。今朝はいい天気ですが、今夜までに嵐が来そうな気がします。",
            "待って、今の聞こえた？ドアの向こうで誰かが歩いていて、全然落ち着かないんだ。"]),
        "ko": .init(native: "한국어", english: "Korean", samples: [
            "안녕하세요, 제 이름은 %@입니다. 오늘 아침은 날씨가 좋지만, 저녁이 되기 전에 폭풍이 올 것 같아요.",
            "잠깐, 방금 그 소리 들었어요? 누군가 문 뒤에서 걷고 있는데, 정말 불안해요."]),
        "ar": .init(native: "العربية", english: "Arabic", samples: [
            "مرحبًا، اسمي %@. الطقس جميل هذا الصباح، لكنني أظن أن عاصفة ستأتي قبل الليل.",
            "انتظر، هل سمعت ذلك؟ أحدهم يمشي خلف الباب، ولست مطمئنًا أبدًا."]),
        "hi": .init(native: "हिन्दी", english: "Hindi", samples: [
            "नमस्ते, मेरा नाम %@ है। आज सुबह मौसम अच्छा है, लेकिन मुझे लगता है कि शाम से पहले तूफ़ान आएगा।",
            "रुको, तुमने वह सुना? दरवाज़े के पीछे कोई चल रहा है, और मुझे बिल्कुल भी अच्छा नहीं लग रहा।"]),
        "nl": .init(native: "Nederlands", english: "Dutch", samples: [
            "Hallo, ik heet %@. Het is een mooie ochtend, maar ik denk dat er voor vanavond een onweersbui aankomt.",
            "Wacht, hoorde je dat? Er loopt iemand achter de deur, en ik vertrouw het helemaal niet."]),
        "pl": .init(native: "Polski", english: "Polish", samples: [
            "Cześć, nazywam się %@. Jest piękny poranek, ale chyba przed wieczorem przyjdzie burza.",
            "Czekaj, słyszałeś to? Ktoś chodzi za drzwiami i wcale mi się to nie podoba."]),
        "tr": .init(native: "Türkçe", english: "Turkish", samples: [
            "Merhaba, benim adım %@. Bu sabah hava çok güzel ama sanırım akşamdan önce bir fırtına geliyor.",
            "Bekle, bunu duydun mu? Kapının arkasında biri yürüyor ve hiç içim rahat değil."]),
        "sv": .init(native: "Svenska", english: "Swedish", samples: [
            "Hej, jag heter %@. Det är en vacker morgon, men jag tror att ett åskväder kommer före kvällen.",
            "Vänta, hörde du det? Någon går bakom dörren, och jag känner mig inte alls lugn."]),
        "da": .init(native: "Dansk", english: "Danish", samples: [
            "Hej, jeg hedder %@. Det er en dejlig morgen, men jeg tror, der kommer et tordenvejr inden i aften.",
            "Vent, hørte du det? Der går nogen bag døren, og jeg er slet ikke rolig."]),
        "no": .init(native: "Norsk", english: "Norwegian", samples: [
            "Hei, jeg heter %@. Det er en fin morgen, men jeg tror det kommer et tordenvær før i kveld.",
            "Vent, hørte du det? Noen går bak døra, og jeg er ikke rolig i det hele tatt."]),
        "fi": .init(native: "Suomi", english: "Finnish", samples: [
            "Hei, nimeni on %@. Aamu on kaunis, mutta luulen, että ukkonen tulee ennen iltaa.",
            "Odota, kuulitko tuon? Joku kävelee oven takana, enkä ole yhtään rauhallinen."]),
        "el": .init(native: "Ελληνικά", english: "Greek", samples: [
            "Γεια σας, με λένε %@. Έχει ωραία μέρα σήμερα το πρωί, αλλά νομίζω ότι θα έρθει καταιγίδα πριν το βράδυ.",
            "Περίμενε, το άκουσες αυτό; Κάποιος περπατάει πίσω από την πόρτα, και δεν νιώθω καθόλου ήσυχος."]),
        "he": .init(native: "עברית", english: "Hebrew", samples: [
            "שלום, קוראים לי %@. הבוקר מזג האוויר יפה, אבל נראה לי שתגיע סערה לפני הערב.",
            "רגע, שמעת את זה? מישהו הולך מאחורי הדלת, ואני בכלל לא רגוע."]),
        "ms": .init(native: "Bahasa Melayu", english: "Malay", samples: [
            "Helo, nama saya %@. Pagi ini cuaca cerah, tetapi saya rasa ribut akan datang sebelum malam.",
            "Tunggu, awak dengar itu? Ada orang berjalan di belakang pintu, dan saya langsung tidak tenang."]),
        "sw": .init(native: "Kiswahili", english: "Swahili", samples: [
            "Habari, jina langu ni %@. Hali ya hewa ni nzuri asubuhi hii, lakini nadhani dhoruba itakuja kabla ya usiku.",
            "Subiri, umesikia hivyo? Mtu anatembea nyuma ya mlango, na sina amani hata kidogo."]),
    ]

    /// Langues que sait dire un modèle.
    public static func of(_ m: TTSModel) -> [Lang] {
        let codes: [String]
        switch (m.family, m.id) {
        case ("qwen3", _): codes = qwen3
        case (_, "chatterbox-ml"): codes = chatterbox
        case (_, "chatterbox"): codes = ["en"]
        case ("fish", _): codes = fish
        case ("omnivoice", _): codes = order            // modèle annoncé pour plus de 600 langues : tout le catalogue
        default: codes = []
        }
        return codes.compactMap { Lang(rawValue: $0) }.sorted()
    }
    /// Langues de la bibliothèque : celles du modèle qui crée les voix d'après leur description.
    public static var library: [Lang] { TTSModel.find("qwen3-voicedesign").map(of) ?? [.fr, .en] }
    /// Langues d'écoute à la demande : celles d'au moins un modèle de clonage installé (Qwen3 Base au minimum).
    public static func listenable() -> [Lang] {
        let ms = TTSModel.catalog.filter { $0.acting && $0.installed }
        let all = Set(ms.flatMap(of)).union(library)
        return all.sorted()
    }
    /// Modèle de clonage à utiliser pour dire `lang` : celui choisi s'il la parle, sinon le premier installé qui la parle.
    public static func actingModel(for lang: Lang, preferred: String?) -> TTSModel? {
        let ok: (TTSModel) -> Bool = { $0.installed && of($0).contains(lang) }
        if let p = preferred.flatMap(TTSModel.find), ok(p) { return p }
        if let b = TTSModel.find("qwen3-base"), ok(b) { return b }
        return TTSModel.acting.first(where: ok)
    }
}
