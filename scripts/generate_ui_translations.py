#!/usr/bin/env python3
"""
Generate ui_translations/{lang}.json files for manual translation entries.

These JSON files provide translations for strings that don't exist in HelpText
(UI labels, custom descriptions, format strings, NPC names, etc.).
The generate_language_files.py script uses these as fallback when HelpText
lookup fails.

Usage:
    python generate_ui_translations.py
"""

import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "ui_translations")

# ============================================================
# Translation data organized by table -> lang -> {key: value}
# ============================================================

# Helper: for tables where most languages keep the English value,
# define only the languages that differ.

TRANSLATIONS = {}

# --- UIStrings ---
# Screen/menu names, status labels, format strings
# %s placeholders must be preserved in all translations

def _ui():
    """Build UIStrings translations for all languages."""
    # Base structure: key -> {lang: translation}
    t = {
        # Screen names
        "RewardMenu": {
            "fr": "Menu des récompenses", "de": "Belohnungsmenü", "es": "Menú de recompensas",
            "it": "Menu ricompense", "pt-BR": "Menu de recompensas", "ru": "Меню наград",
            "pl": "Menu nagród", "ja": "報酬メニュー", "ko": "보상 메뉴", "zh-CN": "奖励菜单",
        },
        "DoorMenu": {
            "fr": "Menu des portes", "de": "Türmenü", "es": "Menú de puertas",
            "it": "Menu porte", "pt-BR": "Menu de portas", "ru": "Меню дверей",
            "pl": "Menu drzwi", "ja": "ドアメニュー", "ko": "문 메뉴", "zh-CN": "门菜单",
        },
        "StoreMenu": {
            "fr": "Menu de la boutique", "de": "Ladenmenü", "es": "Menú de tienda",
            "it": "Menu negozio", "pt-BR": "Menu da loja", "ru": "Меню магазина",
            "pl": "Menu sklepu", "ja": "ショップメニュー", "ko": "상점 메뉴", "zh-CN": "商店菜单",
        },
        "ResourceInfo": {
            "fr": "Infos ressources", "de": "Ressourceninfo", "es": "Info de recursos",
            "it": "Info risorse", "pt-BR": "Info de recursos", "ru": "Информация о ресурсах",
            "pl": "Informacje o zasobach", "ja": "リソース情報", "ko": "자원 정보", "zh-CN": "资源信息",
        },
        "Relationships": {
            "fr": "Relations", "de": "Beziehungen", "es": "Relaciones",
            "it": "Relazioni", "pt-BR": "Relacionamentos", "ru": "Отношения",
            "pl": "Relacje", "ja": "関係", "ko": "관계", "zh-CN": "关系",
        },
        "MirrorOfNight": {
            "fr": "Miroir de la Nuit", "de": "Spiegel der Nacht", "es": "Espejo de la Noche",
            "it": "Specchio della Notte", "pt-BR": "Espelho da Noite", "ru": "Зеркало Ночи",
            "pl": "Zwierciadło Nocy", "ja": "夜の鏡", "ko": "밤의 거울", "zh-CN": "夜之镜",
        },
        "PactOfPunishment": {
            "fr": "Pacte de Châtiment", "de": "Pakt der Bestrafung", "es": "Pacto de Castigo",
            "it": "Patto di Punizione", "pt-BR": "Pacto de Punição", "ru": "Пакт Наказания",
            "pl": "Pakt Kary", "ja": "罰の契約", "ko": "징벌의 서약", "zh-CN": "惩罚契约",
        },
        "HouseContractor": {
            "fr": "Entrepreneur de la Maison", "de": "Hausunternehmer", "es": "Contratista de la Casa",
            "it": "Appaltatore della Casa", "pt-BR": "Empreiteiro da Casa", "ru": "Подрядчик Дома",
            "pl": "Wykonawca Domu", "ja": "家の請負人", "ko": "집 도급업자", "zh-CN": "房屋承包商",
        },
        "FatedList": {
            "fr": "Liste Fatidique des Prophéties Mineures", "de": "Schicksalsliste kleiner Prophezeiungen",
            "es": "Lista del Destino de Profecías Menores", "it": "Lista del Fato di Profezie Minori",
            "pt-BR": "Lista do Destino de Profecias Menores", "ru": "Предначертанный Список Малых Пророчеств",
            "pl": "Lista Przeznaczenia Mniejszych Proroctw", "ja": "小預言の宿命リスト",
            "ko": "소예언의 운명 목록", "zh-CN": "小预言的命运清单",
        },
        "RunTracker": {
            "fr": "Suivi de course", "de": "Lauf-Tracker", "es": "Rastreador de carrera",
            "it": "Tracciatore di run", "pt-BR": "Rastreador de corrida", "ru": "Трекер забегов",
            "pl": "Śledzenie przebiegów", "ja": "ラントラッカー", "ko": "런 추적기", "zh-CN": "逃亡追踪器",
        },
        "KeepsakeDisplayCase": {
            "fr": "Vitrine de souvenirs", "de": "Andenken-Vitrine", "es": "Vitrina de recuerdos",
            "it": "Vetrina dei ricordi", "pt-BR": "Vitrine de lembranças", "ru": "Витрина памятных вещей",
            "pl": "Gablota pamiątek", "ja": "形見ケース", "ko": "기념품 진열장", "zh-CN": "纪念品陈列柜",
        },
        "WellOfCharon": {
            "fr": "Puits de Charon", "de": "Charons Brunnen", "es": "Pozo de Caronte",
            "it": "Pozzo di Caronte", "pt-BR": "Poço de Caronte", "ru": "Колодец Харона",
            "pl": "Studnia Charona", "ja": "カロンの井戸", "ko": "카론의 우물", "zh-CN": "卡戎之井",
        },
        "WretchedBroker": {
            "fr": "Courtier misérable", "de": "Elender Makler", "es": "Corredor miserable",
            "it": "Mediatore miserabile", "pt-BR": "Corretor miserável", "ru": "Жалкий Маклер",
            "pl": "Nędzny Pośrednik", "ja": "哀れな仲買人", "ko": "비참한 중개인", "zh-CN": "可悲的掮客",
        },
        "BoonInventory": {
            "fr": "Inventaire de faveurs", "de": "Segen-Inventar", "es": "Inventario de dones",
            "it": "Inventario dei doni", "pt-BR": "Inventário de bênçãos", "ru": "Инвентарь даров",
            "pl": "Inwentarz błogosławieństw", "ja": "恩恵インベントリ", "ko": "은혜 인벤토리", "zh-CN": "恩赐清单",
        },
        "PoolOfPurging": {
            "fr": "Bassin de Purification", "de": "Becken der Läuterung", "es": "Pozo de Purificación",
            "it": "Vasca di Purificazione", "pt-BR": "Poço de Purificação", "ru": "Бассейн Очищения",
            "pl": "Sadzawka Oczyszczenia", "ja": "浄化の泉", "ko": "정화의 웅덩이", "zh-CN": "净化之池",
        },
        "PactInfo": {
            "fr": "Infos du pacte", "de": "Pakt-Info", "es": "Info del pacto",
            "it": "Info patto", "pt-BR": "Info do pacto", "ru": "Информация о пакте",
            "pl": "Informacje o pakcie", "ja": "契約情報", "ko": "서약 정보", "zh-CN": "契约信息",
        },
        "BoonInfo": {
            "fr": "Infos de faveur", "de": "Segen-Info", "es": "Info de don",
            "it": "Info dono", "pt-BR": "Info de bênção", "ru": "Информация о даре",
            "pl": "Informacje o błogosławieństwie", "ja": "恩恵情報", "ko": "은혜 정보", "zh-CN": "恩赐信息",
        },
        "MusicPlayer": {
            "fr": "Lecteur de musique", "de": "Musikspieler", "es": "Reproductor de música",
            "it": "Lettore musicale", "pt-BR": "Reprodutor de música", "ru": "Музыкальный проигрыватель",
            "pl": "Odtwarzacz muzyki", "ja": "ミュージックプレイヤー", "ko": "음악 재생기", "zh-CN": "音乐播放器",
        },
        "WeaponAspects": {
            "fr": "Aspects d'arme", "de": "Waffenaspekte", "es": "Aspectos de arma",
            "it": "Aspetti dell'arma", "pt-BR": "Aspectos de arma", "ru": "Аспекты оружия",
            "pl": "Aspekty broni", "ja": "武器のアスペクト", "ko": "무기 양상", "zh-CN": "武器面貌",
        },
        "BoonTray": {
            "fr": "Plateau de faveurs", "de": "Segen-Übersicht", "es": "Bandeja de dones",
            "it": "Vassoio dei doni", "pt-BR": "Bandeja de bênçãos", "ru": "Список даров",
            "pl": "Taca błogosławieństw", "ja": "恩恵トレイ", "ko": "은혜 목록", "zh-CN": "恩赐栏",
        },
        "Codex": {
            "fr": "Codex", "de": "Kodex", "es": "Códex",
            "it": "Codice", "pt-BR": "Códice", "ru": "Кодекс",
            "pl": "Kodeks", "ja": "コデックス", "ko": "코덱스", "zh-CN": "法典",
        },
        "RunHistory": {
            "fr": "Historique de courses", "de": "Lauf-Verlauf", "es": "Historial de carreras",
            "it": "Cronologia delle run", "pt-BR": "Histórico de corridas", "ru": "История забегов",
            "pl": "Historia przebiegów", "ja": "ランの履歴", "ko": "런 기록", "zh-CN": "逃亡历史",
        },
        "RunClear": {
            "fr": "Course réussie", "de": "Lauf abgeschlossen", "es": "Carrera completada",
            "it": "Run completata", "pt-BR": "Corrida concluída", "ru": "Забег завершён",
            "pl": "Przebieg ukończony", "ja": "ランクリア", "ko": "런 클리어", "zh-CN": "逃亡成功",
        },
        "ScryingPool": {
            "fr": "Bassin de divination", "de": "Wahrsagebecken", "es": "Pozo de adivinación",
            "it": "Vasca divinatoria", "pt-BR": "Poço de adivinhação", "ru": "Чаша провидения",
            "pl": "Sadzawka wróżbiarska", "ja": "占いの泉", "ko": "점술의 웅덩이", "zh-CN": "占卜池",
        },
        # Rarity
        "Common": {
            "fr": "Commun", "de": "Gewöhnlich", "es": "Común",
            "it": "Comune", "pt-BR": "Comum", "ru": "Обычный",
            "pl": "Zwykły", "ja": "コモン", "ko": "일반", "zh-CN": "普通",
        },
        "Rare": {
            "fr": "Rare", "de": "Selten", "es": "Raro",
            "it": "Raro", "pt-BR": "Raro", "ru": "Редкий",
            "pl": "Rzadki", "ja": "レア", "ko": "희귀", "zh-CN": "稀有",
        },
        "Epic": {
            "fr": "Épique", "de": "Episch", "es": "Épico",
            "it": "Epico", "pt-BR": "Épico", "ru": "Эпический",
            "pl": "Epicki", "ja": "エピック", "ko": "서사", "zh-CN": "史诗",
        },
        "Heroic": {
            "fr": "Héroïque", "de": "Heroisch", "es": "Heroico",
            "it": "Eroico", "pt-BR": "Heroico", "ru": "Героический",
            "pl": "Heroiczny", "ja": "ヒロイック", "ko": "영웅", "zh-CN": "英雄",
        },
        "Legendary": {
            "fr": "Légendaire", "de": "Legendär", "es": "Legendario",
            "it": "Leggendario", "pt-BR": "Lendário", "ru": "Легендарный",
            "pl": "Legendarny", "ja": "レジェンダリー", "ko": "전설", "zh-CN": "传奇",
        },
        "Duo": {
            "fr": "Duo", "de": "Duo", "es": "Dúo",
            "it": "Duo", "pt-BR": "Duo", "ru": "Дуэт",
            "pl": "Duo", "ja": "デュオ", "ko": "듀오", "zh-CN": "双重",
        },
        # Status labels
        "Locked": {
            "fr": "Verrouillé", "de": "Gesperrt", "es": "Bloqueado",
            "it": "Bloccato", "pt-BR": "Bloqueado", "ru": "Заблокировано",
            "pl": "Zablokowane", "ja": "ロック", "ko": "잠김", "zh-CN": "已锁定",
        },
        "CannotAfford": {
            "fr": "Pas assez de ressources", "de": "Nicht genug Ressourcen", "es": "No puedes permitírtelo",
            "it": "Non puoi permettertelo", "pt-BR": "Sem recursos", "ru": "Недостаточно средств",
            "pl": "Nie stać cię", "ja": "購入不可", "ko": "구매 불가", "zh-CN": "资源不足",
        },
        "Equipped": {
            "fr": "Équipé", "de": "Ausgerüstet", "es": "Equipado",
            "it": "Equipaggiato", "pt-BR": "Equipado", "ru": "Экипировано",
            "pl": "Wyposażony", "ja": "装備中", "ko": "장착됨", "zh-CN": "已装备",
        },
        "Acquired": {
            "fr": "Acquis", "de": "Erhalten", "es": "Adquirido",
            "it": "Acquisito", "pt-BR": "Adquirido", "ru": "Получено",
            "pl": "Zdobyto", "ja": "取得", "ko": "획득", "zh-CN": "已获得",
        },
        "Purchased": {
            "fr": "Acheté", "de": "Gekauft", "es": "Comprado",
            "it": "Acquistato", "pt-BR": "Comprado", "ru": "Куплено",
            "pl": "Kupione", "ja": "購入済み", "ko": "구매됨", "zh-CN": "已购买",
        },
        "Sold": {
            "fr": "Vendu", "de": "Verkauft", "es": "Vendido",
            "it": "Venduto", "pt-BR": "Vendido", "ru": "Продано",
            "pl": "Sprzedano", "ja": "売却済み", "ko": "판매됨", "zh-CN": "已出售",
        },
        "Blocked": {
            "fr": "Bloqué", "de": "Blockiert", "es": "Bloqueado",
            "it": "Bloccato", "pt-BR": "Bloqueado", "ru": "Заблокировано",
            "pl": "Zablokowane", "ja": "ブロック", "ko": "차단됨", "zh-CN": "已阻止",
        },
        "Active": {
            "fr": "Actif", "de": "Aktiv", "es": "Activo",
            "it": "Attivo", "pt-BR": "Ativo", "ru": "Активно",
            "pl": "Aktywne", "ja": "有効", "ko": "활성", "zh-CN": "激活",
        },
        "MaxLevel": {
            "fr": "Niveau max", "de": "Max. Stufe", "es": "Nivel máximo",
            "it": "Livello massimo", "pt-BR": "Nível máximo", "ru": "Макс. уровень",
            "pl": "Maks. poziom", "ja": "最大レベル", "ko": "최대 레벨", "zh-CN": "最高等级",
        },
        "MaxRank": {
            "fr": "Rang max", "de": "Max. Rang", "es": "Rango máximo",
            "it": "Grado massimo", "pt-BR": "Posto máximo", "ru": "Макс. ранг",
            "pl": "Maks. ranga", "ja": "最大ランク", "ko": "최대 등급", "zh-CN": "最高阶级",
        },
        # Resources
        "Darkness": {
            "fr": "Ténèbres", "de": "Dunkelheit", "es": "Oscuridad",
            "it": "Oscurità", "pt-BR": "Escuridão", "ru": "Тьма",
            "pl": "Ciemność", "ja": "闇", "ko": "어둠", "zh-CN": "暗之力",
        },
        "Gemstones": {
            "fr": "Pierres précieuses", "de": "Edelsteine", "es": "Gemas",
            "it": "Gemme", "pt-BR": "Pedras preciosas", "ru": "Самоцветы",
            "pl": "Klejnoty", "ja": "宝石", "ko": "보석", "zh-CN": "宝石",
        },
        "ChthonicKeys": {
            "fr": "Clés Chtoniennes", "de": "Chthonische Schlüssel", "es": "Llaves Ctónicas",
            "it": "Chiavi Ctonie", "pt-BR": "Chaves Ctônicas", "ru": "Хтонические Ключи",
            "pl": "Chtoniczne Klucze", "ja": "冥界の鍵", "ko": "지하 열쇠", "zh-CN": "冥界之钥",
        },
        "Obols": {
            "fr": "Oboles", "de": "Obolen", "es": "Óbolos",
            "it": "Oboli", "pt-BR": "Óbolos", "ru": "Оболы",
            "pl": "Obole", "ja": "オボル", "ko": "오볼", "zh-CN": "冥币",
        },
        "Nectar": {
            "fr": "Nectar", "de": "Nektar", "es": "Néctar",
            "it": "Nettare", "pt-BR": "Néctar", "ru": "Нектар",
            "pl": "Nektar", "ja": "ネクター", "ko": "넥타르", "zh-CN": "琼浆",
        },
        "Ambrosia": {
            "fr": "Ambroisie", "de": "Ambrosia", "es": "Ambrosía",
            "it": "Ambrosia", "pt-BR": "Ambrosia", "ru": "Амброзия",
            "pl": "Ambrozja", "ja": "アンブロシア", "ko": "암브로시아", "zh-CN": "仙酿",
        },
        "TitanBlood": {
            "fr": "Sang de Titan", "de": "Titanenblut", "es": "Sangre de Titán",
            "it": "Sangue di Titano", "pt-BR": "Sangue de Titã", "ru": "Кровь Титана",
            "pl": "Krew Tytana", "ja": "タイタンの血", "ko": "타이탄 피", "zh-CN": "泰坦之血",
        },
        "Diamonds": {
            "fr": "Diamants", "de": "Diamanten", "es": "Diamantes",
            "it": "Diamanti", "pt-BR": "Diamantes", "ru": "Алмазы",
            "pl": "Diamenty", "ja": "ダイヤモンド", "ko": "다이아몬드", "zh-CN": "钻石",
        },
        "Health": {
            "fr": "Santé", "de": "Leben", "es": "Salud",
            "it": "Salute", "pt-BR": "Saúde", "ru": "Здоровье",
            "pl": "Zdrowie", "ja": "体力", "ko": "체력", "zh-CN": "生命",
        },
        "MaxHealth": {
            "fr": "Santé max", "de": "Max. Leben", "es": "Salud máxima",
            "it": "Salute massima", "pt-BR": "Saúde máxima", "ru": "Макс. здоровье",
            "pl": "Maks. zdrowie", "ja": "最大体力", "ko": "최대 체력", "zh-CN": "最大生命",
        },
        "Healing": {
            "fr": "Guérison", "de": "Heilung", "es": "Curación",
            "it": "Guarigione", "pt-BR": "Cura", "ru": "Исцеление",
            "pl": "Leczenie", "ja": "回復", "ko": "치유", "zh-CN": "治疗",
        },
        # Navigation
        "Close": {
            "fr": "Fermer", "de": "Schließen", "es": "Cerrar",
            "it": "Chiudi", "pt-BR": "Fechar", "ru": "Закрыть",
            "pl": "Zamknij", "ja": "閉じる", "ko": "닫기", "zh-CN": "关闭",
        },
        "Reroll": {
            "fr": "Relancer", "de": "Neu würfeln", "es": "Repetir tirada",
            "it": "Ritira", "pt-BR": "Jogar de novo", "ru": "Перебросить",
            "pl": "Przerzuć", "ja": "リロール", "ko": "리롤", "zh-CN": "重掷",
        },
        "Page": {
            "fr": "Page", "de": "Seite", "es": "Página",
            "it": "Pagina", "pt-BR": "Página", "ru": "Страница",
            "pl": "Strona", "ja": "ページ", "ko": "페이지", "zh-CN": "页",
        },
        "Of": {
            "fr": "de", "de": "von", "es": "de",
            "it": "di", "pt-BR": "de", "ru": "из",
            "pl": "z", "ja": "/", "ko": "/", "zh-CN": "/",
        },
        "Level": {
            "fr": "Niveau", "de": "Stufe", "es": "Nivel",
            "it": "Livello", "pt-BR": "Nível", "ru": "Уровень",
            "pl": "Poziom", "ja": "レベル", "ko": "레벨", "zh-CN": "等级",
        },
        "Chamber": {
            "fr": "Salle", "de": "Kammer", "es": "Cámara",
            "it": "Camera", "pt-BR": "Câmara", "ru": "Комната",
            "pl": "Komnata", "ja": "部屋", "ko": "방", "zh-CN": "房间",
        },
        "Heat": {
            "fr": "Chaleur", "de": "Hitze", "es": "Calor",
            "it": "Calore", "pt-BR": "Calor", "ru": "Жар",
            "pl": "Żar", "ja": "ヒート", "ko": "열기", "zh-CN": "热度",
        },
        "To": {
            "fr": "à", "de": "bis", "es": "a",
            "it": "a", "pt-BR": "a", "ru": "до",
            "pl": "do", "ja": "から", "ko": "에서", "zh-CN": "至",
        },
        # Combat
        "DeathDefiance": {
            "fr": "Défi de la Mort", "de": "Todestrotz", "es": "Desafío a la Muerte",
            "it": "Sfida alla Morte", "pt-BR": "Desafio da Morte", "ru": "Вызов Смерти",
            "pl": "Trupie Wyzwanie", "ja": "不屈の魂", "ko": "죽음의 저항", "zh-CN": "死亡抗争",
        },
        "LuckyTooth": {
            "fr": "Dent Chanceuse", "de": "Glückszahn", "es": "Diente de la Suerte",
            "it": "Dente Fortunato", "pt-BR": "Dente da Sorte", "ru": "Счастливый Зуб",
            "pl": "Szczęśliwy Ząb", "ja": "幸運の歯", "ko": "행운의 이빨", "zh-CN": "幸运牙齿",
        },
        "Killed": {
            "fr": "Tué", "de": "Getötet", "es": "Eliminado",
            "it": "Ucciso", "pt-BR": "Eliminado", "ru": "Убит",
            "pl": "Zabity", "ja": "撃破", "ko": "처치", "zh-CN": "击杀",
        },
        "Armor": {
            "fr": "armure", "de": "Rüstung", "es": "armadura",
            "it": "armatura", "pt-BR": "armadura", "ru": "броня",
            "pl": "pancerz", "ja": "装甲", "ko": "방어막", "zh-CN": "护甲",
        },
        "ArmorBroken": {
            "fr": "Armure brisée", "de": "Rüstung zerbrochen", "es": "Armadura rota",
            "it": "Armatura rotta", "pt-BR": "Armadura quebrada", "ru": "Броня сломана",
            "pl": "Pancerz zniszczony", "ja": "装甲破壊", "ko": "방어막 파괴", "zh-CN": "护甲破碎",
        },
        # Boon info
        "AttackBoon": {
            "fr": "Faveur d'Attaque", "de": "Angriffssegen", "es": "Don de Ataque",
            "it": "Dono d'Attacco", "pt-BR": "Bênção de Ataque", "ru": "Дар Атаки",
            "pl": "Błogosławieństwo Ataku", "ja": "攻撃の恩恵", "ko": "공격 은혜", "zh-CN": "攻击恩赐",
        },
        "SpecialBoon": {
            "fr": "Faveur de Technique", "de": "Spezialsegen", "es": "Don de Especial",
            "it": "Dono di Tecnica", "pt-BR": "Bênção Especial", "ru": "Дар Умения",
            "pl": "Błogosławieństwo Techniki", "ja": "必殺の恩恵", "ko": "특수 은혜", "zh-CN": "特殊恩赐",
        },
        "CastBoon": {
            "fr": "Faveur de Sort", "de": "Wurfsegen", "es": "Don de Hechizo",
            "it": "Dono di Sortilegio", "pt-BR": "Bênção de Feitiço", "ru": "Дар Каста",
            "pl": "Błogosławieństwo Rzutu", "ja": "魔弾の恩恵", "ko": "시전 은혜", "zh-CN": "施法恩赐",
        },
        "DashBoon": {
            "fr": "Faveur de Sprint", "de": "Sprintsegen", "es": "Don de Sprint",
            "it": "Dono di Scatto", "pt-BR": "Bênção de Dash", "ru": "Дар Рывка",
            "pl": "Błogosławieństwo Zrywu", "ja": "ダッシュの恩恵", "ko": "대시 은혜", "zh-CN": "冲刺恩赐",
        },
        "CallBoon": {
            "fr": "Faveur d'Invocation", "de": "Rufsegen", "es": "Don de Invocación",
            "it": "Dono d'Invocazione", "pt-BR": "Bênção de Chamado", "ru": "Дар Призыва",
            "pl": "Błogosławieństwo Wezwania", "ja": "召喚の恩恵", "ko": "소환 은혜", "zh-CN": "召唤恩赐",
        },
        "Replaces": {
            "fr": "Remplace", "de": "Ersetzt", "es": "Reemplaza",
            "it": "Sostituisce", "pt-BR": "Substitui", "ru": "Заменяет",
            "pl": "Zastępuje", "ja": "置換", "ko": "교체", "zh-CN": "替换",
        },
        # Notifications
        "GodModeEnabled": {
            "fr": "Mode Dieu activé", "de": "Göttermodus aktiviert", "es": "Modo Dios activado",
            "it": "Modalità Dio attivata", "pt-BR": "Modo Deus ativado", "ru": "Режим Бога включён",
            "pl": "Tryb Boga włączony", "ja": "ゴッドモード有効", "ko": "갓 모드 활성화", "zh-CN": "神明模式已启用",
        },
        "GodModeDisabled": {
            "fr": "Mode Dieu désactivé", "de": "Göttermodus deaktiviert", "es": "Modo Dios desactivado",
            "it": "Modalità Dio disattivata", "pt-BR": "Modo Deus desativado", "ru": "Режим Бога выключен",
            "pl": "Tryb Boga wyłączony", "ja": "ゴッドモード無効", "ko": "갓 모드 비활성화", "zh-CN": "神明模式已关闭",
        },
        "PercentDamageResistance": {
            "fr": "pourcent de résistance aux dégâts", "de": "Prozent Schadensresistenz",
            "es": "por ciento de resistencia al daño", "it": "percento di resistenza ai danni",
            "pt-BR": "por cento de resistência a dano", "ru": "процент сопротивления урону",
            "pl": "procent odporności na obrażenia", "ja": "パーセントのダメージ耐性",
            "ko": "퍼센트 피해 저항", "zh-CN": "百分比伤害抗性",
        },
        "SubtitlesOn": {
            "fr": "Sous-titres activés", "de": "Untertitel ein", "es": "Subtítulos activados",
            "it": "Sottotitoli attivati", "pt-BR": "Legendas ativadas", "ru": "Субтитры включены",
            "pl": "Napisy włączone", "ja": "字幕オン", "ko": "자막 켜짐", "zh-CN": "字幕已开启",
        },
        "SubtitlesOff": {
            "fr": "Sous-titres désactivés", "de": "Untertitel aus", "es": "Subtítulos desactivados",
            "it": "Sottotitoli disattivati", "pt-BR": "Legendas desativadas", "ru": "Субтитры выключены",
            "pl": "Napisy wyłączone", "ja": "字幕オフ", "ko": "자막 꺼짐", "zh-CN": "字幕已关闭",
        },
        "Gained": {
            "fr": "Obtenu", "de": "Erhalten", "es": "Obtenido",
            "it": "Ottenuto", "pt-BR": "Ganhou", "ru": "Получено",
            "pl": "Zdobyto", "ja": "獲得", "ko": "획득", "zh-CN": "获得",
        },
        "NewKeepsakeFrom": {
            "fr": "Nouveau souvenir de", "de": "Neues Andenken von", "es": "Nuevo recuerdo de",
            "it": "Nuovo ricordo da", "pt-BR": "Nova lembrança de", "ru": "Новая памятная вещь от",
            "pl": "Nowa pamiątka od", "ja": "新しい形見：", "ko": "새 기념품：", "zh-CN": "新纪念品来自",
        },
        "EquippedKeepsake": {
            "fr": "Souvenir équipé", "de": "Andenken ausgerüstet", "es": "Recuerdo equipado",
            "it": "Ricordo equipaggiato", "pt-BR": "Lembrança equipada", "ru": "Памятная вещь экипирована",
            "pl": "Pamiątka wyposażona", "ja": "形見装備", "ko": "기념품 장착", "zh-CN": "纪念品已装备",
        },
        "EquippedWeapon": {
            "fr": "Arme équipée", "de": "Waffe ausgerüstet", "es": "Arma equipada",
            "it": "Arma equipaggiata", "pt-BR": "Arma equipada", "ru": "Оружие экипировано",
            "pl": "Broń wyposażona", "ja": "武器装備", "ko": "무기 장착", "zh-CN": "武器已装备",
        },
        "Caught": {
            "fr": "Pêché", "de": "Gefangen", "es": "Pescado",
            "it": "Pescato", "pt-BR": "Pescado", "ru": "Поймано",
            "pl": "Złowiono", "ja": "釣り上げ", "ko": "잡음", "zh-CN": "钓到",
        },
        # Quest status
        "InProgress": {
            "fr": "En cours", "de": "In Bearbeitung", "es": "En progreso",
            "it": "In corso", "pt-BR": "Em andamento", "ru": "В процессе",
            "pl": "W toku", "ja": "進行中", "ko": "진행 중", "zh-CN": "进行中",
        },
        "ReadyToCollect": {
            "fr": "Prêt à collecter", "de": "Bereit zum Einsammeln", "es": "Listo para recoger",
            "it": "Pronto per il ritiro", "pt-BR": "Pronto para coletar", "ru": "Готово к сбору",
            "pl": "Gotowe do odebrania", "ja": "回収可能", "ko": "수집 가능", "zh-CN": "可领取",
        },
        "Completed": {
            "fr": "Terminé", "de": "Abgeschlossen", "es": "Completado",
            "it": "Completato", "pt-BR": "Concluído", "ru": "Завершено",
            "pl": "Ukończone", "ja": "完了", "ko": "완료", "zh-CN": "已完成",
        },
        # Contractor
        "WorkOrders": {
            "fr": "Ordres de travail", "de": "Arbeitsaufträge", "es": "Órdenes de trabajo",
            "it": "Ordini di lavoro", "pt-BR": "Ordens de trabalho", "ru": "Рабочие заказы",
            "pl": "Zlecenia pracy", "ja": "作業指示", "ko": "작업 지시", "zh-CN": "工作订单",
        },
        "Available": {
            "fr": "disponible", "de": "verfügbar", "es": "disponible",
            "it": "disponibile", "pt-BR": "disponível", "ru": "доступно",
            "pl": "dostępne", "ja": "利用可能", "ko": "이용 가능", "zh-CN": "可用",
        },
        # Format strings — %s placeholders MUST be preserved
        "MirrorOpenFmt": {
            "fr": "Miroir de la Nuit, %s Ténèbres, %s Clés Chtoniennes",
            "de": "Spiegel der Nacht, %s Dunkelheit, %s Chthonische Schlüssel",
            "es": "Espejo de la Noche, %s Oscuridad, %s Llaves Ctónicas",
            "it": "Specchio della Notte, %s Oscurità, %s Chiavi Ctonie",
            "pt-BR": "Espelho da Noite, %s Escuridão, %s Chaves Ctônicas",
            "ru": "Зеркало Ночи, %s Тьма, %s Хтонические Ключи",
            "pl": "Zwierciadło Nocy, %s Ciemność, %s Chtoniczne Klucze",
            "ja": "夜の鏡、闇 %s、冥界の鍵 %s",
            "ko": "밤의 거울, 어둠 %s, 지하 열쇠 %s",
            "zh-CN": "夜之镜，暗之力 %s，冥界之钥 %s",
        },
        "PactOpenFmt": {
            "fr": "Pacte de Châtiment, %s sur %s Chaleur",
            "de": "Pakt der Bestrafung, %s von %s Hitze",
            "es": "Pacto de Castigo, %s de %s Calor",
            "it": "Patto di Punizione, %s di %s Calore",
            "pt-BR": "Pacto de Punição, %s de %s Calor",
            "ru": "Пакт Наказания, %s из %s Жар",
            "pl": "Pakt Kary, %s z %s Żar",
            "ja": "罰の契約、ヒート %s / %s",
            "ko": "징벌의 서약, 열기 %s / %s",
            "zh-CN": "惩罚契约，热度 %s / %s",
        },
        "StartRunFmt": {
            "fr": "Démarrer la course avec %s Chaleur",
            "de": "Lauf starten mit %s Hitze",
            "es": "Iniciar carrera con %s Calor",
            "it": "Inizia run con %s Calore",
            "pt-BR": "Iniciar corrida com %s Calor",
            "ru": "Начать забег с %s Жар",
            "pl": "Rozpocznij przebieg z %s Żar",
            "ja": "ヒート %s で出発",
            "ko": "열기 %s로 출발",
            "zh-CN": "以热度 %s 开始逃亡",
        },
        "HealthFmt": {
            "fr": "%s santé", "de": "%s Leben", "es": "%s salud",
            "it": "%s salute", "pt-BR": "%s saúde", "ru": "%s здоровье",
            "pl": "%s zdrowie", "ja": "体力 %s", "ko": "체력 %s", "zh-CN": "生命 %s",
        },
        "HealedFmt": {
            "fr": "Guéri %s, %s santé", "de": "Geheilt %s, %s Leben",
            "es": "Curado %s, %s salud", "it": "Guarito %s, %s salute",
            "pt-BR": "Curado %s, %s saúde", "ru": "Исцелено %s, %s здоровье",
            "pl": "Uleczono %s, %s zdrowie", "ja": "回復 %s、体力 %s",
            "ko": "치유 %s, 체력 %s", "zh-CN": "治疗 %s，生命 %s",
        },
        "LostHealthFmt": {
            "fr": "Perdu %s santé, %s restant", "de": "Verloren %s Leben, %s verbleibend",
            "es": "Perdido %s salud, %s restante", "it": "Perso %s salute, %s rimanente",
            "pt-BR": "Perdeu %s saúde, %s restante", "ru": "Потеряно %s здоровья, %s осталось",
            "pl": "Utracono %s zdrowia, %s pozostało", "ja": "体力 %s 減少、残り %s",
            "ko": "체력 %s 감소, %s 남음", "zh-CN": "失去 %s 生命，剩余 %s",
        },
        "LevelFmt": {
            "fr": "Niveau %s", "de": "Stufe %s", "es": "Nivel %s",
            "it": "Livello %s", "pt-BR": "Nível %s", "ru": "Уровень %s",
            "pl": "Poziom %s", "ja": "レベル %s", "ko": "레벨 %s", "zh-CN": "等级 %s",
        },
        "ChamberFmt": {
            "fr": "Salle %s", "de": "Kammer %s", "es": "Cámara %s",
            "it": "Camera %s", "pt-BR": "Câmara %s", "ru": "Комната %s",
            "pl": "Komnata %s", "ja": "部屋 %s", "ko": "방 %s", "zh-CN": "房间 %s",
        },
        "PageFmt": {
            "fr": "Page %s de %s", "de": "Seite %s von %s", "es": "Página %s de %s",
            "it": "Pagina %s di %s", "pt-BR": "Página %s de %s", "ru": "Страница %s из %s",
            "pl": "Strona %s z %s", "ja": "ページ %s / %s", "ko": "페이지 %s / %s", "zh-CN": "第 %s 页，共 %s 页",
        },
        "GainedFmt": {
            "fr": "Obtenu %s %s", "de": "Erhalten %s %s", "es": "Obtenido %s %s",
            "it": "Ottenuto %s %s", "pt-BR": "Ganhou %s %s", "ru": "Получено %s %s",
            "pl": "Zdobyto %s %s", "ja": "%s %s を獲得", "ko": "%s %s 획득", "zh-CN": "获得 %s %s",
        },
        "AcquiredFmt": {
            "fr": "Acquis : %s", "de": "Erhalten: %s", "es": "Adquirido: %s",
            "it": "Acquisito: %s", "pt-BR": "Adquirido: %s", "ru": "Получено: %s",
            "pl": "Zdobyto: %s", "ja": "取得：%s", "ko": "획득: %s", "zh-CN": "获得：%s",
        },
        "SoldFmt": {
            "fr": "Vendu %s pour %s Oboles", "de": "Verkauft %s für %s Obolen",
            "es": "Vendido %s por %s Óbolos", "it": "Venduto %s per %s Oboli",
            "pt-BR": "Vendido %s por %s Óbolos", "ru": "Продано %s за %s Оболов",
            "pl": "Sprzedano %s za %s Oboli", "ja": "%s を %s オボルで売却",
            "ko": "%s을(를) %s 오볼에 판매", "zh-CN": "以 %s 冥币出售 %s",
        },
        "EquippedFmt": {
            "fr": "Équipé %s", "de": "Ausgerüstet %s", "es": "Equipado %s",
            "it": "Equipaggiato %s", "pt-BR": "Equipado %s", "ru": "Экипировано %s",
            "pl": "Wyposażono %s", "ja": "%s 装備", "ko": "%s 장착", "zh-CN": "已装备 %s",
        },
        "CaughtFmt": {
            "fr": "Pêché : %s", "de": "Gefangen: %s", "es": "Pescado: %s",
            "it": "Pescato: %s", "pt-BR": "Pescado: %s", "ru": "Поймано: %s",
            "pl": "Złowiono: %s", "ja": "釣り上げ：%s", "ko": "잡음: %s", "zh-CN": "钓到：%s",
        },
        "DeathDefianceFmt": {
            "fr": "Défi de la Mort ! %s restant", "de": "Todestrotz! %s verbleibend",
            "es": "¡Desafío a la Muerte! %s restante", "it": "Sfida alla Morte! %s rimanente",
            "pt-BR": "Desafio da Morte! %s restante", "ru": "Вызов Смерти! Осталось %s",
            "pl": "Trupie Wyzwanie! %s pozostało", "ja": "不屈の魂！残り %s",
            "ko": "죽음의 저항! %s 남음", "zh-CN": "死亡抗争！剩余 %s",
        },
        "LuckyToothFmt": {
            "fr": "Dent Chanceuse !", "de": "Glückszahn!", "es": "¡Diente de la Suerte!",
            "it": "Dente Fortunato!", "pt-BR": "Dente da Sorte!", "ru": "Счастливый Зуб!",
            "pl": "Szczęśliwy Ząb!", "ja": "幸運の歯！", "ko": "행운의 이빨!", "zh-CN": "幸运牙齿！",
        },
        "NowPlayingFmt": {
            "fr": "En cours : %s", "de": "Läuft: %s", "es": "Reproduciendo: %s",
            "it": "In riproduzione: %s", "pt-BR": "Reproduzindo: %s", "ru": "Сейчас играет: %s",
            "pl": "Teraz gra: %s", "ja": "再生中：%s", "ko": "재생 중: %s", "zh-CN": "正在播放：%s",
        },
        "PausedFmt": {
            "fr": "En pause : %s", "de": "Pausiert: %s", "es": "Pausado: %s",
            "it": "In pausa: %s", "pt-BR": "Pausado: %s", "ru": "Пауза: %s",
            "pl": "Wstrzymano: %s", "ja": "一時停止：%s", "ko": "일시정지: %s", "zh-CN": "已暂停：%s",
        },
        "ResumedFmt": {
            "fr": "Reprise : %s", "de": "Fortgesetzt: %s", "es": "Reanudado: %s",
            "it": "Ripreso: %s", "pt-BR": "Retomado: %s", "ru": "Продолжение: %s",
            "pl": "Wznowiono: %s", "ja": "再開：%s", "ko": "재개: %s", "zh-CN": "已恢复：%s",
        },
        "UnlockCostFmt": {
            "fr": "%s %s pour débloquer", "de": "%s %s zum Freischalten",
            "es": "%s %s para desbloquear", "it": "%s %s per sbloccare",
            "pt-BR": "%s %s para desbloquear", "ru": "%s %s для разблокировки",
            "pl": "%s %s do odblokowania", "ja": "解放に %s %s 必要",
            "ko": "잠금 해제에 %s %s 필요", "zh-CN": "解锁需要 %s %s",
        },
        "FatedPersuasionFmt": {
            "fr": "Persuasion du destin, Relance %s", "de": "Schicksalsüberredung, Neu würfeln %s",
            "es": "Persuasión del destino, Repetir %s", "it": "Persuasione del fato, Ritira %s",
            "pt-BR": "Persuasão do destino, Jogar de novo %s", "ru": "Убеждение судьбы, Перебросить %s",
            "pl": "Namowa przeznaczenia, Przerzuć %s", "ja": "運命の説得、リロール %s",
            "ko": "운명의 설득, 리롤 %s", "zh-CN": "命运说服，重掷 %s",
        },
        "AddHeatFmt": {
            "fr": "Ajoute %s Chaleur", "de": "Fügt %s Hitze hinzu", "es": "Añade %s Calor",
            "it": "Aggiunge %s Calore", "pt-BR": "Adiciona %s Calor", "ru": "Добавляет %s Жар",
            "pl": "Dodaje %s Żar", "ja": "ヒート %s 追加", "ko": "열기 %s 추가", "zh-CN": "增加 %s 热度",
        },
        "RemoveHeatFmt": {
            "fr": "Retire %s Chaleur", "de": "Entfernt %s Hitze", "es": "Quita %s Calor",
            "it": "Rimuove %s Calore", "pt-BR": "Remove %s Calor", "ru": "Убирает %s Жар",
            "pl": "Usuwa %s Żar", "ja": "ヒート %s 削減", "ko": "열기 %s 제거", "zh-CN": "减少 %s 热度",
        },
        "SwitchToFmt": {
            "fr": "Passer à %s", "de": "Wechseln zu %s", "es": "Cambiar a %s",
            "it": "Passa a %s", "pt-BR": "Mudar para %s", "ru": "Переключить на %s",
            "pl": "Przełącz na %s", "ja": "%s に切替", "ko": "%s(으)로 전환", "zh-CN": "切换为 %s",
        },
        "SwitchedToFmt": {
            "fr": "Passé à %s", "de": "Gewechselt zu %s", "es": "Cambiado a %s",
            "it": "Passato a %s", "pt-BR": "Mudado para %s", "ru": "Переключено на %s",
            "pl": "Przełączono na %s", "ja": "%s に切替完了", "ko": "%s(으)로 전환됨", "zh-CN": "已切换为 %s",
        },
        "LockedKeyCostFmt": {
            "fr": "Verrouillé, %s Clés Chtoniennes pour débloquer",
            "de": "Gesperrt, %s Chthonische Schlüssel zum Freischalten",
            "es": "Bloqueado, %s Llaves Ctónicas para desbloquear",
            "it": "Bloccato, %s Chiavi Ctonie per sbloccare",
            "pt-BR": "Bloqueado, %s Chaves Ctônicas para desbloquear",
            "ru": "Заблокировано, %s Хтонических Ключей для разблокировки",
            "pl": "Zablokowane, %s Chtonicznych Kluczy do odblokowania",
            "ja": "ロック、解放に冥界の鍵 %s 必要",
            "ko": "잠김, 잠금 해제에 지하 열쇠 %s 필요",
            "zh-CN": "已锁定，解锁需要 %s 冥界之钥",
        },
        "ChaosGateHealthFmt": {
            "fr": "Porte du Chaos (%s Santé)", "de": "Chaostor (%s Leben)",
            "es": "Puerta del Caos (%s Salud)", "it": "Porta del Caos (%s Salute)",
            "pt-BR": "Portão do Caos (%s Saúde)", "ru": "Врата Хаоса (%s Здоровья)",
            "pl": "Brama Chaosu (%s Zdrowia)", "ja": "カオスゲート（体力 %s）",
            "ko": "카오스 관문 (체력 %s)", "zh-CN": "混沌之门（生命 %s）",
        },
        "InfernalGateHealthFmt": {
            "fr": "Porte Infernale (%s Santé)", "de": "Höllentor (%s Leben)",
            "es": "Puerta Infernal (%s Salud)", "it": "Porta Infernale (%s Salute)",
            "pt-BR": "Portão Infernal (%s Saúde)", "ru": "Адские Врата (%s Здоровья)",
            "pl": "Brama Piekielna (%s Zdrowia)", "ja": "地獄門（体力 %s）",
            "ko": "지옥 관문 (체력 %s)", "zh-CN": "炼狱之门（生命 %s）",
        },
        "MoreEncountersFmt": {
            "fr": "%s %s de plus avant la prochaine entrée",
            "de": "%s weitere %s bis zum nächsten Eintrag",
            "es": "%s %s más hasta la próxima entrada",
            "it": "Ancora %s %s per la prossima voce",
            "pt-BR": "%s %s a mais até a próxima entrada",
            "ru": "Ещё %s %s до следующей записи",
            "pl": "%s %s więcej do następnego wpisu",
            "ja": "次の項目まであと %s %s",
            "ko": "다음 항목까지 %s %s 더",
            "zh-CN": "还需 %s 次%s才能解锁下一条目",
        },
        "EncountersRemainingFmt": {
            "fr": "%s rencontres restantes", "de": "%s Begegnungen verbleibend",
            "es": "%s encuentros restantes", "it": "%s incontri rimanenti",
            "pt-BR": "%s encontros restantes", "ru": "Осталось %s встреч",
            "pl": "%s spotkań pozostało", "ja": "残り %s 回の遭遇",
            "ko": "%s 전투 남음", "zh-CN": "剩余 %s 次遭遇",
        },
        "WeaponUnlockCostFmt": {
            "fr": "%s Clés Chtoniennes pour débloquer",
            "de": "%s Chthonische Schlüssel zum Freischalten",
            "es": "%s Llaves Ctónicas para desbloquear",
            "it": "%s Chiavi Ctonie per sbloccare",
            "pt-BR": "%s Chaves Ctônicas para desbloquear",
            "ru": "%s Хтонических Ключей для разблокировки",
            "pl": "%s Chtonicznych Kluczy do odblokowania",
            "ja": "解放に冥界の鍵 %s 必要",
            "ko": "잠금 해제에 지하 열쇠 %s 필요",
            "zh-CN": "解锁需要 %s 冥界之钥",
        },
        "TitanBloodAvailableFmt": {
            "fr": "%s Sang de Titan disponible", "de": "%s Titanenblut verfügbar",
            "es": "%s Sangre de Titán disponible", "it": "%s Sangue di Titano disponibile",
            "pt-BR": "%s Sangue de Titã disponível", "ru": "%s Крови Титана доступно",
            "pl": "%s Krwi Tytana dostępnej", "ja": "タイタンの血 %s 利用可能",
            "ko": "타이탄 피 %s 사용 가능", "zh-CN": "可用泰坦之血 %s",
        },
        "ObolsAvailableFmt": {
            "fr": "%s Oboles disponibles", "de": "%s Obolen verfügbar",
            "es": "%s Óbolos disponibles", "it": "%s Oboli disponibili",
            "pt-BR": "%s Óbolos disponíveis", "ru": "%s Оболов доступно",
            "pl": "%s Oboli dostępnych", "ja": "オボル %s 利用可能",
            "ko": "오볼 %s 사용 가능", "zh-CN": "可用冥币 %s",
        },
        "GemsAvailableFmt": {
            "fr": "%s Pierres précieuses disponibles", "de": "%s Edelsteine verfügbar",
            "es": "%s Gemas disponibles", "it": "%s Gemme disponibili",
            "pt-BR": "%s Pedras preciosas disponíveis", "ru": "%s Самоцветов доступно",
            "pl": "%s Klejnotów dostępnych", "ja": "宝石 %s 利用可能",
            "ko": "보석 %s 사용 가능", "zh-CN": "可用宝石 %s",
        },
        "DarknessAvailableFmt": {
            "fr": "%s Ténèbres disponibles", "de": "%s Dunkelheit verfügbar",
            "es": "%s Oscuridad disponible", "it": "%s Oscurità disponibile",
            "pt-BR": "%s Escuridão disponível", "ru": "%s Тьмы доступно",
            "pl": "%s Ciemności dostępnej", "ja": "闇 %s 利用可能",
            "ko": "어둠 %s 사용 가능", "zh-CN": "可用暗之力 %s",
        },
        "SurviveForFmt": {
            "fr": "Survivre pendant %s secondes", "de": "Überlebe %s Sekunden",
            "es": "Sobrevive %s segundos", "it": "Sopravvivi per %s secondi",
            "pt-BR": "Sobreviva por %s segundos", "ru": "Выжить %s секунд",
            "pl": "Przetrwaj %s sekund", "ja": "%s 秒間生き残れ",
            "ko": "%s초 동안 생존", "zh-CN": "存活 %s 秒",
        },
        # Damage feedback
        "DamageFeedbackOff": {
            "fr": "Retour de dégâts désactivé", "de": "Schadensrückmeldung aus",
            "es": "Retroalimentación de daño desactivada", "it": "Feedback danni disattivato",
            "pt-BR": "Feedback de dano desativado", "ru": "Обратная связь урона выключена",
            "pl": "Informacja o obrażeniach wyłączona", "ja": "ダメージフィードバック オフ",
            "ko": "피해 피드백 끔", "zh-CN": "伤害反馈已关闭",
        },
        "DamageFeedbackAudible": {
            "fr": "Retour de dégâts barres de vie sonores",
            "de": "Schadensrückmeldung hörbare Lebensbalken",
            "es": "Retroalimentación de daño barras de vida audibles",
            "it": "Feedback danni barre salute udibili",
            "pt-BR": "Feedback de dano barras de vida audíveis",
            "ru": "Обратная связь урона звуковые полосы здоровья",
            "pl": "Informacja o obrażeniach słyszalne paski zdrowia",
            "ja": "ダメージフィードバック 聴覚ヘルスバー",
            "ko": "피해 피드백 청각 체력바",
            "zh-CN": "伤害反馈 可听生命条",
        },
        "DamageFeedbackDealt": {
            "fr": "Retour de dégâts dégâts infligés",
            "de": "Schadensrückmeldung verursachter Schaden",
            "es": "Retroalimentación de daño daño infligido",
            "it": "Feedback danni danni inflitti",
            "pt-BR": "Feedback de dano dano causado",
            "ru": "Обратная связь урона нанесённый урон",
            "pl": "Informacja o obrażeniach zadane obrażenia",
            "ja": "ダメージフィードバック 与ダメージ",
            "ko": "피해 피드백 가한 피해",
            "zh-CN": "伤害反馈 造成伤害",
        },
        "DamageFeedbackCombined": {
            "fr": "Retour de dégâts combiné",
            "de": "Schadensrückmeldung kombiniert",
            "es": "Retroalimentación de daño combinada",
            "it": "Feedback danni combinato",
            "pt-BR": "Feedback de dano combinado",
            "ru": "Обратная связь урона комбинированная",
            "pl": "Informacja o obrażeniach połączona",
            "ja": "ダメージフィードバック 複合",
            "ko": "피해 피드백 복합",
            "zh-CN": "伤害反馈 综合",
        },
        # Encounter types
        "Encounters": {
            "fr": "rencontres", "de": "Begegnungen", "es": "encuentros",
            "it": "incontri", "pt-BR": "encontros", "ru": "встреч",
            "pl": "spotkań", "ja": "遭遇", "ko": "전투", "zh-CN": "遭遇",
        },
        "Kills": {
            "fr": "éliminations", "de": "Tötungen", "es": "eliminaciones",
            "it": "uccisioni", "pt-BR": "eliminações", "ru": "убийств",
            "pl": "zabójstw", "ja": "撃破", "ko": "처치", "zh-CN": "击杀",
        },
        "Uses": {
            "fr": "utilisations", "de": "Verwendungen", "es": "usos",
            "it": "utilizzi", "pt-BR": "usos", "ru": "использований",
            "pl": "użyć", "ja": "使用", "ko": "사용", "zh-CN": "使用",
        },
        "Catches": {
            "fr": "prises", "de": "Fänge", "es": "capturas",
            "it": "catture", "pt-BR": "capturas", "ru": "поимок",
            "pl": "złowień", "ja": "釣果", "ko": "포획", "zh-CN": "捕获",
        },
        "Gifts": {
            "fr": "cadeaux", "de": "Geschenke", "es": "regalos",
            "it": "regali", "pt-BR": "presentes", "ru": "подарков",
            "pl": "prezentów", "ja": "贈り物", "ko": "선물", "zh-CN": "赠礼",
        },
        # Misc
        "Boons": {
            "fr": "Faveurs", "de": "Segen", "es": "Dones",
            "it": "Doni", "pt-BR": "Bênçãos", "ru": "Дары",
            "pl": "Błogosławieństwa", "ja": "恩恵", "ko": "은혜", "zh-CN": "恩赐",
        },
        "WellItems": {
            "fr": "Objets du Puits", "de": "Brunnen-Gegenstände", "es": "Objetos del Pozo",
            "it": "Oggetti del Pozzo", "pt-BR": "Itens do Poço", "ru": "Предметы Колодца",
            "pl": "Przedmioty ze Studni", "ja": "井戸のアイテム", "ko": "우물 아이템", "zh-CN": "井中物品",
        },
        "DoorToX": {
            "fr": "Porte vers %s", "de": "Tür zu %s", "es": "Puerta a %s",
            "it": "Porta per %s", "pt-BR": "Porta para %s", "ru": "Дверь в %s",
            "pl": "Drzwi do %s", "ja": "%s への扉", "ko": "%s(으)로의 문", "zh-CN": "通往 %s 的门",
        },
        "PathToGarden": {
            "fr": "Chemin vers le Jardin", "de": "Weg zum Garten", "es": "Camino al Jardín",
            "it": "Sentiero per il Giardino", "pt-BR": "Caminho para o Jardim", "ru": "Путь в Сад",
            "pl": "Ścieżka do Ogrodu", "ja": "庭園への道", "ko": "정원으로의 길", "zh-CN": "通往花园的小径",
        },
        "EscapeWindow": {
            "fr": "Fenêtre d'évasion (Pacte de Châtiment)",
            "de": "Fluchtfenster (Pakt der Bestrafung)",
            "es": "Ventana de escape (Pacto de Castigo)",
            "it": "Finestra di fuga (Patto di Punizione)",
            "pt-BR": "Janela de fuga (Pacto de Punição)",
            "ru": "Окно побега (Пакт Наказания)",
            "pl": "Okno ucieczki (Pakt Kary)",
            "ja": "脱出窓（罰の契約）",
            "ko": "탈출 창 (징벌의 서약)",
            "zh-CN": "逃亡之窗（惩罚契约）",
        },
        "ExaminePoint": {
            "fr": "Point d'examen", "de": "Untersuchungspunkt", "es": "Punto de examen",
            "it": "Punto di esame", "pt-BR": "Ponto de exame", "ru": "Точка осмотра",
            "pl": "Punkt badania", "ja": "調査ポイント", "ko": "조사 지점", "zh-CN": "检查点",
        },
        "LockedKeepsake": {
            "fr": "Souvenir verrouillé", "de": "Gesperrtes Andenken", "es": "Recuerdo bloqueado",
            "it": "Ricordo bloccato", "pt-BR": "Lembrança bloqueada", "ru": "Заблокированная памятная вещь",
            "pl": "Zablokowana pamiątka", "ja": "ロックされた形見", "ko": "잠긴 기념품", "zh-CN": "已锁定的纪念品",
        },
        "LockedCompanion": {
            "fr": "Compagnon verrouillé", "de": "Gesperrter Begleiter", "es": "Compañero bloqueado",
            "it": "Compagno bloccato", "pt-BR": "Companheiro bloqueado", "ru": "Заблокированный спутник",
            "pl": "Zablokowany towarzysz", "ja": "ロックされた仲間", "ko": "잠긴 동료", "zh-CN": "已锁定的同伴",
        },
        "NoEarlierRuns": {
            "fr": "Pas de courses antérieures", "de": "Keine früheren Läufe",
            "es": "No hay carreras anteriores", "it": "Nessuna run precedente",
            "pt-BR": "Sem corridas anteriores", "ru": "Нет более ранних забегов",
            "pl": "Brak wcześniejszych przebiegów", "ja": "以前のランはありません",
            "ko": "이전 런 없음", "zh-CN": "没有更早的逃亡记录",
        },
        "NoLaterRuns": {
            "fr": "Pas de courses ultérieures", "de": "Keine späteren Läufe",
            "es": "No hay carreras posteriores", "it": "Nessuna run successiva",
            "pt-BR": "Sem corridas posteriores", "ru": "Нет более поздних забегов",
            "pl": "Brak późniejszych przebiegów", "ja": "以降のランはありません",
            "ko": "이후 런 없음", "zh-CN": "没有更晚的逃亡记录",
        },
        "UpDownBrowse": {
            "fr": "Haut et Bas pour parcourir", "de": "Hoch und Runter zum Durchsuchen",
            "es": "Arriba y Abajo para explorar", "it": "Su e Giù per sfogliare",
            "pt-BR": "Cima e Baixo para navegar", "ru": "Вверх и Вниз для просмотра",
            "pl": "Góra i Dół do przeglądania", "ja": "上下で閲覧",
            "ko": "위아래로 탐색", "zh-CN": "上下浏览",
        },
        # --- Simple labels (status/navigation) ---
        "Free": {
            "fr": "Gratuit", "de": "Kostenlos", "es": "Gratis",
            "it": "Gratuito", "pt-BR": "Grátis", "ru": "Бесплатно",
            "pl": "Za darmo", "ja": "無料", "ko": "무료", "zh-CN": "免费",
        },
        "SoldOut": {
            "fr": "Épuisé", "de": "Ausverkauft", "es": "Agotado",
            "it": "Esaurito", "pt-BR": "Esgotado", "ru": "Распродано",
            "pl": "Wyprzedane", "ja": "売り切れ", "ko": "품절", "zh-CN": "售罄",
        },
        "NotUnlocked": {
            "fr": "Non déverrouillé", "de": "Nicht freigeschaltet", "es": "No desbloqueado",
            "it": "Non sbloccato", "pt-BR": "Não desbloqueado", "ru": "Не разблокировано",
            "pl": "Nie odblokowane", "ja": "未解放", "ko": "잠김", "zh-CN": "未解锁",
        },
        "UnknownAspect": {
            "fr": "Aspect inconnu", "de": "Unbekannter Aspekt", "es": "Aspecto desconocido",
            "it": "Aspetto sconosciuto", "pt-BR": "Aspecto desconhecido", "ru": "Неизвестный аспект",
            "pl": "Nieznany aspekt", "ja": "不明なアスペクト", "ko": "알 수 없는 상", "zh-CN": "未知形态",
        },
        "RequirementsNotMet": {
            "fr": "Verrouillé, conditions non remplies", "de": "Gesperrt, Anforderungen nicht erfüllt",
            "es": "Bloqueado, requisitos no cumplidos", "it": "Bloccato, requisiti non soddisfatti",
            "pt-BR": "Bloqueado, requisitos não atendidos", "ru": "Заблокировано, требования не выполнены",
            "pl": "Zablokowane, wymagania niespełnione", "ja": "ロック、条件未達成",
            "ko": "잠김, 요구사항 미충족", "zh-CN": "已锁定，未满足条件",
        },
        "Cleared": {
            "fr": "Réussi", "de": "Geschafft", "es": "Completado",
            "it": "Superato", "pt-BR": "Concluído", "ru": "Завершено",
            "pl": "Ukończone", "ja": "クリア", "ko": "클리어", "zh-CN": "通关",
        },
        "Died": {
            "fr": "Mort", "de": "Gestorben", "es": "Muerto",
            "it": "Morto", "pt-BR": "Morreu", "ru": "Погиб",
            "pl": "Śmierć", "ja": "死亡", "ko": "사망", "zh-CN": "死亡",
        },
        "CurrentRun": {
            "fr": "Course actuelle", "de": "Aktueller Lauf", "es": "Carrera actual",
            "it": "Run attuale", "pt-BR": "Corrida atual", "ru": "Текущий забег",
            "pl": "Bieżący przebieg", "ja": "現在のラン", "ko": "현재 런", "zh-CN": "当前逃亡",
        },
        "Category": {
            "fr": "catégorie", "de": "Kategorie", "es": "categoría",
            "it": "categoria", "pt-BR": "categoria", "ru": "категория",
            "pl": "kategoria", "ja": "カテゴリ", "ko": "카테고리", "zh-CN": "分类",
        },
        "NowPlayingStatus": {
            "fr": "En cours de lecture", "de": "Wird abgespielt", "es": "Reproduciendo",
            "it": "In riproduzione", "pt-BR": "Tocando agora", "ru": "Сейчас играет",
            "pl": "Teraz odtwarzane", "ja": "再生中", "ko": "재생 중", "zh-CN": "正在播放",
        },
        "PausedStatus": {
            "fr": "En pause", "de": "Pausiert", "es": "Pausado",
            "it": "In pausa", "pt-BR": "Pausado", "ru": "На паузе",
            "pl": "Wstrzymane", "ja": "一時停止", "ko": "일시정지", "zh-CN": "已暂停",
        },
        "Boon": {
            "fr": "Faveur", "de": "Segen", "es": "Don",
            "it": "Dono", "pt-BR": "Bênção", "ru": "Дар",
            "pl": "Błogosławieństwo", "ja": "恩恵", "ko": "은혜", "zh-CN": "恩赐",
        },
        "Charge": {
            "fr": "charge", "de": "Aufladung", "es": "carga",
            "it": "carica", "pt-BR": "carga", "ru": "заряд",
            "pl": "ładunek", "ja": "チャージ", "ko": "충전", "zh-CN": "次",
        },
        "Charges": {
            "fr": "charges", "de": "Aufladungen", "es": "cargas",
            "it": "cariche", "pt-BR": "cargas", "ru": "заряда",
            "pl": "ładunki", "ja": "チャージ", "ko": "충전", "zh-CN": "次",
        },
        # --- Format strings (preserve %s exactly) ---
        "CostHealthFmt": {
            "fr": "Coûte %s Santé", "de": "Kostet %s Gesundheit", "es": "Cuesta %s Salud",
            "it": "Costa %s Salute", "pt-BR": "Custa %s Saúde", "ru": "Стоит %s Здоровья",
            "pl": "Kosztuje %s Zdrowia", "ja": "%s 体力消費", "ko": "%s 체력 소모", "zh-CN": "消耗 %s 生命",
        },
        "SellForFmt": {
            "fr": "Vendre pour %s Oboles", "de": "Verkaufen für %s Obolen", "es": "Vender por %s Óbolos",
            "it": "Vendi per %s Oboli", "pt-BR": "Vender por %s Óbolos", "ru": "Продать за %s Оболов",
            "pl": "Sprzedaj za %s Oboli", "ja": "%s オボルで売却", "ko": "%s 오볼에 판매", "zh-CN": "出售获得 %s 冥币",
        },
        "BoonsToSellFmt": {
            "fr": "%s faveurs disponibles à vendre", "de": "%s Segen zum Verkauf verfügbar",
            "es": "%s dones disponibles para vender", "it": "%s doni disponibili per la vendita",
            "pt-BR": "%s bênçãos disponíveis para vender", "ru": "%s даров доступно для продажи",
            "pl": "%s błogosławieństw do sprzedania", "ja": "%s 個の恩恵を売却可能",
            "ko": "%s개 은혜 판매 가능", "zh-CN": "%s 个恩赐可出售",
        },
        "RunOfFmt": {
            "fr": "Course %s sur %s", "de": "Lauf %s von %s", "es": "Carrera %s de %s",
            "it": "Run %s di %s", "pt-BR": "Corrida %s de %s", "ru": "Забег %s из %s",
            "pl": "Przebieg %s z %s", "ja": "ラン %s / %s", "ko": "런 %s / %s", "zh-CN": "逃亡 %s / %s",
        },
        "DiedInFmt": {
            "fr": "Mort en %s", "de": "Gestorben in %s", "es": "Muerto en %s",
            "it": "Morto in %s", "pt-BR": "Morreu em %s", "ru": "Погиб в %s",
            "pl": "Śmierć w %s", "ja": "%s で死亡", "ko": "%s에서 사망", "zh-CN": "死于 %s",
        },
        "GodModeFmt": {
            "fr": "Mode Dieu %s%%", "de": "Göttermodus %s%%", "es": "Modo Dios %s%%",
            "it": "Modalità Dio %s%%", "pt-BR": "Modo Deus %s%%", "ru": "Режим Бога %s%%",
            "pl": "Tryb Boga %s%%", "ja": "ゴッドモード %s%%", "ko": "갓 모드 %s%%", "zh-CN": "神明模式 %s%%",
        },
        "TimeFmt": {
            "fr": "Temps: %s", "de": "Zeit: %s", "es": "Tiempo: %s",
            "it": "Tempo: %s", "pt-BR": "Tempo: %s", "ru": "Время: %s",
            "pl": "Czas: %s", "ja": "時間: %s", "ko": "시간: %s", "zh-CN": "时间: %s",
        },
        "WeaponFmt": {
            "fr": "Arme: %s", "de": "Waffe: %s", "es": "Arma: %s",
            "it": "Arma: %s", "pt-BR": "Arma: %s", "ru": "Оружие: %s",
            "pl": "Broń: %s", "ja": "武器: %s", "ko": "무기: %s", "zh-CN": "武器: %s",
        },
        "KeepsakeFmt": {
            "fr": "Souvenir: %s", "de": "Andenken: %s", "es": "Recuerdo: %s",
            "it": "Ricordo: %s", "pt-BR": "Lembrança: %s", "ru": "Памятная вещь: %s",
            "pl": "Pamiątka: %s", "ja": "形見: %s", "ko": "기념품: %s", "zh-CN": "纪念品: %s",
        },
        "CompanionFmt": {
            "fr": "Compagnon: %s", "de": "Begleiter: %s", "es": "Compañero: %s",
            "it": "Compagno: %s", "pt-BR": "Companheiro: %s", "ru": "Спутник: %s",
            "pl": "Towarzysz: %s", "ja": "仲間: %s", "ko": "동료: %s", "zh-CN": "同伴: %s",
        },
        "BoonCountFmt": {
            "fr": "%s Faveurs", "de": "%s Segen", "es": "%s Dones",
            "it": "%s Doni", "pt-BR": "%s Bênçãos", "ru": "%s Даров",
            "pl": "%s Błogosławieństw", "ja": "%s 恩恵", "ko": "%s 은혜", "zh-CN": "%s 恩赐",
        },
        "HeatLabelFmt": {
            "fr": "Chaleur: %s", "de": "Hitze: %s", "es": "Calor: %s",
            "it": "Calore: %s", "pt-BR": "Calor: %s", "ru": "Жар: %s",
            "pl": "Żar: %s", "ja": "ヒート: %s", "ko": "열기: %s", "zh-CN": "热度: %s",
        },
        "DarknessLabelFmt": {
            "fr": "Ténèbres: %s", "de": "Dunkelheit: %s", "es": "Oscuridad: %s",
            "it": "Oscurità: %s", "pt-BR": "Escuridão: %s", "ru": "Тьма: %s",
            "pl": "Ciemność: %s", "ja": "闇: %s", "ko": "어둠: %s", "zh-CN": "暗之力: %s",
        },
        "ClearTimeFmt": {
            "fr": "Temps de réussite: %s", "de": "Abschlusszeit: %s", "es": "Tiempo de completado: %s",
            "it": "Tempo di completamento: %s", "pt-BR": "Tempo de conclusão: %s", "ru": "Время прохождения: %s",
            "pl": "Czas ukończenia: %s", "ja": "クリアタイム: %s", "ko": "클리어 시간: %s", "zh-CN": "通关时间: %s",
        },
        "RecordTimeFmt": {
            "fr": "Meilleur temps: %s", "de": "Rekordzeit: %s", "es": "Tiempo récord: %s",
            "it": "Tempo record: %s", "pt-BR": "Tempo recorde: %s", "ru": "Рекордное время: %s",
            "pl": "Rekordowy czas: %s", "ja": "記録タイム: %s", "ko": "기록 시간: %s", "zh-CN": "最佳时间: %s",
        },
        "RecordHeatFmt": {
            "fr": "Chaleur record: %s", "de": "Rekord-Hitze: %s", "es": "Calor récord: %s",
            "it": "Calore record: %s", "pt-BR": "Calor recorde: %s", "ru": "Рекордный жар: %s",
            "pl": "Rekordowy żar: %s", "ja": "記録ヒート: %s", "ko": "기록 열기: %s", "zh-CN": "最高热度: %s",
        },
        "WeaponClearsFmt": {
            "fr": "Arme: %s, %s réussites totales", "de": "Waffe: %s, %s Abschlüsse gesamt",
            "es": "Arma: %s, %s completados totales", "it": "Arma: %s, %s completamenti totali",
            "pt-BR": "Arma: %s, %s conclusões totais", "ru": "Оружие: %s, %s прохождений всего",
            "pl": "Broń: %s, %s ukończeń łącznie", "ja": "武器: %s、合計 %s クリア",
            "ko": "무기: %s, 총 %s 클리어", "zh-CN": "武器: %s，共 %s 次通关",
        },
        "TotalClearsFmt": {
            "fr": "Réussites totales: %s", "de": "Abschlüsse gesamt: %s", "es": "Completados totales: %s",
            "it": "Completamenti totali: %s", "pt-BR": "Conclusões totais: %s", "ru": "Всего прохождений: %s",
            "pl": "Łącznie ukończeń: %s", "ja": "合計クリア: %s", "ko": "총 클리어: %s", "zh-CN": "总通关次数: %s",
        },
        "ClearStreakFmt": {
            "fr": "Série de réussites: %s", "de": "Abschlussserie: %s", "es": "Racha de completados: %s",
            "it": "Serie di completamenti: %s", "pt-BR": "Sequência de conclusões: %s", "ru": "Серия прохождений: %s",
            "pl": "Seria ukończeń: %s", "ja": "連続クリア: %s", "ko": "연속 클리어: %s", "zh-CN": "连续通关: %s",
        },
        "NewTimeRecord": {
            "fr": "Nouveau record de temps!", "de": "Neuer Zeitrekord!", "es": "¡Nuevo récord de tiempo!",
            "it": "Nuovo record di tempo!", "pt-BR": "Novo recorde de tempo!", "ru": "Новый рекорд времени!",
            "pl": "Nowy rekord czasu!", "ja": "タイム新記録！", "ko": "새로운 시간 기록!", "zh-CN": "新时间记录！",
        },
        "NewHeatRecord": {
            "fr": "Nouveau record de chaleur!", "de": "Neuer Hitze-Rekord!", "es": "¡Nuevo récord de calor!",
            "it": "Nuovo record di calore!", "pt-BR": "Novo recorde de calor!", "ru": "Новый рекорд жара!",
            "pl": "Nowy rekord żaru!", "ja": "ヒート新記録！", "ko": "새로운 열기 기록!", "zh-CN": "新热度记录！",
        },
        "NewStreakRecord": {
            "fr": "Nouveau record de série!", "de": "Neuer Serienrekord!", "es": "¡Nuevo récord de racha!",
            "it": "Nuovo record di serie!", "pt-BR": "Novo recorde de sequência!", "ru": "Новый рекорд серии!",
            "pl": "Nowy rekord serii!", "ja": "連続記録更新！", "ko": "새로운 연속 기록!", "zh-CN": "新连续记录！",
        },
        "EntryOfFmt": {
            "fr": "Entrée %s sur %s", "de": "Eintrag %s von %s", "es": "Entrada %s de %s",
            "it": "Voce %s di %s", "pt-BR": "Entrada %s de %s", "ru": "Запись %s из %s",
            "pl": "Wpis %s z %s", "ja": "エントリ %s / %s", "ko": "항목 %s / %s", "zh-CN": "条目 %s / %s",
        },
        "FullyDiscovered": {
            "fr": "Entièrement découvert", "de": "Vollständig entdeckt", "es": "Completamente descubierto",
            "it": "Completamente scoperto", "pt-BR": "Totalmente descoberto", "ru": "Полностью открыто",
            "pl": "W pełni odkryte", "ja": "完全発見", "ko": "완전히 발견됨", "zh-CN": "完全发现",
        },
        "ContinueStory": {
            "fr": "Continuez l'histoire pour en découvrir plus",
            "de": "Setze die Geschichte fort, um mehr zu entdecken",
            "es": "Continúa la historia para descubrir más",
            "it": "Continua la storia per scoprire di più",
            "pt-BR": "Continue a história para descobrir mais",
            "ru": "Продолжайте историю, чтобы узнать больше",
            "pl": "Kontynuuj historię, aby odkryć więcej",
            "ja": "物語を進めてさらに発見",
            "ko": "이야기를 진행하여 더 발견하기",
            "zh-CN": "继续故事以发现更多",
        },
        "TitanBloodUpgradeFmt": {
            "fr": "%s Sang de Titan pour améliorer", "de": "%s Titanenblut zum Aufwerten",
            "es": "%s Sangre de Titán para mejorar", "it": "%s Sangue di Titano per migliorare",
            "pt-BR": "%s Sangue de Titã para melhorar", "ru": "%s Крови Титана для улучшения",
            "pl": "%s Krwi Tytana do ulepszenia", "ja": "%s タイタンの血でアップグレード",
            "ko": "%s 타이탄 피로 업그레이드", "zh-CN": "%s 泰坦之血升级",
        },
        "TitanBloodUnlockFmt": {
            "fr": "%s Sang de Titan pour déverrouiller", "de": "%s Titanenblut zum Freischalten",
            "es": "%s Sangre de Titán para desbloquear", "it": "%s Sangue di Titano per sbloccare",
            "pt-BR": "%s Sangue de Titã para desbloquear", "ru": "%s Крови Титана для разблокировки",
            "pl": "%s Krwi Tytana do odblokowania", "ja": "%s タイタンの血で解放",
            "ko": "%s 타이탄 피로 잠금 해제", "zh-CN": "%s 泰坦之血解锁",
        },
        "UpgradeAspectFmt": {
            "fr": "Améliorer %s. %s Sang de Titan", "de": "Aufwerten %s. %s Titanenblut",
            "es": "Mejorar %s. %s Sangre de Titán", "it": "Migliorare %s. %s Sangue di Titano",
            "pt-BR": "Melhorar %s. %s Sangue de Titã", "ru": "Улучшить %s. %s Крови Титана",
            "pl": "Ulepsz %s. %s Krwi Tytana", "ja": "%s をアップグレード。%s タイタンの血",
            "ko": "%s 업그레이드. %s 타이탄 피", "zh-CN": "升级 %s。%s 泰坦之血",
        },
        "UnlockAspectFmt": {
            "fr": "Déverrouiller %s. %s Sang de Titan", "de": "Freischalten %s. %s Titanenblut",
            "es": "Desbloquear %s. %s Sangre de Titán", "it": "Sbloccare %s. %s Sangue di Titano",
            "pt-BR": "Desbloquear %s. %s Sangue de Titã", "ru": "Разблокировать %s. %s Крови Титана",
            "pl": "Odblokuj %s. %s Krwi Tytana", "ja": "%s を解放。%s タイタンの血",
            "ko": "%s 잠금 해제. %s 타이탄 피", "zh-CN": "解锁 %s。%s 泰坦之血",
        },
        "AspectFmt": {
            "fr": "Aspect %s", "de": "Aspekt %s", "es": "Aspecto %s",
            "it": "Aspetto %s", "pt-BR": "Aspecto %s", "ru": "Аспект %s",
            "pl": "Aspekt %s", "ja": "アスペクト %s", "ko": "상 %s", "zh-CN": "形态 %s",
        },
        "CategoryFmt": {
            "fr": "%s catégorie", "de": "%s Kategorie", "es": "%s categoría",
            "it": "%s categoria", "pt-BR": "%s categoria", "ru": "%s категория",
            "pl": "%s kategoria", "ja": "%s カテゴリ", "ko": "%s 카테고리", "zh-CN": "%s 分类",
        },
        "WeaponAspectsOpenFmt": {
            "fr": "Aspects d'arme, %s. %s Sang de Titan disponible. Haut et Bas pour parcourir, appuyez pour équiper ou améliorer.",
            "de": "Waffenaspekte, %s. %s Titanenblut verfügbar. Hoch und Runter zum Durchsuchen, Drücken zum Ausrüsten oder Aufwerten.",
            "es": "Aspectos de arma, %s. %s Sangre de Titán disponible. Arriba y Abajo para explorar, presiona para equipar o mejorar.",
            "it": "Aspetti arma, %s. %s Sangue di Titano disponibile. Su e Giù per sfogliare, premi per equipaggiare o migliorare.",
            "pt-BR": "Aspectos de arma, %s. %s Sangue de Titã disponível. Cima e Baixo para navegar, pressione para equipar ou melhorar.",
            "ru": "Аспекты оружия, %s. %s Крови Титана доступно. Вверх и Вниз для просмотра, нажмите для экипировки или улучшения.",
            "pl": "Aspekty broni, %s. %s Krwi Tytana dostępne. Góra i Dół do przeglądania, naciśnij aby wyposażyć lub ulepszyć.",
            "ja": "武器アスペクト、%s。%s タイタンの血が利用可能。上下で閲覧、決定で装備またはアップグレード。",
            "ko": "무기 상, %s. %s 타이탄 피 보유. 위아래로 탐색, 눌러서 장착 또는 업그레이드.",
            "zh-CN": "武器形态，%s。%s 泰坦之血可用。上下浏览，按下装备或升级。",
        },
        "MusicPlayerOpenFmt": {
            "fr": "Lecteur musical. %s sur %s pistes déverrouillées. Haut et Bas pour parcourir, appuyez pour lire ou mettre en pause.",
            "de": "Musikspieler. %s von %s Titeln freigeschaltet. Hoch und Runter zum Durchsuchen, Drücken zum Abspielen oder Pausieren.",
            "es": "Reproductor de música. %s de %s pistas desbloqueadas. Arriba y Abajo para explorar, presiona para reproducir o pausar.",
            "it": "Lettore musicale. %s di %s tracce sbloccate. Su e Giù per sfogliare, premi per riprodurre o mettere in pausa.",
            "pt-BR": "Reprodutor de música. %s de %s faixas desbloqueadas. Cima e Baixo para navegar, pressione para tocar ou pausar.",
            "ru": "Музыкальный плеер. %s из %s треков разблокировано. Вверх и Вниз для просмотра, нажмите для воспроизведения или паузы.",
            "pl": "Odtwarzacz muzyki. %s z %s utworów odblokowanych. Góra i Dół do przeglądania, naciśnij aby odtwarzać lub wstrzymać.",
            "ja": "ミュージックプレイヤー。%s / %s トラック解放済み。上下で閲覧、決定で再生または一時停止。",
            "ko": "음악 플레이어. %s / %s 트랙 잠금 해제. 위아래로 탐색, 눌러서 재생 또는 일시정지.",
            "zh-CN": "音乐播放器。%s / %s 曲目已解锁。上下浏览，按下播放或暂停。",
        },
        "RunHistoryOpenFmt": {
            "fr": "Historique de courses. %s courses passées. Gauche et Droite pour parcourir.",
            "de": "Lauf-Verlauf. %s vergangene Läufe. Links und Rechts zum Durchsuchen.",
            "es": "Historial de carreras. %s carreras pasadas. Izquierda y Derecha para explorar.",
            "it": "Cronologia run. %s run passate. Sinistra e Destra per sfogliare.",
            "pt-BR": "Histórico de corridas. %s corridas passadas. Esquerda e Direita para navegar.",
            "ru": "История забегов. %s прошлых забегов. Влево и Вправо для просмотра.",
            "pl": "Historia przebiegów. %s przeszłych przebiegów. Lewo i Prawo do przeglądania.",
            "ja": "ラン履歴。%s 回の過去のラン。左右で閲覧。",
            "ko": "런 기록. %s개 이전 런. 좌우로 탐색.",
            "zh-CN": "逃亡历史。%s 次过往逃亡。左右浏览。",
        },
        "BoonTrayFmt": {
            "fr": "Plateau de faveurs, %s %s", "de": "Segen-Übersicht, %s %s",
            "es": "Bandeja de dones, %s %s", "it": "Vassoio doni, %s %s",
            "pt-BR": "Bandeja de bênçãos, %s %s", "ru": "Панель даров, %s %s",
            "pl": "Panel błogosławieństw, %s %s", "ja": "恩恵トレイ、%s %s",
            "ko": "은혜 트레이, %s %s", "zh-CN": "恩赐栏，%s %s",
        },
        "EscapeAttemptsFmt": {
            "fr": "%s tentatives d'évasion", "de": "%s Fluchtversuche", "es": "%s intentos de escape",
            "it": "%s tentativi di fuga", "pt-BR": "%s tentativas de fuga", "ru": "%s попыток побега",
            "pl": "%s prób ucieczki", "ja": "%s 回の脱出試行", "ko": "%s 탈출 시도", "zh-CN": "%s 次逃亡尝试",
        },
        "FoesVanquishedFmt": {
            "fr": "%s ennemis vaincus", "de": "%s Feinde besiegt", "es": "%s enemigos derrotados",
            "it": "%s nemici sconfitti", "pt-BR": "%s inimigos derrotados", "ru": "%s врагов повержено",
            "pl": "%s wrogów pokonanych", "ja": "%s 体の敵を撃破", "ko": "%s 적 처치", "zh-CN": "%s 敌人被击败",
        },
        "UsedTimesFmt": {
            "fr": "utilisé %s fois", "de": "%s Mal verwendet", "es": "usado %s veces",
            "it": "usato %s volte", "pt-BR": "usado %s vezes", "ru": "использовано %s раз",
            "pl": "użyte %s razy", "ja": "%s 回使用", "ko": "%s회 사용", "zh-CN": "使用 %s 次",
        },
        "NumClearsFmt": {
            "fr": "%s réussites", "de": "%s Abschlüsse", "es": "%s completados",
            "it": "%s completamenti", "pt-BR": "%s conclusões", "ru": "%s прохождений",
            "pl": "%s ukończeń", "ja": "%s クリア", "ko": "%s 클리어", "zh-CN": "%s 次通关",
        },
        "BestTimeFmt": {
            "fr": "Meilleur %sm %ss", "de": "Beste %sm %ss", "es": "Mejor %sm %ss",
            "it": "Migliore %sm %ss", "pt-BR": "Melhor %sm %ss", "ru": "Лучшее %sм %sс",
            "pl": "Najlepszy %sm %ss", "ja": "最高 %s分 %s秒", "ko": "최고 %s분 %s초", "zh-CN": "最佳 %s分 %s秒",
        },
        # --- Encounter/challenge types ---
        "InfernalTroveChallenge": {
            "fr": "Défi du Trésor Infernal", "de": "Infernalische Schatztruhen-Herausforderung",
            "es": "Desafío del Tesoro Infernal", "it": "Sfida del Tesoro Infernale",
            "pt-BR": "Desafio do Tesouro Infernal", "ru": "Испытание Адской Сокровищницы",
            "pl": "Wyzwanie Piekielnego Skarbu", "ja": "地獄の秘宝チャレンジ",
            "ko": "지옥 보물 도전", "zh-CN": "地狱宝藏挑战",
        },
        "ErebusChallenge": {
            "fr": "Défi d'Érèbe, réussir sans subir de dégâts",
            "de": "Erebus-Herausforderung, ohne Schaden abzuschließen",
            "es": "Desafío de Érebo, completar sin recibir daño",
            "it": "Sfida di Erebo, completare senza subire danni",
            "pt-BR": "Desafio de Érebo, completar sem sofrer dano",
            "ru": "Испытание Эреба, пройти без урона",
            "pl": "Wyzwanie Erebu, ukończ bez otrzymywania obrażeń",
            "ja": "エレボスチャレンジ、ダメージを受けずにクリア",
            "ko": "에레보스 도전, 피해 없이 클리어",
            "zh-CN": "厄瑞玻斯挑战，无伤通关",
        },
        "ThanatosChallenge": {
            "fr": "Défi de Thanatos, rivalisez pour les éliminations",
            "de": "Thanatos-Herausforderung, wetteifern um Kills",
            "es": "Desafío de Tánatos, compite por eliminaciones",
            "it": "Sfida di Tanato, gareggia per le uccisioni",
            "pt-BR": "Desafio de Tânatos, compita por eliminações",
            "ru": "Испытание Танатоса, соревнуйтесь в убийствах",
            "pl": "Wyzwanie Tanatosa, rywalizuj o zabójstwa",
            "ja": "タナトスチャレンジ、キル数で競争",
            "ko": "타나토스 도전, 처치 경쟁",
            "zh-CN": "塔纳托斯挑战，击杀竞争",
        },
        "MovingPlatforms": {
            "fr": "Plateformes mobiles", "de": "Bewegliche Plattformen", "es": "Plataformas móviles",
            "it": "Piattaforme mobili", "pt-BR": "Plataformas móveis", "ru": "Движущиеся платформы",
            "pl": "Ruchome platformy", "ja": "動く足場", "ko": "움직이는 플랫폼", "zh-CN": "移动平台",
        },
        "TightDeadline": {
            "fr": "Délai serré", "de": "Knappe Frist", "es": "Plazo ajustado",
            "it": "Scadenza stretta", "pt-BR": "Prazo apertado", "ru": "Жёсткий дедлайн",
            "pl": "Napięty termin", "ja": "タイトデッドライン", "ko": "촉박한 마감", "zh-CN": "紧迫期限",
        },
        "TimeExpired": {
            "fr": "Temps écoulé ! Dégâts en cours, partez maintenant",
            "de": "Zeit abgelaufen! Schaden wird genommen, jetzt gehen",
            "es": "¡Tiempo agotado! Recibiendo daño, sal ahora",
            "it": "Tempo scaduto! Subisci danni, esci ora",
            "pt-BR": "Tempo esgotado! Sofrendo dano, saia agora",
            "ru": "Время вышло! Получаете урон, уходите",
            "pl": "Czas minął! Otrzymujesz obrażenia, uciekaj",
            "ja": "時間切れ！ダメージを受けています、今すぐ離脱",
            "ko": "시간 초과! 피해를 받고 있습니다, 지금 떠나세요",
            "zh-CN": "时间到！正在受伤，立刻离开",
        },
        "Encounters": {
            "fr": "rencontres", "de": "Begegnungen", "es": "encuentros",
            "it": "incontri", "pt-BR": "encontros", "ru": "встреч",
            "pl": "spotkań", "ja": "遭遇", "ko": "조우", "zh-CN": "次遭遇",
        },
        "Kills": {
            "fr": "éliminations", "de": "Tötungen", "es": "eliminaciones",
            "it": "uccisioni", "pt-BR": "eliminações", "ru": "убийств",
            "pl": "zabójstw", "ja": "キル", "ko": "처치", "zh-CN": "次击杀",
        },
        "Uses": {
            "fr": "utilisations", "de": "Einsätze", "es": "usos",
            "it": "usi", "pt-BR": "usos", "ru": "использований",
            "pl": "użyć", "ja": "使用", "ko": "사용", "zh-CN": "次使用",
        },
        "Catches": {
            "fr": "prises", "de": "Fänge", "es": "capturas",
            "it": "catture", "pt-BR": "capturas", "ru": "уловов",
            "pl": "złowień", "ja": "釣果", "ko": "포획", "zh-CN": "次捕获",
        },
        "Gifts": {
            "fr": "cadeaux", "de": "Geschenke", "es": "regalos",
            "it": "regali", "pt-BR": "presentes", "ru": "подарков",
            "pl": "darów", "ja": "贈り物", "ko": "선물", "zh-CN": "次赠礼",
        },
        # --- Chaos boons ---
        "Curse": {
            "fr": "Malédiction", "de": "Fluch", "es": "Maldición",
            "it": "Maledizione", "pt-BR": "Maldição", "ru": "Проклятие",
            "pl": "Klątwa", "ja": "呪い", "ko": "저주", "zh-CN": "诅咒",
        },
        "Blessing": {
            "fr": "Bénédiction", "de": "Segen", "es": "Bendición",
            "it": "Benedizione", "pt-BR": "Bênção", "ru": "Благословение",
            "pl": "Błogosławieństwo", "ja": "祝福", "ko": "축복", "zh-CN": "祝福",
        },
        "CurseLasts": {
            "fr": "Malédiction dure %s rencontres", "de": "Fluch dauert %s Begegnungen",
            "es": "Maldición dura %s encuentros", "it": "Maledizione dura %s incontri",
            "pt-BR": "Maldição dura %s encontros", "ru": "Проклятие длится %s встреч",
            "pl": "Klątwa trwa %s spotkań", "ja": "呪いは %s 回の遭遇で続く",
            "ko": "저주 %s 조우 지속", "zh-CN": "诅咒持续 %s 次遭遇",
        },
        # --- Boon info screen ---
        "PreviouslyAcquired": {
            "fr": "Précédemment acquis", "de": "Zuvor erhalten", "es": "Previamente adquirido",
            "it": "Precedentemente acquisito", "pt-BR": "Previamente adquirido", "ru": "Ранее получено",
            "pl": "Wcześniej zdobyte", "ja": "以前取得済み", "ko": "이전에 획득함", "zh-CN": "此前获得过",
        },
        "NotYetAcquired": {
            "fr": "Pas encore acquis", "de": "Noch nicht erhalten", "es": "Aún no adquirido",
            "it": "Non ancora acquisito", "pt-BR": "Ainda não adquirido", "ru": "Ещё не получено",
            "pl": "Jeszcze nie zdobyte", "ja": "未取得", "ko": "아직 획득하지 않음", "zh-CN": "尚未获得",
        },
        "UpToFmt": {
            "fr": "jusqu'à %s", "de": "bis zu %s", "es": "hasta %s",
            "it": "fino a %s", "pt-BR": "até %s", "ru": "до %s",
            "pl": "do %s", "ja": "最大 %s", "ko": "최대 %s", "zh-CN": "最高 %s",
        },
        # --- Reroll ---
        "Remaining": {
            "fr": "restant", "de": "verbleibend", "es": "restante",
            "it": "rimanente", "pt-BR": "restante", "ru": "осталось",
            "pl": "pozostało", "ja": "残り", "ko": "남음", "zh-CN": "剩余",
        },
        "CostFmt": {
            "fr": "Coût: %s", "de": "Kosten: %s", "es": "Coste: %s",
            "it": "Costo: %s", "pt-BR": "Custo: %s", "ru": "Стоимость: %s",
            "pl": "Koszt: %s", "ja": "コスト: %s", "ko": "비용: %s", "zh-CN": "费用: %s",
        },
        # --- Quest reward ---
        "RewardFmt": {
            "fr": "Récompense: %s %s", "de": "Belohnung: %s %s", "es": "Recompensa: %s %s",
            "it": "Ricompensa: %s %s", "pt-BR": "Recompensa: %s %s", "ru": "Награда: %s %s",
            "pl": "Nagroda: %s %s", "ja": "報酬: %s %s", "ko": "보상: %s %s", "zh-CN": "奖励: %s %s",
        },
    }
    return t


