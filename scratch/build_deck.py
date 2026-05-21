import json
import os
import re
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def translate_rule_name(rule_name):
    # Map common English rule names to Portuguese
    translations = {
        "Middle consonant: ㄱ ㄷ ㅈ ㅂ between two voiced sounds (e.g. vowels)": 
            "Consoante média: ㄱ ㄷ ㅈ ㅂ entre dois sons sonoros (ex: vogais)",
        "ㅅ before /i/, /j/ sound or ㅟ": 
            "ㅅ antes do som /i/, /j/ ou ㅟ",
        "ㅈ, ㅉ, ㅊ before /j/ sound": 
            "ㅈ, ㅉ, ㅊ antes do som /j/",
        "ㅢ pronunciation": 
            "Pronúncia de ㅢ",
        "Liaison: Single Batchim": 
            "Ligação: Batchim Único",
        "Liaison: Tense Consonant Batchim": 
            "Ligação: Batchim de Consoante Tensa",
        "Liaison: Double Consonant Batchim": 
            "Ligação: Batchim de Consoante Dupla",
        "Liaison: ㅎ before ㅇ": 
            "Ligação: ㅎ antes de ㅇ",
        "Palatalisation: ㄷ이 becomes 지 if 이- only has grammatical meaning": 
            "Palatalização: ㄷ이 torna-se 지 se 이- tem apenas significado gramatical",
        "Palatalisation: ㅌ이 and 't-stops + 히' becomes 치 if 히- only has grammatical meaning": 
            "Palatalização: ㅌ이 e 't-stops + 히' tornam-se 치 se 히- tem apenas significado gramatical",
        "Final-initial pair ㄹㄹ": 
            "Par final-inicial ㄹㄹ",
        "Final-initial pair ㄴㄴ": 
            "Par final-inicial ㄴㄴ",
        "Nasalisation: k-stops + ㄴ become ㅇㄴ": 
            "Nasalização: k-stops + ㄴ tornam-se ㅇㄴ",
        "Nasalisation: k-stops + ㅁ become ㅇㅁ": 
            "Nasalização: k-stops + ㅁ tornam-se ㅇㅁ",
        "Nasalisation: t-stops + ㄴ become ㄴㄴ": 
            "Nasalização: t-stops + ㄴ tornam-se ㄴㄴ",
        "Nasalisation: t-stops + ㅁ become ㄴㅁ": 
            "Nasalização: t-stops + ㅁ tornam-se ㄴㅁ",
        "Nasalisation: p-stops + ㄴ becomes ㅁㄴ": 
            "Nasalização: p-stops + ㄴ torna-se ㅁㄴ",
        "Nasalisation: p-stops + ㅁ becomes ㅁㅁ": 
            "Nasalização: p-stops + ㅁ torna-se ㅁㅁ",
        "Aspiration: ㄱㅎ becomes ㅋ, ㅎㄱ becomes ㅋ": 
            "Aspiração: ㄱㅎ torna-se ㅋ, ㅎㄱ torna-se ㅋ",
        "Aspiration: t-stops + ㅎ becomes ㅌ but, t-stops + 히 becomes 치 if it involves palatalisation": 
            "Aspiração: t-stops + ㅎ torna-se ㅌ, mas t-stops + 히 torna-se 치 se envolver palatalização",
        "Aspiration: ㅂㅎ becomes ㅍ": 
            "Aspiração: ㅂㅎ torna-se ㅍ",
        "Aspiration: ㅎㅈ becomes ㅊ": 
            "Aspiração: ㅎㅈ torna-se ㅊ",
        "Aspiration: ㅎㅅ becomes ㅆ": 
            "Aspiração: ㅎㅅ torna-se ㅆ",
        "Final-initial pair ㅁㄹ becomes ㅁㄴ": 
            "Par final-inicial ㅁㄹ torna-se ㅁㄴ",
        "Final-initial pair ㅇㄹ becomes ㅇㄴ": 
            "Par final-inicial ㅇㄹ torna-se ㅇㄴ",
        "Final-initial pair ㄱㄹ becomes ㅇㄴ (can be divided as ㄱㄹ -> ㄱㄴ -> ㅇㄴ)": 
            "Par final-inicial ㄱㄹ torna-se ㅇㄴ",
        "Final-initial pair ㅂㄹ becomes ㅁㄴ (can be divided as ㅂㄹ -> ㅂㄴ -> ㅁㄴ)": 
            "Par final-inicial ㅂㄹ torna-se ㅁㄴ",
        "Final-initial pair ㄴㄹ becomes ㄹㄹ (except some words)": 
            "Par final-inicial ㄴㄹ torna-se ㄹㄹ (exceto algumas palavras)",
        "Final-initial pair ㄹㄴ becomes ㄹㄹ (except some words)": 
            "Par final-inicial ㄹㄴ torna-se ㄹㄹ (exceto algumas palavras)",
        "Tensing: ㄱ ㄷ ㅂ ㅅ ㅈ after ㄱ (ㄲㅋㄳㄺ) ㄷ (ㅅㅆㅈㅊㅌ) or ㅂ (ㅍㄼㄿㅄ)": 
            "Tensão: ㄱ ㄷ ㅂ ㅅ ㅈ após ㄱ (ㄲㅋㄳㄺ) ㄷ (ㅅㅆㅈㅊㅌ) ou ㅂ (ㅍㄼㄿㅄ)",
        "Tensing: Suffix initial ㄱ ㄷ ㅅ ㅈ after a verb stem final ㄴ(ㄵ) ㅁ(ㄻ) ㄼ ㄾ": 
            "Tensão: ㄱ ㄷ ㅅ ㅈ inicial de sufixo após ㄴ(ㄵ) ㅁ(ㄻ) ㄼ ㄾ final do radical do verbo",
        "Tensing: ㄱ ㄷ ㅂ ㅅ ㅈ after modifier ㄹ": 
            "Tensão: ㄱ ㄷ ㅂ ㅅ ㅈ após modificador ㄹ",
        "Tensing: Without a Rule": 
            "Tensão: Sem Regra Específica",
        "Liaison: Between Words Without /j/": 
            "Ligação: Entre Palavras sem /j/",
        "Liaison: Between Words With /j/": 
            "Ligação: Entre Palavras com /j/",
        "Liaison: Between Words With /j/, Final-initial pair ㄹㄴ": 
            "Ligação: Entre Palavras com /j/, Par final-inicial ㄹㄴ"
    }
    return translations.get(rule_name, rule_name)

