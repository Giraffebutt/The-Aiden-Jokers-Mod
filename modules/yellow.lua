local CORRUPT_SUIT = 'yellowaiden_Corrupt'
local CORRUPT_CARD_PREFIX = 'Y'
local STATIC_SOUND = 'yellowaiden_static'
local STATIC_SOUND_DURATION = 2.45
local CORRUPT_MAX_ROLL = 100
local DEFAULT_MUTATION_ODDS = 2
local MUTATION_GUARANTEE_BLINDS = 2
local YELLOW_AIDEN_JOKER_KEY = 'j_yellowaiden_yellow_aiden'
local TV_NOISE_SHADER = 'yellowaiden_tv_noise'
local TV_NOISE_BLINK_RATE = 10
local TV_NOISE_ALPHA = 0.65

local registered_sounds = {}

local function sound_file_exists(filename)
    if not (NFS and NFS.getInfo and SMODS and SMODS.current_mod and SMODS.current_mod.path) then
        return false
    end

    return NFS.getInfo(SMODS.current_mod.path .. 'assets/sounds/' .. filename) ~= nil
end

local function register_sound(key, filename)
    if sound_file_exists(filename) then
        SMODS.Sound {
            key = 'yellowaiden_' .. key,
            path = filename,
            prefix_config = { key = false }
        }
        registered_sounds['yellowaiden_' .. key] = true
    end
end

local function play_registered_sound(sound_key, pitch, volume)
    if registered_sounds[sound_key] then
        play_sound(sound_key, pitch or 1, volume or 0.7)
    end
end

local function yellowaiden_log(message)
    if sendInfoMessage then
        sendInfoMessage(message, 'YellowAiden')
    end
end

local function real_time()
    if G and G.TIMERS and G.TIMERS.REAL then
        return G.TIMERS.REAL
    end

    return 0
end

local function is_yellow_aiden_joker(card)
    local center = card and card.config and card.config.center

    return center
        and (
            center.key == YELLOW_AIDEN_JOKER_KEY
            or center.original_key == 'yellow_aiden'
        )
end

local function start_tv_noise_blink(card)
    if card and card.ability then
        card.ability.yellowaiden_tv_noise_until = real_time() + STATIC_SOUND_DURATION
    end
end

local function tv_noise_blink_is_active(card)
    if not (card and card.ability and card.ability.yellowaiden_tv_noise_until) then
        return false
    end

    if real_time() >= card.ability.yellowaiden_tv_noise_until then
        card.ability.yellowaiden_tv_noise_until = nil
        return false
    end

    return true
end

local function ensure_yellow_aiden_extra(card)
    if not (card and card.ability) then
        return {
            odds = DEFAULT_MUTATION_ODDS,
            countdown = MUTATION_GUARANTEE_BLINDS
        }
    end

    card.ability.extra = card.ability.extra or {}
    local odds = tonumber(card.ability.extra.odds) or DEFAULT_MUTATION_ODDS
    local saved_misses = tonumber(card.ability.extra.misses)
    local countdown = tonumber(card.ability.extra.countdown)
        or (saved_misses and (MUTATION_GUARANTEE_BLINDS - saved_misses))
        or MUTATION_GUARANTEE_BLINDS

    card.ability.extra.odds = math.max(1, math.min(odds, DEFAULT_MUTATION_ODDS))
    card.ability.extra.countdown = math.max(1, math.min(countdown, MUTATION_GUARANTEE_BLINDS))
    card.ability.extra.misses = nil

    return card.ability.extra
end

local function get_mutation_countdown(card)
    local extra = ensure_yellow_aiden_extra(card)

    if G and G.GAME then
        if G.GAME.yellowaiden_mutation_countdown == nil then
            G.GAME.yellowaiden_mutation_countdown = extra.countdown
        end

        return G.GAME.yellowaiden_mutation_countdown
    end

    return extra.countdown
end

local function set_mutation_countdown(card, countdown)
    local extra = ensure_yellow_aiden_extra(card)
    local clamped = math.max(1, math.min(countdown, MUTATION_GUARANTEE_BLINDS))
    extra.countdown = clamped

    if G and G.GAME then
        G.GAME.yellowaiden_mutation_countdown = clamped
    end
end