def _resource_display_names():
    """ResourceDisplayNames — internal resource keys to localized names."""
    return {
        "MetaPoints": {
            "fr": "Ténèbres", "de": "Dunkelheit", "es": "Oscuridad",
            "it": "Oscurità", "pt-BR": "Escuridão", "ru": "Тьма",
            "pl": "Ciemność", "ja": "闇", "ko": "어둠", "zh-CN": "暗之力",
        },
        "Gems": {
            "fr": "Pierres précieuses", "de": "Edelsteine", "es": "Gemas",
            "it": "Gemme", "pt-BR": "Pedras preciosas", "ru": "Самоцветы",
            "pl": "Klejnoty", "ja": "宝石", "ko": "보석", "zh-CN": "宝石",
        },
        "LockKeys": {
            "fr": "Clés Chtoniennes", "de": "Chthonische Schlüssel", "es": "Llaves Ctónicas",
            "it": "Chiavi Ctonie", "pt-BR": "Chaves Ctônicas", "ru": "Хтонические Ключи",
            "pl": "Chtoniczne Klucze", "ja": "冥界の鍵", "ko": "지하 열쇠", "zh-CN": "冥界之钥",
        },
        "GiftPoints": {
            "fr": "Nectar", "de": "Nektar", "es": "Néctar",
            "it": "Nettare", "pt-BR": "Néctar", "ru": "Нектар",
            "pl": "Nektar", "ja": "ネクター", "ko": "넥타르", "zh-CN": "琼浆",
        },
        "SuperGiftPoints": {
            "fr": "Ambroisie", "de": "Ambrosia", "es": "Ambrosía",
            "it": "Ambrosia", "pt-BR": "Ambrosia", "ru": "Амброзия",
            "pl": "Ambrozja", "ja": "アンブロシア", "ko": "암브로시아", "zh-CN": "仙酿",
        },
        "SuperLockKeys": {
            "fr": "Sang de Titan", "de": "Titanenblut", "es": "Sangre de Titán",
            "it": "Sangue di Titano", "pt-BR": "Sangue de Titã", "ru": "Кровь Титана",
            "pl": "Krew Tytana", "ja": "タイタンの血", "ko": "타이탄 피", "zh-CN": "泰坦之血",
        },
        "SuperGems": {
            "fr": "Diamants", "de": "Diamanten", "es": "Diamantes",
            "it": "Diamanti", "pt-BR": "Diamantes", "ru": "Алмазы",
            "pl": "Diamenty", "ja": "ダイヤモンド", "ko": "다이아몬드", "zh-CN": "钻石",
        },
    }