def clean_html(text):
    if not text:
        return ""
    text = re.sub(r'<[^>]+>', ' ', text)
    text = text.replace('&nbsp;', ' ').replace('&#x27;', "'").replace('&quot;', '"')
    return ' '.join(text.split())

def main():
    # 1. Load existing deck
    existing_path = "decks/korean_hangul.json"
    print(f"Loading existing deck from {existing_path}...")
    with open(existing_path, "r", encoding="utf-8") as f:
        existing_data = json.load(f)
    
    # We want to keep KOR_001 to KOR_040 (21 vowels, 19 consonants)
    # The existing cards KOR_001 to KOR_040 match vowels and consonants perfectly.
    new_cards = []
    for card in existing_data["cards"]:
        card_id = card["id"]
        # extract numeric suffix
        num = int(card_id.split("_")[1])
        if num <= 40:
            new_cards.append(card)
            
    print(f"Preserved {len(new_cards)} vowels and consonants cards.")
    
    # 2. Load extracted notes
    notes_path = "scratch/extracted_notes.json"
    print(f"Loading extracted Anki notes from {notes_path}...")
    with open(notes_path, "r", encoding="utf-8") as f:
        notes = json.load(f)
        
    # Group notes by model type
    model_notes = {}
    for n in notes:
        m = n["model"]
        if m not in model_notes:
            model_notes[m] = []
        model_notes[m].append(n)
        
    consonant_finals = model_notes.get("soi.ko.c.ConsonantFinals", [])
    consonant_clusters = model_notes.get("soi.ko.d.ConsonantClusters", [])
    pronunciation_changes = model_notes.get("soi.ko.e.PronunciationChanges", [])
    
    # 3. Process Final Consonants (Batchim) (16 cards: KOR_041 to KOR_056)
    # We want the standard alphabetical order of these 16 notes.
    # Note that scratch/extracted_notes.json might already be in this order, but let's be safe and order them.
    # Order: ㄱ, ㄴ, ㄷ, ㄹ, ㅁ, ㅂ, ㅅ, ㅇ, ㅈ, ㅎ, ㅊ, ㅋ, ㅌ, ㅍ, ㄲ, ㅆ
    batchim_order = ["ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅎ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㄲ", "ㅆ"]
    ordered_finals = []
    for letter in batchim_order:
        found = [n for n in consonant_finals if n["fields"].get("krLetter") == letter]
        if found:
            ordered_finals.append(found[0])
            
    # Definitions translation dictionary for batchim examples
    defn_translations = {
        "price, striking": "preço",
        "I (casual) + topic particle": "eu (casual) + partícula de tópico",
        "immediately, soon": "imediatamente",
        "colour": "cor",
        "heart": "coração/mente",
        "rice": "arroz/refeição",
        "clothes": "roupas",
        "yup, yeah": "sim (informal)",
        "day, daytime, afternoon": "dia/tarde",
        "flower": "flor",
        "kitchen": "cozinha",
        "bottom": "baixo/fundo",
        "side": "lado",
        "outside": "fora",
        "existent": "existir/ter"
    }
    
    # Syllables/words for TTS queries for batchim
    batchim_tts = {
        "ㄱ": "가격",
        "ㄴ": "안",
        "ㄷ": "곧",
        "ㄹ": "색깔",
        "ㅁ": "마음",
        "ㅂ": "밥",
        "ㅅ": "옷",
        "ㅇ": "응",
        "ㅈ": "낮",
        "ㅎ": "낳",
        "ㅊ": "꽃",
        "ㅋ": "부엌",
        "ㅌ": "밑",
        "ㅍ": "옆",
        "ㄲ": "밖",
        "ㅆ": "있다"
    }

    card_idx = 41
    for note in ordered_finals:
        f = note["fields"]
        letter = f.get("krLetter")
        name = f.get("name")
        example = f.get("example", "").strip()
        en_defn = f.get("enDefn", "").strip()
        fin_rom_raw = f.get("finRom", "")
        
        # Primary final sound is prefix of finRom (before '/')
        answer = fin_rom_raw.split("/")[0].strip() if fin_rom_raw else "t"
        if letter == "ㅇ":
            answer = "ng"
            
        # Explanations
        if letter == "ㅎ":
            explanation = "In the final position (Batchim), 'ㅎ' (Hieut) is pronounced as a silent or 't' stop sound depending on what follows. It usually combines with other consonants to aspirate them."
            explanation_pt = "Na posição final (Batchim), 'ㅎ' (Hieut) é pronunciado como um som mudo ou de parada 't', dependendo do que segue. Geralmente se combina com outras consoantes para aspirá-las."
        else:
            explanation = f"In the final position (Batchim), '{letter}' ({name}) is pronounced as a '{answer}' stop sound."
            explanation_pt = f"Na posição final (Batchim), '{letter}' ({name}) é pronunciado como um som de parada '{answer}'."
            if example:
                pt_defn = defn_translations.get(en_defn, en_defn)
                explanation += f" Example: '{example}' ({en_defn})."
                explanation_pt += f" Exemplo: '{example}' ({pt_defn})."
                
        new_cards.append({
            "id": f"KOR_{card_idx:03d}",
            "question": f"{letter}\n(Batchim)",
            "answer": answer,
            "explanation": explanation,
            "explanation_pt": explanation_pt,
            "tts_query": batchim_tts.get(letter, letter)
        })
        card_idx += 1

    # 4. Process Consonant Clusters (11 cards: KOR_057 to KOR_067)
    cluster_order = ["ㄺ", "ㄵ", "ㄶ", "ㄼ", "ㅀ", "ㄻ", "ㅄ", "ㄳ", "ㄽ", "ㄾ", "ㄿ"]
    ordered_clusters = []
    for letter in cluster_order:
        found = [n for n in consonant_clusters if n["fields"].get("krLetter") == letter]
        if found:
            ordered_clusters.append(found[0])
            
    cluster_details = {
        "ㄺ": {"ans": "k", "ex": "닭", "en": "chicken", "pron": "독", "pt": "frango", "act_pron": "닥"},
        "ㄵ": {"ans": "n", "ex": "앉다", "en": "to sit", "pron": "안따", "pt": "sentar", "act_pron": "안따"},
        "ㄶ": {"ans": "n", "ex": "많다", "en": "to be many", "pron": "만타", "pt": "haver muito", "act_pron": "만타"},
        "ㄼ": {"ans": "l", "ex": "여덟", "en": "eight", "pron": "여덜", "pt": "oito", "act_pron": "여덜"},
        "ㅀ": {"ans": "l", "ex": "잃다", "en": "to lose", "pron": "일타", "pt": "perder", "act_pron": "일타"},
        "ㄻ": {"ans": "m", "ex": "삶", "en": "life", "pron": "삼", "pt": "vida", "act_pron": "삼"},
        "ㅄ": {"ans": "p", "ex": "값", "en": "price", "pron": "갑", "pt": "preço", "act_pron": "갑"},
        "ㄳ": {"ans": "k", "ex": "넋", "en": "soul", "pron": "넉", "pt": "alma", "act_pron": "넉"},
        "ㄽ": {"ans": "l", "ex": "외곬", "en": "single way", "pron": "외골", "pt": "caminho único", "act_pron": "외골"},
        "ㄾ": {"ans": "l", "ex": "핥다", "en": "to lick", "pron": "할따", "pt": "lamber", "act_pron": "할따"},
        "ㄿ": {"ans": "p", "ex": "읊다", "en": "to recite", "pron": "읖따", "pt": "recitar", "act_pron": "읖따"}
    }
    
    for note in ordered_clusters:
        f = note["fields"]
        letter = f.get("krLetter")
        details = cluster_details.get(letter)
        answer = details["ans"]
        ex = details["ex"]
        en = details["en"]
        pron = details["act_pron"]
        pt = details["pt"]
        
        explanation = f"Double final consonant (Cluster) '{letter}' is pronounced as '{answer}'. Example: '{ex}' ({en}) is pronounced as [{pron}]."
        explanation_pt = f"A consoante final dupla (Cluster) '{letter}' é pronunciada como '{answer}'. Exemplo: '{ex}' ({pt}) é pronunciado como [{pron}]."
        
        new_cards.append({
            "id": f"KOR_{card_idx:03d}",
            "question": f"{letter}\n(Cluster)",
            "answer": answer,
            "explanation": explanation,
            "explanation_pt": explanation_pt,
            "tts_query": ex
        })
        card_idx += 1

    # 5. Process Pronunciation Changes (36 cards: KOR_068 to KOR_103)
    for note in pronunciation_changes:
        f = note["fields"]
        rule_name = f.get("RuleName", "").strip()
        ex1 = f.get("ex1", "").strip()
        pron1 = f.get("pron1", "").strip()
        en1 = f.get("en1", "").strip()
        
        # Extract bracketed answer
        m = re.search(r'\[([^\]]+)\]', pron1)
        answer = f"[{m.group(1)}]" if m else ex1
        
        # Clean answer to remove things like tone markers or extra spaces if any, e.g. `[a̠ɡi]` is fine
        answer = answer.strip()
        
        # Compile examples
        examples_en = []
        examples_pt = []
        
        # Let's map definitions of common examples for translations
        word_translations = {
            "baby": "bebê",
            "where": "onde",
            "father": "pai",
            "at last, finally": "finalmente",
            "idiot": "idiota",
            "sea, ocean": "mar",
            "hour, time": "hora/tempo",
            "to rest, repose": "descansar",
            "shower, shower bath": "banho/chuveiro",
            "shirt": "camisa",
            "shopping": "compras",
            "supermarket, grocery store": "supermercado",
            "to have, hold": "ter/segurar",
            "chair, stool": "cadeira",
            "clothes": "roupas",
            "existent": "existente/ter",
            "chicken": "frango",
            "good": "bom",
            "sunrise": "nascer do sol",
            "together": "juntos",
            "to not know": "não saber",
            "to meet": "encontrar",
            "grade": "série/ano escolar",
            "broth": "caldo/sopa",
            "closing": "fechando",
            "wife of one's eldest son": "esposa do filho mais velho",
            "to thank": "agradecer",
            "duties": "deveres/tarefas",
            "North Korea": "Coreia do Norte",
            "the eldest brother": "o irmão mais velho",
            "admission to a school": "admissão escolar",
            "confirmation ending": "sufixo de confirmação",
            "do not": "não fazer",
            "shabby, ragged": "desgastado",
            "president": "presidente",
            "expo": "exposição",
            "rational": "racional",
            "Korean wave": "onda coreana (Hallyu)",
            "to lose": "perder",
            "hot": "quente",
            "wear": "calçar/vestir",
            "person to meet": "pessoa a encontrar",
            "Chinese characters": "caracteres chineses (Hanja)",
            "on a flower": "sobre uma flor",
            "cotton blanket": "cobertor de algodão",
            "field labour": "trabalho de campo"
        }
        
        for i in range(1, 7):
            ex_w = f.get(f"ex{i}", "").strip()
            pr_w = f.get(f"pron{i}", "").strip()
            en_w = f.get(f"en{i}", "").strip()
            
            if ex_w:
                # Clean up pronunciation value
                pr_w_cleaned = clean_html(pr_w)
                
                # Check translation
                pt_w = word_translations.get(en_w, en_w)
                # Some en_w might contain extra details, clean them
                for k, v in word_translations.items():
                    if k in en_w.lower():
                        pt_w = v
                        break
                
                examples_en.append(f"- {ex_w} ({en_w}) -> {pr_w_cleaned}")
                examples_pt.append(f"- {ex_w} ({pt_w}) -> {pr_w_cleaned}")
                
        rule_name_pt = translate_rule_name(rule_name)
        
        explanation = f"Rule: {rule_name}\n\nExamples:\n" + "\n".join(examples_en)
        explanation_pt = f"Regra: {rule_name_pt}\n\nExemplos:\n" + "\n".join(examples_pt)
        
        new_cards.append({
            "id": f"KOR_{card_idx:03d}",
            "question": f"{rule_name}\n(e.g., {ex1})",
            "answer": answer,
            "explanation": explanation,
            "explanation_pt": explanation_pt,
            "tts_query": ex1
        })
        card_idx += 1

    # 6. Verify count and save
    print(f"Total cards generated: {len(new_cards)}")
    assert len(new_cards) == 103, f"Expected 103 cards, but got {len(new_cards)}"
    
    existing_data["cards"] = new_cards
    
    print(f"Saving updated deck to {existing_path}...")
    with open(existing_path, "w", encoding="utf-8") as f:
        json.dump(existing_data, f, indent=4, ensure_ascii=False)
        
    print("SUCCESS: Unified deck generated successfully!")

if __name__ == "__main__":
    main()
