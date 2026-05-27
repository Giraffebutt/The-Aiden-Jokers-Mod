local GREEN_AIDEN_KEY = 'j_greenaiden_green_aiden'
local POOP_SEAL_KEY = 'greenaiden_poop'
local POOP_MULT_PER_BLIND = 3
local POOP_MULT_MAX = 20
local APPLY_NUMERATOR = 2
local APPLY_DENOMINATOR = 3

local function current_blind_key(context)
    if not (G and G.GAME and G.GAME.round_resets) then
        return nil
    end

    local blind = context and context.blind or G.GAME.blind or G.GAME.round_resets.blind
    local blind_key = blind and (blind.key or blind.name or blind.config and blind.config.blind and blind.config.blind.key) or 'blind'

    return tostring(G.GAME.round_resets.ante or 0) .. ':' .. tostring(blind_key)
end

local function is_green_aiden_joker(card)
    local center = card and card.config and card.config.center

    return center
        and (
            center.key == GREEN_AIDEN_KEY
            or center.original_key == 'green_aiden'
        )
end

local function is_joker(card)
    return card
        and card.ability
        and card.ability.set == 'Joker'
        and card.config
        and card.config.center
end

local function has_poop_seal(card)
    return card and card.seal == POOP_SEAL_KEY
end

local function can_receive_poop_seal(source, target)
    return is_joker(target)
        and target ~= source
        and not target.getting_sliced
        and not target.seal
        and not is_green_aiden_joker(target)
end

local function eligible_jokers_for_poop(source)
    local eligible = {}

    if not (G and G.jokers and G.jokers.cards) then
        return eligible
    end

    for _, joker in ipairs(G.jokers.cards) do
        if can_receive_poop_seal(source, joker) then
            eligible[#eligible + 1] = joker
        end
    end

    return eligible
end

local function ensure_poop_mult(card)
    if not (card and card.ability) then
        return 0
    end

    card.ability.greenaiden_poop_mult = card.ability.greenaiden_poop_mult or 0
    return card.ability.greenaiden_poop_mult
end

local function clear_poop_seal(card)
    if not (card and card.ability) then
        return
    end

    if card.set_seal then
        card:set_seal(nil, true, true)
    else
        card.seal = nil
    end

    card.ability.seal = {}
    card.ability.greenaiden_poop_mult = nil
    card.ability.greenaiden_poop_last_blind = nil
    card.ability.greenaiden_poop_remove_after_score = nil
end

local function add_poop_mult_for_blind(card, context)
    if not (card and card.ability) then
        return false
    end

    local blind_key = current_blind_key(context)
    if not blind_key or card.ability.greenaiden_poop_last_blind == blind_key then
        return false
    end

    card.ability.greenaiden_poop_last_blind = blind_key
    local current_mult = ensure_poop_mult(card)
    if current_mult >= POOP_MULT_MAX then
        card.ability.greenaiden_poop_remove_after_score = true
        return false
    end

    local new_mult = math.min(current_mult + POOP_MULT_PER_BLIND, POOP_MULT_MAX)
    local gained_mult = new_mult - current_mult
    card.ability.greenaiden_poop_mult = new_mult

    if new_mult >= POOP_MULT_MAX then
        card.ability.greenaiden_poop_remove_after_score = true
    end

    card_eval_status_text(card, 'extra', nil, nil, nil, {
        message = '+' .. tostring(gained_mult) .. ' Mult',
        colour = G.C.MULT
    })

    return true
end

local function poop_scoring_effect(card, context)
    if not (context and context.joker_main and has_poop_seal(card)) then
        return nil
    end

    local mult = ensure_poop_mult(card)
    if mult <= 0 then
        return nil
    end

    local effect = {
        mult = mult,
        message = localize { type = 'variable', key = 'a_mult', vars = { mult } },
        colour = G.C.MULT,
        card = context.blueprint_card or card
    }

    if card.ability.greenaiden_poop_remove_after_score and not context.blueprint then
        effect.extra = {
            message = 'Poop Gone!',
            colour = G.C.UI.TEXT_INACTIVE,
            card = context.blueprint_card or card,
            func = function()
                clear_poop_seal(card)
            end
        }
    end

    return effect
end

local function append_extra_effect(base, extra)
    if not extra then
        return base
    end

    if not base then
        return extra
    end

    local cursor = base
    while type(cursor.extra) == 'table' do
        cursor = cursor.extra
    end
    cursor.extra = extra

    return base
end

local calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context, ...)
    local ret, post = calculate_joker_ref(self, context, ...)

    if has_poop_seal(self) then
        if context and context.setting_blind then
            add_poop_mult_for_blind(self, context)
        end

        ret = append_extra_effect(ret, poop_scoring_effect(self, context))
    end

    return ret, post
end