def _choice_display_names():
    """ChoiceDisplayNames — NPC benefit choices."""
    return {
        "ChoiceText_Healing": {
            "fr": "Restauration de santé", "de": "Gesundheitswiederherstellung",
            "es": "Restauración de salud", "it": "Ripristino salute",
            "pt-BR": "Restauração de saúde", "ru": "Восстановление здоровья",
            "pl": "Przywrócenie zdrowia", "ja": "体力回復", "ko": "체력 회복", "zh-CN": "生命恢复",
        },
        "ChoiceText_Darkness": {
            "fr": "Ténèbres", "de": "Dunkelheit", "es": "Oscuridad",
            "it": "Oscurità", "pt-BR": "Escuridão", "ru": "Тьма",
            "pl": "Ciemność", "ja": "闇", "ko": "어둠", "zh-CN": "暗之力",
        },
        "ChoiceText_Money": {
            "fr": "Oboles", "de": "Obolen", "es": "Óbolos",
            "it": "Oboli", "pt-BR": "Óbolos", "ru": "Оболы",
            "pl": "Obole", "ja": "オボル", "ko": "오볼", "zh-CN": "冥币",
        },
        "ChoiceText_BuffExtraChance": {
            "fr": "Restaurer Défi de la Mort", "de": "Todestrotz wiederherstellen",
            "es": "Restaurar Desafío a la Muerte", "it": "Ripristina Sfida alla Morte",
            "pt-BR": "Restaurar Desafio da Morte", "ru": "Восстановить Вызов Смерти",
            "pl": "Przywróć Trupie Wyzwanie", "ja": "不屈の魂を回復", "ko": "죽음의 저항 복구", "zh-CN": "恢复死亡抗争",
        },
        "ChoiceText_BuffExtraChanceReplenish": {
            "fr": "Restaurer Défi de la Mort", "de": "Todestrotz wiederherstellen",
            "es": "Restaurar Desafío a la Muerte", "it": "Ripristina Sfida alla Morte",
            "pt-BR": "Restaurar Desafio da Morte", "ru": "Восстановить Вызов Смерти",
            "pl": "Przywróć Trupie Wyzwanie", "ja": "不屈の魂を回復", "ko": "죽음의 저항 복구", "zh-CN": "恢复死亡抗争",
        },
        "ChoiceText_BuffHealing": {
            "fr": "Guérison après chaque rencontre", "de": "Heilung nach jeder Begegnung",
            "es": "Curación tras cada encuentro", "it": "Guarigione dopo ogni incontro",
            "pt-BR": "Cura após cada encontro", "ru": "Исцеление после каждой встречи",
            "pl": "Leczenie po każdym spotkaniu", "ja": "各遭遇後に回復", "ko": "각 전투 후 치유", "zh-CN": "每次遭遇后治疗",
        },
        "ChoiceText_BuffWeapon": {
            "fr": "Buff d'arme temporaire", "de": "Temporärer Waffenbuff",
            "es": "Mejora temporal de arma", "it": "Potenziamento arma temporaneo",
            "pt-BR": "Melhoria temporária de arma", "ru": "Временное усиление оружия",
            "pl": "Tymczasowe wzmocnienie broni", "ja": "一時的な武器強化", "ko": "임시 무기 강화", "zh-CN": "临时武器增益",
        },
        "ChoiceText_BuffSlottedBoonRarity": {
            "fr": "Améliorer une faveur aléatoire à une rareté supérieure",
            "de": "Zufälligen Segen zu höherer Seltenheit aufwerten",
            "es": "Mejorar un don aleatorio a mayor rareza",
            "it": "Migliora un dono casuale a rarità superiore",
            "pt-BR": "Melhorar uma bênção aleatória para raridade superior",
            "ru": "Улучшить случайный дар до более высокой редкости",
            "pl": "Ulepsz losowe błogosławieństwo do wyższej rzadkości",
            "ja": "ランダムな恩恵のレアリティを上昇",
            "ko": "무작위 은혜의 등급 상승",
            "zh-CN": "随机提升一个恩赐的稀有度",
        },
        "ChoiceText_BuffMegaPom": {
            "fr": "Monter de niveau plusieurs faveurs aléatoires",
            "de": "Mehrere zufällige Segen aufleveln",
            "es": "Subir de nivel varios dones aleatorios",
            "it": "Fai salire di livello diversi doni casuali",
            "pt-BR": "Subir de nível várias bênçãos aleatórias",
            "ru": "Повысить уровень нескольких случайных даров",
            "pl": "Podnieś poziom kilku losowych błogosławieństw",
            "ja": "複数のランダムな恩恵をレベルアップ",
            "ko": "여러 무작위 은혜 레벨업",
            "zh-CN": "随机提升数个恩赐的等级",
        },
        "ChoiceText_BuffFutureBoonRarity": {
            "fr": "La prochaine faveur a une rareté améliorée",
            "de": "Nächster Segen hat verbesserte Seltenheit",
            "es": "El próximo don tiene rareza mejorada",
            "it": "Il prossimo dono ha rarità migliorata",
            "pt-BR": "Próxima bênção tem raridade melhorada",
            "ru": "Следующий дар улучшенной редкости",
            "pl": "Następne błogosławieństwo ma lepszą rzadkość",
            "ja": "次の恩恵のレアリティが上昇",
            "ko": "다음 은혜의 등급 향상",
            "zh-CN": "下一个恩赐的稀有度提升",
        },
    }


def _slot_descriptions():
    """SlotDescriptions — boon slot type names."""
    return {
        "Melee": {
            "fr": "Attaque", "de": "Angriff", "es": "Ataque",
            "it": "Attacco", "pt-BR": "Ataque", "ru": "Атака",
            "pl": "Atak", "ja": "攻撃", "ko": "공격", "zh-CN": "攻击",
        },
        "Secondary": {
            "fr": "Technique", "de": "Spezial", "es": "Especial",
            "it": "Tecnica", "pt-BR": "Especial", "ru": "Умение",
            "pl": "Technika", "ja": "必殺", "ko": "특수", "zh-CN": "特殊",
        },
        "Ranged": {
            "fr": "Sort", "de": "Wurf", "es": "Hechizo",
            "it": "Sortilegio", "pt-BR": "Feitiço", "ru": "Каст",
            "pl": "Rzut", "ja": "魔弾", "ko": "시전", "zh-CN": "施法",
        },
        "Rush": {
            "fr": "Sprint", "de": "Sprint", "es": "Sprint",
            "it": "Scatto", "pt-BR": "Dash", "ru": "Рывок",
            "pl": "Zryw", "ja": "ダッシュ", "ko": "대시", "zh-CN": "冲刺",
        },
        "Shout": {
            "fr": "Invocation", "de": "Ruf", "es": "Invocación",
            "it": "Invocazione", "pt-BR": "Chamado", "ru": "Призыв",
            "pl": "Wezwanie", "ja": "召喚", "ko": "소환", "zh-CN": "召唤",
        },
    }


# --- God name mapping (used by DuoBoonGods) ---
_GOD_NAMES = {
    "Zeus":      {"fr": "Zeus", "de": "Zeus", "es": "Zeus", "it": "Zeus", "pt-BR": "Zeus", "ru": "Зевс", "pl": "Zeus", "ja": "ゼウス", "ko": "제우스", "zh-CN": "宙斯"},
    "Poseidon":  {"fr": "Poséidon", "de": "Poseidon", "es": "Poseidón", "it": "Poseidone", "pt-BR": "Poseidon", "ru": "Посейдон", "pl": "Posejdon", "ja": "ポセイドン", "ko": "포세이돈", "zh-CN": "波塞冬"},
    "Athena":    {"fr": "Athéna", "de": "Athene", "es": "Atenea", "it": "Atena", "pt-BR": "Atena", "ru": "Афина", "pl": "Atena", "ja": "アテナ", "ko": "아테나", "zh-CN": "雅典娜"},
    "Ares":      {"fr": "Arès", "de": "Ares", "es": "Ares", "it": "Ares", "pt-BR": "Ares", "ru": "Арес", "pl": "Ares", "ja": "アレス", "ko": "아레스", "zh-CN": "阿瑞斯"},
    "Aphrodite": {"fr": "Aphrodite", "de": "Aphrodite", "es": "Afrodita", "it": "Afrodite", "pt-BR": "Afrodite", "ru": "Афродита", "pl": "Afrodyta", "ja": "アフロディーテ", "ko": "아프로디테", "zh-CN": "阿佛洛狄忒"},
    "Artemis":   {"fr": "Artémis", "de": "Artemis", "es": "Artemisa", "it": "Artemide", "pt-BR": "Ártemis", "ru": "Артемида", "pl": "Artemida", "ja": "アルテミス", "ko": "아르테미스", "zh-CN": "阿尔忒弥斯"},
    "Dionysus":  {"fr": "Dionysos", "de": "Dionysos", "es": "Dioniso", "it": "Dioniso", "pt-BR": "Dionísio", "ru": "Дионис", "pl": "Dionizos", "ja": "ディオニュソス", "ko": "디오니소스", "zh-CN": "狄俄尼索斯"},
    "Hermes":    {"fr": "Hermès", "de": "Hermes", "es": "Hermes", "it": "Ermes", "pt-BR": "Hermes", "ru": "Гермес", "pl": "Hermes", "ja": "ヘルメス", "ko": "헤르메스", "zh-CN": "赫尔墨斯"},
    "Demeter":   {"fr": "Déméter", "de": "Demeter", "es": "Deméter", "it": "Demetra", "pt-BR": "Deméter", "ru": "Деметра", "pl": "Demeter", "ja": "デメテル", "ko": "데메테르", "zh-CN": "得墨忒耳"},
}


def _duo_boon_gods():
    """DuoBoonGods — god name pairs for duo boons. Constructed from _GOD_NAMES."""
    # English pairs: trait_key -> "God1, God2"
    pairs = {
        "ImpactBoltTrait": ("Zeus", "Poseidon"),
        "ReboundingAthenaCastTrait": ("Zeus", "Athena"),
        "AutoRetaliateTrait": ("Zeus", "Ares"),
        "RegeneratingCappedSuperTrait": ("Zeus", "Aphrodite"),
        "AmmoBoltTrait": ("Zeus", "Artemis"),
        "LightningCloudTrait": ("Zeus", "Dionysus"),
        "JoltDurationTrait": ("Zeus", "Demeter"),
        "StatusImmunityTrait": ("Poseidon", "Athena"),
        "PoseidonAresProjectileTrait": ("Poseidon", "Ares"),
        "ImprovedPomTrait": ("Poseidon", "Aphrodite"),
        "ArtemisBonusProjectileTrait": ("Poseidon", "Artemis"),
        "RaritySuperBoost": ("Poseidon", "Demeter"),
        "BlizzardOrbTrait": ("Demeter", "Poseidon"),
        "TriggerCurseTrait": ("Athena", "Ares"),
        "SlowProjectileTrait": ("Athena", "Aphrodite"),
        "ArtemisReflectBuffTrait": ("Athena", "Artemis"),
        "DionysusNullifyProjectileTrait": ("Athena", "Dionysus"),
        "CastBackstabTrait": ("Athena", "Demeter"),
        "NoLastStandRegenerationTrait": ("Athena", "Demeter"),
        "CurseSickTrait": ("Ares", "Aphrodite"),
        "AresHomingTrait": ("Ares", "Artemis"),
        "PoisonTickRateTrait": ("Ares", "Dionysus"),
        "StationaryRiftTrait": ("Ares", "Demeter"),
        "HeartsickCritDamageTrait": ("Aphrodite", "Artemis"),
        "DionysusAphroditeStackIncreaseTrait": ("Aphrodite", "Dionysus"),
        "SelfLaserTrait": ("Aphrodite", "Demeter"),
        "PoisonCritVulnerabilityTrait": ("Artemis", "Dionysus"),
        "HomingLaserTrait": ("Artemis", "Demeter"),
        "IceStrikeArrayTrait": ("Dionysus", "Demeter"),
    }
    t = {}
    for trait, (god1, god2) in pairs.items():
        t[trait] = {}
        for lang in ["fr", "de", "es", "it", "pt-BR", "ru", "pl", "ja", "ko", "zh-CN"]:
            n1 = _GOD_NAMES[god1].get(lang, god1)
            n2 = _GOD_NAMES[god2].get(lang, god2)
            t[trait][lang] = f"{n1}, {n2}"
    return t


def _npc_display_names():
    """NPCDisplayNames — NPC name translations. Western langs keep English for most."""
    # Most NPC names are proper Greek names that stay the same in Western languages.
    # Only CJK + Russian need transliteration for most entries.
    _npc = {
        "Zagreus": {"ru": "Загрей", "ja": "ザグレウス", "ko": "자그레우스", "zh-CN": "扎格列欧斯"},
        "Hades": {"ru": "Аид", "ja": "ハデス", "ko": "하데스", "zh-CN": "哈迪斯"},
        "Cerberus": {"ru": "Цербер", "ja": "ケルベロス", "ko": "케르베로스", "zh-CN": "刻耳柏洛斯"},
        "Achilles": {"ru": "Ахиллес", "ja": "アキレウス", "ko": "아킬레우스", "zh-CN": "阿喀琉斯"},
        "Nyx": {"ru": "Никта", "ja": "ニュクス", "ko": "닉스", "zh-CN": "倪克斯"},
        "Thanatos": {"ru": "Танатос", "ja": "タナトス", "ko": "타나토스", "zh-CN": "塔纳托斯"},
        "Charon": {"fr": "Charon", "ru": "Харон", "ja": "カロン", "ko": "카론", "zh-CN": "卡戎"},
        "Hypnos": {"ru": "Гипнос", "ja": "ヒュプノス", "ko": "히프노스", "zh-CN": "许普诺斯"},
        "Megaera": {"ru": "Мегера", "ja": "メガイラ", "ko": "메가이라", "zh-CN": "墨盖拉"},
        "Orpheus": {"fr": "Orphée", "ru": "Орфей", "ja": "オルフェウス", "ko": "오르페우스", "zh-CN": "俄耳甫斯"},
        "Dusa": {"ru": "Дуса", "ja": "デューサ", "ko": "두사", "zh-CN": "杜莎"},
        "Skelly": {"ru": "Скелли", "ja": "スケリー", "ko": "스켈리", "zh-CN": "骷髅"},
        "Sisyphus": {"fr": "Sisyphe", "es": "Sísifo", "it": "Sisifo", "pt-BR": "Sísifo", "ru": "Сизиф", "pl": "Syzyf", "ja": "シーシュポス", "ko": "시시포스", "zh-CN": "西西弗斯"},
        "Eurydice": {"fr": "Eurydice", "es": "Eurídice", "it": "Euridice", "ru": "Эвридика", "pl": "Eurydyka", "ja": "エウリュディケー", "ko": "에우리디케", "zh-CN": "欧律狄刻"},
        "Patroclus": {"fr": "Patrocle", "es": "Patroclo", "it": "Patroclo", "pt-BR": "Pátroclo", "ru": "Патрокл", "pl": "Patroklos", "ja": "パトロクロス", "ko": "파트로클로스", "zh-CN": "帕特洛克罗斯"},
        "Bouldy": {"ru": "Камень", "ja": "ボルディ", "ko": "볼디", "zh-CN": "石头"},
        "Persephone": {"fr": "Perséphone", "es": "Perséfone", "it": "Persefone", "ru": "Персефона", "pl": "Persefona", "ja": "ペルセポネー", "ko": "페르세포네", "zh-CN": "珀耳塞福涅"},
        "Alecto": {"fr": "Alecto", "ru": "Алекто", "ja": "アレクトー", "ko": "알렉토", "zh-CN": "阿勒克托"},
        "Tisiphone": {"fr": "Tisiphone", "ru": "Тисифона", "ja": "ティーシポネー", "ko": "티시포네", "zh-CN": "提西福涅"},
        "Theseus": {"fr": "Thésée", "es": "Teseo", "it": "Teseo", "pt-BR": "Teseu", "ru": "Тесей", "pl": "Tezeusz", "ja": "テーセウス", "ko": "테세우스", "zh-CN": "忒修斯"},
        "Asterius": {"ru": "Астериос", "ja": "アステリオス", "ko": "아스테리오스", "zh-CN": "阿斯忒里俄斯"},
        "Chaos": {"ru": "Хаос", "ja": "カオス", "ko": "카오스", "zh-CN": "混沌"},
    }
    # Map each NPC key to its English display name, then look up translations
    key_to_name = {
        "CharProtag": "Zagreus", "PlayerUnit": "Zagreus", "PlayerUnit_Intro": "Zagreus",
        "NPC_Hades_01": "Hades", "NPC_Cerberus_01": "Cerberus",
        "NPC_Achilles_01": "Achilles", "NPC_Achilles_Story_01": "Achilles",
        "NPC_Nyx_01": "Nyx", "NPC_Thanatos_01": "Thanatos", "NPC_Charon_01": "Charon",
        "NPC_Hypnos_01": "Hypnos", "NPC_Megaera_01": "Megaera", "NPC_Orpheus_01": "Orpheus",
        "NPC_Dusa_01": "Dusa", "NPC_Skelly_01": "Skelly", "SkellyBackstory": "Skelly",
        "NPC_Sisyphus_01": "Sisyphus", "NPC_Eurydice_01": "Eurydice",
        "NPC_Patroclus_01": "Patroclus", "NPC_Patroclus_Unnamed_01": "Patroclus",
        "NPC_Bouldy_01": "Bouldy", "NPC_Persephone_01": "Persephone",
        "NPC_Persephone_Home_01": "Persephone", "NPC_Persephone_Unnamed_01": "Persephone",
        "NPC_FurySister_01": "Megaera", "NPC_FurySister_02": "Alecto",
        "NPC_FurySister_03": "Tisiphone", "NPC_Theseus_01": "Theseus",
        "Theseus": "Theseus", "NPC_Asterius_01": "Asterius", "Asterius": "Asterius",
        "NPC_Chaos_01": "Chaos", "Chaos": "Chaos",
    }
    t = {}
    for key, name in key_to_name.items():
        if name in _npc:
            t[key] = _npc[name]
    return t