local function current_blind_key(context)
    if not (G and G.GAME and G.GAME.round_resets) then
        return nil
    end

    local blind = context and context.blind or G.GAME.blind or G.GAME.round_resets.blind
    local blind_key = blind and (blind.key or blind.name or blind.config and blind.config.blind and blind.config.blind.key) or 'blind'

    return tostring(G.GAME.round_resets.ante or 0) .. ':' .. tostring(blind_key)
end

local function already_rolled_this_blind(context)
    local key = current_blind_key(context)
    if not (key and G and G.GAME) then
        return false
    end

    return G.GAME.yellowaiden_last_roll_key == key
end

local function mark_rolled_this_blind(context)
    local key = current_blind_key(context)
    if key and G and G.GAME then
        G.GAME.yellowaiden_last_roll_key = key
    end
end

local function set_pending_mutation(context, pending)
    local key = current_blind_key(context)
    if key and G and G.GAME then
        G.GAME.yellowaiden_pending_mutation_key = pending and key or nil
    end
end

local function has_pending_mutation(context)
    local key = current_blind_key(context)
    if not (key and G and G.GAME) then
        return false
    end

    return G.GAME.yellowaiden_pending_mutation_key == key
end

local function is_corrupt_card(card)
    return card
        and card.base
        and card.base.suit == CORRUPT_SUIT
end

