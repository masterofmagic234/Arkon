extends RefCounted
## Original dialogue; the faces and input are owned by Level3Dialogue.

const RECEPTION: Array[Dictionary] = [
    {"speaker":"КАРОЛИНА", "portrait":"carolina", "text":"Эй! Здесь кто-нибудь есть? Я за пиццей."},
    {"speaker":"КАРОЛИНА", "portrait":"carolina", "text":"Ладно. Похоже, всё самое интересное опять на кухне."},
]

const KITCHEN: Array[Dictionary] = [
    {"speaker":"КАРОЛИНА", "portrait":"carolina", "text":"Добрый вечер. Где моя пицца? Я заказывала ещё до всей этой беготни."},
    {"speaker":"ПОВАР", "portrait":"chef", "text":"Сейчас достану. А это у тебя за спиной… шишкомёт?"},
    {"speaker":"КАРОЛИНА", "portrait":"carolina", "text":"Долгая история. Очень пушистая. Пицца уже готова?"},
    {"speaker":"ПОВАР", "portrait":"chef", "text":"Ты выглядишь как белка в колесе. Только белка обычно без такой пушки."},
    {"speaker":"КАРОЛИНА", "portrait":"carolina", "text":"Поверь, белки сегодня вооружены гораздо лучше меня."},
    {"speaker":"ПОВАР", "portrait":"chef", "text":"Ха. Хорошо, понял. Одну минуту — и забирай свою пиццу."},
]

const AFTERMATH: Array[Dictionary] = [
    {"speaker":"ПОВАР", "portrait":"chef", "expression":"shocked", "text":"Они… они правда были с оружием. Это вообще что сейчас было?"},
    {"speaker":"КАРОЛИНА", "portrait":"carolina", "text":"Я же сказала: долгая история. Где пицца?"},
    {"speaker":"ПОВАР", "portrait":"chef", "expression":"shocked", "text":"Вот. На стойке. Просто забери. За счёт заведения."},
    {"speaker":"КАРОЛИНА", "portrait":"carolina", "text":"Спасибо. Хорошей тебе тихой смены."},
]