# --- Keepsake name translations (shared by KeepsakeDisplayNames + KeepsakeGiftNames) ---
_KEEPSAKE_NAMES = {
    "Old Spiked Collar": {
        "fr": "Vieux Collier \u00e0 Pointes", "de": "Altes Stachelhalsband", "es": "Viejo Collar de Pinchos",
        "it": "Vecchio Collare a Punte", "pt-BR": "Velha Coleira de Espinhos", "ru": "\u0421\u0442\u0430\u0440\u044b\u0439 \u041e\u0448\u0435\u0439\u043d\u0438\u043a \u0441 \u0428\u0438\u043f\u0430\u043c\u0438",
        "pl": "Stara Kolczasta Obro\u017ca", "ja": "\u53e4\u3044\u30c8\u30b2\u4ed8\u304d\u9996\u8f2a", "ko": "\ub0a1\uc740 \uac00\uc2dc \ubaa9\uac78\uc774", "zh-CN": "\u65e7\u5c16\u523a\u9879\u5708",
    },
    "Myrmidon Bracer": {
        "fr": "Brassard de Myrmidon", "de": "Myrmidonen-Armschiene", "es": "Brazal de Mirmidon",
        "it": "Bracciale Mirmidone", "pt-BR": "Bra\u00e7al de Mirm\u00eddone", "ru": "\u041d\u0430\u0440\u0443\u0447 \u041c\u0438\u0440\u043c\u0438\u0434\u043e\u043d\u0446\u0430",
        "pl": "Naramiennik Mirmidona", "ja": "\u30df\u30e5\u30eb\u30df\u30c9\u30fc\u30f3\u306e\u8155\u5f53\u3066", "ko": "\ubbf8\ub974\ubbf8\ub3c8 \ud314\ucc0c", "zh-CN": "\u5f25\u5c14\u7c73\u987f\u62a4\u8155",
    },
    "Black Shawl": {
        "fr": "Ch\u00e2le Noir", "de": "Schwarzer Schal", "es": "Chal Negro",
        "it": "Scialle Nero", "pt-BR": "Xale Negro", "ru": "\u0427\u0451\u0440\u043d\u0430\u044f \u0428\u0430\u043b\u044c",
        "pl": "Czarny Szal", "ja": "\u9ed2\u3044\u30b7\u30e7\u30fc\u30eb", "ko": "\uac80\uc740 \uc200", "zh-CN": "\u9ed1\u8272\u62ab\u5dfe",
    },
    "Pierced Butterfly": {
        "fr": "Papillon Perc\u00e9", "de": "Durchbohrter Schmetterling", "es": "Mariposa Perforada",
        "it": "Farfalla Trafitta", "pt-BR": "Borboleta Perfurada", "ru": "\u041f\u0440\u043e\u043a\u043e\u043b\u043e\u0442\u0430\u044f \u0411\u0430\u0431\u043e\u0447\u043a\u0430",
        "pl": "Przebity Motyl", "ja": "\u7a7f\u305f\u308c\u305f\u8776", "ko": "\uaf2d\ud78c \ub098\ube44", "zh-CN": "\u523a\u7a7f\u7684\u8774\u8776",
    },
    "Bone Hourglass": {
        "fr": "Sablier d'Os", "de": "Knochen-Sanduhr", "es": "Reloj de Arena de Hueso",
        "it": "Clessidra d'Osso", "pt-BR": "Ampulheta de Osso", "ru": "\u041a\u043e\u0441\u0442\u044f\u043d\u044b\u0435 \u041f\u0435\u0441\u043e\u0447\u043d\u044b\u0435 \u0427\u0430\u0441\u044b",
        "pl": "Ko\u015bciany Klepsydra", "ja": "\u9aa8\u306e\u7802\u6642\u8a08", "ko": "\ubf08 \ubaa8\ub798\uc2dc\uacc4", "zh-CN": "\u9aa8\u8d28\u6c99\u6f0f",
    },
    "Chthonic Coin Purse": {
        "fr": "Bourse Chtonienne", "de": "Chthonische Geldb\u00f6rse", "es": "Monedero Ct\u00f3nico",
        "it": "Borsa Ctonia", "pt-BR": "Bolsa Ct\u00f4nica", "ru": "\u0425\u0442\u043e\u043d\u0438\u0447\u0435\u0441\u043a\u0438\u0439 \u041a\u043e\u0448\u0435\u043b\u0451\u043a",
        "pl": "Chtoniczny Sakiewka", "ja": "\u51a5\u754c\u306e\u5c0f\u92ad\u5165\u308c", "ko": "\uba85\uacc4\uc758 \ub3d9\uc804 \uc9c0\uac11", "zh-CN": "\u51a5\u754c\u94b1\u888b",
    },
    "Skull Earring": {
        "fr": "Boucle d'Oreille Cr\u00e2ne", "de": "Sch\u00e4del-Ohrring", "es": "Pendiente de Calavera",
        "it": "Orecchino Teschio", "pt-BR": "Brinco de Caveira", "ru": "\u0421\u0435\u0440\u044c\u0433\u0430 \u0441 \u0427\u0435\u0440\u0435\u043f\u043e\u043c",
        "pl": "Kolczyk z Czaszk\u0105", "ja": "\u9ab8\u9aa8\u306e\u30a4\u30e4\u30ea\u30f3\u30b0", "ko": "\ud574\uace8 \uadc0\uac78\uc774", "zh-CN": "\u9ab7\u9ac5\u8033\u73af",
    },
    "Distant Memory": {
        "fr": "Souvenir Lointain", "de": "Ferne Erinnerung", "es": "Recuerdo Lejano",
        "it": "Ricordo Lontano", "pt-BR": "Mem\u00f3ria Distante", "ru": "\u0414\u0430\u043b\u0451\u043a\u043e\u0435 \u0412\u043e\u0441\u043f\u043e\u043c\u0438\u043d\u0430\u043d\u0438\u0435",
        "pl": "Odleg\u0142e Wspomnienie", "ja": "\u9060\u3044\u8a18\u61b6", "ko": "\uba3c \uae30\uc5b5", "zh-CN": "\u9065\u8fdc\u7684\u8bb0\u5fc6",
    },
    "Harpy Feather Duster": {
        "fr": "Plumeau de Harpie", "de": "Harpyien-Staubwedel", "es": "Plumero de Arp\u00eda",
        "it": "Piumino d'Arpia", "pt-BR": "Espanador de Harpia", "ru": "\u041c\u0435\u0442\u0451\u043b\u043a\u0430 \u0413\u0430\u0440\u043f\u0438\u0438",
        "pl": "Miot\u0142a z Pi\u00f3r Harpii", "ja": "\u30cf\u30fc\u30d4\u30fc\u306e\u7fbd\u6383\u304d", "ko": "\ud558\ud53c \uae43\ud138 \ube57\uc790\ub8e8", "zh-CN": "\u9e1f\u8eab\u5973\u5996\u7fbd\u6bdb\u629b",
    },
    "Lucky Tooth": {
        "fr": "Dent de Chance", "de": "Gl\u00fcckszahn", "es": "Diente de la Suerte",
        "it": "Dente Fortunato", "pt-BR": "Dente da Sorte", "ru": "\u0421\u0447\u0430\u0441\u0442\u043b\u0438\u0432\u044b\u0439 \u0417\u0443\u0431",
        "pl": "Szcz\u0119\u015bliwy Z\u0105b", "ja": "\u5e78\u904b\u306e\u6b6f", "ko": "\ud589\uc6b4\uc758 \uc774\ube68", "zh-CN": "\u5e78\u8fd0\u7259\u9f7f",
    },
    "Shattered Shackle": {
        "fr": "Cha\u00eene Bris\u00e9e", "de": "Zerbrochene Fessel", "es": "Grillete Roto",
        "it": "Catena Spezzata", "pt-BR": "Algema Estilha\u00e7ada", "ru": "\u0420\u0430\u0437\u0431\u0438\u0442\u044b\u0435 \u041e\u043a\u043e\u0432\u044b",
        "pl": "Rozbi\u0442e Kajdany", "ja": "\u7815\u3051\u305f\u675f\u7e1b", "ko": "\ubd80\uc11c\uc9c4 \uc871\uc1c4", "zh-CN": "\u7834\u788e\u7684\u675f\u7f1a",
    },
    "Evergreen Acorn": {
        "fr": "Gland \u00c9ternel", "de": "Immergr\u00fcne Eichel", "es": "Bellota Perenne",
        "it": "Ghianda Sempreverde", "pt-BR": "Bolota Perene", "ru": "\u0412\u0435\u0447\u043d\u043e\u0437\u0435\u043b\u0451\u043d\u044b\u0439 \u0416\u0451\u043b\u0443\u0434\u044c",
        "pl": "Wiecznie Zielony \u017bo\u0142\u0105d\u017a", "ja": "\u5e38\u7dd1\u306e\u30c9\u30f3\u30b0\u30ea", "ko": "\uc0c1\ub85d \ub3c4\ud1a0\ub9ac", "zh-CN": "\u5e38\u9752\u6a61\u5b9e",
    },
    "Broken Spearpoint": {
        "fr": "Pointe de Lance Bris\u00e9e", "de": "Zerbrochene Speerspitze", "es": "Punta de Lanza Rota",
        "it": "Punta di Lancia Spezzata", "pt-BR": "Ponta de Lan\u00e7a Quebrada", "ru": "\u0421\u043b\u043e\u043c\u0430\u043d\u043d\u044b\u0439 \u041d\u0430\u043a\u043e\u043d\u0435\u0447\u043d\u0438\u043a \u041a\u043e\u043f\u044c\u044f",
        "pl": "Z\u0142amany Grot W\u0142\u00f3czni", "ja": "\u6298\u308c\u305f\u69cd\u5148", "ko": "\ubd80\ub7ec\uc9c4 \ucc3d\ub0a0", "zh-CN": "\u65ad\u88c2\u67aa\u5c16",
    },
    "Thunder Signet": {
        "fr": "Sceau du Tonnerre", "de": "Donner-Siegel", "es": "Sello del Trueno",
        "it": "Sigillo del Tuono", "pt-BR": "Selo do Trov\u00e3o", "ru": "\u041f\u0435\u0447\u0430\u0442\u044c \u0413\u0440\u043e\u043c\u0430",
        "pl": "Piecz\u0119\u0107 Pioruna", "ja": "\u96f7\u306e\u5370\u7ae0", "ko": "\ucc9c\ub465\uc758 \uc778\uc7a5", "zh-CN": "\u96f7\u9706\u5370\u7ae0",
    },
    "Conch Shell": {
        "fr": "Coquillage", "de": "Muschelhorn", "es": "Caracola",
        "it": "Conchiglia", "pt-BR": "Concha", "ru": "\u0420\u0430\u043a\u043e\u0432\u0438\u043d\u0430",
        "pl": "Muszla", "ja": "\u5dfb\u304d\u8c9d", "ko": "\uc18c\ub77c\uac8c", "zh-CN": "\u6d77\u87ba",
    },
    "Owl Pendant": {
        "fr": "Pendentif Chouette", "de": "Eulen-Anh\u00e4nger", "es": "Colgante de B\u00faho",
        "it": "Pendente del Gufo", "pt-BR": "Pingente de Coruja", "ru": "\u0421\u043e\u0432\u0438\u043d\u044b\u0439 \u041a\u0443\u043b\u043e\u043d",
        "pl": "Sowi Wisiorek", "ja": "\u30d5\u30af\u30ed\u30a6\u306e\u30da\u30f3\u30c0\u30f3\u30c8", "ko": "\uc62c\ube7c\ubbf8 \ud39c\ub358\ud2b8", "zh-CN": "\u732b\u5934\u9e70\u5782\u9970",
    },
    "Blood-Filled Vial": {
        "fr": "Fiole de Sang", "de": "Blutgef\u00fcllte Phiole", "es": "Frasco Lleno de Sangre",
        "it": "Fiala di Sangue", "pt-BR": "Frasco de Sangue", "ru": "\u0424\u043b\u0430\u043a\u043e\u043d \u0441 \u041a\u0440\u043e\u0432\u044c\u044e",
        "pl": "Fiolka Krwi", "ja": "\u8840\u5165\u308a\u306e\u5c0f\u74f6", "ko": "\ud53c\ub85c \uac00\ub4dd \ucc2c \uc720\ub9ac\ubcd1", "zh-CN": "\u8840\u74f6",
    },
    "Eternal Rose": {
        "fr": "Rose \u00c9ternelle", "de": "Ewige Rose", "es": "Rosa Eterna",
        "it": "Rosa Eterna", "pt-BR": "Rosa Eterna", "ru": "\u0412\u0435\u0447\u043d\u0430\u044f \u0420\u043e\u0437\u0430",
        "pl": "Wieczna R\u00f3\u017ca", "ja": "\u6c38\u9060\u306e\u30d0\u30e9", "ko": "\uc601\uc6d0\ud55c \uc7a5\ubbf8", "zh-CN": "\u6c38\u6052\u4e4b\u73ab",
    },
    "Adamant Arrowhead": {
        "fr": "Pointe de Fl\u00e8che Adamantine", "de": "Adamant-Pfeilspitze", "es": "Punta de Flecha Adamantina",
        "it": "Punta di Freccia Adamantina", "pt-BR": "Ponta de Flecha Adamantina", "ru": "\u0410\u0434\u0430\u043c\u0430\u043d\u0442\u043e\u0432\u044b\u0439 \u041d\u0430\u043a\u043e\u043d\u0435\u0447\u043d\u0438\u043a",
        "pl": "Adamantowy Grot Strza\u0142y", "ja": "\u30a2\u30c0\u30de\u30f3\u30c8\u306e\u77e2\u5c3b", "ko": "\uac15\ucca0 \ud654\uc0b4\ucd09", "zh-CN": "\u7cbe\u94a2\u7bad\u5934",
    },
    "Overflowing Cup": {
        "fr": "Coupe D\u00e9bordante", "de": "\u00dcberflie\u00dfender Kelch", "es": "Copa Rebosante",
        "it": "Coppa Traboccante", "pt-BR": "C\u00e1lice Transbordante", "ru": "\u041f\u0435\u0440\u0435\u043f\u043e\u043b\u043d\u0435\u043d\u043d\u044b\u0439 \u041a\u0443\u0431\u043e\u043a",
        "pl": "Przepe\u0142niony Puchar", "ja": "\u6ea2\u308c\u308b\u676f", "ko": "\ub118\uccd0\ud750\ub974\ub294 \uc794", "zh-CN": "\u6ea2\u6ee1\u4e4b\u676f",
    },
    "Lambent Plume": {
        "fr": "Plume Chatoyante", "de": "Schimmernde Feder", "es": "Pluma Refulgente",
        "it": "Piuma Luminosa", "pt-BR": "Pluma Cintilante", "ru": "\u0421\u0438\u044f\u044e\u0449\u0435\u0435 \u041f\u0435\u0440\u043e",
        "pl": "L\u015bni\u0105ce Pi\u00f3ro", "ja": "\u8f1d\u304f\u7fbd\u6839", "ko": "\ube5b\ub098\ub294 \uae43\ud138", "zh-CN": "\u95ea\u8000\u7fbd\u6bdb",
    },
    "Frostbitten Horn": {
        "fr": "Corne Gel\u00e9e", "de": "Frostiges Horn", "es": "Cuerno Helado",
        "it": "Corno Ghiacciato", "pt-BR": "Chifre Congelado", "ru": "\u041e\u0431\u043c\u043e\u0440\u043e\u0436\u0435\u043d\u043d\u044b\u0439 \u0420\u043e\u0433",
        "pl": "Zmarzni\u0119ty R\u00f3g", "ja": "\u51cd\u3066\u3064\u3044\u305f\u89d2", "ko": "\uc5bc\uc5b4\ubd99\uc740 \ubfd4", "zh-CN": "\u51bb\u4f24\u4e4b\u89d2",
    },
    "Cosmic Egg": {
        "fr": "\u0152uf Cosmique", "de": "Kosmisches Ei", "es": "Huevo C\u00f3smico",
        "it": "Uovo Cosmico", "pt-BR": "Ovo C\u00f3smico", "ru": "\u041a\u043e\u0441\u043c\u0438\u0447\u0435\u0441\u043a\u043e\u0435 \u042f\u0439\u0446\u043e",
        "pl": "Kosmiczne Jajo", "ja": "\u5b87\u5b99\u306e\u5375", "ko": "\uc6b0\uc8fc\uc758 \uc54c", "zh-CN": "\u5b87\u5b99\u4e4b\u5375",
    },
    "Sigil of the Dead": {
        "fr": "Sceau des Morts", "de": "Siegel der Toten", "es": "Sello de los Muertos",
        "it": "Sigillo dei Morti", "pt-BR": "Selo dos Mortos", "ru": "\u041f\u0435\u0447\u0430\u0442\u044c \u041c\u0451\u0440\u0442\u0432\u044b\u0445",
        "pl": "Piecz\u0119\u0107 Umar\u0142ych", "ja": "\u6b7b\u8005\u306e\u5370\u7ae0", "ko": "\uc8fd\uc740 \uc790\uc758 \uc778\u7ae0", "zh-CN": "\u4ea1\u8005\u4e4b\u5370",
    },
    # Companions
    "Battie": {"ja": "\u30d0\u30c3\u30c6\u30a3", "ko": "\ubc30\ud2f0", "zh-CN": "\u8759\u8760\u5c0f\u59b9", "ru": "\u0411\u0430\u0442\u0442\u0438"},
    "Rib": {"ja": "\u30ea\u30d6", "ko": "\ub9ac\ube0c", "zh-CN": "\u9aa8\u808b", "ru": "\u0420\u0438\u0431"},
    "Mort": {"ja": "\u30e2\u30eb\u30c8", "ko": "\ubaa8\ud2b8", "zh-CN": "\u83ab\u7279", "ru": "\u041c\u043e\u0440\u0442"},
    "Shady": {"ja": "\u30b7\u30a7\u30a4\u30c7\u30a3", "ko": "\uc250\uc774\ub514", "zh-CN": "\u5f71\u5b50", "ru": "\u0428\u0435\u0439\u0434\u0438"},
    "Antos": {"ja": "\u30a2\u30f3\u30c8\u30b9", "ko": "\uc548\ud1a0\uc2a4", "zh-CN": "\u5b89\u6258\u65af", "ru": "\u0410\u043d\u0442\u043e\u0441"},
    "Fidi": {"ja": "\u30d5\u30a3\u30fc\u30c7\u30a3", "ko": "\ud53c\ub514", "zh-CN": "\u83f2\u8fea", "ru": "\u0424\u0438\u0434\u0438"},
}


def _keepsake_display_names():
    """KeepsakeDisplayNames — keepsake item names."""
    key_to_name = {
        "CerberusKeepsake": "Old Spiked Collar", "AchillesKeepsake": "Myrmidon Bracer",
        "NyxKeepsake": "Black Shawl", "ThanatosKeepsake": "Pierced Butterfly",
        "ChronKeepsake": "Bone Hourglass", "HypnosKeepsake": "Chthonic Coin Purse",
        "MegKeepsake": "Skull Earring", "OrpheusKeepsake": "Distant Memory",
        "DusaKeepsake": "Harpy Feather Duster", "SkellyKeepsake": "Lucky Tooth",
        "SisyphusKeepsake": "Shattered Shackle", "EurydiceKeepsake": "Evergreen Acorn",
        "PatroclusKeepsake": "Broken Spearpoint", "ZeusKeepsake": "Thunder Signet",
        "PoseidonKeepsake": "Conch Shell", "AthenaKeepsake": "Owl Pendant",
        "AresKeepsake": "Blood-Filled Vial", "AphroditeKeepsake": "Eternal Rose",
        "ArtemisKeepsake": "Adamant Arrowhead", "DionysusKeepsake": "Overflowing Cup",
        "HermesKeepsake": "Lambent Plume", "DemeterKeepsake": "Frostbitten Horn",
        "ChaosKeepsake": "Cosmic Egg", "HadesKeepsake": "Sigil of the Dead",
        "ReincarnationTrait": "Lucky Tooth",
        "FurySummonTrait": "Battie", "AntosSummonTrait": "Rib",
        "NpcSummonTrait_Thanatos": "Mort", "NpcSummonTrait_Sisyphus": "Shady",
        "NpcSummonTrait_Achilles": "Antos", "NpcSummonTrait_Dusa": "Fidi",
    }
    t = {}
    for key, name in key_to_name.items():
        if name in _KEEPSAKE_NAMES:
            t[key] = _KEEPSAKE_NAMES[name]
    return t