local function add_eligible_card(cards, seen, card)
    if card
        and not seen[card]
        and card.base
        and card.base.value
        and not is_corrupt_card(card)
        and not (card.ability and card.ability.eternal)
    then
        seen[card] = true
        cards[#cards + 1] = card
    end
end

local function add_eligible_cards_from_area(cards, seen, area)
    if not (area and area.cards) then
        return
    end

    for _, card in ipairs(area.cards) do
        add_eligible_card(cards, seen, card)
    end
end

local function eligible_cards_for_corruption(prefer_visible)
    local cards = {}
    local seen = {}

    if prefer_visible then
        add_eligible_cards_from_area(cards, seen, G and G.hand)
    end

    if G and G.playing_cards then
        for _, card in ipairs(G.playing_cards) do
            add_eligible_card(cards, seen, card)
        end
    end

    if not prefer_visible then
        add_eligible_cards_from_area(cards, seen, G and G.hand)
    end

    add_eligible_cards_from_area(cards, seen, G and G.deck)
    add_eligible_cards_from_area(cards, seen, G and G.discard)
    add_eligible_cards_from_area(cards, seen, G and G.play)

    return cards
end

local function corrupt_base_for_card(card)
    if not (card and card.base and card.base.value and SMODS and SMODS.Ranks and SMODS.Suits) then
        return nil
    end

    local rank = SMODS.Ranks[card.base.value]
    local suit = SMODS.Suits[CORRUPT_SUIT]
    if not (rank and suit and rank.card_key and suit.card_key and G and G.P_CARDS) then
        return nil
    end

    return G.P_CARDS[suit.card_key .. '_' .. rank.card_key]
end

-- exponent controls how aggressively values are skewed toward the low end.
-- Higher exponent = rarer high numbers. Default 4 makes >30 noticeably rarer
-- than the old exponent-3 curve. Pass a higher value (e.g. 8) for xmult,
-- where even moderate values are very powerful.
local function rare_corrupt_roll(seed, min_value, exponent)
    min_value = min_value or 1
    exponent = exponent or 4
    local roll = pseudorandom(seed)
    local span = CORRUPT_MAX_ROLL - min_value + 1

    return math.min(CORRUPT_MAX_ROLL, min_value + math.floor((roll ^ exponent) * span))
end

-- Returns a globally unique ID for each corrupted card within the current run.
local function get_next_corrupt_id()
    if G and G.GAME then
        G.GAME.yellowaiden_corrupt_count = (G.GAME.yellowaiden_corrupt_count or 0) + 1
        return tostring(G.GAME.yellowaiden_corrupt_count)
    end
    return tostring(math.random(999999))
end

-- Rolls and permanently stores the scoring effect for a corrupt card so that
-- each card has a fixed, displayable bonus from the moment it is mutated.
local function pre_roll_corrupt_effect(card)
    if not (card and card.ability) then return end

    -- Idempotent: skip if already rolled (e.g. loaded from a save).
    if card.ability.yellowaiden_corrupt_effect_type then return end

    local id = get_next_corrupt_id()
    card.ability.yellowaiden_corrupt_id = id
    local sp = 'yellowaiden_c' .. id .. '_'

    local effects = { 'chips', 'mult', 'xmult', 'money' }
    if not card.seal    then effects[#effects + 1] = 'seal'    end
    if not card.edition then effects[#effects + 1] = 'edition' end

    local effect = pseudorandom_element(effects, pseudoseed(sp .. 'fx'))
    card.ability.yellowaiden_corrupt_effect_type = effect

    if effect == 'chips' then
        local amt = rare_corrupt_roll(sp .. 'amt', 1, 4)
        card.ability.yellowaiden_corrupt_effect_amount = amt
        card.ability.yellowaiden_corrupt_label = '+' .. amt .. ' Chips'
    elseif effect == 'mult' then
        local amt = rare_corrupt_roll(sp .. 'amt', 1, 4)
        card.ability.yellowaiden_corrupt_effect_amount = amt
        card.ability.yellowaiden_corrupt_label = '+' .. amt .. ' Mult'
    elseif effect == 'xmult' then
        -- exponent 8: X2–X5 is typical, X10+ is uncommon, X30+ is very rare
        local amt = rare_corrupt_roll(sp .. 'amt', 2, 8)
        card.ability.yellowaiden_corrupt_effect_amount = amt
        card.ability.yellowaiden_corrupt_label = 'X' .. amt .. ' Mult'
    elseif effect == 'money' then
        local amt = rare_corrupt_roll(sp .. 'amt', 1, 4)
        card.ability.yellowaiden_corrupt_effect_amount = amt
        card.ability.yellowaiden_corrupt_label = '+$' .. amt
    elseif effect == 'seal' then
        local seals = { 'Red', 'Blue', 'Gold', 'Purple' }
        local seal = pseudorandom_element(seals, pseudoseed(sp .. 'seal'))
        card.ability.yellowaiden_corrupt_seal_type = seal
        card.ability.yellowaiden_corrupt_label = seal .. ' Seal'
    elseif effect == 'edition' then
        local editions = { 'foil', 'holo', 'polychrome' }
        local edition = pseudorandom_element(editions, pseudoseed(sp .. 'ed'))
        card.ability.yellowaiden_corrupt_edition_type = edition
        local edition_labels = { foil = 'Foil', holo = 'Holographic', polychrome = 'Polychrome' }
        card.ability.yellowaiden_corrupt_label = edition_labels[edition] or 'Edition'
    end
end

local function mutate_card_to_corrupt(card)
    if SMODS and SMODS.change_base then
        local changed_card, err = SMODS.change_base(card, CORRUPT_SUIT, card.base and card.base.value)
        if not changed_card then
            return false, err or 'missing_base'
        end
    else
        local corrupt_base = corrupt_base_for_card(card)
        if not corrupt_base then
            return false, 'missing_base'
        end

        card:set_base(corrupt_base)
    end

    card.ability = card.ability or {}
    card.ability.yellowaiden_corrupt = true
    pre_roll_corrupt_effect(card)
    play_registered_sound(STATIC_SOUND, 1, 0.8)

    if card.start_materialize then
        card:start_materialize({ G.C.GOLD }, nil, 0.7)
    elseif card.juice_up then
        card:juice_up(0.7, 0.7)
    end

    return true
end

local function pick_random_eligible_card(seed, prefer_visible)
    local cards = eligible_cards_for_corruption(prefer_visible)
    if #cards <= 0 then
        return nil
    end

    return pseudorandom_element(cards, pseudoseed(seed))
end

local function finish_mutation(card, context, prefer_visible)
    local seed = 'yellowaiden_corrupt_card' .. (current_blind_key(context) or '')
    local target = pick_random_eligible_card(seed, prefer_visible)
    if not target then
        return false, 'no_target'
    end

    local mutated, reason = mutate_card_to_corrupt(target)
    if not mutated then
        return false, reason
    end

    set_pending_mutation(context, false)
    set_mutation_countdown(card, MUTATION_GUARANTEE_BLINDS)
    start_tv_noise_blink(card)

    if card.juice_up then
        card:juice_up(0.8, 0.8)
    end

    if prefer_visible and G and G.hand then
        G.hand:sort()
    end

    return true
end

local function roll_for_mutation(card, context)
    if already_rolled_this_blind(context) then
        return nil
    end

    mark_rolled_this_blind(context)

    local countdown = get_mutation_countdown(card)
    local guaranteed = countdown <= 1
    local odds = ensure_yellow_aiden_extra(card).odds or DEFAULT_MUTATION_ODDS
    local rolled = guaranteed or pseudorandom('yellowaiden_corrupt_mutation' .. (current_blind_key(context) or '')) < (1 / odds)

    if not rolled then
        set_mutation_countdown(card, countdown - 1)
        yellowaiden_log('Mutation missed; guaranteed in ' .. tostring(get_mutation_countdown(card)) .. ' blind(s).')

        return {
            message = tostring(get_mutation_countdown(card)) .. ' Blind',
            colour = G.C.UI.TEXT_INACTIVE,
            card = card
        }
    end

    local mutated, reason = finish_mutation(card, context, context.first_hand_drawn)
    if mutated then
        yellowaiden_log('Mutation succeeded on ' .. tostring(current_blind_key(context) or 'unknown blind') .. '.')
        return {
            message = 'Corrupted!',
            colour = G.C.GOLD,
            card = card
        }
    end

    if reason == 'no_target' and context.setting_blind then
        set_pending_mutation(context, true)
        yellowaiden_log('Mutation queued until first hand draw; no target was available at blind selection.')
        return {
            message = 'Pending...',
            colour = G.C.GOLD,
            card = card
        }
    end

    yellowaiden_log('Mutation failed: ' .. tostring(reason or 'unknown reason') .. '.')
    return {
        message = reason == 'no_target' and 'No Target!' or 'No Base Card!',
        colour = G.C.RED,
        card = card
    }
end

local function corrupt_scoring_effect(card)
    local effect = card.ability and card.ability.yellowaiden_corrupt_effect_type
    local amount = card.ability and card.ability.yellowaiden_corrupt_effect_amount

    -- Fallback: cards that were corrupted before this version have no stored
    -- effect, so roll one now and cache it for future scoring events.
    if not effect then
        pre_roll_corrupt_effect(card)
        effect = card.ability and card.ability.yellowaiden_corrupt_effect_type
        amount = card.ability and card.ability.yellowaiden_corrupt_effect_amount
    end

    if effect == 'chips' then
        return {
            chips = amount,
            message = '+' .. amount .. ' Chips',
            colour = G.C.CHIPS,
            card = card
        }
    end

    if effect == 'mult' then
        return {
            mult = amount,
            message = '+' .. amount .. ' Mult',
            colour = G.C.MULT,
            card = card
        }
    end

    if effect == 'xmult' then
        return {
            x_mult = amount,
            message = 'X' .. amount .. ' Mult',
            colour = G.C.MULT,
            card = card
        }
    end

    if effect == 'money' then
        return {
            dollars = amount,
            message = '+$' .. amount,
            colour = G.C.MONEY,
            card = card
        }
    end

    if effect == 'seal' then
        if card.seal then return nil end
        local seal = card.ability.yellowaiden_corrupt_seal_type
        card:set_seal(seal, true, true)
        return {
            message = seal .. ' Seal',
            colour = G.C.GOLD,
            card = card
        }
    end

    if effect == 'edition' then
        if card.edition then return nil end
        local edition = card.ability.yellowaiden_corrupt_edition_type
        card:set_edition({ [edition] = true }, true, false)
        return {
            message = 'Edition!',
            colour = G.C.DARK_EDITION,
            card = card
        }
    end
end

register_sound('static', 'static.mp3')

SMODS.Shader {
    key = TV_NOISE_SHADER,
    path = 'tv_noise.fs',
    prefix_config = { key = false }
}

SMODS.DrawStep {
    key = 'yellowaiden_tv_noise_blink',
    prefix_config = { key = false },
    order = 21,
    func = function(card, layer)
        if not (is_yellow_aiden_joker(card) and tv_noise_blink_is_active(card)) then
            return
        end

        if math.floor(real_time() * TV_NOISE_BLINK_RATE) % 2 ~= 0 then
            return
        end

        local shader_send = { real_time(), TV_NOISE_ALPHA }

        if card.children and card.children.center then
            card.children.center:draw_shader(TV_NOISE_SHADER, nil, shader_send)
        end

        if card.children
            and card.children.front
            and (card.ability.delayed or not card:should_hide_front())
        then
            card.children.front:draw_shader(TV_NOISE_SHADER, nil, shader_send)
        end
    end,
    conditions = { vortex = false, facing = 'front' }
}

SMODS.Atlas {
    key = 'yellowaiden_Jokers',
    path = 'yellowaiden_Jokers.png',
    px = 71,
    py = 95,
    prefix_config = { key = false }
}

SMODS.Atlas {
    key = 'yellowaiden_CorruptDeck',
    path = 'yellowaiden_CorruptDeck.png',
    px = 71,
    py = 95,
    prefix_config = { key = false }
}

SMODS.Suit {
    key = CORRUPT_SUIT,
    card_key = 'yellowaiden_' .. CORRUPT_CARD_PREFIX,
    prefix_config = { key = false, card_key = false, atlas = false },
    pos = { y = 0 },
    ui_pos = { x = 0, y = 0 },
    lc_atlas = 'yellowaiden_CorruptDeck',
    hc_atlas = 'yellowaiden_CorruptDeck',
    lc_ui_atlas = 'yellowaiden_CorruptDeck',
    hc_ui_atlas = 'yellowaiden_CorruptDeck',
    lc_colour = HEX('D8B500'),
    hc_colour = HEX('FFD84D'),
    loc_txt = {
        singular = 'Corruption',
        plural = 'Corruption',
        description = {
            name = 'Corruption',
            text = {
                'When scored:',
                '{C:attention}#1#{}'
            }
        }
    },
    loc_vars = function(self, info_queue, card)
        local label = card and card.ability and card.ability.yellowaiden_corrupt_label or '???'
        return { vars = { label } }
    end,
    in_pool = function(self, args)
        return false
    end
}

BalatroAidenMod.add_calculate(function(self, context)
    if context.individual
        and context.cardarea == G.play
        and context.other_card
        and is_corrupt_card(context.other_card)
        and not context.repetition
    then
        return corrupt_scoring_effect(context.other_card)
    end
end)

SMODS.Joker {
    key = YELLOW_AIDEN_JOKER_KEY,
    prefix_config = { key = false, atlas = false },
    loc_txt = {
        name = 'Yellow Aiden',
        text = {
            '{C:green}#1# in #2#{} chance',
            'when a {C:attention}Blind{} is selected',
            'to mutate a random card',
            'in your deck into {C:gold}Corruption{}',
            '{C:inactive}Guaranteed in #3# Blind(s){}',
            '{C:inactive}Corruption rolls can reach 100{}'
        }
    },
    config = {
        extra = {
            odds = DEFAULT_MUTATION_ODDS,
            countdown = MUTATION_GUARANTEE_BLINDS
        }
    },
    loc_vars = function(self, info_queue, card)
        local extra = card and ensure_yellow_aiden_extra(card) or self.config.extra
        local odds = math.max(1, math.min(tonumber(extra.odds) or DEFAULT_MUTATION_ODDS, DEFAULT_MUTATION_ODDS))
        local countdown = card and get_mutation_countdown(card) or (extra.countdown or MUTATION_GUARANTEE_BLINDS)

        return {
            vars = { 1, odds, countdown }
        }
    end,
    atlas = 'yellowaiden_Jokers',
    rarity = 3,
    cost = 8,
    unlocked = true,
    discovered = true,
    blueprint_compat = true,
    eternal_compat = true,
    perishable_compat = true,
    pos = { x = 0, y = 0 },
    calculate = function(self, card, context)
        if not (card and card.ability) then
            return
        end

        ensure_yellow_aiden_extra(card)

        if context.first_hand_drawn and has_pending_mutation(context) then
            local mutated, reason = finish_mutation(card, context, true)
            if mutated then
                return {
                    message = 'Corrupted!',
                    colour = G.C.GOLD,
                    card = card
                }
            end

            return {
                message = reason == 'no_target' and 'No Target!' or 'No Base Card!',
                colour = G.C.RED,
                card = card
            }
        end

        if context.setting_blind or context.first_hand_drawn then
            return roll_for_mutation(card, context)
        end
    end
}
