import re
from copy import deepcopy
from collections import Counter
from unidecode import unidecode
from difflib import get_close_matches, SequenceMatcher


def word_intersection(small: str, big: str,
                      ordered=False, approximate=True, stop_symbols=".-,+'?;()–"):
    # ----------------------------------------------------------------
    # REMOVE STOP SYMBOLS
    # ----------------------------------------------------------------
    if stop_symbols:
        trans = str.maketrans({char: None for char in stop_symbols.replace(' ', '')})
        small = process_input(small, stop_symbols_string=stop_symbols, trans=trans)
        big = process_input(big, stop_symbols_string=stop_symbols, trans=trans)

    # ----------------------------------------------------------------
    # TOKENIZING
    # ----------------------------------------------------------------
    smaller_set = list(filter(None, small.split(sep=' ')))
    bigger_set = list(filter(None, big.split(sep=' ')))

    # ---------------------------------------------------------------
    # FIND INTERSECTION REGARDLESS OF THE ORDER OF THE INPUT TOKENS
    # ----------------------------------------------------------------
    if ordered is False:
        found = Counter()
        smaller_c = Counter(smaller_set)
        bigger_c = Counter(bigger_set)

        # BASIC
        if approximate is False:
            for data in set(smaller_set) & set(bigger_set):
                diff = smaller_c[data] - bigger_c[data]
                found[data] = smaller_c[data] if diff < 0 else bigger_c[data]

            normalised = sum(found.values()) / float(sum(smaller_c.values()))

        # APPROXIMATION
        else:
            approximation = 0
            src_counter = dict(smaller_c)
            trg_counter = dict(bigger_c)
            candidates, ratios, results = {}, {}, {}
            intersection = []

            # FOR EACH TOKEN
            for key in src_counter:
                # 1. GET THE LIST OF CANDIDATES
                candidates[key] = get_close_matches(key, list(trg_counter.keys()))

                # 2. IF LIST, THEN GET THE RATIO OF THE FIRST CANDIDATE
                if candidates[key]:
                    ratios[key] = SequenceMatcher(None, key, candidates[key][0]).ratio()

            while True:
                if ratios:
                    t = max(ratios, key=ratios.get)
                    matched = candidates[t][0]
                    if trg_counter[matched] > 0:
                        if t in results:
                            results[t] += [(matched, ratios[t])]
                        else:
                            results[t] = [(matched, ratios[t])]

                        intersection.append(matched)
                        approximation += ratios[t]
                        trg_counter[matched] -= 1
                        src_counter[t] -= 1

                    if src_counter[t] == 0:
                        del ratios[t]
                    else:
                        if len(candidates[t]) == 1:
                            del candidates[t]
                            del ratios[t]
                        else:
                            candidates[t] = candidates[t][1:]
                            ratios[t] = SequenceMatcher(None, t, candidates[t][0]).ratio()

                    if len(ratios) == 0 or len(candidates) == 0:
                        break
                else:
                    break

            tokens = len(smaller_set)
            normalised = approximation / tokens

        return normalised

    # ----------------------------------------------------------------
    # FIND INTERSECTION WHILE KEEPING THE ORDER OF THE INPUT TOKENS.
    # When it is in order, if the matched word is at position x, the
    # code expects the next word tyo be at position x+1 if not, no
    # then point of continuing
    # ----------------------------------------------------------------
    else:
        intersection = []

        # BASIC
        if approximate is False:
            index = -1
            for token in smaller_set:
                if token in bigger_set[index + 1:]:
                    new_idx = bigger_set[index + 1:].index(token)
                    index = new_idx
                    intersection.append(token)
                else:
                    break

            strength = len(intersection) / float(len(smaller_set))

        # APPROXIMATION
        else:
            candidates, results, ratios = {}, {}, {}
            tokens = len(smaller_set)

            for token in smaller_set:
                candidates[token] = get_close_matches(token, bigger_set)
                if candidates[token]:
                    ratios[token] = SequenceMatcher(None, token, candidates[token][0]).ratio()

            approximation = 0
            src_tokens = deepcopy(smaller_set)
            trg_tokens = deepcopy(bigger_set)

            while True:
                t = src_tokens[0]
                if len(candidates[t]) == 0:
                    del src_tokens[0]
                    continue

                idx_match = -1
                matched = ''
                for m in candidates[t]:
                    if m in trg_tokens:
                        matched = m
                        if t in results:
                            results[t] += [(matched, ratios[t])]
                        else:
                            results[t] = [(matched, ratios[t])]

                        intersection.append(matched)

                        approximation += ratios[t]

                        idx_match = trg_tokens.index(matched)
                        trg_tokens = trg_tokens[idx_match + 1:]
                        break

                if idx_match == -1:
                    candidates[t] = []
                else:
                    idx_match = candidates[t].index(matched)
                    candidates[t] = candidates[t][idx_match + 1:]
                    if len(candidates[t]) > 0:
                        ratios[t] = SequenceMatcher(None, t, candidates[t][0]).ratio()
                    else:
                        del ratios[t]

                del src_tokens[0]

                if len(src_tokens) == 0 or len(trg_tokens) == 0:
                    break

            strength = approximation / tokens

        return strength


def character_mapping(input_text):
    if type(input_text) is str:
        return unidecode(input_text)


def remove_info_in_bracket(text):
    temp = str(text)
    if temp:
        pattern = re.findall('( *\\(.*?\\) *)', temp, re.S)
        for component in pattern:
            if component.endswith(" ") and component.startswith(" "):
                temp = str(temp).replace(component, " ", 1)
            elif component.startswith(" ") is not True and component.endswith(" "):
                temp = str(temp).replace(component, "", 1)
            elif component.startswith(" ") is True and component.endswith(" ") is not True:
                temp = str(temp).replace(component, "", 1)
            else:
                temp = str(temp).replace(component, "", 1)

        temp = str(temp).strip()

    return temp


def process_input(text, stop_symbols_string, trans):
    # DIACRITIC CHARACTERS MAPPING
    string = character_mapping(text)

    # REMOVE DATA IN BRACKETS
    # REMOVE (....) FROM THE VALUE
    string = remove_info_in_bracket(string)

    # REMOVE SYMBOLS OR CHARACTER
    stop_s = stop_symbols_string.strip().replace("–", "\xe2\x80\x93").replace(" ", "")
    if stop_s is not None and len(stop_s) > 0:
        string = string.translate(trans)

    return string.strip()