def _objective_descriptions():
    """ObjectiveDescriptions — weapon tutorial text."""
    t = {
        "SwordWeapon": {
            "fr": "Appuyez sur Attaque pour Frapper", "de": "Dr\u00fccke Angriff zum Zuschlagen",
            "es": "Pulsa Ataque para Golpear", "it": "Premi Attacco per Colpire",
            "pt-BR": "Pressione Ataque para Golpear", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0434\u043b\u044f \u0423\u0434\u0430\u0440\u0430",
            "pl": "Naci\u015bnij Atak, aby Uderzy\u0107", "ja": "\u653b\u6483\u3067\u65ac\u308a\u304b\u304b\u308b", "ko": "\uacf5\uaca9\uc73c\ub85c \ud0c0\uaca9", "zh-CN": "\u6309\u653b\u51fb\u8fdb\u884c\u6253\u51fb",
        },
        "SwordParry": {
            "fr": "Appuyez sur Technique pour Frappe Nova", "de": "Dr\u00fccke Spezial f\u00fcr Nova-Schlag",
            "es": "Pulsa Especial para Golpe Nova", "it": "Premi Tecnica per Colpo Nova",
            "pt-BR": "Pressione Especial para Golpe Nova", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0423\u0434\u0430\u0440\u0430 \u041d\u043e\u0432\u044b",
            "pl": "Naci\u015bnij Technik\u0119 dla Uderzenia Nova", "ja": "\u5fc5\u6bba\u3067\u30ce\u30f4\u30a1\u30b9\u30de\u30c3\u30b7\u30e5", "ko": "\ud2b9\uc218\ub85c \ub178\ubc14 \uc2a4\ub9e4\uc2dc", "zh-CN": "\u6309\u7279\u6b8a\u8fdb\u884c\u65b0\u661f\u7206\u53d1",
        },
        "SwordWeaponDash": {
            "fr": "Appuyez sur Attaque en sprintant pour Frappe \u00c9clair", "de": "Dr\u00fccke Angriff beim Sprinten f\u00fcr Blitzschlag",
            "es": "Pulsa Ataque mientras Sprintas para Golpe Rel\u00e1mpago", "it": "Premi Attacco durante lo Scatto per Colpo Lampo",
            "pt-BR": "Pressione Ataque enquanto corre para Golpe Rel\u00e2mpago", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0432\u043e \u0432\u0440\u0435\u043c\u044f \u0420\u044b\u0432\u043a\u0430 \u0434\u043b\u044f \u041c\u043e\u043b\u043d\u0438\u0435\u043d\u043e\u0441\u043d\u043e\u0433\u043e \u0423\u0434\u0430\u0440\u0430",
            "pl": "Naci\u015bnij Atak podczas Zrywu dla Ciosu B\u0142yskawicy", "ja": "\u30c0\u30c3\u30b7\u30e5\u4e2d\u306b\u653b\u6483\u3067\u77ac\u9593\u65ac\u308a", "ko": "\ub300\uc2dc \uc911 \uacf5\uaca9\uc73c\ub85c \uc21c\uac04\ud0c0\uaca9", "zh-CN": "\u51b2\u523a\u65f6\u6309\u653b\u51fb\u8fdb\u884c\u95ea\u73b0\u6253\u51fb",
        },
        "SwordWeaponArthur": {
            "fr": "Appuyez sur Attaque pour Frappe Lourde", "de": "Dr\u00fccke Angriff f\u00fcr Schweren Hieb",
            "es": "Pulsa Ataque para Golpe Pesado", "it": "Premi Attacco per Colpo Pesante",
            "pt-BR": "Pressione Ataque para Golpe Pesado", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0434\u043b\u044f \u0422\u044f\u0436\u0451\u043b\u043e\u0433\u043e \u0423\u0434\u0430\u0440\u0430",
            "pl": "Naci\u015bnij Atak dla Ci\u0119\u017ckiego Ciosu", "ja": "\u653b\u6483\u3067\u91cd\u65ac\u308a", "ko": "\uacf5\u6483\uc73c\ub85c \uac15\ud0c0", "zh-CN": "\u6309\u653b\u51fb\u8fdb\u884c\u91cd\u51fb",
        },
        "ConsecrationField": {
            "fr": "Appuyez sur Technique pour Terre Sacr\u00e9e", "de": "Dr\u00fccke Spezial f\u00fcr Heiligen Boden",
            "es": "Pulsa Especial para Tierra Consagrada", "it": "Premi Tecnica per Terreno Sacro",
            "pt-BR": "Pressione Especial para Solo Sagrado", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0421\u0432\u044f\u0449\u0435\u043d\u043d\u043e\u0439 \u0417\u0435\u043c\u043b\u0438",
            "pl": "Naci\u015bnij Technik\u0119 dla \u015awi\u0119tej Ziemi", "ja": "\u5fc5\u6bba\u3067\u8056\u5730\u3092\u5c55\u958b", "ko": "\ud2b9\uc218\ub85c \uc2e0\uc131\ud55c \ub545 \uc0dd\uc131", "zh-CN": "\u6309\u7279\u6b8a\u521b\u5efa\u795e\u5723\u9886\u5730",
        },
        "SpearWeapon": {
            "fr": "Appuyez sur Attaque pour Frapper", "de": "Dr\u00fccke Angriff zum Zuschlagen",
            "es": "Pulsa Ataque para Golpear", "it": "Premi Attacco per Colpire",
            "pt-BR": "Pressione Ataque para Golpear", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0434\u043b\u044f \u0423\u0434\u0430\u0440\u0430",
            "pl": "Naci\u015bnij Atak, aby Uderzy\u0107", "ja": "\u653b\u6483\u3067\u7a81\u304f", "ko": "\uacf5\u6483\uc73c\ub85c \ud0c0\uaca9", "zh-CN": "\u6309\u653b\u51fb\u8fdb\u884c\u6253\u51fb",
        },
        "SpearWeaponSpin": {
            "fr": "Maintenez puis Rel\u00e2chez Attaque pour Attaque Tourbillon", "de": "Halte dann Lasse Angriff los f\u00fcr Wirbelangriff",
            "es": "Mant\u00e9n y Suelta Ataque para Ataque Giratorio", "it": "Tieni e Rilascia Attacco per Attacco Rotante",
            "pt-BR": "Segure e Solte Ataque para Ataque Girat\u00f3rio", "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0438 \u041e\u0442\u043f\u0443\u0441\u0442\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0434\u043b\u044f \u0412\u0438\u0445\u0440\u0435\u0432\u043e\u0439 \u0410\u0442\u0430\u043a\u0438",
            "pl": "Przytrzymaj i Pu\u015b\u0107 Atak dla Ataku Wirowego", "ja": "\u653b\u6483\u9577\u62bc\u3057\u3067\u56de\u8ee2\u653b\u6483", "ko": "\uacf5\u6483 \uae38\uac8c \ub20c\ub800\ub2e4 \ub193\uc544 \ud68c\uc804 \uacf5\u6483", "zh-CN": "\u957f\u6309\u653b\u51fb\u540e\u91ca\u653e\u8fdb\u884c\u65cb\u98ce\u653b\u51fb",
        },
        "SpearWeaponThrow": {
            "fr": "Appuyez sur Technique pour Empaler et Rappeler", "de": "Dr\u00fccke Spezial zum Aufspie\u00dfen und Zur\u00fcckrufen",
            "es": "Pulsa Especial para Empalar y Recuperar", "it": "Premi Tecnica per Infilzare e Richiamare",
            "pt-BR": "Pressione Especial para Empalar e Chamar de Volta", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u041f\u0440\u043e\u043d\u0437\u0438\u0442\u044c \u0438 \u0412\u0435\u0440\u043d\u0443\u0442\u044c",
            "pl": "Naci\u015bnij Technik\u0119 dla Nadzienia i Przywo\u0142ania", "ja": "\u5fc5\u6bba\u3067\u8cab\u304d\u3068\u56de\u53ce", "ko": "\ud2b9\uc218\ub85c \uaf3d\uae30\uc640 \ud68c\uc218", "zh-CN": "\u6309\u7279\u6b8a\u8fdb\u884c\u4e32\u523a\u548c\u53ec\u56de",
        },
        "SpearWeaponDash": {
            "fr": "Appuyez sur Attaque en sprintant pour Frappe \u00c9clair", "de": "Dr\u00fccke Angriff beim Sprinten f\u00fcr Blitzschlag",
            "es": "Pulsa Ataque mientras Sprintas para Golpe Rel\u00e1mpago", "it": "Premi Attacco durante lo Scatto per Colpo Lampo",
            "pt-BR": "Pressione Ataque enquanto corre para Golpe Rel\u00e2mpago", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0432\u043e \u0432\u0440\u0435\u043c\u044f \u0420\u044b\u0432\u043a\u0430 \u0434\u043b\u044f \u041c\u043e\u043b\u043d\u0438\u0435\u043d\u043e\u0441\u043d\u043e\u0433\u043e \u0423\u0434\u0430\u0440\u0430",
            "pl": "Naci\u015bnij Atak podczas Zrywu dla Ciosu B\u0142yskawicy", "ja": "\u30c0\u30c3\u30b7\u30e5\u4e2d\u306b\u653b\u6483\u3067\u77ac\u9593\u7a81\u304d", "ko": "\ub300\uc2dc \uc911 \uacf5\u6483\uc73c\ub85c \uc21c\uac04\ud0c0\uaca9", "zh-CN": "\u51b2\u523a\u65f6\u6309\u653b\u51fb\u8fdb\u884c\u95ea\u73b0\u6253\u51fb",
        },
        "ShieldWeapon": {
            "fr": "Appuyez sur Attaque pour Frapper", "de": "Dr\u00fccke Angriff zum Schlagen",
            "es": "Pulsa Ataque para Golpear", "it": "Premi Attacco per Colpire",
            "pt-BR": "Pressione Ataque para Golpear", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0434\u043b\u044f \u0423\u0434\u0430\u0440\u0430",
            "pl": "Naci\u015bnij Atak, aby Uderzy\u0107", "ja": "\u653b\u6483\u3067\u6bb4\u308b", "ko": "\uacf5\u6483\uc73c\ub85c \ud0c0\uaca9", "zh-CN": "\u6309\u653b\u51fb\u8fdb\u884c\u6253\u51fb",
        },
        "ShieldWeaponRush": {
            "fr": "Maintenez Attaque pour D\u00e9fendre, Rel\u00e2chez pour Charge", "de": "Halte Angriff zum Verteidigen, Loslassen f\u00fcr Sturmangriff",
            "es": "Mant\u00e9n Ataque para Defender, Suelta para Embestida", "it": "Tieni Attacco per Difendere, Rilascia per Carica",
            "pt-BR": "Segure Ataque para Defender, Solte para Investida", "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0434\u043b\u044f \u0417\u0430\u0449\u0438\u0442\u044b, \u041e\u0442\u043f\u0443\u0441\u0442\u0438\u0442\u0435 \u0434\u043b\u044f \u0420\u044b\u0432\u043a\u0430",
            "pl": "Przytrzymaj Atak, aby Broni\u0107, Pu\u015b\u0107 dla Szar\u017cy", "ja": "\u653b\u6483\u9577\u62bc\u3057\u3067\u9632\u5fa1\u3001\u96e2\u3057\u3066\u7a81\u9032", "ko": "\uacf5\u6483 \uae38\uac8c \ub20c\ub7ec \ubc29\uc5b4, \ub193\uc544\uc11c \ub3cc\uc9c4", "zh-CN": "\u957f\u6309\u653b\u51fb\u9632\u5fa1\uff0c\u91ca\u653e\u8fdb\u884c\u725b\u51b2",
        },
        "ShieldThrow": {
            "fr": "Appuyez sur Technique pour Lancer", "de": "Dr\u00fccke Spezial zum Werfen",
            "es": "Pulsa Especial para Lanzar", "it": "Premi Tecnica per Lanciare",
            "pt-BR": "Pressione Especial para Arremessar", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0411\u0440\u043e\u0441\u043a\u0430",
            "pl": "Naci\u015bnij Technik\u0119, aby Rzuci\u0107", "ja": "\u5fc5\u6bba\u3067\u6295\u3052\u308b", "ko": "\ud2b9\uc218\ub85c \ub358\uc9c0\uae30", "zh-CN": "\u6309\u7279\u6b8a\u8fdb\u884c\u6295\u63b7",
        },
        "ShieldWeaponDash": {
            "fr": "Appuyez sur Attaque en sprintant pour Frappe \u00c9clair", "de": "Dr\u00fccke Angriff beim Sprinten f\u00fcr Blitzschlag",
            "es": "Pulsa Ataque mientras Sprintas para Golpe Rel\u00e1mpago", "it": "Premi Attacco durante lo Scatto per Colpo Lampo",
            "pt-BR": "Pressione Ataque enquanto corre para Golpe Rel\u00e2mpago", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0432\u043e \u0432\u0440\u0435\u043c\u044f \u0420\u044b\u0432\u043a\u0430 \u0434\u043b\u044f \u041c\u043e\u043b\u043d\u0438\u0435\u043d\u043e\u0441\u043d\u043e\u0433\u043e \u0423\u0434\u0430\u0440\u0430",
            "pl": "Naci\u015bnij Atak podczas Zrywu dla Ciosu B\u0142yskawicy", "ja": "\u30c0\u30c3\u30b7\u30e5\u4e2d\u306b\u653b\u6483\u3067\u77ac\u9593\u6253\u3061", "ko": "\ub300\uc2dc \uc911 \uacf5\u6483\uc73c\ub85c \uc21c\uac04\ud0c0\uaca9", "zh-CN": "\u51b2\u523a\u65f6\u6309\u653b\u51fb\u8fdb\u884c\u95ea\u73b0\u6253\u51fb",
        },
        "BowWeapon": {
            "fr": "Maintenez Attaque pour Tirer", "de": "Halte Angriff zum Schie\u00dfen",
            "es": "Mant\u00e9n Ataque para Disparar", "it": "Tieni Attacco per Sparare",
            "pt-BR": "Segure Ataque para Disparar", "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0434\u043b\u044f \u0421\u0442\u0440\u0435\u043b\u044c\u0431\u044b",
            "pl": "Przytrzymaj Atak, aby Strzeli\u0107", "ja": "\u653b\u6483\u9577\u62bc\u3057\u3067\u5c04\u3064", "ko": "\uacf5\u6383 \uae38\uac8c \ub20c\ub7ec \ubc1c\uc0ac", "zh-CN": "\u957f\u6309\u653b\u51fb\u8fdb\u884c\u5c04\u51fb",
        },
        "BowSplitShot": {
            "fr": "Appuyez sur Technique pour Tir en Volley", "de": "Dr\u00fccke Spezial f\u00fcr Salve",
            "es": "Pulsa Especial para Descarga", "it": "Premi Tecnica per Raffica",
            "pt-BR": "Pressione Especial para Rajada", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0417\u0430\u043b\u043f\u0430",
            "pl": "Naci\u015bnij Technik\u0119 dla Salwy", "ja": "\u5fc5\u6bba\u3067\u4e00\u6589\u5c04\u6483", "ko": "\ud2b9\uc218\ub85c \uc77c\uc81c\uc0ac\uaca9", "zh-CN": "\u6309\u7279\u6b8a\u8fdb\u884c\u9f50\u5c04",
        },
        "BowWeaponDash": {
            "fr": "Appuyez sur Attaque en sprintant pour Frappe \u00c9clair", "de": "Dr\u00fccke Angriff beim Sprinten f\u00fcr Blitzschlag",
            "es": "Pulsa Ataque mientras Sprintas para Golpe Rel\u00e1mpago", "it": "Premi Attacco durante lo Scatto per Colpo Lampo",
            "pt-BR": "Pressione Ataque enquanto corre para Golpe Rel\u00e2mpago", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0432\u043e \u0432\u0440\u0435\u043c\u044f \u0420\u044b\u0432\u043a\u0430 \u0434\u043b\u044f \u041c\u043e\u043b\u043d\u0438\u0435\u043d\u043e\u0441\u043d\u043e\u0433\u043e \u0423\u0434\u0430\u0440\u0430",
            "pl": "Naci\u015bnij Atak podczas Zrywu dla Ciosu B\u0142yskawicy", "ja": "\u30c0\u30c3\u30b7\u30e5\u4e2d\u306b\u653b\u6483\u3067\u77ac\u9593\u5c04\u6483", "ko": "\ub300\uc2dc \uc911 \uacf5\u6383\uc73c\ub85c \uc21c\uac04\ud0c0\uaca9", "zh-CN": "\u51b2\u523a\u65f6\u6309\u653b\u51fb\u8fdb\u884c\u95ea\u73b0\u6253\u51fb",
        },
        "PerfectCharge": {
            "fr": "Rel\u00e2chez Attaque pendant le flash pour Tir Puissant", "de": "Lasse Angriff beim Aufleuchten f\u00fcr Kraftschuss los",
            "es": "Suelta Ataque durante el destello para Disparo de Poder", "it": "Rilascia Attacco durante il flash per Colpo Potente",
            "pt-BR": "Solte Ataque durante o flash para Tiro Poderoso", "ru": "\u041e\u0442\u043f\u0443\u0441\u0442\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0432\u043e \u0432\u0440\u0435\u043c\u044f \u0432\u0441\u043f\u044b\u0448\u043a\u0438 \u0434\u043b\u044f \u041c\u043e\u0449\u043d\u043e\u0433\u043e \u0412\u044b\u0441\u0442\u0440\u0435\u043b\u0430",
            "pl": "Pu\u015b\u0107 Atak podczas b\u0142ysku dla Strza\u0142u Mocy", "ja": "\u70b9\u6ec5\u4e2d\u306b\u653b\u6483\u3092\u96e2\u3057\u3066\u5f37\u5c04\u6483", "ko": "\uc12c\uad11 \uc911 \uacf5\u6383\uc744 \ub193\uc544 \uac15\ub825 \uc0ac\uaca9", "zh-CN": "\u95ea\u5149\u65f6\u91ca\u653e\u653b\u51fb\u8fdb\u884c\u5f3a\u529b\u5c04\u51fb",
        },
        "GunWeapon": {
            "fr": "Maintenez Attaque pour Tirer", "de": "Halte Angriff zum Schie\u00dfen",
            "es": "Mant\u00e9n Ataque para Disparar", "it": "Tieni Attacco per Sparare",
            "pt-BR": "Segure Ataque para Disparar", "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0434\u043b\u044f \u0421\u0442\u0440\u0435\u043b\u044c\u0431\u044b",
            "pl": "Przytrzymaj Atak, aby Strzeli\u0107", "ja": "\u653b\u6483\u9577\u62bc\u3057\u3067\u5c04\u6483", "ko": "\uacf5\u6383 \uae38\uac8c \ub20c\ub7ec \uc0ac\uaca9", "zh-CN": "\u957f\u6309\u653b\u51fb\u8fdb\u884c\u5c04\u51fb",
        },
        "GunWeaponManualReload": {
            "fr": "Appuyez sur Recharger pour Recharger", "de": "Dr\u00fccke Nachladen zum Nachladen",
            "es": "Pulsa Recargar para Recargar", "it": "Premi Ricarica per Ricaricare",
            "pt-BR": "Pressione Recarregar para Recarregar", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u041f\u0435\u0440\u0435\u0437\u0430\u0440\u044f\u0434\u043a\u0430 \u0434\u043b\u044f \u041f\u0435\u0440\u0435\u0437\u0430\u0440\u044f\u0434\u043a\u0438",
            "pl": "Naci\u015bnij Prze\u0142aduj, aby Prze\u0142adowa\u0107", "ja": "\u30ea\u30ed\u30fc\u30c9\u3067\u88c5\u586b", "ko": "\uc7ac\uc7a5\uc804\uc73c\ub85c \uc7ac\uc7a5\uc804", "zh-CN": "\u6309\u88c5\u5f39\u8fdb\u884c\u88c5\u5f39",
        },
        "GunGrenadeToss": {
            "fr": "Maintenez puis Rel\u00e2chez Technique pour Bombarder", "de": "Halte dann Lasse Spezial f\u00fcr Bombardierung los",
            "es": "Mant\u00e9n y Suelta Especial para Bombardear", "it": "Tieni e Rilascia Tecnica per Bombardare",
            "pt-BR": "Segure e Solte Especial para Bombardear", "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0438 \u041e\u0442\u043f\u0443\u0441\u0442\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0411\u043e\u043c\u0431\u0430\u0440\u0434\u0438\u0440\u043e\u0432\u043a\u0438",
            "pl": "Przytrzymaj i Pu\u015b\u0107 Technik\u0119 dla Bombardowania", "ja": "\u5fc5\u6bba\u9577\u62bc\u3057\u3067\u7206\u6483", "ko": "\ud2b9\uc218 \uae38\uac8c \ub20c\ub800\ub2e4 \ub193\uc544 \ud3ed\uaca9", "zh-CN": "\u957f\u6309\u7279\u6b8a\u540e\u91ca\u653e\u8fdb\u884c\u8f70\u70b8",
        },
        "GunWeaponDash": {
            "fr": "Appuyez sur Attaque en sprintant pour Frappe \u00c9clair", "de": "Dr\u00fccke Angriff beim Sprinten f\u00fcr Blitzschlag",
            "es": "Pulsa Ataque mientras Sprintas para Golpe Rel\u00e1mpago", "it": "Premi Attacco durante lo Scatto per Colpo Lampo",
            "pt-BR": "Pressione Ataque enquanto corre para Golpe Rel\u00e2mpago", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0432\u043e \u0432\u0440\u0435\u043c\u044f \u0420\u044b\u0432\u043a\u0430 \u0434\u043b\u044f \u041c\u043e\u043b\u043d\u0438\u0435\u043d\u043e\u0441\u043d\u043e\u0433\u043e \u0423\u0434\u0430\u0440\u0430",
            "pl": "Naci\u015bnij Atak podczas Zrywu dla Ciosu B\u0142yskawicy", "ja": "\u30c0\u30c3\u30b7\u30e5\u4e2d\u306b\u653b\u6483\u3067\u77ac\u9593\u5c04\u6483", "ko": "\ub300\uc2dc \uc911 \uacf5\u6383\uc73c\ub85c \uc21c\uac04\ud0c0\uaca9", "zh-CN": "\u51b2\u523a\u65f6\u6309\u653b\u51fb\u8fdb\u884c\u95ea\u73b0\u6253\u51fb",
        },
        "ManualReload": {
            "fr": "Appuyez sur Recharger pour Recharger", "de": "Dr\u00fccke Nachladen zum Nachladen",
            "es": "Pulsa Recargar para Recargar", "it": "Premi Ricarica per Ricaricare",
            "pt-BR": "Pressione Recarregar para Recarregar", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u041f\u0435\u0440\u0435\u0437\u0430\u0440\u044f\u0434\u043a\u0430 \u0434\u043b\u044f \u041f\u0435\u0440\u0435\u0437\u0430\u0440\u044f\u0434\u043a\u0438",
            "pl": "Naci\u015bnij Prze\u0142aduj, aby Prze\u0142adowa\u0107", "ja": "\u30ea\u30ed\u30fc\u30c9\u3067\u88c5\u586b", "ko": "\uc7ac\uc7a5\uc804\uc73c\ub85c \uc7ac\uc7a5\uc804", "zh-CN": "\u6309\u88c5\u5f39\u8fdb\u884c\u88c5\u5f39",
        },
        "FistWeapon": {
            "fr": "Maintenez Attaque pour Marteler", "de": "Halte Angriff zum Pr\u00fcgeln",
            "es": "Mant\u00e9n Ataque para Golpear", "it": "Tieni Attacco per Pestare",
            "pt-BR": "Segure Ataque para Socar", "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0434\u043b\u044f \u041a\u043e\u043c\u0431\u043e",
            "pl": "Przytrzymaj Atak, aby M\u0142\u00f3ci\u0107", "ja": "\u653b\u6483\u9577\u62bc\u3057\u3067\u9023\u6253", "ko": "\uacf5\u6383 \uae38\uac8c \ub20c\ub7ec \ub09c\ud0c0", "zh-CN": "\u957f\u6309\u653b\u51fb\u8fdb\u884c\u8fde\u6253",
        },
        "FistWeaponSpecial": {
            "fr": "Appuyez sur Technique pour Coup Ascendant", "de": "Dr\u00fccke Spezial f\u00fcr Aufsteigenden Schnitt",
            "es": "Pulsa Especial para Corte Ascendente", "it": "Premi Tecnica per Taglio Ascendente",
            "pt-BR": "Pressione Especial para Golpe Ascendente", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0412\u043e\u0441\u0445\u043e\u0434\u044f\u0449\u0435\u0433\u043e \u0423\u0434\u0430\u0440\u0430",
            "pl": "Naci\u015bnij Technik\u0119 dla Ci\u0119cia Wznosz\u0105cego", "ja": "\u5fc5\u6bba\u3067\u30e9\u30a4\u30b8\u30f3\u30b0\u30ab\u30c3\u30bf\u30fc", "ko": "\ud2b9\uc218\ub85c \ub77c\uc774\uc9d5 \ucee4\ud130", "zh-CN": "\u6309\u7279\u6b8a\u8fdb\u884c\u4e0a\u5347\u65a9",
        },
        "FistWeaponDash": {
            "fr": "Appuyez sur Attaque en sprintant pour Frappe Sprint", "de": "Dr\u00fccke Angriff beim Sprinten f\u00fcr Sprint-Schlag",
            "es": "Pulsa Ataque mientras Sprintas para Golpe de Sprint", "it": "Premi Attacco durante lo Scatto per Colpo Sprint",
            "pt-BR": "Pressione Ataque enquanto corre para Golpe de Dash", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0432\u043e \u0432\u0440\u0435\u043c\u044f \u0420\u044b\u0432\u043a\u0430 \u0434\u043b\u044f \u0423\u0434\u0430\u0440\u0430 \u0420\u044b\u0432\u043a\u043e\u043c",
            "pl": "Naci\u015bnij Atak podczas Zrywu dla Ciosu Zrywu", "ja": "\u30c0\u30c3\u30b7\u30e5\u4e2d\u306b\u653b\u6483\u3067\u30c0\u30c3\u30b7\u30e5\u30b9\u30c8\u30e9\u30a4\u30af", "ko": "\ub300\uc2dc \uc911 \uacf5\u6383\uc73c\ub85c \ub300\uc2dc \ud0c0\uaca9", "zh-CN": "\u51b2\u523a\u65f6\u6309\u653b\u51fb\u8fdb\u884c\u51b2\u523a\u6253\u51fb",
        },
        "EXMove": {
            "fr": "Appuyez sur Attaque et Technique ensemble pour Mouvement EX", "de": "Dr\u00fccke Angriff und Spezial gleichzeitig f\u00fcr EX-Zug",
            "es": "Pulsa Ataque y Especial juntos para Movimiento EX", "it": "Premi Attacco e Tecnica insieme per Mossa EX",
            "pt-BR": "Pressione Ataque e Especial juntos para Golpe EX", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0438 \u0423\u043c\u0435\u043d\u0438\u0435 \u0432\u043c\u0435\u0441\u0442\u0435 \u0434\u043b\u044f EX-\u041f\u0440\u0438\u0451\u043c\u0430",
            "pl": "Naci\u015bnij Atak i Technik\u0119 razem dla Ruchu EX", "ja": "\u653b\u6483\u3068\u5fc5\u6bba\u540c\u6642\u62bc\u3057\u3067EX\u6280", "ko": "\uacf5\u6383\uacfc \ud2b9\uc218 \ub3d9\uc2dc \ub20c\ub7ec EX\uae30", "zh-CN": "\u540c\u65f6\u6309\u653b\u51fb\u548c\u7279\u6b8a\u8fdb\u884cEX\u62db\u5f0f",
        },
        "SuperMove": {
            "fr": "Appuyez sur Invocation pour l'Aide divine", "de": "Dr\u00fccke Ruf f\u00fcr G\u00f6ttliche Hilfe",
            "es": "Pulsa Invocaci\u00f3n para Ayuda", "it": "Premi Invocazione per Aiuto",
            "pt-BR": "Pressione Chamado para Ajuda", "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u041f\u0440\u0438\u0437\u044b\u0432 \u0434\u043b\u044f \u041f\u043e\u043c\u043e\u0449\u0438",
            "pl": "Naci\u015bnij Wezwanie, aby u\u017cy\u0107 Pomocy", "ja": "\u53ec\u559a\u3067\u63f4\u8b77\u3092\u4f7f\u3046", "ko": "\uc18c\ud658\uc73c\ub85c \uc6d0\uc870", "zh-CN": "\u6309\u53ec\u5524\u4f7f\u7528\u63f4\u52a9",
        },
        "BuildSuper": {
            "fr": "Remplissez la Jauge divine pour utiliser l'Aide", "de": "F\u00fclle die G\u00f6tterleiste f\u00fcr Hilfe",
            "es": "Llena la Barra Divina para usar Ayuda", "it": "Riempi la Barra Divina per usare l'Aiuto",
            "pt-BR": "Encha a Barra Divina para usar Ajuda", "ru": "\u041d\u0430\u043a\u043e\u043f\u0438\u0442\u0435 \u0411\u043e\u0436\u0435\u0441\u0442\u0432\u0435\u043d\u043d\u0443\u044e \u0428\u043a\u0430\u043b\u0443 \u0434\u043b\u044f \u041f\u043e\u043c\u043e\u0449\u0438",
            "pl": "Nape\u0142nij Miernik Boski, aby u\u017cy\u0107 Pomocy", "ja": "\u795e\u30b2\u30fc\u30b8\u3092\u305f\u3081\u3066\u63f4\u8b77\u3092\u4f7f\u3046", "ko": "\uc2e0 \uac8c\uc774\uc9c0\ub97c \ucc44\uc6cc \uc6d0\uc870 \uc0ac\uc6a9", "zh-CN": "\u586b\u6ee1\u795e\u529b\u69fd\u4f7f\u7528\u63f4\u52a9",
        },
        "SpearWeaponThrowTeleport": {
            "fr": "Appuyez sur Technique pour Lancer, appuyez \u00e0 nouveau pour T\u00e9l\u00e9portation",
            "de": "Dr\u00fccke Spezial zum Werfen, nochmal dr\u00fccken zum Teleportieren",
            "es": "Pulsa Especial para Lanzar, pulsa de nuevo para Teletransportarte",
            "it": "Premi Tecnica per Lanciare, premi di nuovo per Teletrasportarti",
            "pt-BR": "Pressione Especial para Arremessar, pressione novamente para se Teletransportar",
            "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0411\u0440\u043e\u0441\u043a\u0430, \u043d\u0430\u0436\u043c\u0438\u0442\u0435 \u0441\u043d\u043e\u0432\u0430 \u0434\u043b\u044f \u0422\u0435\u043b\u0435\u043f\u043e\u0440\u0442\u0430\u0446\u0438\u0438",
            "pl": "Naci\u015bnij Technik\u0119, aby Rzuci\u0107, naci\u015bnij ponownie, aby si\u0119 Teleportowa\u0107",
            "ja": "\u5fc5\u6bba\u3067\u6295\u3052\u308b\u3001\u518d\u5ea6\u62bc\u3057\u3066\u30c6\u30ec\u30dd\u30fc\u30c8",
            "ko": "\ud2b9\uc218\ub85c \ub358\uc9c0\uae30, \ub2e4\uc2dc \ub20c\ub7ec \ud154\ub808\ud3ec\ud2b8",
            "zh-CN": "\u6309\u7279\u6b8a\u6295\u63b7\uff0c\u518d\u6309\u4f20\u9001\u81ea\u5df1",
        },
        "SpearThrowRegularRetrieve": {
            "fr": "Appuyez sur Technique pour Lancer, appuyez \u00e0 nouveau pour Rappeler",
            "de": "Dr\u00fccke Spezial zum Werfen, nochmal dr\u00fccken zum Zur\u00fcckrufen",
            "es": "Pulsa Especial para Lanzar, pulsa de nuevo para Recuperar",
            "it": "Premi Tecnica per Lanciare, premi di nuovo per Richiamare",
            "pt-BR": "Pressione Especial para Arremessar, pressione novamente para Chamar de Volta",
            "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0411\u0440\u043e\u0441\u043a\u0430, \u043d\u0430\u0436\u043c\u0438\u0442\u0435 \u0441\u043d\u043e\u0432\u0430 \u0434\u043b\u044f \u0412\u043e\u0437\u0432\u0440\u0430\u0442\u0430",
            "pl": "Naci\u015bnij Technik\u0119, aby Rzuci\u0107, naci\u015bnij ponownie, aby Przywo\u0142a\u0107",
            "ja": "\u5fc5\u6bba\u3067\u6295\u3052\u308b\u3001\u518d\u5ea6\u62bc\u3057\u3066\u56de\u53ce",
            "ko": "\ud2b9\uc218\ub85c \ub358\uc9c0\uae30, \ub2e4\uc2dc \ub20c\ub7ec \ud68c\uc218",
            "zh-CN": "\u6309\u7279\u6b8a\u6295\u63b7\uff0c\u518d\u6309\u53ec\u56de",
        },
        "SpearWeaponThrowSingle": {
            "fr": "Maintenez Technique pour charger le Lancer",
            "de": "Halte Spezial, um den Wurf aufzuladen",
            "es": "Mant\u00e9n Especial para cargar el Lanzamiento",
            "it": "Tieni premuto Tecnica per caricare il Lancio",
            "pt-BR": "Segure Especial para carregar o Arremesso",
            "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0437\u0430\u0440\u044f\u0434\u043a\u0438 \u0411\u0440\u043e\u0441\u043a\u0430",
            "pl": "Przytrzymaj Technik\u0119, aby na\u0142adowa\u0107 Rzut",
            "ja": "\u5fc5\u6bba\u9577\u62bc\u3057\u3067\u6295\u3052\u3092\u30c1\u30e3\u30fc\u30b8",
            "ko": "\ud2b9\uc218 \uae38\uac8c \ub20c\ub7ec \ub358\uc9c0\uae30 \ucc28\uc9c0",
            "zh-CN": "\u957f\u6309\u7279\u6b8a\u84c4\u529b\u6295\u63b7",
        },
        "SpearWeaponSpinRanged": {
            "fr": "Maintenez Technique pour charger une Ru\u00e9e Furieuse",
            "de": "Halte Spezial, um einen Rasenden Ansturm aufzuladen",
            "es": "Mant\u00e9n Especial para cargar un Embestida Furiosa",
            "it": "Tieni premuto Tecnica per caricare una Carica Furiosa",
            "pt-BR": "Segure Especial para carregar um Avan\u00e7o Furioso",
            "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0437\u0430\u0440\u044f\u0434\u043a\u0438 \u042f\u0440\u043e\u0441\u0442\u043d\u043e\u0433\u043e \u0420\u044b\u0432\u043a\u0430",
            "pl": "Przytrzymaj Technik\u0119, aby na\u0142adowa\u0107 Szale\u0144czy Szturm",
            "ja": "\u5fc5\u6bba\u9577\u62bc\u3057\u3067\u731b\u9032\u3092\u30c1\u30e3\u30fc\u30b8",
            "ko": "\ud2b9\uc218 \uae38\uac8c \ub20c\ub7ec \uad11\ub780\uc758 \ub3cc\uc9c4 \ucc28\uc9c0",
            "zh-CN": "\u957f\u6309\u7279\u6b8a\u84c4\u529b\u72c2\u66b4\u51b2\u950b",
        },
        "ShieldGrind": {
            "fr": "Maintenez Technique pour surfer sur le Bouclier",
            "de": "Halte Spezial, um auf dem Schild zu surfen",
            "es": "Mant\u00e9n Especial para surfear sobre el Escudo",
            "it": "Tieni premuto Tecnica per surfare sullo Scudo",
            "pt-BR": "Segure Especial para surfar no Escudo",
            "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0441\u043a\u043e\u043b\u044c\u0436\u0435\u043d\u0438\u044f \u043d\u0430 \u0429\u0438\u0442\u0435",
            "pl": "Przytrzymaj Technik\u0119, aby surfowa\u0107 na Tarczy",
            "ja": "\u5fc5\u6bba\u9577\u62bc\u3057\u3067\u76fe\u30b5\u30fc\u30d5\u30a3\u30f3",
            "ko": "\ud2b9\uc218 \uae38\uac8c \ub20c\ub7ec \ubc29\ud328 \uc11c\ud551",
            "zh-CN": "\u957f\u6309\u7279\u6b8a\u5728\u76fe\u724c\u4e0a\u6ed1\u884c",
        },
        "ShieldRushAndThrow": {
            "fr": "Appuyez sur Technique pour Ru\u00e9e du Dragon",
            "de": "Dr\u00fccke Spezial f\u00fcr Drachensturm",
            "es": "Pulsa Especial para Embestida del Drag\u00f3n",
            "it": "Premi Tecnica per Carica del Drago",
            "pt-BR": "Pressione Especial para Investida do Drag\u00e3o",
            "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0420\u044b\u0432\u043a\u0430 \u0414\u0440\u0430\u043a\u043e\u043d\u0430",
            "pl": "Naci\u015bnij Technik\u0119 dla Smoczego Szturmu",
            "ja": "\u5fc5\u6bba\u3067\u30c9\u30e9\u30b4\u30f3\u30e9\u30c3\u30b7\u30e5",
            "ko": "\ud2b9\uc218\ub85c \ub4dc\ub798\uace4 \ub7ec\uc2dc",
            "zh-CN": "\u6309\u7279\u6b8a\u8fdb\u884c\u9f99\u4e4b\u51b2\u950b",
        },
        "BeowulfAttack": {
            "fr": "Maintenez Technique pour charger le Sort dans votre prochaine Attaque",
            "de": "Halte Spezial, um den Wurf in deinen n\u00e4chsten Angriff zu laden",
            "es": "Mant\u00e9n Especial para cargar Hechizo en tu pr\u00f3ximo Ataque",
            "it": "Tieni premuto Tecnica per caricare il Sortilegio nel prossimo Attacco",
            "pt-BR": "Segure Especial para carregar Feiti\u00e7o no pr\u00f3ximo Ataque",
            "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0437\u0430\u0440\u044f\u0434\u043a\u0438 \u041a\u0430\u0441\u0442\u0430 \u0432 \u0441\u043b\u0435\u0434\u0443\u044e\u0449\u0443\u044e \u0410\u0442\u0430\u043a\u0443",
            "pl": "Przytrzymaj Technik\u0119, aby za\u0142adowa\u0107 Rzut do nast\u0119pnego Ataku",
            "ja": "\u5fc5\u6bba\u9577\u62bc\u3057\u3067\u6b21\u306e\u653b\u6483\u306b\u9b54\u5f3e\u3092\u8fbc\u3081\u308b",
            "ko": "\ud2b9\uc218 \uae38\uac8c \ub20c\ub7ec \ub2e4\uc74c \uacf5\u6383\uc5d0 \uc2dc\uc804 \uc7a5\uc804",
            "zh-CN": "\u957f\u6309\u7279\u6b8a\u5c06\u65bd\u6cd5\u88c5\u5165\u4e0b\u6b21\u653b\u51fb",
        },
        "BeowulfSpecial": {
            "fr": "Maintenez Technique pour charger le Sort dans un lancer puissant",
            "de": "Halte Spezial, um den Wurf in einen m\u00e4chtigen Wurf zu laden",
            "es": "Mant\u00e9n Especial para cargar Hechizo en un lanzamiento poderoso",
            "it": "Tieni premuto Tecnica per caricare il Sortilegio in un lancio potente",
            "pt-BR": "Segure Especial para carregar Feiti\u00e7o em um arremesso poderoso",
            "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0437\u0430\u0440\u044f\u0434\u043a\u0438 \u041a\u0430\u0441\u0442\u0430 \u0432 \u043c\u043e\u0449\u043d\u044b\u0439 \u0431\u0440\u043e\u0441\u043e\u043a",
            "pl": "Przytrzymaj Technik\u0119, aby za\u0142adowa\u0107 Rzut w pot\u0119\u017cny rzut",
            "ja": "\u5fc5\u6bba\u9577\u62bc\u3057\u3067\u5f37\u529b\u306a\u6295\u3052\u306b\u9b54\u5f3e\u3092\u8fbc\u3081\u308b",
            "ko": "\ud2b9\uc218 \uae38\uac8c \ub20c\ub7ec \uac15\ub825\ud55c \ub358\uc9c0\uae30\uc5d0 \uc2dc\uc804 \uc7a5\uc804",
            "zh-CN": "\u957f\u6309\u7279\u6b8a\u5c06\u65bd\u6cd5\u88c5\u5165\u5f3a\u529b\u6295\u63b7",
        },
        "BeowulfTackle": {
            "fr": "Maintenez Attaque pour D\u00e9fendre, Rel\u00e2chez pour charger",
            "de": "Halte Angriff zum Verteidigen, Loslassen zum Anst\u00fcrmen",
            "es": "Mant\u00e9n Ataque para Defender, Suelta para embestir",
            "it": "Tieni premuto Attacco per Difendere, Rilascia per caricare",
            "pt-BR": "Segure Ataque para Defender, Solte para investir",
            "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0410\u0442\u0430\u043a\u0443 \u0434\u043b\u044f \u0417\u0430\u0449\u0438\u0442\u044b, \u041e\u0442\u043f\u0443\u0441\u0442\u0438\u0442\u0435 \u0434\u043b\u044f \u0440\u044b\u0432\u043a\u0430",
            "pl": "Przytrzymaj Atak, aby Broni\u0107, Pu\u015b\u0107, aby szar\u017cowa\u0107",
            "ja": "\u653b\u6483\u9577\u62bc\u3057\u3067\u9632\u5fa1\u3001\u96e2\u3057\u3066\u7a81\u9032",
            "ko": "\uacf5\uaca9 \uae38\uac8c \ub20c\ub7ec \ubc29\uc5b4, \ub193\uc544\uc11c \ub3cc\uc9c4",
            "zh-CN": "\u957f\u6309\u653b\u51fb\u9632\u5fa1\uff0c\u91ca\u653e\u8fdb\u884c\u51b2\u649e",
        },
        "LoadAmmoApplicator": {
            "fr": "Appuyez sur Sort pour charger des munitions, puis appuyez sur Attaque ou Technique",
            "de": "Dr\u00fccke Wurf, um Munition zu laden, dann dr\u00fccke Angriff oder Spezial",
            "es": "Pulsa Hechizo para cargar munici\u00f3n, luego pulsa Ataque o Especial",
            "it": "Premi Sortilegio per caricare munizioni, poi premi Attacco o Tecnica",
            "pt-BR": "Pressione Feiti\u00e7o para carregar muni\u00e7\u00e3o, depois pressione Ataque ou Especial",
            "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u041a\u0430\u0441\u0442 \u0434\u043b\u044f \u0437\u0430\u0440\u044f\u0434\u043a\u0438 \u0431\u043e\u0435\u043f\u0440\u0438\u043f\u0430\u0441\u043e\u0432, \u0437\u0430\u0442\u0435\u043c \u043d\u0430\u0436\u043c\u0438\u0442\u0435 \u0410\u0442\u0430\u043a\u0430 \u0438\u043b\u0438 \u0423\u043c\u0435\u043d\u0438\u0435",
            "pl": "Naci\u015bnij Rzut, aby za\u0142adowa\u0107 amunicj\u0119, potem naci\u015bnij Atak lub Technik\u0119",
            "ja": "\u9b54\u5f3e\u3067\u5f3e\u3092\u88c5\u586b\u3001\u305d\u306e\u5f8c\u653b\u6483\u304b\u5fc5\u6bba\u3092\u62bc\u3059",
            "ko": "\uc2dc\uc804\uc73c\ub85c \ud0c4\uc57d \uc7a5\uc804, \uadf8 \ud6c4 \uacf5\u6383 \ub610\ub294 \ud2b9\uc218 \ub204\ub974\uae30",
            "zh-CN": "\u6309\u65bd\u6cd5\u88c5\u5f39\uff0c\u7136\u540e\u6309\u653b\u51fb\u6216\u7279\u6b8a",
        },
        "GunEmpower": {
            "fr": "Maintenez Technique pour allumer le Lance-roquettes",
            "de": "Halte Spezial, um den Raketenwerfer zu z\u00fcnden",
            "es": "Mant\u00e9n Especial para encender el Lanzacohetes",
            "it": "Tieni premuto Tecnica per accendere il Lanciarazzi",
            "pt-BR": "Segure Especial para acender o Lan\u00e7a-foguetes",
            "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0437\u0430\u0436\u0438\u0433\u0430\u043d\u0438\u044f \u0420\u0430\u043a\u0435\u0442\u043d\u0438\u0446\u044b",
            "pl": "Przytrzymaj Technik\u0119, aby odpali\u0107 Wyrzutni\u0119 Rakiet",
            "ja": "\u5fc5\u6bba\u9577\u62bc\u3057\u3067\u30ed\u30b1\u30c3\u30c8\u30e9\u30f3\u30c1\u30e3\u30fc\u3092\u70b9\u706b",
            "ko": "\ud2b9\uc218 \uae38\uac8c \ub20c\ub7ec \ub85c\ucf13 \ub7f0\ucc98 \uc810\ud654",
            "zh-CN": "\u957f\u6309\u7279\u6b8a\u70b9\u71c3\u706b\u7bad\u53d1\u5c04\u5668",
        },
        "GunGrenadeLucifer": {
            "fr": "Appuyez sur Technique pour tirer un rayon de Feu Infernal",
            "de": "Dr\u00fccke Spezial, um einen H\u00f6llenfeuer-Strahl abzufeuern",
            "es": "Pulsa Especial para disparar un rayo de Fuego Infernal",
            "it": "Premi Tecnica per sparare un raggio di Fuoco Infernale",
            "pt-BR": "Pressione Especial para disparar um raio de Fogo Infernal",
            "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0432\u044b\u0441\u0442\u0440\u0435\u043b\u0430 \u043b\u0443\u0447\u043e\u043c \u0410\u0434\u0441\u043a\u043e\u0433\u043e \u041e\u0433\u043d\u044f",
            "pl": "Naci\u015bnij Technik\u0119, aby wystrzeli\u0107 promie\u0144 Piekielnego Ognia",
            "ja": "\u5fc5\u6bba\u3067\u30d8\u30eb\u30d5\u30a1\u30a4\u30a2\u30d3\u30fc\u30e0\u3092\u767a\u5c04",
            "ko": "\ud2b9\uc218\ub85c \uc9c0\uc625\uc758 \ubd88 \ube54 \ubc1c\uc0ac",
            "zh-CN": "\u6309\u7279\u6b8a\u53d1\u5c04\u5730\u72f1\u706b\u5149\u675f",
        },
        "GunGrenadeLuciferBlast": {
            "fr": "Maintenez Technique pour d\u00e9tonner les rayons de Feu Infernal",
            "de": "Halte Spezial, um H\u00f6llenfeuer-Strahlen zu z\u00fcnden",
            "es": "Mant\u00e9n Especial para detonar los rayos de Fuego Infernal",
            "it": "Tieni premuto Tecnica per detonare i raggi di Fuoco Infernale",
            "pt-BR": "Segure Especial para detonar os raios de Fogo Infernal",
            "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0434\u0435\u0442\u043e\u043d\u0430\u0446\u0438\u0438 \u043b\u0443\u0447\u0435\u0439 \u0410\u0434\u0441\u043a\u043e\u0433\u043e \u041e\u0433\u043d\u044f",
            "pl": "Przytrzymaj Technik\u0119, aby zdetonowa\u0107 promienie Piekielnego Ognia",
            "ja": "\u5fc5\u6bba\u9577\u62bc\u3057\u3067\u30d8\u30eb\u30d5\u30a1\u30a4\u30a2\u5149\u7dda\u3092\u7206\u7834",
            "ko": "\ud2b9\uc218 \uae38\uac8c \ub20c\ub7ec \uc9c0\uc625\uc758 \ubd88 \uad11\uc120 \ud3ed\ud30c",
            "zh-CN": "\u957f\u6309\u7279\u6b8a\u5f15\u7206\u5730\u72f1\u706b\u5149\u7ebf",
        },
        "GunWeaponActiveReload": {
            "fr": "Appuyez sur Recharger pour un rechargement rapide",
            "de": "Dr\u00fccke Nachladen f\u00fcr schnelleres Nachladen",
            "es": "Pulsa Recargar para una recarga r\u00e1pida",
            "it": "Premi Ricarica per una ricarica rapida",
            "pt-BR": "Pressione Recarregar para recarga r\u00e1pida",
            "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u041f\u0435\u0440\u0435\u0437\u0430\u0440\u044f\u0434\u043a\u0430 \u0434\u043b\u044f \u0443\u0441\u043a\u043e\u0440\u0435\u043d\u043d\u043e\u0439 \u043f\u0435\u0440\u0435\u0437\u0430\u0440\u044f\u0434\u043a\u0438",
            "pl": "Naci\u015bnij Prze\u0142aduj dla szybszego prze\u0142adowania",
            "ja": "\u30ea\u30ed\u30fc\u30c9\u3067\u624b\u52d5\u88c5\u586b\u30d6\u30fc\u30b9\u30c8",
            "ko": "\uc7ac\uc7a5\uc804\uc73c\ub85c \uc218\ub3d9 \uc7ac\uc7a5\uc804 \ubd80\uc2a4\ud2b8",
            "zh-CN": "\u6309\u88c5\u5f39\u8fdb\u884c\u624b\u52a8\u88c5\u5f39\u52a0\u901f",
        },
        "FistWeaponSpecialDash": {
            "fr": "Appuyez sur Technique en sprintant pour Uppercut Sprint",
            "de": "Dr\u00fccke Spezial beim Sprinten f\u00fcr Sprint-Uppercut",
            "es": "Pulsa Especial mientras Sprintas para Uppercut de Sprint",
            "it": "Premi Tecnica durante lo Scatto per Montante Sprint",
            "pt-BR": "Pressione Especial enquanto corre para Uppercut de Dash",
            "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0432\u043e \u0432\u0440\u0435\u043c\u044f \u0420\u044b\u0432\u043a\u0430 \u0434\u043b\u044f \u0410\u043f\u043f\u0435\u0440\u043a\u043e\u0442\u0430 \u0420\u044b\u0432\u043a\u043e\u043c",
            "pl": "Naci\u015bnij Technik\u0119 podczas Zrywu dla Uppercut Zrywu",
            "ja": "\u30c0\u30c3\u30b7\u30e5\u4e2d\u306b\u5fc5\u6bba\u3067\u30c0\u30c3\u30b7\u30e5\u30a2\u30c3\u30d1\u30fc",
            "ko": "\ub300\uc2dc \uc911 \ud2b9\uc218\ub85c \ub300\uc2dc \uc5b4\ud37c",
            "zh-CN": "\u51b2\u523a\u65f6\u6309\u7279\u6b8a\u8fdb\u884c\u51b2\u523a\u4e0a\u52fe\u62f3",
        },
        "FistWeaponFistWeave": {
            "fr": "Alternez entre Attaque et Technique pour des d\u00e9g\u00e2ts bonus",
            "de": "Wechsle zwischen Angriff und Spezial f\u00fcr Bonusschaden",
            "es": "Alterna entre Ataque y Especial para da\u00f1o extra",
            "it": "Alterna tra Attacco e Tecnica per danni bonus",
            "pt-BR": "Alterne entre Ataque e Especial para dano b\u00f4nus",
            "ru": "\u0427\u0435\u0440\u0435\u0434\u0443\u0439\u0442\u0435 \u0410\u0442\u0430\u043a\u0443 \u0438 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0434\u043e\u043f\u043e\u043b\u043d\u0438\u0442\u0435\u043b\u044c\u043d\u043e\u0433\u043e \u0443\u0440\u043e\u043d\u0430",
            "pl": "Przeplataj Atak i Technik\u0119 dla dodatkowych obra\u017ce\u0144",
            "ja": "\u653b\u6483\u3068\u5fc5\u6bba\u3092\u4ea4\u4e92\u306b\u62bc\u3057\u3066\u30dc\u30fc\u30ca\u30b9\u30c0\u30e1\u30fc\u30b8",
            "ko": "\uacf5\u6383\uacfc \ud2b9\uc218\ub97c \ubc88\uac08\uc544 \ub20c\ub7ec \ucd94\uac00 \ud53c\ud574",
            "zh-CN": "\u4ea4\u66ff\u6309\u653b\u51fb\u548c\u7279\u6b8a\u83b7\u5f97\u989d\u5916\u4f24\u5bb3",
        },
        "FistSpecialVacuum": {
            "fr": "Maintenez Technique pour attirer les ennemis vers vous",
            "de": "Halte Spezial, um Feinde zu dir zu ziehen",
            "es": "Mant\u00e9n Especial para atraer enemigos hacia ti",
            "it": "Tieni premuto Tecnica per attirare i nemici verso di te",
            "pt-BR": "Segure Especial para puxar inimigos para perto de voc\u00ea",
            "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u043f\u0440\u0438\u0442\u044f\u0433\u0438\u0432\u0430\u043d\u0438\u044f \u0432\u0440\u0430\u0433\u043e\u0432 \u043a \u0441\u0435\u0431\u0435",
            "pl": "Przytrzymaj Technik\u0119, aby przyci\u0105gn\u0105\u0107 wrog\u00f3w do siebie",
            "ja": "\u5fc5\u6bba\u9577\u62bc\u3057\u3067\u6575\u3092\u5f15\u304d\u5bc4\u305b\u308b",
            "ko": "\ud2b9\uc218 \uae38\uac8c \ub20c\ub7ec \uc801\uc744 \ub04c\uc5b4\ub2f9\uae30\uae30",
            "zh-CN": "\u957f\u6309\u7279\u6b8a\u5c06\u654c\u4eba\u62c9\u5411\u81ea\u5df1",
        },
        "FistWeaponGilgamesh": {
            "fr": "Maintenez Attaque pour un combo finisseur Mutilant",
            "de": "Halte Angriff f\u00fcr einen Verst\u00fcmmelnden Combo-Finisher",
            "es": "Mant\u00e9n Ataque para un combo final Mutilante",
            "it": "Tieni premuto Attacco per un finale combo Mutilante",
            "pt-BR": "Segure Ataque para um combo finalizador Mutilante",
            "ru": "\u0423\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0410\u0442\u0430\u043a\u0443 \u0434\u043b\u044f \u041a\u0430\u043b\u0435\u0447\u0430\u0449\u0435\u0433\u043e \u0437\u0430\u0432\u0435\u0440\u0448\u0430\u044e\u0449\u0435\u0433\u043e \u043a\u043e\u043c\u0431\u043e",
            "pl": "Przytrzymaj Atak dla Okaleczaj\u0105cego zako\u0144czenia combo",
            "ja": "\u653b\u6483\u9577\u62bc\u3057\u3067\u5207\u88c2\u30b3\u30f3\u30dc\u30d5\u30a3\u30cb\u30c3\u30b7\u30e3\u30fc",
            "ko": "\uacf5\u6383 \uae38\uac8c \ub20c\ub7ec \uc808\u5207 \ucf64\ubcf4 \ud53c\ub2c8\uc154",
            "zh-CN": "\u957f\u6309\u653b\u51fb\u8fdb\u884c\u81f4\u6b8b\u8fde\u62db\u7ec8\u7ed3\u6280",
        },
        "RushWeaponGilgamesh": {
            "fr": "Appuyez sur Technique pour Uppercut Sprint les ennemis",
            "de": "Dr\u00fccke Spezial f\u00fcr Sprint-Uppercut auf Feinde",
            "es": "Pulsa Especial para Uppercut de Sprint a los enemigos",
            "it": "Premi Tecnica per Montante Sprint sui nemici",
            "pt-BR": "Pressione Especial para Uppercut de Dash nos inimigos",
            "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0410\u043f\u043f\u0435\u0440\u043a\u043e\u0442\u0430 \u0420\u044b\u0432\u043a\u043e\u043c \u043f\u043e \u0432\u0440\u0430\u0433\u0430\u043c",
            "pl": "Naci\u015bnij Technik\u0119 dla Uppercut Zrywu na wrog\u00f3w",
            "ja": "\u5fc5\u6bba\u3067\u6575\u306b\u30c0\u30c3\u30b7\u30e5\u30a2\u30c3\u30d1\u30fc",
            "ko": "\ud2b9\uc218\ub85c \uc801\uc5d0\uac8c \ub300\uc2dc \uc5b4\ud37c",
            "zh-CN": "\u6309\u7279\u6b8a\u5bf9\u654c\u4eba\u8fdb\u884c\u51b2\u523a\u4e0a\u52fe\u62f3",
        },
        "FistDetonationWeapon": {
            "fr": "Appuyez sur Technique pour d\u00e9tonner les effets de S\u00e9isme",
            "de": "Dr\u00fccke Spezial, um Beben-Effekte zu z\u00fcnden",
            "es": "Pulsa Especial para detonar efectos de Temblor",
            "it": "Premi Tecnica per detonare effetti Sisma",
            "pt-BR": "Pressione Especial para detonar efeitos de Terremoto",
            "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0423\u043c\u0435\u043d\u0438\u0435 \u0434\u043b\u044f \u0434\u0435\u0442\u043e\u043d\u0430\u0446\u0438\u0438 \u044d\u0444\u0444\u0435\u043a\u0442\u043e\u0432 \u0421\u043e\u0442\u0440\u044f\u0441\u0435\u043d\u0438\u044f",
            "pl": "Naci\u015bnij Technik\u0119, aby zdetonowa\u0107 efekty Wstrz\u0105su",
            "ja": "\u5fc5\u6bba\u3067\u30af\u30a8\u30a4\u30af\u52b9\u679c\u3092\u7206\u7834",
            "ko": "\ud2b9\uc218\ub85c \uc9c0\uc9c4 \ud6a8\uacfc \ud3ed\ud30c",
            "zh-CN": "\u6309\u7279\u6b8a\u5f15\u7206\u5730\u9707\u6548\u679c",
        },
        "ModifiedRush": {
            "fr": "Appuyez sur Sprint pour Sprinter",
            "de": "Dr\u00fccke Sprint zum Sprinten",
            "es": "Pulsa Sprint para Sprintar",
            "it": "Premi Scatto per Scattare",
            "pt-BR": "Pressione Dash para usar o Dash",
            "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0420\u044b\u0432\u043e\u043a \u0434\u043b\u044f \u0420\u044b\u0432\u043a\u0430",
            "pl": "Naci\u015bnij Zryw, aby wykona\u0107 Zryw",
            "ja": "\u30c0\u30c3\u30b7\u30e5\u3067\u30c0\u30c3\u30b7\u30e5",
            "ko": "\ub300\uc2dc\ub85c \ub300\uc2dc",
            "zh-CN": "\u6309\u51b2\u523a\u8fdb\u884c\u51b2\u523a",
        },
        "ModifiedRanged": {
            "fr": "Appuyez sur Sort pour utiliser votre Sort",
            "de": "Dr\u00fccke Wurf, um deinen Wurf zu benutzen",
            "es": "Pulsa Hechizo para usar tu Hechizo",
            "it": "Premi Sortilegio per usare il tuo Sortilegio",
            "pt-BR": "Pressione Feiti\u00e7o para usar seu Feiti\u00e7o",
            "ru": "\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u041a\u0430\u0441\u0442 \u0434\u043b\u044f \u0438\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u043d\u0438\u044f \u041a\u0430\u0441\u0442\u0430",
            "pl": "Naci\u015bnij Rzut, aby u\u017cy\u0107 Rzutu",
            "ja": "\u9b54\u5f3e\u3067\u9b54\u5f3e\u3092\u4f7f\u3046",
            "ko": "\uc2dc\uc804\uc73c\ub85c \uc2dc\uc804 \uc0ac\uc6a9",
            "zh-CN": "\u6309\u65bd\u6cd5\u4f7f\u7528\u65bd\u6cd5",
        },
    }
    return t