local function apply_poop_seal(source, context)
    local eligible = eligible_jokers_for_poop(source)
    if #eligible <= 0 then
        return {
            message = 'No Target!',
            colour = G.C.UI.TEXT_INACTIVE,
            card = source
        }
    end

    local seed = 'greenaiden_poop_seal' .. (current_blind_key(context) or '') .. ':' .. tostring(#eligible)
    local target = pseudorandom_element(eligible, pseudoseed(seed))

    if not (target and target.set_seal and G and G.P_SEALS and G.P_SEALS[POOP_SEAL_KEY]) then
        return {
            message = 'No Seal!',
            colour = G.C.UI.TEXT_INACTIVE,
            card = source
        }
    end

    target.ability.greenaiden_poop_mult = 0
    target.ability.greenaiden_poop_last_blind = nil
    target.ability.greenaiden_poop_remove_after_score = nil

    target:set_seal(POOP_SEAL_KEY, nil, true)
    add_poop_mult_for_blind(target, context)

    return {
        message = 'Poop Seal!',
        colour = G.C.GREEN,
        card = source
    }
end

SMODS.Atlas {
    key = 'greenaiden_Jokers',
    path = 'greenaiden_Jokers.png',
    px = 71,
    py = 95,
    prefix_config = { key = false }
}

SMODS.Atlas {
    key = 'greenaiden_PoopSeal',
    path = 'greenaiden_PoopSeal.png',
    px = 71,
    py = 95,
    prefix_config = { key = false }
}

SMODS.Sound {
    key = 'greenaiden_perfect_fart',
    path = 'perfect-fart.ogg',
    prefix_config = { key = false }
}

SMODS.Seal {
    key = POOP_SEAL_KEY,
    atlas = 'greenaiden_PoopSeal',
    prefix_config = { key = false, atlas = false },
    pos = { x = 0, y = 0 },
    badge_colour = HEX('6b4a24'),
    text_colour = G.C.WHITE,
    discovered = true,
    weight = 0,
    sound = {
        sound = 'greenaiden_perfect_fart',
        per = 1,
        vol = 0.5
    },
    loc_txt = {
        name = 'Poop Seal',
        label = 'Poop Seal',
        text = {
            'Gains {C:mult}+#1#{} Mult',
            'at the start of each blind',
            'disappears after scoring at {C:mult}+#3#{} Mult',
            '{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)'
        }
    },
    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                POOP_MULT_PER_BLIND,
                ensure_poop_mult(card),
                POOP_MULT_MAX
            }
        }
    end
}

SMODS.Joker {
    key = GREEN_AIDEN_KEY,
    prefix_config = { key = false, atlas = false },
    loc_txt = {
        name = 'Green Aiden',
        text = {
            'At the start of each blind,',
            '{C:green}#1# in #2#{} chance to give',
            'a random other {C:attention}Joker{}',
            'a {C:attention}Poop Seal{}',
            '{C:inactive}Poop Seal caps at +20 Mult{}',
            '{C:inactive}Poop Seal cannot stack{}'
        }
    },
    atlas = 'greenaiden_Jokers',
    pos = { x = 0, y = 0 },
    rarity = 2,
    cost = 6,
    unlocked = true,
    discovered = true,
    blueprint_compat = true,
    eternal_compat = true,
    perishable_compat = true,
    config = {
        extra = {
            numerator = APPLY_NUMERATOR,
            denominator = APPLY_DENOMINATOR,
            poop_mult = POOP_MULT_PER_BLIND
        }
    },
    loc_vars = function(self, info_queue, card)
        local extra = card and card.ability and card.ability.extra or self.config.extra

        return {
            vars = {
                extra.numerator or APPLY_NUMERATOR,
                extra.denominator or APPLY_DENOMINATOR
            }
        }
    end,
    calculate = function(self, card, context)
        if not (context and context.setting_blind) then
            return nil
        end

        local blind_key = current_blind_key(context)
        if not blind_key or card.ability.greenaiden_last_poop_roll == blind_key then
            return nil
        end
        card.ability.greenaiden_last_poop_roll = blind_key

        if #eligible_jokers_for_poop(card) <= 0 then
            return {
                message = 'No Target!',
                colour = G.C.UI.TEXT_INACTIVE,
                card = card
            }
        end

        local extra = card.ability.extra or self.config.extra
        local numerator = extra.numerator or APPLY_NUMERATOR
        local denominator = extra.denominator or APPLY_DENOMINATOR
        local seed = 'greenaiden_poop_roll' .. blind_key

        if SMODS.pseudorandom_probability(card, seed, numerator, denominator, 'greenaiden_poop') then
            return apply_poop_seal(card, context)
        end

        return {
            message = 'No Poop!',
            colour = G.C.UI.TEXT_INACTIVE,
            card = card
        }
    end
}