def _god_flavor_text():
    """GodFlavorText — god boon offer flavor text spoken when a god's boon menu opens."""
    t = {
        "ZeusUpgrade": {
            "fr": "Zeus vous offre une b\u00e9n\u00e9diction",
            "de": "Zeus bietet dir einen Segen an",
            "es": "Zeus te ofrece una bendici\u00f3n",
            "it": "Zeus ti offre una benedizione",
            "pt-BR": "Zeus oferece uma b\u00ean\u00e7\u00e3o",
            "ru": "\u0417\u0435\u0432\u0441 \u043f\u0440\u0435\u0434\u043b\u0430\u0433\u0430\u0435\u0442 \u0431\u043b\u0430\u0433\u043e\u0441\u043b\u043e\u0432\u0435\u043d\u0438\u0435",
            "pl": "Zeus oferuje ci b\u0142ogos\u0142awie\u0144stwo",
            "ja": "\u30bc\u30a6\u30b9\u304c\u795d\u798f\u3092\u63d0\u4f9b",
            "ko": "\uc81c\uc6b0\uc2a4\uac00 \ucd95\ubcf5\uc744 \uc81c\uacf5",
            "zh-CN": "\u5b99\u65af\u63d0\u4f9b\u795d\u798f",
        },
        "PoseidonUpgrade": {
            "fr": "Pos\u00e9idon vous offre une b\u00e9n\u00e9diction",
            "de": "Poseidon bietet dir einen Segen an",
            "es": "Poseid\u00f3n te ofrece una bendici\u00f3n",
            "it": "Poseidone ti offre una benedizione",
            "pt-BR": "Poseidon oferece uma b\u00ean\u00e7\u00e3o",
            "ru": "\u041f\u043e\u0441\u0435\u0439\u0434\u043e\u043d \u043f\u0440\u0435\u0434\u043b\u0430\u0433\u0430\u0435\u0442 \u0431\u043b\u0430\u0433\u043e\u0441\u043b\u043e\u0432\u0435\u043d\u0438\u0435",
            "pl": "Posejdon oferuje ci b\u0142ogos\u0142awie\u0144stwo",
            "ja": "\u30dd\u30bb\u30a4\u30c9\u30f3\u304c\u795d\u798f\u3092\u63d0\u4f9b",
            "ko": "\ud3ec\uc138\uc774\ub3c8\uc774 \ucd95\ubcf5\uc744 \uc81c\uacf5",
            "zh-CN": "\u6ce2\u585e\u51ac\u63d0\u4f9b\u795d\u798f",
        },
        "AthenaUpgrade": {
            "fr": "Ath\u00e9na vous offre une b\u00e9n\u00e9diction",
            "de": "Athene bietet dir einen Segen an",
            "es": "Atenea te ofrece una bendici\u00f3n",
            "it": "Atena ti offre una benedizione",
            "pt-BR": "Atena oferece uma b\u00ean\u00e7\u00e3o",
            "ru": "\u0410\u0444\u0438\u043d\u0430 \u043f\u0440\u0435\u0434\u043b\u0430\u0433\u0430\u0435\u0442 \u0431\u043b\u0430\u0433\u043e\u0441\u043b\u043e\u0432\u0435\u043d\u0438\u0435",
            "pl": "Atena oferuje ci b\u0142ogos\u0142awie\u0144stwo",
            "ja": "\u30a2\u30c6\u30ca\u304c\u795d\u798f\u3092\u63d0\u4f9b",
            "ko": "\uc544\ud14c\ub098\uac00 \ucd95\ubcf5\uc744 \uc81c\uacf5",
            "zh-CN": "\u96c5\u5178\u5a1c\u63d0\u4f9b\u795d\u798f",
        },
        "AresUpgrade": {
            "fr": "Ar\u00e8s vous offre une b\u00e9n\u00e9diction",
            "de": "Ares bietet dir einen Segen an",
            "es": "Ares te ofrece una bendici\u00f3n",
            "it": "Ares ti offre una benedizione",
            "pt-BR": "Ares oferece uma b\u00ean\u00e7\u00e3o",
            "ru": "\u0410\u0440\u0435\u0441 \u043f\u0440\u0435\u0434\u043b\u0430\u0433\u0430\u0435\u0442 \u0431\u043b\u0430\u0433\u043e\u0441\u043b\u043e\u0432\u0435\u043d\u0438\u0435",
            "pl": "Ares oferuje ci b\u0142ogos\u0142awie\u0144stwo",
            "ja": "\u30a2\u30ec\u30b9\u304c\u795d\u798f\u3092\u63d0\u4f9b",
            "ko": "\uc544\ub808\uc2a4\uac00 \ucd95\ubcf5\uc744 \uc81c\uacf5",
            "zh-CN": "\u963f\u745e\u65af\u63d0\u4f9b\u795d\u798f",
        },
        "AphroditeUpgrade": {
            "fr": "Aphrodite vous offre une b\u00e9n\u00e9diction",
            "de": "Aphrodite bietet dir einen Segen an",
            "es": "Afrodita te ofrece una bendici\u00f3n",
            "it": "Afrodite ti offre una benedizione",
            "pt-BR": "Afrodite oferece uma b\u00ean\u00e7\u00e3o",
            "ru": "\u0410\u0444\u0440\u043e\u0434\u0438\u0442\u0430 \u043f\u0440\u0435\u0434\u043b\u0430\u0433\u0430\u0435\u0442 \u0431\u043b\u0430\u0433\u043e\u0441\u043b\u043e\u0432\u0435\u043d\u0438\u0435",
            "pl": "Afrodyta oferuje ci b\u0142ogos\u0142awie\u0144stwo",
            "ja": "\u30a2\u30d5\u30ed\u30c7\u30a3\u30fc\u30c6\u304c\u795d\u798f\u3092\u63d0\u4f9b",
            "ko": "\uc544\ud504\ub85c\ub514\ud14c\uac00 \ucd95\ubcf5\uc744 \uc81c\uacf5",
            "zh-CN": "\u963f\u4f5b\u6d1b\u72c4\u5fce\u63d0\u4f9b\u795d\u798f",
        },
        "ArtemisUpgrade": {
            "fr": "Art\u00e9mis vous offre une b\u00e9n\u00e9diction",
            "de": "Artemis bietet dir einen Segen an",
            "es": "Artemisa te ofrece una bendici\u00f3n",
            "it": "Artemide ti offre una benedizione",
            "pt-BR": "\u00c1rtemis oferece uma b\u00ean\u00e7\u00e3o",
            "ru": "\u0410\u0440\u0442\u0435\u043c\u0438\u0434\u0430 \u043f\u0440\u0435\u0434\u043b\u0430\u0433\u0430\u0435\u0442 \u0431\u043b\u0430\u0433\u043e\u0441\u043b\u043e\u0432\u0435\u043d\u0438\u0435",
            "pl": "Artemida oferuje ci b\u0142ogos\u0142awie\u0144stwo",
            "ja": "\u30a2\u30eb\u30c6\u30df\u30b9\u304c\u795d\u798f\u3092\u63d0\u4f9b",
            "ko": "\uc544\ub974\ud14c\ubbf8\uc2a4\uac00 \ucd95\ubcf5\uc744 \uc81c\uacf5",
            "zh-CN": "\u963f\u5c14\u5fce\u5f25\u65af\u63d0\u4f9b\u795d\u798f",
        },
        "DionysusUpgrade": {
            "fr": "Dionysos vous offre une b\u00e9n\u00e9diction",
            "de": "Dionysos bietet dir einen Segen an",
            "es": "Dioniso te ofrece una bendici\u00f3n",
            "it": "Dioniso ti offre una benedizione",
            "pt-BR": "Dion\u00edsio oferece uma b\u00ean\u00e7\u00e3o",
            "ru": "\u0414\u0438\u043e\u043d\u0438\u0441 \u043f\u0440\u0435\u0434\u043b\u0430\u0433\u0430\u0435\u0442 \u0431\u043b\u0430\u0433\u043e\u0441\u043b\u043e\u0432\u0435\u043d\u0438\u0435",
            "pl": "Dionizos oferuje ci b\u0142ogos\u0142awie\u0144stwo",
            "ja": "\u30c7\u30a3\u30aa\u30cb\u30e5\u30bd\u30b9\u304c\u795d\u798f\u3092\u63d0\u4f9b",
            "ko": "\ub514\uc624\ub2c8\uc18c\uc2a4\uac00 \ucd95\ubcf5\uc744 \uc81c\uacf5",
            "zh-CN": "\u72c4\u4fc4\u5c3c\u7d22\u65af\u63d0\u4f9b\u795d\u798f",
        },
        "HermesUpgrade": {
            "fr": "Herm\u00e8s vous offre une b\u00e9n\u00e9diction",
            "de": "Hermes bietet dir einen Segen an",
            "es": "Hermes te ofrece una bendici\u00f3n",
            "it": "Ermes ti offre una benedizione",
            "pt-BR": "Hermes oferece uma b\u00ean\u00e7\u00e3o",
            "ru": "\u0413\u0435\u0440\u043c\u0435\u0441 \u043f\u0440\u0435\u0434\u043b\u0430\u0433\u0430\u0435\u0442 \u0431\u043b\u0430\u0433\u043e\u0441\u043b\u043e\u0432\u0435\u043d\u0438\u0435",
            "pl": "Hermes oferuje ci b\u0142ogos\u0142awie\u0144stwo",
            "ja": "\u30d8\u30eb\u30e1\u30b9\u304c\u795d\u798f\u3092\u63d0\u4f9b",
            "ko": "\ud5e4\ub974\uba54\uc2a4\uac00 \ucd95\ubcf5\uc744 \uc81c\uacf5",
            "zh-CN": "\u8d6b\u5c14\u58a8\u65af\u63d0\u4f9b\u795d\u798f",
        },
        "DemeterUpgrade": {
            "fr": "D\u00e9m\u00e9ter vous offre une b\u00e9n\u00e9diction",
            "de": "Demeter bietet dir einen Segen an",
            "es": "Dem\u00e9ter te ofrece una bendici\u00f3n",
            "it": "Demetra ti offre una benedizione",
            "pt-BR": "Dem\u00e9ter oferece uma b\u00ean\u00e7\u00e3o",
            "ru": "\u0414\u0435\u043c\u0435\u0442\u0440\u0430 \u043f\u0440\u0435\u0434\u043b\u0430\u0433\u0430\u0435\u0442 \u0431\u043b\u0430\u0433\u043e\u0441\u043b\u043e\u0432\u0435\u043d\u0438\u0435",
            "pl": "Demeter oferuje ci b\u0142ogos\u0142awie\u0144stwo",
            "ja": "\u30c7\u30e1\u30c6\u30eb\u304c\u795d\u798f\u3092\u63d0\u4f9b",
            "ko": "\ub370\uba54\ud14c\ub974\uac00 \ucd95\ubcf5\uc744 \uc81c\uacf5",
            "zh-CN": "\u5f97\u58a8\u5fce\u8033\u63d0\u4f9b\u795d\u798f",
        },
        "TrialUpgrade": {
            "fr": "\u00c9preuve des Olympiens",
            "de": "Pr\u00fcfung der Olympier",
            "es": "Prueba de los Ol\u00edmpicos",
            "it": "Prova degli Olimpi",
            "pt-BR": "Provac\u00e3o dos Ol\u00edmpicos",
            "ru": "\u0418\u0441\u043f\u044b\u0442\u0430\u043d\u0438\u0435 \u041e\u043b\u0438\u043c\u043f\u0438\u0439\u0446\u0435\u0432",
            "pl": "Pr\u00f3ba Olimpijczyk\u00f3w",
            "ja": "\u30aa\u30ea\u30e5\u30f3\u30dd\u30b9\u306e\u8a66\u7df4",
            "ko": "\uc62c\ub9bc\ud3ec\uc2a4\uc758 \uc2dc\ub828",
            "zh-CN": "\u5965\u6797\u5339\u65af\u7684\u8bd5\u70bc",
        },
        "StackUpgrade": {
            "fr": "Pomme de Puissance",
            "de": "Apfel der Macht",
            "es": "Manzana de Poder",
            "it": "Pomo del Potere",
            "pt-BR": "Ma\u00e7\u00e3 do Poder",
            "ru": "\u042f\u0431\u043b\u043e\u043a\u043e \u0421\u0438\u043b\u044b",
            "pl": "Jab\u0142ko Mocy",
            "ja": "\u30d1\u30ef\u30fc\u30a2\u30c3\u30d7\u306e\u30b6\u30af\u30ed",
            "ko": "\ud30c\uc6cc\uc758 \uc11d\ub958",
            "zh-CN": "\u529b\u91cf\u4e4b\u77f3\u69b4",
        },
        "StackUpgradeRare": {
            "fr": "Pomme de Puissance am\u00e9lior\u00e9e",
            "de": "Verbesserter Apfel der Macht",
            "es": "Manzana de Poder mejorada",
            "it": "Pomo del Potere migliorato",
            "pt-BR": "Ma\u00e7\u00e3 do Poder melhorada",
            "ru": "\u0423\u043b\u0443\u0447\u0448\u0435\u043d\u043d\u043e\u0435 \u042f\u0431\u043b\u043e\u043a\u043e \u0421\u0438\u043b\u044b",
            "pl": "Ulepszone Jab\u0142ko Mocy",
            "ja": "\u5f37\u5316\u30d1\u30ef\u30fc\u30a2\u30c3\u30d7\u306e\u30b6\u30af\u30ed",
            "ko": "\uac15\ud654\ub41c \ud30c\uc6cc\uc758 \uc11d\ub958",
            "zh-CN": "\u5f3a\u5316\u529b\u91cf\u4e4b\u77f3\u69b4",
        },
        "HarvestBoonDrop": {
            "fr": "R\u00e9colte de Chaos",
            "de": "Chaos-Ernte",
            "es": "Cosecha del Caos",
            "it": "Raccolto del Caos",
            "pt-BR": "Colheita do Caos",
            "ru": "\u0423\u0440\u043e\u0436\u0430\u0439 \u0425\u0430\u043e\u0441\u0430",
            "pl": "\u017bniwa Chaosu",
            "ja": "\u30ab\u30aa\u30b9\u306e\u53ce\u7a6b",
            "ko": "\uce74\uc624\uc2a4\uc758 \uc218\ud655",
            "zh-CN": "\u6df7\u6c8c\u4e4b\u6536\u83b7",
        },
        "WeaponUpgrade": {
            "fr": "Marteau de D\u00e9dale. Le ma\u00eetre artisan a abandonn\u00e9 ses propres outils une fois son travail funeste pour Had\u00e8s achev\u00e9.",
            "de": "Hammer des D\u00e4dalus. Der Meisterhandwerker verwarf seine eigenen Werkzeuge, als seine d\u00fcstere Arbeit f\u00fcr Hades vollendet war.",
            "es": "Martillo de D\u00e9dalo. El maestro artesano descart\u00f3 sus propias herramientas una vez completado su siniestro trabajo para Hades.",
            "it": "Martello di Dedalo. Il maestro artigiano abbandon\u00f2 i propri strumenti una volta completata la sua opera funesta per Ade.",
            "pt-BR": "Martelo de D\u00e9dalo. O mestre artes\u00e3o descartou suas pr\u00f3prias ferramentas quando seu trabalho sombrio para Hades foi conclu\u00eddo.",
            "ru": "\u041c\u043e\u043b\u043e\u0442 \u0414\u0435\u0434\u0430\u043b\u0430. \u041c\u0430\u0441\u0442\u0435\u0440 \u043e\u0442\u0431\u0440\u043e\u0441\u0438\u043b \u0441\u0432\u043e\u0438 \u0438\u043d\u0441\u0442\u0440\u0443\u043c\u0435\u043d\u0442\u044b, \u043a\u043e\u0433\u0434\u0430 \u0435\u0433\u043e \u0437\u043b\u043e\u0432\u0435\u0449\u0430\u044f \u0440\u0430\u0431\u043e\u0442\u0430 \u0434\u043b\u044f \u0410\u0438\u0434\u0430 \u0431\u044b\u043b\u0430 \u0437\u0430\u0432\u0435\u0440\u0448\u0435\u043d\u0430.",
            "pl": "M\u0142ot Dedala. Mistrz rzemie\u015blnik porzuci\u0142 w\u0142asne narz\u0119dzia, gdy jego mroczna praca dla Hadesa zosta\u0142a uko\u0144czona.",
            "ja": "\u30c0\u30a4\u30c0\u30ed\u30b9\u306e\u69cc\u3002\u540d\u5de5\u306f\u30cf\u30c7\u30b9\u306e\u305f\u3081\u306e\u4e0d\u5409\u306a\u4ed5\u4e8b\u3092\u7d42\u3048\u305f\u5f8c\u3001\u81ea\u3089\u306e\u5de5\u5177\u3092\u6368\u3066\u305f\u3002",
            "ko": "\ub2e4\uc774\ub2ec\ub85c\uc2a4\uc758 \ub9dd\uce58. \uba85\uc7a5\uc740 \ud558\ub370\uc2a4\ub97c \uc704\ud55c \uc554\uc6b8\ud55c \uc791\uc5c5\uc744 \ub9c8\uce5c \ud6c4 \uc790\uc2e0\uc758 \ub3c4\uad6c\ub97c \ubc84\ub838\ub2e4.",
            "zh-CN": "\u4ee3\u8fbe\u7f57\u65af\u4e4b\u9524\u3002\u5de8\u5320\u5728\u5b8c\u6210\u4e3a\u54c8\u8fea\u65af\u7684\u9634\u68ee\u5de5\u4f5c\u540e\u4e22\u5f03\u4e86\u81ea\u5df1\u7684\u5de5\u5177\u3002",
        },
    }
    return t


def _mirror_flavor_text():
    """MirrorFlavorText — Mirror of Night upgrade names + flavor text for open announcement."""
    t = {
        "FirstStrikeMetaUpgrade": {
            "fr": "Pr\u00e9sence Ardente. Que votre passion br\u00fble comme le feu.",
            "de": "Feurige Präsenz. Lass deine Leidenschaft wie Feuer brennen.",
            "es": "Presencia \u00cdgnea. Que tu pasi\u00f3n arda como el fuego.",
            "it": "Presenza Ardente. Che la tua passione bruci come il fuoco.",
            "pt-BR": "Presen\u00e7a Flamejante. Que sua paix\u00e3o queime como fogo.",
            "ru": "\u041e\u0433\u043d\u0435\u043d\u043d\u043e\u0435 \u041f\u0440\u0438\u0441\u0443\u0442\u0441\u0442\u0432\u0438\u0435. \u041f\u0443\u0441\u0442\u044c \u0432\u0430\u0448\u0430 \u0441\u0442\u0440\u0430\u0441\u0442\u044c \u0433\u043e\u0440\u0438\u0442 \u043a\u0430\u043a \u043e\u0433\u043e\u043d\u044c.",
            "pl": "Ognista Obecno\u015b\u0107. Niech twoja pasja p\u0142onie jak ogie\u0144.",
            "ja": "\u706b\u306e\u5b58\u5728\u3002\u60c5\u71b1\u3092\u708e\u306e\u3088\u3046\u306b\u71c3\u3084\u305b\u3002",
            "ko": "\ubd88\uaf43\uc758 \uc874\uc7ac. \uc5f4\uc815\uc744 \ubd88\ucc98\ub7fc \ud0dc\uc6cc\ub77c.",
            "zh-CN": "\u7130\u706b\u5b58\u5728\u3002\u8ba9\u4f60\u7684\u70ed\u60c5\u5982\u706b\u71c3\u70e7\u3002",
        },
        "DoorHealMetaUpgrade": {
            "fr": "Vitalit\u00e9 Chthonienne. Puisez de la force \u00e0 chaque seuil franchi.",
            "de": "Chthonische Vitalität. Schöpfe Kraft an jeder Schwelle.",
            "es": "Vitalidad Ct\u00f3nica. Obt\u00e9n fuerza en cada umbral que cruces.",
            "it": "Vitalit\u00e0 Ctonia. Trai forza da ogni soglia che attraversi.",
            "pt-BR": "Vitalidade Ct\u00f4nica. Obtenha for\u00e7a a cada limiar cruzado.",
            "ru": "\u0425\u0442\u043e\u043d\u0438\u0447\u0435\u0441\u043a\u0430\u044f \u0416\u0438\u0437\u043d\u0435\u043d\u043d\u043e\u0441\u0442\u044c. \u0427\u0435\u0440\u043f\u0430\u0439\u0442\u0435 \u0441\u0438\u043b\u0443 \u043d\u0430 \u043a\u0430\u0436\u0434\u043e\u043c \u043f\u043e\u0440\u043e\u0433\u0435.",
            "pl": "Chtoniczna Witaln\u0105\u015b\u0107. Czerp si\u0142\u0119 na ka\u017cdym progu.",
            "ja": "\u51a5\u5e9c\u306e\u6d3b\u529b\u3002\u6577\u5c45\u3092\u8d8a\u3048\u308b\u305f\u3073\u306b\u529b\u3092\u5f97\u3088\u3002",
            "ko": "\uba85\uacc4\uc758 \ud65c\ub825. \ubb38\ud134\uc744 \ub118\uc744 \ub54c\ub9c8\ub2e4 \ud798\uc744 \uc5bb\uc5b4\ub77c.",
            "zh-CN": "\u51a5\u5e9c\u6d3b\u529b\u3002\u6bcf\u8d8a\u8fc7\u4e00\u9053\u95e8\u69db\u5c31\u83b7\u5f97\u529b\u91cf\u3002",
        },
        "DarknessHealMetaUpgrade": {
            "fr": "R\u00e9g\u00e9n\u00e9ration Sombre. Les t\u00e9n\u00e8bres sont une source de force.",
            "de": "Dunkle Regeneration. Dunkelheit ist eine Quelle der Stärke.",
            "es": "Regeneraci\u00f3n Oscura. La oscuridad es fuente de fuerza.",
            "it": "Rigenerazione Oscura. L'oscurit\u00e0 \u00e8 una fonte di forza.",
            "pt-BR": "Regenera\u00e7\u00e3o Sombria. A escurid\u00e3o \u00e9 fonte de for\u00e7a.",
            "ru": "\u0422\u0451\u043c\u043d\u0430\u044f \u0420\u0435\u0433\u0435\u043d\u0435\u0440\u0430\u0446\u0438\u044f. \u0422\u044c\u043c\u0430 \u2014 \u0438\u0441\u0442\u043e\u0447\u043d\u0438\u043a \u0441\u0438\u043b\u044b.",
            "pl": "Mroczna Regeneracja. Ciemno\u015b\u0107 jest \u017ar\u00f3d\u0142em si\u0142y.",
            "ja": "\u95c7\u306e\u518d\u751f\u3002\u95c7\u306f\u529b\u306e\u6e90\u3002",
            "ko": "\uc5b4\ub460\uc758 \uc7ac\uc0dd. \uc5b4\ub460\uc740 \ud798\uc758 \uc6d0\ucc9c.",
            "zh-CN": "\u6697\u5f71\u518d\u751f\u3002\u9ed1\u6697\u662f\u529b\u91cf\u7684\u6e90\u6cc9\u3002",
        },
        "BackstabMetaUpgrade": {
            "fr": "Faveur Infernale. Frappez dans l'ombre, frappez sans \u00eatre vu.",
            "de": "Infernale Gunst. Schlag aus dem Schatten, schlag ungesehen.",
            "es": "Favor Infernal. Golpea desde las sombras, golpea sin ser visto.",
            "it": "Favore Infernale. Colpisci dall'ombra, colpisci senza essere visto.",
            "pt-BR": "Favor Infernal. Golpeie nas sombras, golpeie sem ser visto.",
            "ru": "\u0410\u0434\u0441\u043a\u0430\u044f \u041c\u0438\u043b\u043e\u0441\u0442\u044c. \u041d\u0430\u043d\u043e\u0441\u0438\u0442\u0435 \u0443\u0434\u0430\u0440 \u0438\u0437 \u0442\u0435\u043d\u0438, \u043d\u0435\u0437\u0430\u043c\u0435\u0447\u0435\u043d\u043d\u044b\u043c.",
            "pl": "Piekielna Przychylno\u015b\u0107. Uderz z cienia, uderz niezauwa\u017cony.",
            "ja": "\u5730\u7344\u306e\u6069\u5bf5\u3002\u5f71\u304b\u3089\u6483\u3061\u3001\u898b\u3048\u306c\u3068\u3053\u308d\u304b\u3089\u653b\u3081\u3088\u3002",
            "ko": "\uc9c0\uc625\uc758 \uc740\ucd1d. \uadf8\ub9bc\uc790\uc5d0\uc11c \uacf5\u6383\ud558\ub77c.",
            "zh-CN": "\u51a5\u5e9c\u6069\u5ba0\u3002\u4ece\u6697\u5904\u51fa\u51fb\uff0c\u65e0\u5f62\u4e4b\u4e2d\u6253\u51fb\u654c\u4eba\u3002",
        },
        "StoredAmmoVulnerabilityMetaUpgrade": {
            "fr": "Vengeance Boiling. Les ennemis marqu\u00e9s souffriront davantage.",
            "de": "Brodelnde Rache. Markierte Feinde erleiden mehr Schaden.",
            "es": "Venganza Hirviente. Los enemigos marcados sufrir\u00e1n m\u00e1s.",
            "it": "Vendetta Bollente. I nemici segnati soffriranno di pi\u00f9.",
            "pt-BR": "Vingan\u00e7a Fervente. Inimigos marcados sofrer\u00e3o mais.",
            "ru": "\u041a\u0438\u043f\u044f\u0449\u0430\u044f \u041c\u0435\u0441\u0442\u044c. \u041e\u0442\u043c\u0435\u0447\u0435\u043d\u043d\u044b\u0435 \u0432\u0440\u0430\u0433\u0438 \u043f\u043e\u0441\u0442\u0440\u0430\u0434\u0430\u044e\u0442 \u0441\u0438\u043b\u044c\u043d\u0435\u0435.",
            "pl": "Wrz\u0105ca Zemsta. Oznaczeni wrogowie b\u0119d\u0105 cierpie\u0107 bardziej.",
            "ja": "\u6cb8\u9a30\u306e\u5fa9\u8b90\u3002\u5370\u306e\u4ed8\u3044\u305f\u6575\u306f\u3088\u308a\u82e6\u3057\u3080\u3060\u308d\u3046\u3002",
            "ko": "\ub04c\uc5b4\uc624\ub974\ub294 \ubcf5\uc218. \ud45c\uc2dd\ub41c \uc801\uc740 \ub354 \ud070 \uace0\ud1b5\uc744 \ubc1b\uc73c\ub9ac\ub77c.",
            "zh-CN": "\u6cb8\u817e\u590d\u4ec7\u3002\u88ab\u6807\u8bb0\u7684\u654c\u4eba\u5c06\u627f\u53d7\u66f4\u591a\u4f24\u5bb3\u3002",
        },
        "HealthMetaUpgrade": {
            "fr": "Endurance Tenace. La r\u00e9silience est la force des dieux.",
            "de": "Zähe Ausdauer. Widerstandskraft ist die Stärke der Götter.",
            "es": "Resistencia Tenaz. La resiliencia es la fuerza de los dioses.",
            "it": "Resistenza Tenace. La resilienza \u00e8 la forza degli d\u00e8i.",
            "pt-BR": "Resist\u00eancia Tenaz. A resili\u00eancia \u00e9 a for\u00e7a dos deuses.",
            "ru": "\u0423\u043f\u043e\u0440\u043d\u0430\u044f \u0412\u044b\u043d\u043e\u0441\u043b\u0438\u0432\u043e\u0441\u0442\u044c. \u0421\u0442\u043e\u0439\u043a\u043e\u0441\u0442\u044c \u2014 \u0441\u0438\u043b\u0430 \u0431\u043e\u0433\u043e\u0432.",
            "pl": "Wytrwa\u0142a Wytrzyma\u0142o\u015b\u0107. Odporno\u015b\u0107 to si\u0142a bog\u00f3w.",
            "ja": "\u4e0d\u5c48\u306e\u5fcd\u8010\u3002\u56de\u5fa9\u529b\u3053\u305d\u795e\u3005\u306e\u529b\u3002",
            "ko": "\ub04c\uc9c8\uae34 \uc778\ub0b4. \ud68c\ubcf5\ub825\uc740 \uc2e0\ub4e4\uc758 \ud798.",
            "zh-CN": "\u575a\u97e7\u8010\u529b\u3002\u97e7\u6027\u662f\u795e\u660e\u7684\u529b\u91cf\u3002",
        },
        "HighHealthDamageMetaUpgrade": {
            "fr": "Faveur Familiale. Les liens familiaux sont source de pouvoir.",
            "de": "Familiäre Gunst. Familienbande sind eine Quelle der Macht.",
            "es": "Favor Familiar. Los lazos familiares son fuente de poder.",
            "it": "Favore Familiare. I legami familiari sono fonte di potere.",
            "pt-BR": "Favor Familiar. La\u00e7os familiares s\u00e3o fonte de poder.",
            "ru": "\u0421\u0435\u043c\u0435\u0439\u043d\u0430\u044f \u041c\u0438\u043b\u043e\u0441\u0442\u044c. \u0421\u0435\u043c\u0435\u0439\u043d\u044b\u0435 \u0443\u0437\u044b \u2014 \u0438\u0441\u0442\u043e\u0447\u043d\u0438\u043a \u0441\u0438\u043b\u044b.",
            "pl": "Rodzinna Przychylno\u015b\u0107. Wi\u0119zi rodzinne s\u0105 \u017ar\u00f3d\u0142em mocy.",
            "ja": "\u5bb6\u65cf\u306e\u5bf5\u611b\u3002\u5bb6\u65cf\u306e\u7d46\u306f\u529b\u306e\u6e90\u3002",
            "ko": "\uac00\uc871\uc758 \uc740\ucd1d. \uac00\uc871\uc758 \uc720\ub300\ub294 \ud798\uc758 \uc6d0\ucc9c.",
            "zh-CN": "\u5bb6\u65cf\u6069\u5ba0\u3002\u5bb6\u65cf\u7ebd\u5e26\u662f\u529b\u91cf\u7684\u6e90\u6cc9\u3002",
        },
        "RerollMetaUpgrade": {
            "fr": "Persuasion du Destin. Le destin est malleable pour ceux qui persistent.",
            "de": "Schicksalsüberzeugung. Das Schicksal ist formbar für Beharrliche.",
            "es": "Persuasi\u00f3n del Destino. El destino es maleable para los persistentes.",
            "it": "Persuasione del Destino. Il destino \u00e8 malleabile per i persistenti.",
            "pt-BR": "Persuas\u00e3o do Destino. O destino \u00e9 male\u00e1vel para os persistentes.",
            "ru": "\u0423\u0431\u0435\u0436\u0434\u0435\u043d\u0438\u0435 \u0421\u0443\u0434\u044c\u0431\u044b. \u0421\u0443\u0434\u044c\u0431\u0430 \u043f\u043e\u0434\u0430\u0442\u043b\u0438\u0432\u0430 \u0434\u043b\u044f \u043d\u0430\u0441\u0442\u043e\u0439\u0447\u0438\u0432\u044b\u0445.",
            "pl": "Perswazja Losu. Los jest podatny dla wytrwa\u0142ych.",
            "ja": "\u904b\u547d\u306e\u8aac\u5f97\u3002\u904b\u547d\u306f\u6301\u4e45\u529b\u3042\u308b\u8005\u306b\u5f93\u3046\u3002",
            "ko": "\uc6b4\uba85\uc758 \uc124\ub4dd. \uc6b4\uba85\uc740 \ub05d\uae30 \uc788\ub294 \uc790\uc5d0\uac8c \uad74\ubcf5\ud55c\ub2e4.",
            "zh-CN": "\u547d\u8fd0\u8bf4\u670d\u3002\u547d\u8fd0\u5bf9\u575a\u6301\u8005\u662f\u53ef\u5851\u7684\u3002",
        },
        "RerollPanelMetaUpgrade": {
            "fr": "Auth\u00e9ntique Persuasion. Le destin peut \u00eatre r\u00e9\u00e9crit par les d\u00e9termin\u00e9s.",
            "de": "Echte Überzeugung. Das Schicksal kann von Entschlossenen umgeschrieben werden.",
            "es": "Persuasi\u00f3n Aut\u00e9ntica. El destino puede ser reescrito por los determinados.",
            "it": "Persuasione Autentica. Il destino pu\u00f2 essere riscritto dai determinati.",
            "pt-BR": "Persuas\u00e3o Aut\u00eantica. O destino pode ser reescrito pelos determinados.",
            "ru": "\u0418\u0441\u0442\u0438\u043d\u043d\u043e\u0435 \u0423\u0431\u0435\u0436\u0434\u0435\u043d\u0438\u0435. \u0421\u0443\u0434\u044c\u0431\u0443 \u043c\u043e\u0433\u0443\u0442 \u043f\u0435\u0440\u0435\u043f\u0438\u0441\u0430\u0442\u044c \u0440\u0435\u0448\u0438\u0442\u0435\u043b\u044c\u043d\u044b\u0435.",
            "pl": "Autentyczna Perswazja. Los mo\u017ce zosta\u0107 przepisany przez zdeterminowanych.",
            "ja": "\u771f\u306e\u8aac\u5f97\u3002\u904b\u547d\u306f\u6c7a\u610f\u3042\u308b\u8005\u304c\u66f8\u304d\u63db\u3048\u3089\u308c\u308b\u3002",
            "ko": "\uc9c4\uc815\ud55c \uc124\ub4dd. \uc6b4\uba85\uc740 \uacb0\uc5f0\ud55c \uc790\uac00 \ub2e4\uc2dc \uc4f8 \uc218 \uc788\ub2e4.",
            "zh-CN": "\u771f\u6b63\u8bf4\u670d\u3002\u547d\u8fd0\u53ef\u4ee5\u88ab\u575a\u5b9a\u8005\u6539\u5199\u3002",
        },
        "ExtraChanceMetaUpgrade": {
            "fr": "D\u00e9fi Mortel. La mort est un d\u00e9but, pas une fin.",
            "de": "Tödliche Trotzung. Der Tod ist ein Anfang, kein Ende.",
            "es": "Desaf\u00edo Mortal. La muerte es un comienzo, no un final.",
            "it": "Sfida Mortale. La morte \u00e8 un inizio, non una fine.",
            "pt-BR": "Desafio Mortal. A morte \u00e9 um come\u00e7o, n\u00e3o um fim.",
            "ru": "\u0421\u043c\u0435\u0440\u0442\u0435\u043b\u044c\u043d\u044b\u0439 \u0412\u044b\u0437\u043e\u0432. \u0421\u043c\u0435\u0440\u0442\u044c \u2014 \u044d\u0442\u043e \u043d\u0430\u0447\u0430\u043b\u043e, \u0430 \u043d\u0435 \u043a\u043e\u043d\u0435\u0446.",
            "pl": "Wy\u0142om \u015amierci. \u015amier\u0107 to pocz\u0105tek, nie koniec.",
            "ja": "\u6b7b\u306e\u53cd\u6297\u3002\u6b7b\u306f\u59cb\u307e\u308a\u3067\u3042\u308a\u3001\u7d42\u308f\u308a\u3067\u306f\u306a\u3044\u3002",
            "ko": "\uc8fd\uc74c\uc758 \ud56d\ubc18. \uc8fd\uc74c\uc740 \uc2dc\uc791\uc774\uc9c0 \ub05d\uc774 \uc544\ub2c8\ub2e4.",
            "zh-CN": "\u6b7b\u4ea1\u53cd\u6297\u3002\u6b7b\u4ea1\u662f\u5f00\u59cb\uff0c\u4e0d\u662f\u7ed3\u675c\u3002",
        },
        "ExtraChanceReplenishMetaUpgrade": {
            "fr": "Obstination Tenace. Le temps gu\u00e9rit toutes les blessures de l'\u00e2me.",
            "de": "Hartnäckige Sturheit. Zeit heilt alle Wunden der Seele.",
            "es": "Obstinaci\u00f3n Tenaz. El tiempo cura todas las heridas del alma.",
            "it": "Testardaggine Tenace. Il tempo guarisce tutte le ferite dell'anima.",
            "pt-BR": "Obstina\u00e7\u00e3o Tenaz. O tempo cura todas as feridas da alma.",
            "ru": "\u0423\u043f\u043e\u0440\u043d\u043e\u0435 \u0423\u043f\u0440\u044f\u043c\u0441\u0442\u0432\u043e. \u0412\u0440\u0435\u043c\u044f \u0438\u0441\u0446\u0435\u043b\u044f\u0435\u0442 \u0432\u0441\u0435 \u0440\u0430\u043d\u044b \u0434\u0443\u0448\u0438.",
            "pl": "Wytrwa\u0142y Upór. Czas leczy wszystkie rany duszy.",
            "ja": "\u4e0d\u5c48\u306e\u9811\u56fa\u3002\u6642\u306f\u9b42\u306e\u3059\u3079\u3066\u306e\u50b7\u3092\u7652\u3059\u3002",
            "ko": "\ub04c\uc9c8\uae34 \uace0\uc9d1. \uc2dc\uac04\uc774 \uc601\ud63c\uc758 \ubaa8\ub4e0 \uc0c1\ucc98\ub97c \uce58\uc720\ud55c\ub2e4.",
            "zh-CN": "\u987d\u5f3a\u56fa\u6267\u3002\u65f6\u95f4\u6cbb\u6108\u7075\u9b42\u7684\u6240\u6709\u4f24\u53e3\u3002",
        },
        "MoneyMetaUpgrade": {
            "fr": "Poches Profondes. Que la richesse coule comme le Styx.",
            "de": "Tiefe Taschen. Möge der Reichtum wie der Styx fließen.",
            "es": "Bolsillos Profundos. Que la riqueza fluya como el Estigia.",
            "it": "Tasche Profonde. Che la ricchezza scorra come lo Stige.",
            "pt-BR": "Bolsos Profundos. Que a riqueza flua como o Estige.",
            "ru": "\u0413\u043b\u0443\u0431\u043e\u043a\u0438\u0435 \u041a\u0430\u0440\u043c\u0430\u043d\u044b. \u041f\u0443\u0441\u0442\u044c \u0431\u043e\u0433\u0430\u0442\u0441\u0442\u0432\u043e \u0442\u0435\u0447\u0451\u0442 \u043a\u0430\u043a \u0421\u0442\u0438\u043a\u0441.",
            "pl": "G\u0142\u0119bokie Kieszenie. Niech bogactwo p\u0142ynie jak Styks.",
            "ja": "\u6df1\u3044\u61d0\u3002\u5bcc\u304c\u30b9\u30c6\u30e5\u30af\u30b9\u306e\u3088\u3046\u306b\u6d41\u308c\u308b\u3088\u3046\u306b\u3002",
            "ko": "\uae4a\uc740 \uc8fc\uba38\ub2c8. \ubd80\uac00 \uc2a4\ud2f1\uc2a4\ucc98\ub7fc \ud750\ub974\ub3c4\ub85d.",
            "zh-CN": "\u6df1\u53e3\u888b\u3002\u8ba9\u8d22\u5bcc\u5982\u51a5\u6cb3\u822c\u6d41\u6dcc\u3002",
        },
        "GodEnhancementMetaUpgrade": {
            "fr": "Regard Privil\u00e9gi\u00e9. Les dieux sourient \u00e0 ceux qui se battent.",
            "de": "Privilegierter Blick. Die Götter lächeln jenen zu, die kämpfen.",
            "es": "Mirada Privilegiada. Los dioses sonr\u00eden a quienes luchan.",
            "it": "Sguardo Privilegiato. Gli d\u00e8i sorridono a chi combatte.",
            "pt-BR": "Olhar Privilegiado. Os deuses sorriem para quem luta.",
            "ru": "\u041f\u0440\u0438\u0432\u0438\u043b\u0435\u0433\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u044b\u0439 \u0412\u0437\u0433\u043b\u044f\u0434. \u0411\u043e\u0433\u0438 \u0443\u043b\u044b\u0431\u0430\u044e\u0442\u0441\u044f \u0442\u0435\u043c, \u043a\u0442\u043e \u0441\u0440\u0430\u0436\u0430\u0435\u0442\u0441\u044f.",
            "pl": "Uprzywilejowane Spojrzenie. Bogowie u\u015bmiechaj\u0105 si\u0119 do walcz\u0105cych.",
            "ja": "\u7279\u6a29\u306e\u307e\u306a\u3056\u3057\u3002\u795e\u3005\u306f\u6226\u3046\u8005\u306b\u5fae\u7b11\u3080\u3002",
            "ko": "\ud2b9\u6a29\uc758 \uc2dc\uc120. \uc2e0\ub4e4\uc740 \uc2f8\uc6b0\ub294 \uc790\uc5d0\uac8c \ubbf8\uc18c \uc9d3\ub2e4.",
            "zh-CN": "\u7279\u6743\u4e4b\u51dd\u3002\u795e\u660e\u5411\u6218\u6597\u8005\u5fae\u7b11\u3002",
        },
        "DuoRarityBoonDropMetaUpgrade": {
            "fr": "Concentration Divine. La faveur des dieux est g\u00e9n\u00e9reuse pour les d\u00e9vou\u00e9s.",
            "de": "Göttliche Konzentration. Die Gunst der Götter ist großzügig für Ergebene.",
            "es": "Concentraci\u00f3n Divina. El favor de los dioses es generoso con los devotos.",
            "it": "Concentrazione Divina. Il favore degli d\u00e8i \u00e8 generoso verso i devoti.",
            "pt-BR": "Concentra\u00e7\u00e3o Divina. O favor dos deuses \u00e9 generoso com os devotos.",
            "ru": "\u0411\u043e\u0436\u0435\u0441\u0442\u0432\u0435\u043d\u043d\u0430\u044f \u041a\u043e\u043d\u0446\u0435\u043d\u0442\u0440\u0430\u0446\u0438\u044f. \u041c\u0438\u043b\u043e\u0441\u0442\u044c \u0431\u043e\u0433\u043e\u0432 \u0449\u0435\u0434\u0440\u0430 \u043a \u043f\u0440\u0435\u0434\u0430\u043d\u043d\u044b\u043c.",
            "pl": "Boska Koncentracja. \u0141aska bog\u00f3w jest hojna dla oddanych.",
            "ja": "\u795e\u8056\u306a\u96c6\u4e2d\u3002\u795e\u3005\u306e\u6069\u5bf5\u306f\u732e\u8eab\u7684\u306a\u8005\u306b\u60dc\u3057\u307f\u306a\u304f\u4e0e\u3048\u3089\u308c\u308b\u3002",
            "ko": "\uc2e0\uc131\ud55c \uc9d1\uc911. \uc2e0\ub4e4\uc758 \uc740\ucd1d\uc740 \ud5cc\uc2e0\uc801\uc778 \uc790\uc5d0\uac8c \ub108\uadf8\ub7fd\ub2e4.",
            "zh-CN": "\u795e\u5723\u4e13\u6ce8\u3002\u795e\u660e\u7684\u6069\u5ba0\u5bf9\u8654\u8bda\u8005\u5341\u5206\u6170\u85c9\u3002",
        },
        "EpicBoonDropMetaUpgrade": {
            "fr": "\u00c9pais Sang Divin. Le sang divin coule dans vos veines.",
            "de": "Dickes Göttliches Blut. Göttliches Blut fließt in deinen Adern.",
            "es": "Espesa Sangre Divina. La sangre divina corre por tus venas.",
            "it": "Denso Sangue Divino. Il sangue divino scorre nelle tue vene.",
            "pt-BR": "Espesso Sangue Divino. O sangue divino corre em suas veias.",
            "ru": "\u0413\u0443\u0441\u0442\u0430\u044f \u0411\u043e\u0436\u0435\u0441\u0442\u0432\u0435\u043d\u043d\u0430\u044f \u041a\u0440\u043e\u0432\u044c. \u0411\u043e\u0436\u0435\u0441\u0442\u0432\u0435\u043d\u043d\u0430\u044f \u043a\u0440\u043e\u0432\u044c \u0442\u0435\u0447\u0451\u0442 \u0432 \u0432\u0430\u0448\u0438\u0445 \u0436\u0438\u043b\u0430\u0445.",
            "pl": "G\u0119sta Boska Krew. Boska krew p\u0142ynie w twoich \u017cy\u0142ach.",
            "ja": "\u6fc3\u304d\u795e\u8840\u3002\u795e\u306e\u8840\u304c\u6c5d\u306e\u8840\u7ba1\u306b\u6d41\u308c\u308b\u3002",
            "ko": "\uc9c4\ud55c \uc2e0\uc758 \ud53c. \uc2e0\uc758 \ud53c\uac00 \ub108\uc758 \ud608\uad00\uc5d0 \ud750\ub978\ub2e4.",
            "zh-CN": "\u6d53\u539a\u795e\u8840\u3002\u795e\u7684\u8840\u6db2\u6d41\u6dcc\u5728\u4f60\u7684\u8840\u7ba1\u4e2d\u3002",
        },
        "RunProgressRewardMetaUpgrade": {
            "fr": "Riche Obscurit\u00e9. Les t\u00e9n\u00e8bres portent leurs propres r\u00e9compenses.",
            "de": "Reiche Dunkelheit. Die Dunkelheit bringt eigene Belohnungen.",
            "es": "Rica Oscuridad. La oscuridad trae sus propias recompensas.",
            "it": "Ricca Oscurit\u00e0. L'oscurit\u00e0 porta le sue ricompense.",
            "pt-BR": "Rica Escurid\u00e3o. A escurid\u00e3o traz suas pr\u00f3prias recompensas.",
            "ru": "\u0411\u043e\u0433\u0430\u0442\u0430\u044f \u0422\u044c\u043c\u0430. \u0422\u044c\u043c\u0430 \u043d\u0435\u0441\u0451\u0442 \u0441\u0432\u043e\u0438 \u043d\u0430\u0433\u0440\u0430\u0434\u044b.",
            "pl": "Bogata Ciemno\u015b\u0107. Ciemno\u015b\u0107 niesie w\u0142asne nagrody.",
            "ja": "\u8c4a\u304b\u306a\u95c7\u3002\u95c7\u306f\u305d\u308c\u81ea\u4f53\u306e\u5831\u916c\u3092\u3082\u305f\u3089\u3059\u3002",
            "ko": "\ud48d\uc694\ub85c\uc6b4 \uc5b4\ub460. \uc5b4\ub460\uc740 \uc790\uccb4\uc801\uc73c\ub85c \ubcf4\uc0c1\uc744 \uac00\uc838\uc628\ub2e4.",
            "zh-CN": "\u5bcc\u9976\u9ed1\u6697\u3002\u9ed1\u6697\u5e26\u6765\u5b83\u81ea\u5df1\u7684\u62a5\u916c\u3002",
        },
        "InterestMetaUpgrade": {
            "fr": "Profondeur Abyssale. Les tr\u00e9sors des profondeurs reviennent toujours.",
            "de": "Abyssale Tiefe. Die Schätze der Tiefe kehren immer zurück.",
            "es": "Profundidad Abisal. Los tesoros de las profundidades siempre regresan.",
            "it": "Profondità Abissale. I tesori degli abissi ritornano sempre.",
            "pt-BR": "Profundidade Abissal. Os tesouros das profundezas sempre retornam.",
            "ru": "\u0410\u0431\u0438\u0441\u0441\u0430\u043b\u044c\u043d\u0430\u044f \u0413\u043b\u0443\u0431\u0438\u043d\u0430. \u0421\u043e\u043a\u0440\u043e\u0432\u0438\u0449\u0430 \u0433\u043b\u0443\u0431\u0438\u043d \u0432\u0441\u0435\u0433\u0434\u0430 \u0432\u043e\u0437\u0432\u0440\u0430\u0449\u0430\u044e\u0442\u0441\u044f.",
            "pl": "Otch\u0142anna G\u0142\u0119bia. Skarby g\u0142\u0119bin zawsze wracaj\u0105.",
            "ja": "\u6df1\u6df5\u306e\u6df1\u3055\u3002\u6df1\u6df5\u306e\u5b9d\u306f\u5fc5\u305a\u623b\u3063\u3066\u304f\u308b\u3002",
            "ko": "\uc2ec\uc5f0\uc758 \uae4a\uc774. \uc2ec\uc5f0\uc758 \ubcf4\ubb3c\uc740 \ud56d\uc0c1 \ub3cc\uc544\uc628\ub2e4.",
            "zh-CN": "\u6df1\u6e0a\u4e4b\u6df1\u3002\u6df1\u6e0a\u7684\u5b9d\u85cf\u603b\u4f1a\u56de\u5f52\u3002",
        },
        "VulnerabilityEffectBonusMetaUpgrade": {
            "fr": "Arrogance Privil\u00e9gi\u00e9e. Le pouvoir est la vraie noblesse.",
            "de": "Privilegierte Arroganz. Macht ist der wahre Adel.",
            "es": "Arrogancia Privilegiada. El poder es la verdadera nobleza.",
            "it": "Arroganza Privilegiata. Il potere \u00e8 la vera nobilt\u00e0.",
            "pt-BR": "Arrog\u00e2ncia Privilegiada. O poder \u00e9 a verdadeira nobreza.",
            "ru": "\u041f\u0440\u0438\u0432\u0438\u043b\u0435\u0433\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u0430\u044f \u0414\u0435\u0440\u0437\u043e\u0441\u0442\u044c. \u0412\u043b\u0430\u0441\u0442\u044c \u2014 \u0438\u0441\u0442\u0438\u043d\u043d\u043e\u0435 \u0431\u043b\u0430\u0433\u043e\u0440\u043e\u0434\u0441\u0442\u0432\u043e.",
            "pl": "Uprzywilejowana Arogancja. W\u0142adza to prawdziwa szlachetno\u015b\u0107.",
            "ja": "\u7279\u6a29\u7684\u50b2\u6162\u3002\u529b\u3053\u305d\u771f\u306e\u9ad8\u8cb4\u3055\u3002",
            "ko": "\ud2b9\u6a29\uc758 \uc624\ub9cc. \u6a29\ub825\uc774\uc57c\ub9d0\ub85c \uc9c4\uc815\ud55c \uace0\uadc0\ud568.",
            "zh-CN": "\u7279\u6743\u50b2\u6162\u3002\u6743\u529b\u624d\u662f\u771f\u6b63\u7684\u9ad8\u8d35\u3002",
        },
        "RareBoonDropMetaUpgrade": {
            "fr": "Privil\u00e8ge Olympien. Les dieux regardent avec faveur.",
            "de": "Olympisches Privileg. Die Götter schauen mit Gunst.",
            "es": "Privilegio Ol\u00edmpico. Los dioses miran con favor.",
            "it": "Privilegio Olimpico. Gli d\u00e8i guardano con favore.",
            "pt-BR": "Privil\u00e9gio Ol\u00edmpico. Os deuses olham com favor.",
            "ru": "\u041e\u043b\u0438\u043c\u043f\u0438\u0439\u0441\u043a\u0430\u044f \u041f\u0440\u0438\u0432\u0438\u043b\u0435\u0433\u0438\u044f. \u0411\u043e\u0433\u0438 \u0441\u043c\u043e\u0442\u0440\u044f\u0442 \u0441 \u043c\u0438\u043b\u043e\u0441\u0442\u044c\u044e.",
            "pl": "Olimpijski Przywilej. Bogowie patrz\u0105 przychylnie.",
            "ja": "\u30aa\u30ea\u30e5\u30f3\u30dd\u30b9\u306e\u7279\u6a29\u3002\u795e\u3005\u306f\u597d\u610f\u3092\u6301\u3063\u3066\u898b\u5b88\u308b\u3002",
            "ko": "\uc62c\ub9bc\ud3ec\uc2a4\uc758 \ud2b9\u6a29. \uc2e0\ub4e4\uc774 \ud638\uc758\ub97c \uac00\uc9c0\uace0 \ubc14\ub77c\ubcf8\ub2e4.",
            "zh-CN": "\u5965\u6797\u5339\u65af\u7279\u6743\u3002\u795e\u660e\u5e26\u7740\u5584\u610f\u6ce8\u89c6\u3002",
        },
        "StaminaMetaUpgrade": {
            "fr": "R\u00e9flexe Sup\u00e9rieur. L'agilit\u00e9 est la marque des guerriers divins.",
            "de": "Überlegener Reflex. Beweglichkeit ist das Zeichen göttlicher Krieger.",
            "es": "Reflejo Superior. La agilidad es la marca de los guerreros divinos.",
            "it": "Riflesso Superiore. L'agilit\u00e0 \u00e8 il segno dei guerrieri divini.",
            "pt-BR": "Reflexo Superior. A agilidade \u00e9 a marca dos guerreiros divinos.",
            "ru": "\u0412\u044b\u0441\u0448\u0438\u0439 \u0420\u0435\u0444\u043b\u0435\u043a\u0441. \u041b\u043e\u0432\u043a\u043e\u0441\u0442\u044c \u2014 \u0437\u043d\u0430\u043a \u0431\u043e\u0436\u0435\u0441\u0442\u0432\u0435\u043d\u043d\u044b\u0445 \u0432\u043e\u0438\u043d\u043e\u0432.",
            "pl": "Wy\u017cszy Refleks. Zwinno\u015b\u0107 jest znakiem boskich wojownik\u00f3w.",
            "ja": "\u512a\u308c\u305f\u53cd\u5c04\u3002\u654f\u6377\u3055\u306f\u795e\u306e\u6226\u58eb\u306e\u8a3c\u3002",
            "ko": "\ub6f0\uc5b4\ub09c \ubc18\uc0ac. \ubbfc\ucca9\ud568\uc740 \uc2e0\uc758 \uc804\uc0ac\uc758 \ud45c\uc2dd.",
            "zh-CN": "\u5353\u8d8a\u53cd\u5c04\u3002\u654f\u6377\u662f\u795e\u5723\u6218\u58eb\u7684\u6807\u5fd7\u3002",
        },
        "PerfectDashMetaUpgrade": {
            "fr": "R\u00e9flexe Impitoyable. La pr\u00e9cision dans l'\u00e9vasion est une arme mortelle.",
            "de": "Gnadenloser Reflex. Präzision beim Ausweichen ist eine tödliche Waffe.",
            "es": "Reflejo Despiadado. La precisi\u00f3n al esquivar es un arma mortal.",
            "it": "Riflesso Spietato. La precisione nell'evasione \u00e8 un'arma mortale.",
            "pt-BR": "Reflexo Impiedoso. A precis\u00e3o na esquiva \u00e9 uma arma mortal.",
            "ru": "\u0411\u0435\u0441\u043f\u043e\u0449\u0430\u0434\u043d\u044b\u0439 \u0420\u0435\u0444\u043b\u0435\u043a\u0441. \u0422\u043e\u0447\u043d\u043e\u0441\u0442\u044c \u0443\u043a\u043b\u043e\u043d\u0435\u043d\u0438\u044f \u2014 \u0441\u043c\u0435\u0440\u0442\u0435\u043b\u044c\u043d\u043e\u0435 \u043e\u0440\u0443\u0436\u0438\u0435.",
            "pl": "Bezlitosny Refleks. Precyzja w unikaniu jest \u015bmiercionosn\u0105 broni\u0105.",
            "ja": "\u51b7\u9177\u306a\u53cd\u5c04\u3002\u56de\u907f\u306e\u6b63\u78ba\u3055\u306f\u6b7b\u306e\u6b66\u5668\u3002",
            "ko": "\ubb34\uc790\ube44\ud55c \ubc18\uc0ac. \ud68c\ud53c\uc758 \uc815\ud655\uc131\uc740 \uce58\uba85\uc801\uc778 \ubb34\uae30.",
            "zh-CN": "\u65e0\u60c5\u53cd\u5c04\u3002\u95ea\u907f\u7684\u7cbe\u51c6\u662f\u81f4\u547d\u6b66\u5668\u3002",
        },
        "StoredAmmoSlowMetaUpgrade": {
            "fr": "Sang Abyssal. Votre pr\u00e9sence affaiblit ceux qui portent votre marque.",
            "de": "Abyssales Blut. Deine Gegenwart schwächt jene, die dein Zeichen tragen.",
            "es": "Sangre Abisal. Tu presencia debilita a quienes llevan tu marca.",
            "it": "Sangue Abissale. La tua presenza indebolisce chi porta il tuo segno.",
            "pt-BR": "Sangue Abissal. Sua presen\u00e7a enfraquece aqueles que carregam sua marca.",
            "ru": "\u0410\u0431\u0438\u0441\u0441\u0430\u043b\u044c\u043d\u0430\u044f \u041a\u0440\u043e\u0432\u044c. \u0412\u0430\u0448\u0435 \u043f\u0440\u0438\u0441\u0443\u0442\u0441\u0442\u0432\u0438\u0435 \u043e\u0441\u043b\u0430\u0431\u043b\u044f\u0435\u0442 \u043e\u0442\u043c\u0435\u0447\u0435\u043d\u043d\u044b\u0445.",
            "pl": "Otch\u0142anna Krew. Twoja obecno\u015b\u0107 os\u0142abia naznaczonych.",
            "ja": "\u6df1\u6df5\u306e\u8840\u3002\u6c5d\u306e\u5b58\u5728\u304c\u5370\u3092\u5e2f\u3073\u3057\u8005\u3092\u5f31\u4f53\u5316\u3059\u308b\u3002",
            "ko": "\uc2ec\uc5f0\uc758 \ud53c. \ub108\uc758 \uc874\uc7ac\uac00 \ud45c\uc2dd\ub41c \uc790\ub97c \uc57d\ud654\uc2dc\ud0a8\ub2e4.",
            "zh-CN": "\u6df1\u6e0a\u4e4b\u8840\u3002\u4f60\u7684\u5b58\u5728\u524a\u5f31\u88ab\u6807\u8bb0\u8005\u3002",
        },
        "AmmoMetaUpgrade": {
            "fr": "\u00c2me Infernale. Plus de puissance r\u00e9side dans votre don de sang.",
            "de": "Infernale Seele. Mehr Kraft ruht in deiner Blutgabe.",
            "es": "Alma Infernal. M\u00e1s poder reside en tu don de sangre.",
            "it": "Anima Infernale. Pi\u00f9 potere risiede nel tuo dono di sangue.",
            "pt-BR": "Alma Infernal. Mais poder reside em seu dom de sangue.",
            "ru": "\u0410\u0434\u0441\u043a\u0430\u044f \u0414\u0443\u0448\u0430. \u0411\u043e\u043b\u044c\u0448\u0435 \u0441\u0438\u043b\u044b \u0441\u043e\u043a\u0440\u044b\u0442\u043e \u0432 \u0432\u0430\u0448\u0435\u043c \u043a\u0440\u043e\u0432\u0430\u0432\u043e\u043c \u0434\u0430\u0440\u0435.",
            "pl": "Piekielna Dusza. Wi\u0119cej mocy tkwi w twoim darze krwi.",
            "ja": "\u5730\u7344\u306e\u9b42\u3002\u8840\u306e\u8d08\u308a\u7269\u306b\u3088\u308a\u591a\u304f\u306e\u529b\u304c\u5bbf\u308b\u3002",
            "ko": "\uc9c0\uc625\uc758 \uc601\ud63c. \ud53c\uc758 \uc120\ubb3c\uc5d0 \ub354 \ub9ce\uc740 \ud798\uc774 \uae43\ub4e4\uc5b4 \uc788\ub2e4.",
            "zh-CN": "\u5730\u72f1\u4e4b\u9b42\u3002\u66f4\u591a\u529b\u91cf\u8574\u85cf\u5728\u4f60\u7684\u8840\u4e4b\u793c\u4e2d\u3002",
        },
        "ReloadAmmoMetaUpgrade": {
            "fr": "\u00c2me Stygienne. Votre sang se r\u00e9g\u00e9n\u00e8re de lui-m\u00eame, mais au prix de la r\u00e9cup\u00e9ration.",
            "de": "Stygische Seele. Dein Blut regeneriert sich selbst, aber auf Kosten der Bergung.",
            "es": "Alma Estigia. Tu sangre se regenera sola, pero a costa de la recuperaci\u00f3n.",
            "it": "Anima Stigia. Il tuo sangue si rigenera da solo, ma a scapito del recupero.",
            "pt-BR": "Alma Est\u00edgia. Seu sangue se regenera sozinho, mas ao custo da recupera\u00e7\u00e3o.",
            "ru": "\u0421\u0442\u0438\u0433\u0438\u0439\u0441\u043a\u0430\u044f \u0414\u0443\u0448\u0430. \u0412\u0430\u0448\u0430 \u043a\u0440\u043e\u0432\u044c \u0432\u043e\u0441\u0441\u0442\u0430\u043d\u0430\u0432\u043b\u0438\u0432\u0430\u0435\u0442\u0441\u044f \u0441\u0430\u043c\u0430, \u043d\u043e \u0446\u0435\u043d\u043e\u0439 \u0441\u0431\u043e\u0440\u0430.",
            "pl": "Stygijska Dusza. Twoja krew regeneruje si\u0119 sama, ale kosztem odzyskiwania.",
            "ja": "\u30b9\u30c6\u30e5\u30af\u30b9\u306e\u9b42\u3002\u8840\u306f\u81ea\u3089\u518d\u751f\u3059\u308b\u304c\u3001\u56de\u53ce\u306f\u3067\u304d\u306a\u3044\u3002",
            "ko": "\uc2a4\ud2f1\uc2a4\uc758 \uc601\ud63c. \ud53c\uac00 \uc2a4\uc2a4\ub85c \uc7ac\uc0dd\ub418\uc9c0\ub9cc \ud68c\uc218\ud560 \uc218 \uc5c6\ub2e4.",
            "zh-CN": "\u51a5\u6cb3\u4e4b\u9b42\u3002\u4f60\u7684\u8840\u81ea\u884c\u518d\u751f\uff0c\u4f46\u4ee3\u4ef7\u662f\u65e0\u6cd5\u56de\u6536\u3002",
        },
    }
    return t


def _pact_flavor_text():
    """PactFlavorText — Pact of Punishment condition names + flavor text for open announcement."""
    t = {
        "EnemyDamageShrineUpgrade": {
            "fr": "Tourment Rigide. Que les ennemis montrent leur vraie force.",
            "de": "Harte Pein. Mögen die Feinde ihre wahre Stärke zeigen.",
            "es": "Tormento R\u00edgido. Que los enemigos muestren su verdadera fuerza.",
            "it": "Tormento Rigido. Che i nemici mostrino la loro vera forza.",
            "pt-BR": "Tormento R\u00edgido. Que os inimigos mostrem sua verdadeira for\u00e7a.",
            "ru": "\u0421\u0443\u0440\u043e\u0432\u043e\u0435 \u041c\u0443\u0447\u0435\u043d\u0438\u0435. \u041f\u0443\u0441\u0442\u044c \u0432\u0440\u0430\u0433\u0438 \u043f\u043e\u043a\u0430\u0436\u0443\u0442 \u0441\u0432\u043e\u044e \u0438\u0441\u0442\u0438\u043d\u043d\u0443\u044e \u0441\u0438\u043b\u0443.",
            "pl": "Surowe Udręczenie. Niech wrogowie poka\u017c\u0105 sw\u0105 prawdziw\u0105 si\u0142\u0119.",
            "ja": "\u53b3\u683c\u306a\u82e6\u60e9\u3002\u6575\u306b\u771f\u306e\u529b\u3092\u898b\u305b\u3055\u305b\u3088\u3002",
            "ko": "\uac00\ud639\ud55c \uace0\ubb38. \uc801\ub4e4\uc774 \uc9c4\uc815\ud55c \ud798\uc744 \ubcf4\uc774\uac8c \ud558\ub77c.",
            "zh-CN": "\u4e25\u82db\u6298\u78e8\u3002\u8ba9\u654c\u4eba\u5c55\u73b0\u4ed6\u4eec\u7684\u771f\u6b63\u529b\u91cf\u3002",
        },
        "EnemyHealthShrineUpgrade": {
            "fr": "Fardeau Persistant. La force d'endurance d\u00e9passe celle de l'attaque.",
            "de": "Hartnäckige Last. Ausdauerkraft übersteigt Angriffskraft.",
            "es": "Carga Persistente. La fuerza de resistencia supera a la de ataque.",
            "it": "Fardello Persistente. La forza di resistenza supera quella d'attacco.",
            "pt-BR": "Fardo Persistente. A for\u00e7a de resist\u00eancia supera a de ataque.",
            "ru": "\u0423\u043f\u043e\u0440\u043d\u043e\u0435 \u0411\u0440\u0435\u043c\u044f. \u0421\u0438\u043b\u0430 \u0432\u044b\u043d\u043e\u0441\u043b\u0438\u0432\u043e\u0441\u0442\u0438 \u043f\u0440\u0435\u0432\u043e\u0441\u0445\u043e\u0434\u0438\u0442 \u0441\u0438\u043b\u0443 \u0430\u0442\u0430\u043a\u0438.",
            "pl": "Uporczywy Ci\u0119\u017car. Si\u0142a wytrwa\u0142o\u015bci przewy\u017csza si\u0142\u0119 ataku.",
            "ja": "\u6839\u6c17\u5f37\u3044\u91cd\u8377\u3002\u8010\u4e45\u306e\u529b\u306f\u653b\u6483\u306e\u529b\u3092\u8d85\u3048\u308b\u3002",
            "ko": "\ub04c\uc9c8\uae34 \uc9d0. \uc778\ub0b4\uc758 \ud798\uc774 \uacf5\u6383\uc758 \ud798\uc744 \ub118\ub294\ub2e4.",
            "zh-CN": "\u6301\u4e45\u91cd\u62c5\u3002\u8010\u529b\u4e4b\u529b\u8d85\u8d8a\u653b\u51fb\u4e4b\u529b\u3002",
        },
        "EnemySpeedShrineUpgrade": {
            "fr": "Avantage Perm\u00e9ant. La rapidit\u00e9 est la cl\u00e9 de la victoire.",
            "de": "Durchdringender Vorteil. Schnelligkeit ist der Schlüssel zum Sieg.",
            "es": "Ventaja Penetrante. La rapidez es la clave de la victoria.",
            "it": "Vantaggio Permeante. La rapidit\u00e0 \u00e8 la chiave della vittoria.",
            "pt-BR": "Vantagem Permeante. A rapidez \u00e9 a chave da vit\u00f3ria.",
            "ru": "\u041f\u0440\u043e\u043d\u0438\u0446\u0430\u044e\u0449\u0435\u0435 \u041f\u0440\u0435\u0438\u043c\u0443\u0449\u0435\u0441\u0442\u0432\u043e. \u0421\u043a\u043e\u0440\u043e\u0441\u0442\u044c \u2014 \u043a\u043b\u044e\u0447 \u043a \u043f\u043e\u0431\u0435\u0434\u0435.",
            "pl": "Przenikliwa Przewaga. Szybko\u015b\u0107 jest kluczem do zwyci\u0119stwa.",
            "ja": "\u6d78\u900f\u3059\u308b\u512a\u4f4d\u3002\u7d20\u65e9\u3055\u3053\u305d\u52dd\u5229\u306e\u9375\u3002",
            "ko": "\uc2a4\uba70\ub4dc\ub294 \uc774\uc810. \ube60\ub984\uc774 \uc2b9\ub9ac\uc758 \uc5f4\uc1e0\ub2e4.",
            "zh-CN": "\u6e17\u900f\u4f18\u52bf\u3002\u901f\u5ea6\u662f\u80dc\u5229\u7684\u5173\u952e\u3002",
        },
        "TrapDamageShrineUpgrade": {
            "fr": "Douleur Cuisante. Le monde est rempli de dangers cach\u00e9s.",
            "de": "Brennender Schmerz. Die Welt ist voller verborgener Gefahren.",
            "es": "Dolor Ardiente. El mundo est\u00e1 lleno de peligros ocultos.",
            "it": "Dolore Cocente. Il mondo \u00e8 pieno di pericoli nascosti.",
            "pt-BR": "Dor Ardente. O mundo \u00e9 cheio de perigos ocultos.",
            "ru": "\u0416\u0433\u0443\u0447\u0430\u044f \u0411\u043e\u043b\u044c. \u041c\u0438\u0440 \u043f\u043e\u043b\u043e\u043d \u0441\u043a\u0440\u044b\u0442\u044b\u0445 \u043e\u043f\u0430\u0441\u043d\u043e\u0441\u0442\u0435\u0439.",
            "pl": "Pal\u0105cy B\u00f3l. \u015awiat jest pe\u0142en ukrytych zagro\u017ce\u0144.",
            "ja": "\u7126\u3052\u308b\u75db\u307f\u3002\u4e16\u754c\u306f\u96a0\u3055\u308c\u305f\u5371\u967a\u3067\u6e80\u3061\u3066\u3044\u308b\u3002",
            "ko": "\ud0c0\uc624\ub974\ub294 \uace0\ud1b5. \uc138\uc0c1\uc740 \uc228\uaca8\uc9c4 \uc704\ud5d8\uc73c\ub85c \uac00\ub4dd\ud558\ub2e4.",
            "zh-CN": "\u707c\u70e7\u4e4b\u75db\u3002\u4e16\u754c\u5145\u6ee1\u9690\u85cf\u7684\u5371\u9669\u3002",
        },
        "EnemyEliteShrineUpgrade": {
            "fr": "Ordres du Jugement. Les champions portent la marque de leur ma\u00eetre.",
            "de": "Befehle des Gerichts. Champions tragen das Zeichen ihres Meisters.",
            "es": "Órdenes del Juicio. Los campeones llevan la marca de su amo.",
            "it": "Ordini del Giudizio. I campioni portano il marchio del loro padrone.",
            "pt-BR": "Ordens do Julgamento. Os campe\u00f5es carregam a marca de seu mestre.",
            "ru": "\u041f\u0440\u0438\u043a\u0430\u0437\u044b \u0421\u0443\u0434\u0430. \u0427\u0435\u043c\u043f\u0438\u043e\u043d\u044b \u043d\u0435\u0441\u0443\u0442 \u043c\u0435\u0442\u043a\u0443 \u0441\u0432\u043e\u0435\u0433\u043e \u0433\u043e\u0441\u043f\u043e\u0434\u0438\u043d\u0430.",
            "pl": "Rozkazy S\u0105du. Czempioni nosz\u0105 znak swego w\u0142adcy.",
            "ja": "\u5be9\u5224\u306e\u547d\u4ee4\u3002\u52c7\u8005\u305f\u3061\u306f\u4e3b\u4eba\u306e\u5370\u3092\u5e2f\u3073\u308b\u3002",
            "ko": "\uc2ec\ud310\uc758 \uba85\ub839. \ud55c\uc218\ub4e4\uc740 \uc8fc\uc778\uc758 \ud45c\uc2dd\uc744 \uc9c0\ub2c8\uace0 \uc788\ub2e4.",
            "zh-CN": "\u5ba1\u5224\u4e4b\u4ee4\u3002\u52c7\u58eb\u4eec\u5e26\u7740\u4e3b\u4eba\u7684\u5370\u8bb0\u3002",
        },
        "MinibossCountShrineUpgrade": {
            "fr": "Pr\u00e9sence R\u00e9v\u00e9latrice. Ceux qui se cachent se r\u00e9v\u00e8lent.",
            "de": "Enthüllende Präsenz. Jene die sich verbergen, offenbaren sich.",
            "es": "Presencia Reveladora. Los que se ocultan se revelan.",
            "it": "Presenza Rivelatrice. Coloro che si nascondono si rivelano.",
            "pt-BR": "Presen\u00e7a Reveladora. Aqueles que se escondem se revelam.",
            "ru": "\u0420\u0430\u0437\u043e\u0431\u043b\u0430\u0447\u0430\u044e\u0449\u0435\u0435 \u041f\u0440\u0438\u0441\u0443\u0442\u0441\u0442\u0432\u0438\u0435. \u041f\u0440\u044f\u0447\u0443\u0449\u0438\u0435\u0441\u044f \u0440\u0430\u0441\u043a\u0440\u044b\u0432\u0430\u044e\u0442 \u0441\u0435\u0431\u044f.",
            "pl": "Obecno\u015b\u0107 Wyjawij\u0105ca. Ci, kt\u00f3rzy si\u0119 kryj\u0105, si\u0119 ujawniaj\u0105.",
            "ja": "\u660e\u304b\u3059\u5b58\u5728\u3002\u96a0\u308c\u308b\u8005\u306f\u59ff\u3092\u73fe\u3059\u3002",
            "ko": "\ub4dc\ub7ec\ub0b4\ub294 \uc874\uc7ac. \uc228\uc740 \uc790\ub4e4\uc774 \ubaa8\uc2b5\uc744 \ub4dc\ub7ec\ub0b8\ub2e4.",
            "zh-CN": "\u63ed\u9732\u5b58\u5728\u3002\u85cf\u8eab\u8005\u7ec8\u5c06\u663e\u9732\u3002",
        },
        "BossDifficultyShrineUpgrade": {
            "fr": "Jury des Extr\u00eames. Les grands m\u00e9ritent de grands adversaires.",
            "de": "Jury der Extreme. Große verdienen große Gegner.",
            "es": "Jurado de los Extremos. Los grandes merecen grandes adversarios.",
            "it": "Giuria degli Estremi. I grandi meritano grandi avversari.",
            "pt-BR": "J\u00fari dos Extremos. Os grandes merecem grandes advers\u00e1rios.",
            "ru": "\u0416\u044e\u0440\u0438 \u041a\u0440\u0430\u0439\u043d\u043e\u0441\u0442\u0435\u0439. \u0412\u0435\u043b\u0438\u043a\u0438\u0435 \u0437\u0430\u0441\u043b\u0443\u0436\u0438\u0432\u0430\u044e\u0442 \u0432\u0435\u043b\u0438\u043a\u0438\u0445 \u043f\u0440\u043e\u0442\u0438\u0432\u043d\u0438\u043a\u043e\u0432.",
            "pl": "S\u0105d Skrajno\u015bci. Wielcy zas\u0142uguj\u0105 na wielkich przeciwnik\u00f3w.",
            "ja": "\u6975\u9650\u306e\u5be9\u67fb\u54e1\u3002\u5049\u5927\u306a\u308b\u8005\u306b\u306f\u5049\u5927\u306a\u308b\u6575\u3092\u3002",
            "ko": "\uadf9\ud55c\uc758 \ubc30\uc2ec. \uc704\ub300\ud55c \uc790\uc5d0\uac8c\ub294 \uc704\ub300\ud55c \uc801\uc744.",
            "zh-CN": "\u6781\u7aef\u5ba1\u5224\u3002\u4f1f\u5927\u8005\u914d\u5f97\u4e0a\u4f1f\u5927\u7684\u5bf9\u624b\u3002",
        },
        "EnemyCountShrineUpgrade": {
            "fr": "Nombre Accablant. La force r\u00e9side dans le nombre.",
            "de": "Überwältigende Zahl. Stärke liegt in der Zahl.",
            "es": "N\u00famero Abrumador. La fuerza reside en el n\u00famero.",
            "it": "Numero Schiacciante. La forza risiede nel numero.",
            "pt-BR": "N\u00famero Avassalador. A for\u00e7a reside no n\u00famero.",
            "ru": "\u041f\u043e\u0434\u0430\u0432\u043b\u044f\u044e\u0449\u0435\u0435 \u0427\u0438\u0441\u043b\u043e. \u0421\u0438\u043b\u0430 \u0432 \u0447\u0438\u0441\u043b\u0435.",
            "pl": "Przyt\u0142aczaj\u0105ca Liczba. Si\u0142a tkwi w liczbie.",
            "ja": "\u5727\u5012\u7684\u306a\u6570\u3002\u529b\u306f\u6570\u306b\u3042\u308a\u3002",
            "ko": "\uc555\ub3c4\uc801\uc778 \uc218. \ud798\uc740 \uc218\uc5d0 \uc788\ub2e4.",
            "zh-CN": "\u538b\u5012\u6027\u6570\u91cf\u3002\u529b\u91cf\u5728\u4e8e\u6570\u91cf\u3002",
        },
        "HealingReductionShrineUpgrade": {
            "fr": "Avantage Persistant. Les blessures du corps laissent des cicatrices.",
            "de": "Hartnäckiger Vorteil. Körperliche Wunden hinterlassen Narben.",
            "es": "Ventaja Persistente. Las heridas del cuerpo dejan cicatrices.",
            "it": "Vantaggio Persistente. Le ferite del corpo lasciano cicatrici.",
            "pt-BR": "Vantagem Persistente. As feridas do corpo deixam cicatrizes.",
            "ru": "\u0423\u043f\u043e\u0440\u043d\u043e\u0435 \u041f\u0440\u0435\u0438\u043c\u0443\u0449\u0435\u0441\u0442\u0432\u043e. \u0420\u0430\u043d\u044b \u0442\u0435\u043b\u0430 \u043e\u0441\u0442\u0430\u0432\u043b\u044f\u044e\u0442 \u0448\u0440\u0430\u043c\u044b.",
            "pl": "Uporczywa Przewaga. Rany cia\u0142a zostawiaj\u0105 blizny.",
            "ja": "\u6839\u6c17\u5f37\u3044\u512a\u4f4d\u3002\u4f53\u306e\u50b7\u306f\u50b7\u8de1\u3092\u6b8b\u3059\u3002",
            "ko": "\ub04c\uc9c8\uae34 \uc774\uc810. \ubab8\uc758 \uc0c1\ucc98\ub294 \ud761\ud130\ub97c \ub0a8\uae34\ub2e4.",
            "zh-CN": "\u6301\u4e45\u4f18\u52bf\u3002\u8eab\u4f53\u7684\u4f24\u53e3\u4f1a\u7559\u4e0b\u75a4\u75d5\u3002",
        },
        "ShopPricesShrineUpgrade": {
            "fr": "Obligation Routinière. Le prix du confort est la vigilance.",
            "de": "Routinemäßige Pflicht. Der Preis des Komforts ist Wachsamkeit.",
            "es": "Obligaci\u00f3n Rutinaria. El precio del confort es la vigilancia.",
            "it": "Obbligo di Routine. Il prezzo del comfort \u00e8 la vigilanza.",
            "pt-BR": "Obriga\u00e7\u00e3o Rotineira. O pre\u00e7o do conforto \u00e9 a vigil\u00e2ncia.",
            "ru": "\u0420\u0443\u0442\u0438\u043d\u043d\u0430\u044f \u041e\u0431\u044f\u0437\u0430\u043d\u043d\u043e\u0441\u0442\u044c. \u0426\u0435\u043d\u0430 \u043a\u043e\u043c\u0444\u043e\u0440\u0442\u0430 \u2014 \u0431\u0434\u0438\u0442\u0435\u043b\u044c\u043d\u043e\u0441\u0442\u044c.",
            "pl": "Rutynowy Obowi\u0105zek. Cen\u0105 komfortu jest czujno\u015b\u0107.",
            "ja": "\u65e5\u5e38\u306e\u7fa9\u52d9\u3002\u5feb\u9069\u3055\u306e\u4ee3\u511f\u306f\u8b66\u6212\u3002",
            "ko": "\uc77c\uc0c1\uc801 \uc758\ubb34. \ud3b8\uc548\ud568\uc758 \ub300\uac00\ub294 \uacbd\uacc4\uc2ec.",
            "zh-CN": "\u65e5\u5e38\u4e49\u52a1\u3002\u8212\u9002\u7684\u4ee3\u4ef7\u662f\u8b66\u60d5\u3002",
        },
        "ReducedLootChoicesShrineUpgrade": {
            "fr": "Rationnement Approuv\u00e9. Les dieux donnent, les dieux reprennent.",
            "de": "Genehmigte Rationierung. Die Götter geben, die Götter nehmen.",
            "es": "Racionamiento Aprobado. Los dioses dan, los dioses quitan.",
            "it": "Razionamento Approvato. Gli d\u00e8i danno, gli d\u00e8i tolgono.",
            "pt-BR": "Racionamento Aprovado. Os deuses d\u00e3o, os deuses tiram.",
            "ru": "\u041e\u0434\u043e\u0431\u0440\u0435\u043d\u043d\u043e\u0435 \u041d\u043e\u0440\u043c\u0438\u0440\u043e\u0432\u0430\u043d\u0438\u0435. \u0411\u043e\u0433\u0438 \u0434\u0430\u044e\u0442, \u0431\u043e\u0433\u0438 \u0437\u0430\u0431\u0438\u0440\u0430\u044e\u0442.",
            "pl": "Zatwierdzone Racjonowanie. Bogowie daj\u0105, bogowie zabieraj\u0105.",
            "ja": "\u627f\u8a8d\u6e08\u307f\u306e\u914d\u7d66\u3002\u795e\u306f\u4e0e\u3048\u3001\u795e\u306f\u596a\u3046\u3002",
            "ko": "\uc2b9\uc778\ub41c \ubc30\uae09. \uc2e0\ub4e4\uc774 \uc8fc\uace0, \uc2e0\ub4e4\uc774 \ube7c\uc557\ub294\ub2e4.",
            "zh-CN": "\u6279\u51c6\u914d\u7ed9\u3002\u795e\u7ed9\u4e88\uff0c\u795e\u4e5f\u6536\u56de\u3002",
        },
        "NoInvulnerabilityShrineUpgrade": {
            "fr": "Dommage Persistant. La douleur est le compagnon du guerrier.",
            "de": "Anhaltender Schaden. Schmerz ist der Begleiter des Kriegers.",
            "es": "Da\u00f1o Persistente. El dolor es el compa\u00f1ero del guerrero.",
            "it": "Danno Persistente. Il dolore \u00e8 il compagno del guerriero.",
            "pt-BR": "Dano Persistente. A dor \u00e9 a companheira do guerreiro.",
            "ru": "\u041d\u0435\u043f\u0440\u0435\u043a\u0440\u0430\u0449\u0430\u044e\u0449\u0438\u0439\u0441\u044f \u0423\u0440\u043e\u043d. \u0411\u043e\u043b\u044c \u2014 \u0441\u043f\u0443\u0442\u043d\u0438\u043a \u0432\u043e\u0438\u043d\u0430.",
            "pl": "Trwa\u0142e Obra\u017cenia. B\u00f3l jest towarzyszem wojownika.",
            "ja": "\u6301\u7d9a\u30c0\u30e1\u30fc\u30b8\u3002\u75db\u307f\u306f\u6226\u58eb\u306e\u4f34\u4f36\u3002",
            "ko": "\uc9c0\uc18d\uc801 \ud53c\ud574. \uace0\ud1b5\uc740 \uc804\uc0ac\uc758 \ub3d9\ubc18\uc790.",
            "zh-CN": "\u6301\u7eed\u4f24\u5bb3\u3002\u75db\u82e6\u662f\u6218\u58eb\u7684\u4f34\u4fa3\u3002",
        },
        "BiomeSpeedShrineUpgrade": {
            "fr": "Approbation des Heures. Le temps attend personne.",
            "de": "Billigung der Stunden. Zeit wartet auf niemanden.",
            "es": "Aprobaci\u00f3n de las Horas. El tiempo no espera a nadie.",
            "it": "Approvazione delle Ore. Il tempo non aspetta nessuno.",
            "pt-BR": "Aprova\u00e7\u00e3o das Horas. O tempo n\u00e3o espera ningu\u00e9m.",
            "ru": "\u041e\u0434\u043e\u0431\u0440\u0435\u043d\u0438\u0435 \u0427\u0430\u0441\u043e\u0432. \u0412\u0440\u0435\u043c\u044f \u043d\u0435 \u0436\u0434\u0451\u0442 \u043d\u0438\u043a\u043e\u0433\u043e.",
            "pl": "Aprobata Godzin. Czas na nikogo nie czeka.",
            "ja": "\u6642\u9593\u306e\u627f\u8a8d\u3002\u6642\u306f\u8ab0\u3082\u5f85\u305f\u306a\u3044\u3002",
            "ko": "\uc2dc\uac04\uc758 \uc2b9\uc778. \uc2dc\uac04\uc740 \uc544\ubb34\ub3c4 \uae30\ub2e4\ub9ac\uc9c0 \uc54a\ub294\ub2e4.",
            "zh-CN": "\u65f6\u5149\u6279\u51c6\u3002\u65f6\u95f4\u4e0d\u7b49\u4efb\u4f55\u4eba\u3002",
        },
        "ForceSellShrineUpgrade": {
            "fr": "Douanes Infernales. Vous devez abandonner l'un de vos Bienfaits pour passer entre chaque r\u00e9gion des Enfers.",
            "de": "Unterweltzoll. Du musst einen deiner Segen aufgeben, um zwischen den Regionen der Unterwelt zu wechseln.",
            "es": "Aduanas del Inframundo. Debes entregar una de tus Bendiciones para pasar entre cada regi\u00f3n del inframundo.",
            "it": "Dogana Infernale. Devi cedere una delle tue Benedizioni per passare tra ogni regione degli inferi.",
            "pt-BR": "Alf\u00e2ndega do Submundo. Voc\u00ea deve entregar uma de suas B\u00ean\u00e7\u00e3os para passar entre cada regi\u00e3o do submundo.",
            "ru": "\u0422\u0430\u043c\u043e\u0436\u043d\u044f \u043f\u043e\u0434\u0437\u0435\u043c\u043d\u043e\u0433\u043e \u043c\u0438\u0440\u0430. \u0412\u044b \u0434\u043e\u043b\u0436\u043d\u044b \u043e\u0442\u0434\u0430\u0442\u044c \u043e\u0434\u043d\u043e \u0438\u0437 \u0441\u0432\u043e\u0438\u0445 \u0411\u043b\u0430\u0433\u043e\u0441\u043b\u043e\u0432\u0435\u043d\u0438\u0439, \u0447\u0442\u043e\u0431\u044b \u043f\u0435\u0440\u0435\u0439\u0442\u0438 \u043c\u0435\u0436\u0434\u0443 \u0440\u0435\u0433\u0438\u043e\u043d\u0430\u043c\u0438.",
            "pl": "C\u0142o Podziemi. Musisz odda\u0107 jedno ze swoich B\u0142ogos\u0142awie\u0144stw, aby przej\u015b\u0107 mi\u0119dzy regionami.",
            "ja": "\u51a5\u5e9c\u306e\u7a0e\u95a2\u3002\u5404\u5730\u57df\u3092\u901a\u904e\u3059\u308b\u306b\u306f\u3001\u52a0\u8b77\u306e\u4e00\u3064\u3092\u653e\u68c4\u3057\u306a\u3051\u308c\u3070\u306a\u3089\u306a\u3044\u3002",
            "ko": "\uc9c0\ud558 \uc138\uad00. \uac01 \uc9c0\uc5ed\uc744 \ud1b5\uacfc\ud558\ub824\uba74 \ucd95\ubcf5 \ud558\ub098\ub97c \ud3ec\uae30\ud574\uc57c \ud55c\ub2e4.",
            "zh-CN": "\u51a5\u5e9c\u6d77\u5173\u3002\u4f60\u5fc5\u987b\u653e\u5f03\u4e00\u4e2a\u795d\u798f\u624d\u80fd\u901a\u8fc7\u6bcf\u4e2a\u5730\u533a\u3002",
        },
        "MetaUpgradeStrikeThroughShrineUpgrade": {
            "fr": "Inspection de Routine. Vos talents du Miroir de la Nuit sont syst\u00e9matiquement d\u00e9sactiv\u00e9s, un par un.",
            "de": "Routineinspektion. Deine Talente des Spiegels der Nacht werden systematisch deaktiviert, eines nach dem anderen.",
            "es": "Inspecci\u00f3n Rutinaria. Tus talentos del Espejo de la Noche se desactivan sistem\u00e1ticamente, uno por uno.",
            "it": "Ispezione di Routine. I tuoi talenti dello Specchio della Notte vengono sistematicamente disattivati, uno per uno.",
            "pt-BR": "Inspe\u00e7\u00e3o de Rotina. Seus talentos do Espelho da Noite s\u00e3o sistematicamente desativados, um por um.",
            "ru": "\u041f\u043b\u0430\u043d\u043e\u0432\u0430\u044f \u043f\u0440\u043e\u0432\u0435\u0440\u043a\u0430. \u0412\u0430\u0448\u0438 \u0442\u0430\u043b\u0430\u043d\u0442\u044b \u0417\u0435\u0440\u043a\u0430\u043b\u0430 \u041d\u043e\u0447\u0438 \u0441\u0438\u0441\u0442\u0435\u043c\u0430\u0442\u0438\u0447\u0435\u0441\u043a\u0438 \u043e\u0442\u043a\u043b\u044e\u0447\u0430\u044e\u0442\u0441\u044f, \u043e\u0434\u0438\u043d \u0437\u0430 \u0434\u0440\u0443\u0433\u0438\u043c.",
            "pl": "Rutynowa Inspekcja. Twoje talenty Zwierciad\u0142a Nocy s\u0105 systematycznie wy\u0142\u0105czane, jeden po drugim.",
            "ja": "\u5b9a\u671f\u691c\u67fb\u3002\u591c\u306e\u93e1\u306e\u624d\u80fd\u304c\u4e00\u3064\u305a\u3064\u7121\u52b9\u5316\u3055\u308c\u308b\u3002",
            "ko": "\uc815\uae30 \uac80\uc0ac. \ubc24\uc758 \uac70\uc6b8 \uc7ac\ub2a5\uc774 \ud558\ub098\uc529 \uccb4\uacc4\uc801\uc73c\ub85c \ube44\ud65c\uc131\ud654\ub41c\ub2e4.",
            "zh-CN": "\u4f8b\u884c\u68c0\u67e5\u3002\u4f60\u7684\u591c\u4e4b\u955c\u5929\u8d4b\u4f1a\u88ab\u9010\u4e00\u7981\u7528\u3002",
        },
        "EnemyShieldShrineUpgrade": {
            "fr": "Contr\u00f4le des D\u00e9g\u00e2ts. Chaque ennemi porte un bouclier protecteur qui absorbe le premier coup re\u00e7u.",
            "de": "Schadenskontrolle. Jeder Feind tr\u00e4gt einen Schutzschild, der den ersten Treffer absorbiert.",
            "es": "Control de Da\u00f1os. Cada enemigo lleva un escudo protector que absorbe el primer golpe recibido.",
            "it": "Controllo Danni. Ogni nemico porta uno scudo protettivo che assorbe il primo colpo ricevuto.",
            "pt-BR": "Controle de Danos. Cada inimigo carrega um escudo protetor que absorve o primeiro golpe recebido.",
            "ru": "\u041a\u043e\u043d\u0442\u0440\u043e\u043b\u044c \u0443\u0440\u043e\u043d\u0430. \u041a\u0430\u0436\u0434\u044b\u0439 \u0432\u0440\u0430\u0433 \u043d\u0435\u0441\u0451\u0442 \u0437\u0430\u0449\u0438\u0442\u043d\u044b\u0439 \u0449\u0438\u0442, \u043f\u043e\u0433\u043b\u043e\u0449\u0430\u044e\u0449\u0438\u0439 \u043f\u0435\u0440\u0432\u044b\u0439 \u043f\u043e\u043b\u0443\u0447\u0435\u043d\u043d\u044b\u0439 \u0443\u0434\u0430\u0440.",
            "pl": "Kontrola Obra\u017ce\u0144. Ka\u017cdy wr\u00f3g nosi tarcz\u0119 ochronn\u0105, kt\u00f3ra poch\u0142ania pierwszy otrzymany cios.",
            "ja": "\u30c0\u30e1\u30fc\u30b8\u30b3\u30f3\u30c8\u30ed\u30fc\u30eb\u3002\u5404\u6575\u306f\u6700\u521d\u306e\u4e00\u6483\u3092\u5438\u53ce\u3059\u308b\u4fdd\u8b77\u30b7\u30fc\u30eb\u30c9\u3092\u6301\u3064\u3002",
            "ko": "\ub370\ubbf8\uc9c0 \ucee8\ud2b8\ub864. \uac01 \uc801\uc740 \uccab \ubc88\uc9f8 \uacf5\uaca9\uc744 \ud761\uc218\ud558\ub294 \ubcf4\ud638 \ubc29\ud328\ub97c \uac00\uc9c0\uace0 \uc788\ub2e4.",
            "zh-CN": "\u4f24\u5bb3\u63a7\u5236\u3002\u6bcf\u4e2a\u654c\u4eba\u90fd\u643a\u5e26\u4e00\u4e2a\u80fd\u5438\u6536\u7b2c\u4e00\u6b21\u653b\u51fb\u7684\u4fdd\u62a4\u62a4\u76fe\u3002",
        },
    }
    return t


def _god_boon_descriptions():
    """GodBoonDescriptions — missing boon descriptions not in HelpText."""
    t = {
        "DionysusAoETrait": {
            "fr": "Vos effets de Gueule de Bois infligent des d\u00e9g\u00e2ts dans une zone autour des ennemis affect\u00e9s.",
            "de": "Deine Kater-Effekte verursachen Fl\u00e4chenschaden um betroffene Feinde.",
            "es": "Tus efectos de Resaca infligen da\u00f1o en \u00e1rea alrededor de los enemigos afectados.",
            "it": "I tuoi effetti Sbornia infliggono danni ad area intorno ai nemici colpiti.",
            "pt-BR": "Seus efeitos de Ressaca infligem dano em \u00e1rea ao redor dos inimigos afetados.",
            "ru": "\u042d\u0444\u0444\u0435\u043a\u0442\u044b \u041f\u043e\u0445\u043c\u0435\u043b\u044c\u044f \u043d\u0430\u043d\u043e\u0441\u044f\u0442 \u0443\u0440\u043e\u043d \u043f\u043e \u043e\u0431\u043b\u0430\u0441\u0442\u0438 \u0432\u043e\u043a\u0440\u0443\u0433 \u043f\u043e\u0440\u0430\u0436\u0451\u043d\u043d\u044b\u0445 \u0432\u0440\u0430\u0433\u043e\u0432.",
            "pl": "Twoje efekty Kaca zadaj\u0105 obra\u017cenia obszarowe wok\u00f3\u0142 dotkni\u0119tych wrog\u00f3w.",
            "ja": "\u4e8c\u65e5\u9154\u3044\u52b9\u679c\u304c\u5f71\u97ff\u3092\u53d7\u3051\u305f\u6575\u306e\u5468\u56f2\u306b\u7bc4\u56f2\u30c0\u30e1\u30fc\u30b8\u3092\u4e0e\u3048\u308b\u3002",
            "ko": "\uc219\ucde8 \ud6a8\uacfc\uac00 \uc601\ud5a5\ubc1b\uc740 \uc801 \uc8fc\ubcc0\uc5d0 \ubc94\uc704 \ud53c\ud574\ub97c \uc785\ud788\ub2e4.",
            "zh-CN": "\u4f60\u7684\u5bbf\u9189\u6548\u679c\u5bf9\u53d7\u5f71\u54cd\u7684\u654c\u4eba\u5468\u56f4\u9020\u6210\u8303\u56f4\u4f24\u5bb3\u3002",
        },
        "HarvestBoonDrop": {
            "fr": "La b\u00e9n\u00e9diction du Chaos vous octroie un don du Chaos.",
            "de": "Der Segen des Chaos gew\u00e4hrt dir eine Gabe des Chaos.",
            "es": "La bendici\u00f3n del Caos te otorga un don del Caos.",
            "it": "La benedizione del Caos ti concede un dono del Caos.",
            "pt-BR": "A b\u00ean\u00e7\u00e3o do Caos concede a voc\u00ea um dom do Caos.",
            "ru": "\u0411\u043b\u0430\u0433\u043e\u0441\u043b\u043e\u0432\u0435\u043d\u0438\u0435 \u0425\u0430\u043e\u0441\u0430 \u0434\u0430\u0440\u0443\u0435\u0442 \u0434\u0430\u0440 \u0425\u0430\u043e\u0441\u0430.",
            "pl": "B\u0142ogos\u0142awie\u0144stwo Chaosu obdarza ci\u0119 darem Chaosu.",
            "ja": "\u30ab\u30aa\u30b9\u306e\u795d\u798f\u304c\u30ab\u30aa\u30b9\u306e\u8d08\u308a\u7269\u3092\u4e0e\u3048\u308b\u3002",
            "ko": "\uce74\uc624\uc2a4\uc758 \ucd95\ubcf5\uc774 \uce74\uc624\uc2a4\uc758 \uc120\ubb3c\uc744 \uc900\ub2e4.",
            "zh-CN": "\u6df7\u6c8c\u7684\u795d\u798f\u8d60\u4e88\u4f60\u6df7\u6c8c\u4e4b\u793c\u3002",
        },
    }
    return t


def _contractor_item_names():
    """ContractorItemNames — music track entries for House Contractor.
    Music titles are generally kept as English across all languages."""
    t = {
        "MusicExploration1_MC": {
            "fr": "Out of Tartarus", "de": "Out of Tartarus", "es": "Out of Tartarus",
            "it": "Out of Tartarus", "pt-BR": "Out of Tartarus",
            "ru": "Out of Tartarus", "pl": "Out of Tartarus",
            "ja": "Out of Tartarus", "ko": "Out of Tartarus", "zh-CN": "Out of Tartarus",
        },
        "MusicExploration2_MC": {
            "fr": "Scourge of the Furies", "de": "Scourge of the Furies", "es": "Scourge of the Furies",
            "it": "Scourge of the Furies", "pt-BR": "Scourge of the Furies",
            "ru": "Scourge of the Furies", "pl": "Scourge of the Furies",
            "ja": "Scourge of the Furies", "ko": "Scourge of the Furies", "zh-CN": "Scourge of the Furies",
        },
        "MusicExploration3_MC": {
            "fr": "Wretched Shades", "de": "Wretched Shades", "es": "Wretched Shades",
            "it": "Wretched Shades", "pt-BR": "Wretched Shades",
            "ru": "Wretched Shades", "pl": "Wretched Shades",
            "ja": "Wretched Shades", "ko": "Wretched Shades", "zh-CN": "Wretched Shades",
        },
        "MusicExploration4_MC": {
            "fr": "The Painful Way", "de": "The Painful Way", "es": "The Painful Way",
            "it": "The Painful Way", "pt-BR": "The Painful Way",
            "ru": "The Painful Way", "pl": "The Painful Way",
            "ja": "The Painful Way", "ko": "The Painful Way", "zh-CN": "The Painful Way",
        },
        "MusicExploration5_MC": {
            "fr": "Through Asphodel", "de": "Through Asphodel", "es": "Through Asphodel",
            "it": "Through Asphodel", "pt-BR": "Through Asphodel",
            "ru": "Through Asphodel", "pl": "Through Asphodel",
            "ja": "Through Asphodel", "ko": "Through Asphodel", "zh-CN": "Through Asphodel",
        },
        "MusicExplorationMiniBoss_MC": {
            "fr": "Bone-Hydra", "de": "Bone-Hydra", "es": "Bone-Hydra",
            "it": "Bone-Hydra", "pt-BR": "Bone-Hydra",
            "ru": "Bone-Hydra", "pl": "Bone-Hydra",
            "ja": "Bone-Hydra", "ko": "Bone-Hydra", "zh-CN": "Bone-Hydra",
        },
        "MusicExploration6_MC": {
            "fr": "The King and the Bull", "de": "The King and the Bull", "es": "The King and the Bull",
            "it": "The King and the Bull", "pt-BR": "The King and the Bull",
            "ru": "The King and the Bull", "pl": "The King and the Bull",
            "ja": "The King and the Bull", "ko": "The King and the Bull", "zh-CN": "The King and the Bull",
        },
        "MusicExploration7_MC": {
            "fr": "Elysium", "de": "Elysium", "es": "Elysium",
            "it": "Elysium", "pt-BR": "Elysium",
            "ru": "Elysium", "pl": "Elysium",
            "ja": "Elysium", "ko": "Elysium", "zh-CN": "Elysium",
        },
        "MusicExploration8_MC": {
            "fr": "Your Sentence", "de": "Your Sentence", "es": "Your Sentence",
            "it": "Your Sentence", "pt-BR": "Your Sentence",
            "ru": "Your Sentence", "pl": "Your Sentence",
            "ja": "Your Sentence", "ko": "Your Sentence", "zh-CN": "Your Sentence",
        },
        "MusicExploration9_MC": {
            "fr": "Death and I", "de": "Death and I", "es": "Death and I",
            "it": "Death and I", "pt-BR": "Death and I",
            "ru": "Death and I", "pl": "Death and I",
            "ja": "Death and I", "ko": "Death and I", "zh-CN": "Death and I",
        },
        "MusicExploration10_MC": {
            "fr": "Final Expense", "de": "Final Expense", "es": "Final Expense",
            "it": "Final Expense", "pt-BR": "Final Expense",
            "ru": "Final Expense", "pl": "Final Expense",
            "ja": "Final Expense", "ko": "Final Expense", "zh-CN": "Final Expense",
        },
        "MusicFinalBoss1_MC": {
            "fr": "God of the Dead", "de": "God of the Dead", "es": "God of the Dead",
            "it": "God of the Dead", "pt-BR": "God of the Dead",
            "ru": "God of the Dead", "pl": "God of the Dead",
            "ja": "God of the Dead", "ko": "God of the Dead", "zh-CN": "God of the Dead",
        },
        "MusicCharonFight_MC": {
            "fr": "Wretched Broker", "de": "Wretched Broker", "es": "Wretched Broker",
            "it": "Wretched Broker", "pt-BR": "Wretched Broker",
            "ru": "Wretched Broker", "pl": "Wretched Broker",
            "ja": "Wretched Broker", "ko": "Wretched Broker", "zh-CN": "Wretched Broker",
        },
        "MusicMouseTrapSting": {
            "fr": "Hymn to Zagreus", "de": "Hymn to Zagreus", "es": "Hymn to Zagreus",
            "it": "Hymn to Zagreus", "pt-BR": "Hymn to Zagreus",
            "ru": "Hymn to Zagreus", "pl": "Hymn to Zagreus",
            "ja": "Hymn to Zagreus", "ko": "Hymn to Zagreus", "zh-CN": "Hymn to Zagreus",
        },
        "MusicOrpheusAndEurydice_MC": {
            "fr": "In the Blood", "de": "In the Blood", "es": "In the Blood",
            "it": "In the Blood", "pt-BR": "In the Blood",
            "ru": "In the Blood", "pl": "In the Blood",
            "ja": "In the Blood", "ko": "In the Blood", "zh-CN": "In the Blood",
        },
        "MusicHomeGuitar_MC": {
            "fr": "Lament of Orpheus", "de": "Lament of Orpheus", "es": "Lament of Orpheus",
            "it": "Lament of Orpheus", "pt-BR": "Lament of Orpheus",
            "ru": "Lament of Orpheus", "pl": "Lament of Orpheus",
            "ja": "Lament of Orpheus", "ko": "Lament of Orpheus", "zh-CN": "Lament of Orpheus",
        },
        "MusicOrpheusAndEurydiceIntro_MC": {
            "fr": "Good Riddance", "de": "Good Riddance", "es": "Good Riddance",
            "it": "Good Riddance", "pt-BR": "Good Riddance",
            "ru": "Good Riddance", "pl": "Good Riddance",
            "ja": "Good Riddance", "ko": "Good Riddance", "zh-CN": "Good Riddance",
        },
        "MusicGuitarEurydice_MC": {
            "fr": "Good Riddance (Eurydice)", "de": "Good Riddance (Eurydice)", "es": "Good Riddance (Eurydice)",
            "it": "Good Riddance (Eurydice)", "pt-BR": "Good Riddance (Eurydice)",
            "ru": "Good Riddance (Eurydice)", "pl": "Good Riddance (Eurydice)",
            "ja": "Good Riddance (Eurydice)", "ko": "Good Riddance (Eurydice)", "zh-CN": "Good Riddance (Eurydice)",
        },
        "MusicGuitarOrpheus_MC": {
            "fr": "Good Riddance (Orpheus)", "de": "Good Riddance (Orpheus)", "es": "Good Riddance (Orpheus)",
            "it": "Good Riddance (Orpheus)", "pt-BR": "Good Riddance (Orpheus)",
            "ru": "Good Riddance (Orpheus)", "pl": "Good Riddance (Orpheus)",
            "ja": "Good Riddance (Orpheus)", "ko": "Good Riddance (Orpheus)", "zh-CN": "Good Riddance (Orpheus)",
        },
        "MusicHome_MC": {
            "fr": "House of Hades", "de": "House of Hades", "es": "House of Hades",
            "it": "House of Hades", "pt-BR": "House of Hades",
            "ru": "House of Hades", "pl": "House of Hades",
            "ja": "House of Hades", "ko": "House of Hades", "zh-CN": "House of Hades",
        },
        "MusicHome2_MC": {
            "fr": "No Escape", "de": "No Escape", "es": "No Escape",
            "it": "No Escape", "pt-BR": "No Escape",
            "ru": "No Escape", "pl": "No Escape",
            "ja": "No Escape", "ko": "No Escape", "zh-CN": "No Escape",
        },
        "MusicCredits_MC": {
            "fr": "On the Coast", "de": "On the Coast", "es": "On the Coast",
            "it": "On the Coast", "pt-BR": "On the Coast",
            "ru": "On the Coast", "pl": "On the Coast",
            "ja": "On the Coast", "ko": "On the Coast", "zh-CN": "On the Coast",
        },
        "MusicExploration1GuitarOnly_MC": {
            "fr": "Mouth of Styx", "de": "Mouth of Styx", "es": "Mouth of Styx",
            "it": "Mouth of Styx", "pt-BR": "Mouth of Styx",
            "ru": "Mouth of Styx", "pl": "Mouth of Styx",
            "ja": "Mouth of Styx", "ko": "Mouth of Styx", "zh-CN": "Mouth of Styx",
        },
        "MusicExplorationTheseus_MC": {
            "fr": "The Exalted", "de": "The Exalted", "es": "The Exalted",
            "it": "The Exalted", "pt-BR": "The Exalted",
            "ru": "The Exalted", "pl": "The Exalted",
            "ja": "The Exalted", "ko": "The Exalted", "zh-CN": "The Exalted",
        },
        "MusicFinalBoss2_MC": {
            "fr": "In the Blood (Instrumental)", "de": "In the Blood (Instrumental)", "es": "In the Blood (Instrumental)",
            "it": "In the Blood (Instrumental)", "pt-BR": "In the Blood (Instrumental)",
            "ru": "In the Blood (Instrumental)", "pl": "In the Blood (Instrumental)",
            "ja": "In the Blood (Instrumental)", "ko": "In the Blood (Instrumental)", "zh-CN": "In the Blood (Instrumental)",
        },
        "MusicGuitarSurface_MC": {
            "fr": "Good Riddance (Hades)", "de": "Good Riddance (Hades)", "es": "Good Riddance (Hades)",
            "it": "Good Riddance (Hades)", "pt-BR": "Good Riddance (Hades)",
            "ru": "Good Riddance (Hades)", "pl": "Good Riddance (Hades)",
            "ja": "Good Riddance (Hades)", "ko": "Good Riddance (Hades)", "zh-CN": "Good Riddance (Hades)",
        },
        "MusicCredits2_MC": {
            "fr": "One Last Song", "de": "One Last Song", "es": "One Last Song",
            "it": "One Last Song", "pt-BR": "One Last Song",
            "ru": "One Last Song", "pl": "One Last Song",
            "ja": "One Last Song", "ko": "One Last Song", "zh-CN": "One Last Song",
        },
        "MusicGuitarOrpheusAndEurydice_MC": {
            "fr": "Good Riddance (Orpheus & Eurydice)", "de": "Good Riddance (Orpheus & Eurydice)", "es": "Good Riddance (Orpheus & Eurydice)",
            "it": "Good Riddance (Orpheus & Eurydice)", "pt-BR": "Good Riddance (Orpheus & Eurydice)",
            "ru": "Good Riddance (Orpheus & Eurydice)", "pl": "Good Riddance (Orpheus & Eurydice)",
            "ja": "Good Riddance (Orpheus & Eurydice)", "ko": "Good Riddance (Orpheus & Eurydice)", "zh-CN": "Good Riddance (Orpheus & Eurydice)",
        },
    }
    return t


def _keepsake_gift_names():
    """KeepsakeGiftNames — keepsake names for gift notifications + NPC names for gift sources."""
    key_to_name = {
        "ZeusKeepsake": "Thunder Signet", "PoseidonKeepsake": "Conch Shell",
        "AthenaKeepsake": "Owl Pendant", "AresKeepsake": "Blood-Filled Vial",
        "AphroditeKeepsake": "Eternal Rose", "ArtemisKeepsake": "Adamant Arrowhead",
        "DionysusKeepsake": "Overflowing Cup", "HermesKeepsake": "Lambent Plume",
        "DemeterKeepsake": "Frostbitten Horn", "ChaosKeepsake": "Cosmic Egg",
        "MaxHealthKeepsakeTrait": "Old Spiked Collar", "DirectionalArmorTrait": "Broken Spearpoint",
        "ReincarnationTrait": "Lucky Tooth",
        "CerberusKeepsake": "Old Spiked Collar", "AchillesKeepsake": "Myrmidon Bracer",
        "NyxKeepsake": "Black Shawl", "ThanatosKeepsake": "Pierced Butterfly",
        "ChronKeepsake": "Bone Hourglass", "HypnosKeepsake": "Chthonic Coin Purse",
        "MegKeepsake": "Skull Earring", "OrpheusKeepsake": "Distant Memory",
        "DusaKeepsake": "Harpy Feather Duster", "SkellyKeepsake": "Lucky Tooth",
        "SisyphusKeepsake": "Shattered Shackle", "EurydiceKeepsake": "Evergreen Acorn",
        "PatroclusKeepsake": "Broken Spearpoint", "HadesKeepsake": "Sigil of the Dead",
        "FurySummonTrait": "Battie", "AntosSummonTrait": "Rib",
        "NpcSummonTrait_Thanatos": "Mort", "NpcSummonTrait_Sisyphus": "Shady",
        "NpcSummonTrait_Achilles": "Antos", "NpcSummonTrait_Dusa": "Fidi",
    }
    t = {}
    for key, name in key_to_name.items():
        if name in _KEEPSAKE_NAMES:
            t[key] = _KEEPSAKE_NAMES[name]

    # NPC name entries used as gift sources in "New Keepsake from [NPC]" notifications
    _npc_names = {
        "Achilles": {"ru": "\u0410\u0445\u0438\u043b\u043b\u0435\u0441", "ja": "\u30a2\u30ad\u30ec\u30a6\u30b9", "ko": "\uc544\ud0ac\ub808\uc6b0\uc2a4", "zh-CN": "\u963f\u5580\u7409\u65af"},
        "Megaera": {"ru": "\u041c\u0435\u0433\u0435\u0440\u0430", "ja": "\u30e1\u30ac\u30a4\u30e9", "ko": "\uba54\uac00\uc774\ub77c", "zh-CN": "\u58a8\u76d6\u62c9"},
        "Theseus": {"fr": "Th\u00e9s\u00e9e", "es": "Teseo", "it": "Teseo", "pt-BR": "Teseu", "ru": "\u0422\u0435\u0441\u0435\u0439", "pl": "Tezeusz", "ja": "\u30c6\u30fc\u30bb\u30a6\u30b9", "ko": "\ud14c\uc138\uc6b0\uc2a4", "zh-CN": "\u5fce\u4fee\u65af"},
        "Asterius": {"ru": "\u0410\u0441\u0442\u0435\u0440\u0438\u043e\u0441", "ja": "\u30a2\u30b9\u30c6\u30ea\u30aa\u30b9", "ko": "\uc544\uc2a4\ud14c\ub9ac\uc624\uc2a4", "zh-CN": "\u963f\u65af\u5fce\u91cc\u4fc4\u65af"},
        "Chaos": {"ru": "\u0425\u0430\u043e\u0441", "ja": "\u30ab\u30aa\u30b9", "ko": "\uce74\uc624\uc2a4", "zh-CN": "\u6df7\u6c8c"},
    }
    npc_key_to_name = {
        "NPC_Achilles_Story_01": "Achilles",
        "NPC_Megaera_01": "Megaera",
        "NPC_Theseus_01": "Theseus",
        "NPC_Asterius_01": "Asterius",
        "Asterius": "Asterius",
        "Chaos": "Chaos",
    }
    for key, name in npc_key_to_name.items():
        if name in _npc_names:
            t[key] = _npc_names[name]

    return t


# ============================================================
# Main: Generate JSON files
# ============================================================
def _extract_lang(table_data, lang):
    """Extract entries for a specific language from a table_data dict."""
    result = {}
    for key, translations in table_data.items():
        if lang in translations:
            result[key] = translations[lang]
    return result


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Build all translation tables
    tables = {
        "UIStrings": _ui(),
        "ResourceDisplayNames": _resource_display_names(),
        "ChoiceDisplayNames": _choice_display_names(),
        "SlotDescriptions": _slot_descriptions(),
        "DuoBoonGods": _duo_boon_gods(),
        "NPCDisplayNames": _npc_display_names(),
        "KeepsakeDisplayNames": _keepsake_display_names(),
        "KeepsakeGiftNames": _keepsake_gift_names(),
        "ObjectiveDescriptions": _objective_descriptions(),
        "GodFlavorText": _god_flavor_text(),
        "MirrorFlavorText": _mirror_flavor_text(),
        "PactFlavorText": _pact_flavor_text(),
        "GodBoonDescriptions": _god_boon_descriptions(),
        "ContractorItemNames": _contractor_item_names(),
    }

    langs = ["de", "es", "fr", "it", "ja", "ko", "pl", "pt-BR", "ru", "zh-CN"]

    for lang in langs:
        data = {}
        for table_name, table_data in tables.items():
            entries = _extract_lang(table_data, lang)
            if entries:
                data[table_name] = entries

        # Write JSON
        output_path = os.path.join(OUTPUT_DIR, f"{lang}.json")
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        total = sum(len(v) for v in data.values())
        print(f"  {lang}.json: {total} entries ({len(data)} tables)")

    print(f"\nGenerated {len(langs)} translation files in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
